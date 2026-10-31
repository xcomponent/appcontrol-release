#!/usr/bin/env bash
# Validate a deployed AppControl release on a real OpenShift cluster.
# The test exercises: Route -> frontend proxy -> backend -> gateway -> agent ->
# start/check/stop commands.
set -euo pipefail
umask 077
CURL_TLS=()
if [[ -n "${ROUTE_CA_FILE:-}" ]]; then CURL_TLS=(--cacert "$ROUTE_CA_FILE"); fi

NAMESPACE="${NAMESPACE:?NAMESPACE is required}"
RELEASE="${RELEASE:-appcontrol-e2e}"
ADMIN_EMAIL="${ADMIN_EMAIL:?ADMIN_EMAIL is required}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:?ADMIN_PASSWORD is required}"
AGENT_IMAGE="${AGENT_IMAGE:?AGENT_IMAGE is required}"
TIMEOUT="${TIMEOUT:-300}"
OC="${OC:-oc}"
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

log() { echo "[OpenShift E2E] $*"; }
ok() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*" >&2; }

route_host=$("$OC" -n "$NAMESPACE" get route "$RELEASE" -o jsonpath='{.spec.host}')
base_url="https://${route_host}"

wait_for_url() {
  local url="$1"
  local deadline=$((SECONDS + TIMEOUT))
  until curl --fail --silent --show-error "${CURL_TLS[@]}" "$url" >/dev/null; do
    if (( SECONDS >= deadline )); then
      echo "Timed out waiting for $url" >&2
      return 1
    fi
    sleep 5
  done
}

api() {
  local method="$1"
  local path="$2"
  shift 2
  curl --fail --silent --show-error "${CURL_TLS[@]}" \
    --request "$method" \
    --header "Authorization: Bearer $token" \
    --header "Content-Type: application/json" \
    "${base_url}/api/v1${path}" "$@"
}

api_code() {
  local method="$1"
  local path="$2"
  shift 2
  curl --silent --output /dev/null --write-out '%{http_code}' "${CURL_TLS[@]}" \
    --request "$method" \
    --header "Authorization: Bearer $token" \
    --header "Content-Type: application/json" \
    "${base_url}/api/v1${path}" "$@"
}

wait_component_state() {
  local app_id="$1"
  local component_name="$2"
  local expected="$3"
  local timeout="${4:-60}"
  local deadline=$((SECONDS + timeout))
  local current
  while (( SECONDS < deadline )); do
    current=$(api GET "/apps/${app_id}" |
      jq -r --arg name "$component_name" \
        '.components[]? | select(.name == $name) | (.current_state // .state // "UNKNOWN")')
    if [[ "$current" == "$expected" ]]; then
      return 0
    fi
    sleep 3
  done
  return 1
}

echo "Waiting for AppControl through OpenShift Route ${route_host}"
wait_for_url "${base_url}/health"

login=$(curl --fail --silent --show-error "${CURL_TLS[@]}" \
  --request POST \
  --header "Content-Type: application/json" \
  --data "$(jq -nc --arg email "$ADMIN_EMAIL" --arg password "$ADMIN_PASSWORD" \
    '{email:$email,password:$password}')" \
  "${base_url}/api/v1/auth/login")
token=$(jq -er '.token' <<<"$login")

pki_code=$(api_code POST "/pki/init" --data '{"org_name":"OpenShift qualification"}')
[[ "$pki_code" == "200" || "$pki_code" == "409" ]] || { fail "PKI initialization failed: $pki_code"; exit 1; }
gateway_cert=$(api POST "/pki/server-cert" --data "$(jq -nc --arg host "${RELEASE}-gateway" '{common_name:$host,san_dns:[$host],validity_days:1}')")
jq --arg name "${RELEASE}-gateway-tls" --arg ns "$NAMESPACE" \
  '{apiVersion:"v1",kind:"Secret",metadata:{name:$name,namespace:$ns},type:"Opaque",stringData:{"gateway.crt":.cert_pem,"gateway.key":.key_pem,"pki-ca.crt":.ca_pem}}' <<<"$gateway_cert" | "$OC" apply -f -
unset gateway_cert

gateway_token=$(api POST "/enrollment/tokens" \
  --data '{"name":"openshift-e2e-gateway","scope":"gateway","valid_hours":1}' |
  jq -er '.token')

"$OC" -n "$NAMESPACE" create secret generic "${RELEASE}-gateway-enrollment" \
  --from-literal=token="$gateway_token" \
  --dry-run=client -o yaml | "$OC" apply -f -
