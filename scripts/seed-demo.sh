#!/usr/bin/env bash
# scripts/seed-demo.sh
#
# Seeds the running AppControl stack with the Core Banking System demo
# application from examples/banking-core-system.json. Used by the
# documentation screenshot pipeline and by anyone who wants a demo
# environment with realistic data.
#
# Idempotent: if the demo app is already present, the import is skipped.

set -euo pipefail

BACKEND_URL="${BACKEND_URL:-http://localhost:3000}"
ADMIN_EMAIL="${SEED_ADMIN_EMAIL:-admin@localhost}"
ADMIN_PASSWORD="${SEED_ADMIN_PASSWORD:-admin}"
EXAMPLE_FILE="${EXAMPLE_FILE:-/workspace/examples/banking-core-system.json}"
DEMO_APP_NAME="${DEMO_APP_NAME:-Core Banking System}"
DEMO_AGENT_HOSTNAME="${DEMO_AGENT_HOSTNAME:-demo-host}"
DEMO_SITE_NAME="${DEMO_SITE_NAME:-Default}"
DEMO_SITE_CODE="${DEMO_SITE_CODE:-default}"
DEMO_SITE_LOCATION="${DEMO_SITE_LOCATION:-}"
TOKEN_OUT="${TOKEN_OUT:-/workspace/state/enrollment-token}"

log() { echo "[seed-demo] $*"; }
fail() { echo "[seed-demo] ERROR: $*" >&2; exit 1; }

# api_call METHOD PATH [JSON_BODY] [EXTRA_CURL_ARGS...]
# Performs the call, prints the response body to stdout on success, and
# exits 1 with the response body on stderr on any non-2xx status. This
# replaces "curl -sf" so callers always know why an HTTP call failed.
api_call() {
  local method=$1 path=$2 body=""
  shift 2
  # The body is optional. A following curl flag must remain an argument,
  # and a two-argument GET must never pass METHOD/PATH as additional URLs.
  if [ "$#" -gt 0 ] && [[ "$1" != -* ]]; then
    body=$1
    shift
  fi
  local tmp http_code resp_body
  tmp=$(mktemp)
  # Keep one nonempty array; empty-array expansion under set -u also fails
  # with the Bash 3.2 supplied by macOS.
  local -a curl_args=(-sS -o "$tmp" -w "%{http_code}" -X "$method" "${BACKEND_URL}${path}")
  if [ -n "${AUTH_TOKEN:-}" ]; then
    curl_args+=(-H "Authorization: Bearer $AUTH_TOKEN")
  fi
  if [ -n "$body" ]; then
    curl_args+=(-H "Content-Type: application/json" -d "$body")
  fi
  if [ "$#" -gt 0 ]; then
    curl_args+=("$@")
  fi

  if ! http_code=$(curl "${curl_args[@]}"); then
    rm -f "$tmp"
    log "[$method $path] connection failed" >&2
    return 22
  fi
  resp_body=$(cat "$tmp")
  rm -f "$tmp"

  if [[ ! "$http_code" =~ ^[0-9]{3}$ ]]; then
    log "[$method $path] invalid HTTP status" >&2
    return 22
  fi
  if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
    log "[$method $path] HTTP $http_code" >&2
    log "  response: $resp_body" >&2
    return 22
  fi
  printf '%s' "$resp_body"
}

# 1. Wait for backend health
log "Waiting for backend at $BACKEND_URL ..."
for i in $(seq 1 60); do
  if curl -sf "$BACKEND_URL/health" >/dev/null 2>&1; then
    log "Backend healthy after ${i}s"
    break
  fi
  if [ "$i" = "60" ]; then
    fail "Backend not healthy after 120s"
  fi
  sleep 2
done

# 2. Login
log "Logging in as $ADMIN_EMAIL"
LOGIN_PAYLOAD=$(jq -n --arg e "$ADMIN_EMAIL" --arg p "$ADMIN_PASSWORD" \
  '{email: $e, password: $p}')
LOGIN_RESPONSE=$(api_call POST /api/v1/auth/login "$LOGIN_PAYLOAD") \
  || fail "Login failed (see HTTP body above)"
AUTH_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token // empty')
[ -n "$AUTH_TOKEN" ] || fail "No token in login response: $LOGIN_RESPONSE"
log "Logged in"

# 3. Ensure at least one site exists in the org.
SITES_RESPONSE=$(api_call GET /api/v1/sites '') \
  || fail "Listing sites failed (see HTTP body above)"
SITE_COUNT=$(echo "$SITES_RESPONSE" | jq -r '(.sites // .) | length' 2>/dev/null || echo 0)
log "Sites in org: $SITE_COUNT"
if [ "${SITE_COUNT:-0}" = "0" ]; then
  log "Creating primary demo site '$DEMO_SITE_NAME'"
  SITE_PAYLOAD=$(jq -n --arg name "$DEMO_SITE_NAME" --arg code "$DEMO_SITE_CODE" \
    --arg location "$DEMO_SITE_LOCATION" \
    '{name:$name,code:$code,site_type:"primary",location:(if $location == "" then null else $location end)}')
  api_call POST /api/v1/sites "$SITE_PAYLOAD" >/dev/null \
    || fail "Creating default site failed"
