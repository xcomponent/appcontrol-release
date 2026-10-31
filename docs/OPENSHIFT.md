# Deploying and testing AppControl on OpenShift

The Helm chart in `helm/appcontrol` is the single source of truth for both
Kubernetes and OpenShift. The OpenShift profile adds a TLS Route, disables
Ingress, and leaves UID/GID selection to the namespace Security Context
Constraint (SCC).

## What is tested

The `OpenShift` GitHub Actions workflow has two levels:

1. Every relevant pull request renders and lints the chart, checks the Route,
   and rejects fixed UIDs/GIDs, privileged containers, or incomplete
   `restricted-v2` security contexts.
2. Manual and scheduled runs deploy AppControl to a real OpenShift cluster,
   verify the SCC selected by admission, deploy an agent, and execute the same
   start/check/stop/restart scenario as the local full-stack E2E test.

The CI does not install an OpenShift cluster inside a GitHub-hosted runner.
OpenShift Local requires a virtual machine and is not suitable for nested
virtualization there. Instead, the workflow connects to an existing cluster.

## Red Hat Developer Sandbox

The no-cost Red Hat Developer Sandbox is suitable for this E2E job. It is a
shared, quota-limited trial environment, so use one dedicated project and let
the workflow remove its release after every run.

1. Start a sandbox from
   [Red Hat Developer Sandbox](https://developers.redhat.com/developer-sandbox).
2. In the OpenShift console, open **Copy login command**, then **Display Token**.
3. Record the three values shown by:

   ```bash
   oc whoami --show-server
   oc whoami -t
   oc project -q
   ```

4. In the GitHub repository, create these Actions secrets:

   | Secret | Value |
   |---|---|
   | `OPENSHIFT_SERVER` | Output of `oc whoami --show-server` |
   | `OPENSHIFT_TOKEN` | Output of `oc whoami -t` |
   | `OPENSHIFT_NAMESPACE` | Output of `oc project -q` |

Tokens and sandbox instances expire. Replace `OPENSHIFT_TOKEN` when login
starts failing, and update all three values when a new sandbox is provisioned.

## Launch the CI deployment

After the workflow is present on GitHub:

1. Open **Actions → OpenShift**.
2. Select **Run workflow**.
3. Select the branch to test.
4. Follow the `Real OpenShift deployment and execution` job.

The normal `CI / Docker Build` matrix builds backend, frontend, gateway, and
agent once, in parallel, and publishes immutable SHA-tagged images to GHCR.
The OpenShift job verifies and consumes those exact images; it does not rebuild
them. It then creates short-lived secrets, installs the chart, runs the E2E
scenario, uploads diagnostics on failure, and removes only resources belonging
to its `appcontrol-e2e` release.

Scheduled workflows run only from the default branch. The weekly schedule
therefore becomes active after this change is merged into `main`.

## Manual Helm deployment

Production deployments should use an external or operator-managed PostgreSQL
database. Create secrets without placing credentials in a values file:

```bash
oc create secret generic appcontrol-database \
  --from-literal=database-url='postgresql://USER:PASSWORD@HOST:5432/appcontrol'

oc create secret generic appcontrol-jwt \
  --from-literal=jwt-secret="$(openssl rand -hex 48)"
```

Deploy:

```bash
helm upgrade --install appcontrol helm/appcontrol \
  --namespace "$(oc project -q)" \
  -f helm/appcontrol/values-openshift.yaml \
  --set backend.database.existingSecret=appcontrol-database \
  --set backend.jwt.existingSecret=appcontrol-jwt \
  --set backend.image.repository=REGISTRY/appcontrol-backend \
  --set frontend.image.repository=REGISTRY/appcontrol-frontend \
  --set gateway.image.repository=REGISTRY/appcontrol-gateway \
  --set backend.image.tag=VERSION \
  --set frontend.image.tag=VERSION \
  --set gateway.image.tag=VERSION \
  --wait --timeout 12m
```

Retrieve the generated Route:

```bash
oc get route appcontrol -o jsonpath='https://{.spec.host}{"\n"}'
```

## Security model

The chart is designed for `restricted-v2` and `restricted-v3`:

- no fixed `runAsUser`, `runAsGroup`, or `fsGroup`;
- `runAsNonRoot: true`;
- `seccompProfile: RuntimeDefault`;
- privilege escalation disabled;
- all Linux capabilities dropped;
- application images permit an arbitrary OpenShift UID to access only the
  files and writable directories it needs.

The frontend proxies `/api`, `/ws`, `/health`, and `/ready` internally. Only
one edge-terminated Route is required for the browser application.

## Diagnostics

```bash
oc get pods,route,pvc
oc get events --sort-by=.lastTimestamp
oc logs deployment/appcontrol-backend --tail=200
oc logs deployment/appcontrol-gateway --tail=200
oc describe pod POD_NAME
```

For CI failures, download the `openshift-diagnostics` artifact from the failed
GitHub Actions run.