helm upgrade "$RELEASE" "$REPO_ROOT/helm/appcontrol" \
  --namespace "$NAMESPACE" \
  --reuse-values \
  --set "gateway.enrollment.existingSecret=${RELEASE}-gateway-enrollment" \
  --set "gateway.tls.enabled=true" \
  --set "gateway.tls.existingSecret=${RELEASE}-gateway-tls" \
  --wait --timeout "${TIMEOUT}s"

gateway_id=""
deadline=$((SECONDS + TIMEOUT))
while (( SECONDS < deadline )); do
  gateway_id=$(api GET "/gateways" |
    jq -r '
      if (.sites? | type) == "array" then
        [.sites[]?.gateways[]?][0].id // empty
      elif (.gateways? | type) == "array" then
        .gateways[0].id // empty
      elif type == "array" then
        .[0].id // empty
      else
        empty
      end
    ')
  [[ -n "$gateway_id" ]] && break
  sleep 3
done
[[ -n "$gateway_id" ]]
api POST "/gateways/${gateway_id}/activate" --data '{}' >/dev/null || true

agent_token=$(api POST "/enrollment/tokens" \
  --data '{"name":"openshift-e2e-agent","scope":"agent","max_uses":2,"valid_hours":1}' |
  jq -er '.token')
"$OC" -n "$NAMESPACE" create secret generic "${RELEASE}-agent-enrollment" \
  --from-literal=token="$agent_token" \
  --dry-run=client -o yaml | "$OC" apply -f -

cat <<EOF | "$OC" apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${RELEASE}-e2e-agent
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: appcontrol
    app.kubernetes.io/instance: ${RELEASE}
    app.kubernetes.io/component: e2e-agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: ${RELEASE}
      app.kubernetes.io/component: e2e-agent
  template:
    metadata:
      labels:
        app.kubernetes.io/name: appcontrol
        app.kubernetes.io/instance: ${RELEASE}
        app.kubernetes.io/component: e2e-agent
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: agent
          image: ${AGENT_IMAGE}
          imagePullPolicy: Always
          args:
            - --config
            - /var/lib/appcontrol/agent.yaml
            - --enroll
            - wss://${RELEASE}-gateway:4443
            - --enroll-dir
            - /var/lib/appcontrol
            - --bootstrap-token-file
            - /var/run/secrets/appcontrol/token
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
          env:
            - name: ENROLLMENT_CA_FILE
              value: /trusted/ca.crt
            - name: AGENT_HOSTNAME
              value: openshift-e2e-agent
            - name: RUST_LOG
              value: info
          volumeMounts:
            - name: enrollment-ca
              mountPath: /trusted
              readOnly: true
            - name: data
              mountPath: /data
            - name: config
              mountPath: /var/lib/appcontrol
            - name: enrollment
              mountPath: /var/run/secrets/appcontrol
              readOnly: true
      volumes:
        - name: enrollment-ca
          secret:
            secretName: ${RELEASE}-gateway-tls
            items:
              - key: pki-ca.crt
                path: ca.crt
        - name: data
          emptyDir: {}
        - name: config
          emptyDir: {}
        - name: enrollment
          secret:
            secretName: ${RELEASE}-agent-enrollment
EOF

"$OC" -n "$NAMESPACE" rollout status "deployment/${RELEASE}-e2e-agent" \
  --timeout="${TIMEOUT}s"

agent_id=""
deadline=$((SECONDS + TIMEOUT))
while (( SECONDS < deadline )); do
  agent_id=$(api GET "/agents" |
    jq -r '[.agents // . | if type == "array" then .[] else empty end] |
      map(select(.hostname == "openshift-e2e-agent" or .id == "openshift-e2e-agent")) |
      .[0].id // empty')
  [[ -n "$agent_id" ]] && break
  sleep 3
done
[[ -n "$agent_id" ]]

refresh_agent_config() {
  log "Waiting for the live OpenShift agent configuration update..."
  local deadline=$((SECONDS + 60))
  local agent_logs
  while (( SECONDS < deadline )); do
    agent_logs=$("$OC" -n "$NAMESPACE" logs \
      "deployment/${RELEASE}-e2e-agent" --since=2m 2>&1 || true)
    if grep -q "Received config update" <<<"$agent_logs"; then
      ok "Agent component configuration refreshed"
      return 0
    fi
    sleep 2
  done
  fail "Agent did not receive its component configuration"
  return 1
}

# shellcheck source=../tests/e2e-command-cycle.sh
source "$REPO_ROOT/tests/e2e-command-cycle.sh"
run_appcontrol_command_cycle "$agent_id" "openshift"

echo "OpenShift E2E passed: Route, API, gateway, agent and command execution are operational."