fi

# 4. Import the demo app (idempotent)
APPS_RESPONSE=$(api_call GET /api/v1/apps '') \
  || fail "Listing apps failed"
EXISTING=$(echo "$APPS_RESPONSE" \
  | jq -r --arg n "$DEMO_APP_NAME" '.apps[] | select(.name == $n) | .id' \
  | head -n 1)

if [ -n "$EXISTING" ]; then
  log "Demo app '$DEMO_APP_NAME' already exists ($EXISTING). Skipping import."
else
  [ -f "$EXAMPLE_FILE" ] || fail "Example file not found: $EXAMPLE_FILE"
  log "Importing $EXAMPLE_FILE (hosts → '$DEMO_AGENT_HOSTNAME')"

  REWRITTEN=$(jq --arg h "$DEMO_AGENT_HOSTNAME" '
    if (.application.components? | type) == "array" then
      .application.components |= map(.host = $h)
    else
      {
        format_version: "4.0",
        application: (
          .components |= map(
          # Force every component onto our single demo agent.
          .host = $h
          # The v4 import expects commands nested under .commands as
          # { check: {cmd}, start: {cmd}, stop: {cmd}, integrity_check: ...}.
          # The example uses the flat shell-style fields. Wrap them.
          | .commands = {
              check: (if .check_cmd            then {cmd: .check_cmd}            else null end),
              start: (if .start_cmd            then {cmd: .start_cmd}            else null end),
              stop:  (if .stop_cmd             then {cmd: .stop_cmd}             else null end),
              integrity_check: (if .integrity_check_cmd then {cmd: .integrity_check_cmd} else null end),
              infra_check:     (if .infra_check_cmd     then {cmd: .infra_check_cmd}     else null end),
              rebuild:         (if .rebuild_cmd         then {cmd: .rebuild_cmd}         else null end)
            }
          # Drop the flat *_cmd siblings — V4Component#[serde(deny_unknown)]
          # would not error here, but we keep the payload clean.
          | del(.check_cmd, .start_cmd, .stop_cmd,
                .integrity_check_cmd, .infra_check_cmd, .rebuild_cmd)
        )
          | .tags = (
            if (.tags | type) == "object" then
              (.tags | to_entries | map(.key + "=" + (.value | tostring)))
            else (.tags // [])
            end
            )
        )
      }
    end
  ' "$EXAMPLE_FILE")

  IMPORT_PAYLOAD=$(jq -n --arg json "$REWRITTEN" '{json: $json}')
  IMPORT_RESPONSE=$(api_call POST /api/v1/import/json "$IMPORT_PAYLOAD") \
    || fail "Import failed (see HTTP body above)"
  APP_ID=$(echo "$IMPORT_RESPONSE" | jq -r '.application_id // .app_id // .id // empty')
  log "Imported demo app: ${APP_ID:-?}"
fi

# 5. Provision an enrollment token for the demo agent
mkdir -p "$(dirname "$TOKEN_OUT")"
# Bootstrap trust comes from the authenticated control plane, never from an
# unverified enrollment connection. Share only the public CA with demo agents.
api_call GET /api/v1/pki/ca | jq -er '.ca_cert_pem' > "$(dirname "$TOKEN_OUT")/enrollment-ca.crt"
TOKEN_USABLE=false
if [ -s "$TOKEN_OUT" ]; then
  TOKENS=$(api_call GET /api/v1/enrollment/tokens '') || fail "Cannot validate cached enrollment token"
  if jq -e --rawfile cached "$TOKEN_OUT" '
    .tokens | any(.scope == "agent" and .revoked_at == null
      and .token_prefix == ($cached[0:18])
      and (.max_uses == null or .current_uses < .max_uses)
      and ((.expires_at | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601) > (now + 300)))
  ' <<<"$TOKENS" >/dev/null; then
    TOKEN_USABLE=true
  fi
fi
if [ "$TOKEN_USABLE" = true ]; then
  log "Cached enrollment token remains valid — retaining it"
else
  log "Creating enrollment token for the demo agents (missing, expired, revoked or exhausted cache)"
  TOKEN_RESPONSE=$(api_call POST /api/v1/enrollment/tokens \
    '{"name":"demo-agent","scope":"agent","valid_hours":168}') \
    || fail "Creating enrollment token failed (see HTTP body above)"
  ENROLL_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token // empty')
  [ -n "$ENROLL_TOKEN" ] || fail "No token in response: $TOKEN_RESPONSE"
  printf '%s' "$ENROLL_TOKEN" > "$TOKEN_OUT"
  chmod 600 "$TOKEN_OUT" 2>/dev/null || true
  log "Enrollment token written to $TOKEN_OUT"
fi

log "Done."
