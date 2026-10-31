# High Availability

This page distinguishes the current reconstruction deployment from HA patterns that still require implementation and qualification. For DR scenarios, see [Disaster Recovery](DISASTER_RECOVERY.md).

!!! warning "Current reconstruction boundary — 12 September 2026"
    Use **one backend**, disable backend autoscaling, and schedule backend upgrades with an interruption. The Helm defaults use `replicaCount: 1` and `strategy.type: Recreate`. Command routing and WebSocket subscribers are local to the backend process; cross-backend routing and durable resumption of interrupted reconstruction operations are not implemented. A shared database, an ownership lease or `HA_MODE=true` does not supply these guarantees. See the [reconstruction improvement plan](../demo-rebuild/AMELIORATIONS-PRODUIT.fr.md), R01–R04.

## Table of contents

- [HA topology overview](#ha-topology-overview)
- [Backend HA](#backend-ha)
- [Gateway HA](#gateway-ha)
- [Database HA](#database-ha)
- [Agent reconnect semantics](#agent-reconnect-semantics)
- [WebSocket affinity](#websocket-affinity)
- [Example load balancer configurations](#example-load-balancer-configurations)
- [Example Helm values overlay](#example-helm-values-overlay)
- [What survives, what does not](#what-survives-what-does-not)

---

## HA topology overview

```
                ┌──────────────────────────┐
                │ External LB / Ingress    │  L7, TLS, one backend target
                │   appcontrol.example.com │
                └────────┬─────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                 │
   ┌────▼─────┐                      ┌────▼─────┐
   │ Frontend │  x N (nginx)         │ Backend  │  x 1 (Rust + Axum)
   │  pods    │                      │  pods    │
   └──────────┘                      └────┬─────┘
                                          │ sqlx pool (TCP+TLS)
                                          ▼
                                  ┌───────────────┐
                                  │ PostgreSQL 16 │  Primary + sync replica
                                  │   Patroni /   │  (or managed: RDS Multi-AZ,
                                  │   pgBouncer   │   CloudSQL HA, Azure HA)
                                  └───────────────┘

                ┌──────────────────────────┐
                │ External LB (TCP)         │
                │  gateway.example.com:4443 │  Layer 4, NLB
                └────────┬─────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                 │
   ┌────▼──────┐                     ┌────▼──────┐
   │ Gateway 1 │ (PRD zone)          │ Gateway 2 │ (DR zone)
   └────┬──────┘                     └────┬──────┘
        │ WSS mTLS                        │ WSS mTLS
        ▼                                 ▼
    Agents in PRD                     Agents in DR
```

Three failure domains are independent:

- **Backend** persists application/audit records in the database, but keeps connections and active execution tasks in process memory. Do not scale it horizontally for reconstruction yet.
- **Gateway** has no database dependency. Agent reconnection to another gateway is separate from backend HA and must be qualified with the configured endpoints.
- **Database** uses PostgreSQL native replication (managed or self-hosted with Patroni).

---

## Backend HA

Persistent records survive a backend restart when the database survives. Live gateway routes, browser subscriptions and executing reconstruction tasks do not become available to another backend merely because it shares that database.

### Shared settings do not implement backend HA

| Environment variable | Required for HA | Notes |
|----------------------|-----------------|-------|
| `HA_MODE=true` | Rate limiting only | Uses PostgreSQL counters; does not route commands/events between backends or resume operations. |
| `DATABASE_URL` | **Yes** | All replicas point at the same DB (or a load-balanced read-write endpoint). |
| `JWT_SECRET` | **Yes** | Must be **identical** across replicas; JWTs signed by replica A must validate on replica B. |
| `JWT_ISSUER` | Yes | Must be identical across replicas. |
| `DB_POOL_SIZE` | Tune | Each replica opens its own pool. Total connections = `replicas × DB_POOL_SIZE`. Don't exceed PostgreSQL's `max_connections`. |
| `SHUTDOWN_TIMEOUT_SECS` | Shutdown setting | Must fit within the pod termination grace period; it is not an operation completion or recovery guarantee. |

See [Configuration — Backend HA](CONFIGURATION.md#high-availability).

### Replica count

Use **one backend** for the current reconstruction pilot. The chart generates no HPA; do not attach an external autoscaler or override the count above one. Size and load-test this instance against the client's workload.

The backend PDB uses `minAvailable: 1`; with one replica this can block a voluntary node drain. It does not provide redundancy or preserve an operation during a Deployment update. `Recreate` prevents old/new replicas from overlapping during that update and causes a planned control-plane interruption. Finish or reconcile operations before maintenance.

Multiple backend replicas are a future qualification target: gateway connected to B, command submitted to A, browser on another backend, followed by loss of the connection owner. These cases require cross-backend routing and a defined interruption/reconciliation contract before an HA claim.

### Load-balancer health checks

| Probe | Endpoint | Frequency | Treats as unhealthy if |
|-------|----------|-----------|------------------------|
| Liveness | `/health` | 10 s | Pod fails the probe — Kubernetes restarts it |
| Readiness | `/ready` | 5 s | Pod removed from Service endpoints (DB unreachable, migrations in progress) |
| LB pool health | `/ready` | 5 s | LB stops routing new requests to the pod |

```yaml
# Illustrative probes; inspect the rendered chart for its actual timings
livenessProbe:
  httpGet: { path: /health, port: 3000 }
  initialDelaySeconds: 30
  periodSeconds: 10
readinessProbe:
  httpGet: { path: /ready, port: 3000 }
  periodSeconds: 5
  failureThreshold: 3
```

### Sticky sessions

A single backend needs no affinity between backend replicas. With multiple backends, JWT validation alone is insufficient: the gateway connection and its command route may belong to another process. HTTP cookie/IP affinity does not align independently established gateway and browser connections. See [WebSocket affinity](#websocket-affinity).

### Drain behavior

The backend has a shutdown signal handler and an HTTP graceful-shutdown path. They do not checkpoint reconstruction tasks or transfer them to another process. Do not use a timeout or pod readiness as proof that an operation completed. Stop new operation submissions, await terminal results and resolve ambiguous external jobs before a planned restart. After an unexpected restart, obtain fresh checks and reconcile recorded operations before retrying; an external command may have continued running.

---

## Gateway HA

Gateways are stateless WebSocket relays. They hold no database connection and no agent state — each agent's `(agent_id, gateway_id)` mapping is tracked by the backend in `agents.last_gateway_id` for routing.

### Why server-side gateway clustering is not needed

The gateway-failover problem is solved **on the agent side**: each agent is configured with multiple `gateway.urls` and falls over automatically. This is the same pattern Consul uses for client → server failover.

```yaml
# /etc/appcontrol/agent.yaml
gateway:
  urls:
    - wss://gateway-prd-01.example.com:4443/ws
    - wss://gateway-prd-02.example.com:4443/ws
  failover_strategy: ordered     # try first, fall through on failure
  primary_retry_secs: 300        # return to primary every 5 min once it recovers
  reconnect_interval_secs: 10
```

### Behind a TCP load balancer

If you want a single DNS entry, place a Layer-4 LB (AWS NLB, GCP TCP LB, HAProxy) in front of your gateway pool:

```yaml
gateway:
  urls:
    - wss://gateway.example.com:4443/ws       # NLB VIP
```

In this case, you do not need the multi-URL agent config. **However:**

- An NLB conceals the actual gateway pod identity; `agents.last_gateway_id` may be incorrect during a brief failover window.
- The agent does not know which pod it lands on; if the pod has a stale cert, the agent gets a TLS error and retries.
- Mixing NLB + multi-URL gives the best of both — if the NLB itself is down, agents try the individual gateway URLs.

### How many gateways

| Zone size | Recommended gateway count | Why |
|-----------|---------------------------:|-----|
| < 500 agents | 2 | N+1 redundancy |
| 500–5000 agents | 3 | Load distribution + N+1 |
| > 5000 agents | ≥ 4 | Distribute connection count |

Each gateway can handle thousands of WebSocket connections. The practical limit is the host's file-descriptor `ulimit` and memory (one connection ~ 64 KB resident).

### Maintenance workflow

1. Mark the gateway inactive in the backend:
   ```bash
   curl -X PATCH https://appcontrol.example.com/api/v1/gateways/<id> \
     -H "Authorization: Bearer $TOKEN" \
     -d '{"is_active": false}'
   ```
2. Agents detect the disconnection, fail over to the next gateway in their list.
3. Perform maintenance (kernel patch, upgrade, cert rotation).
4. Re-enable the gateway:
   ```bash
   curl -X PATCH https://appcontrol.example.com/api/v1/gateways/<id> \
     -H "Authorization: Bearer $TOKEN" \
     -d '{"is_active": true}'
   ```
5. With `failover_strategy: ordered` and `primary_retry_secs: 300`, agents return to the primary within 5 min.

---

## Database HA

AppControl supports any production-grade PostgreSQL 16 HA setup.

### Managed services (recommended)

| Provider | Service | HA option |
|----------|---------|-----------|
| AWS | RDS for PostgreSQL | Multi-AZ standby (sync), automatic failover |
| GCP | CloudSQL | HA with failover replica (sync) |
| Azure | Azure Database for PostgreSQL Flexible Server | Zone-redundant HA |
| Generic | CrunchyData PGO, Zalando Patroni | Streaming replication + Etcd consensus |

### Recommended PostgreSQL config

```ini
# postgresql.conf
max_connections = 200                # replicas × DB_POOL_SIZE + headroom
shared_buffers = 4GB                 # 25 % of host RAM
effective_cache_size = 12GB          # 75 % of host RAM
work_mem = 16MB
maintenance_work_mem = 1GB
wal_level = replica
synchronous_commit = on              # required: lose less than 1 commit on failover
synchronous_standby_names = 'replica-1'
checkpoint_timeout = 15min
max_wal_size = 4GB
archive_mode = on
archive_command = 'your-wal-archive-command'  # see BACKUP_RESTORE.md
```

### Failover handling

The backend uses a sqlx connection pool. On primary loss, requests can fail while connections and the read-write endpoint recover. `DB_CONNECT_TIMEOUT_SECS` is a connection timeout, not an end-to-end failover guarantee. Verify the provider's promotion, DNS/LB behavior and recovery of the pool in the deployment being qualified. An interrupted operation still requires reconciliation.

An optional PgBouncer layer can manage database connections; it does not guarantee error-free failover or resume an interrupted reconstruction:

```
backend pods ─── (sqlx) ──▶ pgbouncer ──▶ PostgreSQL primary
```

Size connection pools against PostgreSQL's limits and test database failover with an active operation. Database redundancy does not remove the single-backend reconstruction boundary.

### Read replicas

AppControl does not currently route any query to a read replica. The backend uses a single `DATABASE_URL` (set in `crates/backend/src/config.rs::AppConfig::database_url`) for both reads and writes, and every repository implementation in `crates/backend/src/repository/` is wired against that one pool.

Adding read-replica routing — a separate `DATABASE_REPLICA_URL` pool that report endpoints (`/api/v1/reports/*`) and the heavier audit queries could opt into — is on the roadmap. It is not yet implemented and is not exposed as a configuration knob.

---

## Agent reconnect semantics

Agents can reconnect after a gateway or backend failure. Reconnection does not prove completion of commands that were in flight or resume a backend reconstruction task.

### State at the agent

The agent maintains:

- **Component config snapshot** — last `UpdateConfig` from the backend, kept in memory.
- **Local scheduler** — runs checks autonomously based on the snapshot; does not poll the backend.
- **Delta tracking** — for each component, the last `exit_code` sent. A new `CheckResult` is only sent when the exit code changes.
- **Offline buffer** — sled DB at `/var/lib/appcontrol/buffer-{agent-id}`, ≤ 100 MB, FIFO rotation.

### Reconnect sequence

1. WebSocket close detected.
2. Agent enters reconnect loop:
   - Try `gateway.urls[0]`. If failure, wait `reconnect_interval_secs` and try `[1]`, etc.
   - Exponential backoff on repeated failure: 1, 2, 4, 8, 16, 32, 60 (max) seconds.
3. On successful connect, agent sends `Register { agent_id, hostname, ip_addresses, labels, version }`.
4. Agent replays the offline buffer in chronological order before resuming real-time deltas.

### Results and ACKs

Command results are correlated by request UUID; real backend/gateway/agent tests verify matching results and ACKs. This is a transport/persistence proof, not an exactly-once guarantee for an external effect or a durable reconstruction-resume mechanism. Inspect the recorded command and provider job before repeating an ambiguous action. See the [process and ACK evidence](../demo-rebuild/media/output/validation/reconstruction-v2/executor-e2e/summary.json) and improvement-plan R02/R03.

### Buffer-on-disk during disconnect

While disconnected:

- Agent continues running checks.
- Each `CheckResult` is written to the local sled DB with a nanosecond-precision timestamp key.
- Buffer is FIFO bounded at 100 MB by default (override with the `BUFFER_MAX_BYTES` environment variable on the agent process; value in bytes, `0` or unparseable value falls back to the default). When the cap is exceeded, the oldest entries are evicted in order until the buffer fits again.
- On reconnect, the buffer is drained in order, then the agent resumes real-time mode.

This means a 1 h disconnect on a 50-component agent at 30 s check interval produces ≈ 6000 buffered events × 200 bytes = ~1.2 MB — well under the buffer cap.

---

## WebSocket affinity

The backend exposes two WebSocket endpoints:

- `/ws` for the frontend (browsers + CLI watch operations).
- `/ws/gateway` for gateways (one persistent connection per gateway).

### Hub model — process-local routing

The hub keeps gateway routes and WebSocket senders in process memory. The reconstruction path calls that local hub. A PostgreSQL `LISTEN/NOTIFY` bridge for cross-backend commands/events is **not implemented** in this path. Database persistence alone does not deliver a command to a gateway owned by another backend or publish an event to that backend's browser subscribers.

### Implication for load balancing

- Route browser/API and gateway connections to the same single backend for the current pilot.
- Sticky HTTP sessions are not a substitute for cross-backend routing.
- A browser can reconnect after restart; an in-flight operation does **not** automatically resume. Inspect its persisted status and reconcile external effects before a fresh assessment and approved retry.

### Implication for monitoring

Monitor backend readiness, gateway/agent connectivity and operation/command results separately. A healthy pod or an open WebSocket is not proof that the requested application recovery completed.

---

## Example load balancer configurations

### HAProxy — backend (HTTP/HTTPS + WebSocket)

```haproxy
global
    log stdout format raw daemon
    maxconn 50000

defaults
    mode http
    timeout connect 5s
    timeout client  60s
    timeout server  60s
    timeout tunnel  3600s     # long for WebSocket /ws

frontend appcontrol_https
    bind *:443 ssl crt /etc/haproxy/certs/appcontrol.pem
    http-request set-header X-Forwarded-Proto https
    default_backend appcontrol_backend

backend appcontrol_backend
    balance roundrobin
    option httpchk GET /ready
    http-check expect status 200
    server backend-1 10.0.0.11:3000 check
```

### HAProxy — gateway (TCP, mTLS pass-through)

mTLS pass-through means HAProxy cannot inspect the cert — the gateway terminates TLS.

```haproxy
frontend gateway_tls
    mode tcp
    bind *:4443
    default_backend gateway_pool

backend gateway_pool
    mode tcp
    balance roundrobin
    option tcp-check
    tcp-check connect port 4443 ssl
    server gw-1 10.0.0.21:4443 check
    server gw-2 10.0.0.22:4443 check
    server gw-3 10.0.0.23:4443 check
```

### nginx — backend (with WebSocket upgrade)

```nginx
upstream appcontrol_backend {
    least_conn;
    server backend-1:3000 max_fails=3 fail_timeout=10s;
}

map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 443 ssl http2;
    server_name appcontrol.example.com;
    ssl_certificate     /etc/nginx/certs/appcontrol.crt;
    ssl_certificate_key /etc/nginx/certs/appcontrol.key;

    location /api/ {
        proxy_pass http://appcontrol_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 60s;
    }

    location /ws {
        proxy_pass http://appcontrol_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade    $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host       $host;
        proxy_read_timeout 3600s;
    }

    location / {
        proxy_pass http://frontend:8080;
    }
}
```

---

## Example Helm values overlay

This overlay retains one backend and two gateway/frontend replicas. It is a reconstruction pilot configuration, not a qualified multi-backend HA topology. Use the production secrets, authentication and network settings from the deployment guide.

```yaml
# reconstruction-values.yaml — overlay over production-values.yaml
backend:
  replicaCount: 1
  strategy:
    type: Recreate
  env:
    APP_ENV: "production"
    HA_MODE: "false"
    SHUTDOWN_TIMEOUT_SECS: "25"
  resources:
    requests: { cpu: "1", memory: 1Gi }
    limits: { cpu: "2", memory: 2Gi }

gateway:
  replicaCount: 2
  service:
    type: LoadBalancer

frontend:
  replicaCount: 2

podDisruptionBudget:
  enabled: true
  backend: { minAvailable: 1 }
  gateway: { minAvailable: 1 }
  frontend: { minAvailable: 1 }

postgresql:
  enabled: false
```

No backend HPA is generated by the chart. Also disable any external HPA, KEDA or platform policy targeting this Deployment. Inspect the rendered values before applying them. Use the [planned maintenance procedure](PRODUCTION_DEPLOYMENT.md#backend-frontend--gateway-planned-update) for an existing installation; do not upgrade during an active or unresolved operation.

```bash
helm template appcontrol ./helm/appcontrol \
  --namespace appcontrol \
  --values production-values.yaml \
  --values reconstruction-values.yaml
```

---

## What survives, what does not

These are boundaries to verify in the client environment, not guaranteed recovery times.

| Failure | Current behavior and required verification |
|---------|----------------------------------------------|
| Single backend stops | Control-plane interruption. Database records remain if the DB survives; restart one backend, collect fresh checks and reconcile interrupted operations. No automatic task transfer/resume. |
| One of several gateways stops | Agents can reconnect to a configured reachable gateway. Verify registration, fresh checks and correlated command results; a job already in flight may need reconciliation. |
| All gateways stop | Backend cannot send commands to those agents. Existing managed processes may continue; collect fresh evidence after reconnect. |
| PostgreSQL primary fails | Recovery depends on the DB provider and connection endpoint. Requests/operations may fail; test this case and reconcile external commands. |
| PostgreSQL and its replica are lost | Restore the control-plane DB and required keys/configuration from tested backups. |
| A site or inter-site link is lost | Single-backend availability depends on its site; target agents and data may also be unreachable. No automatic backend failover or external fencing is implied. See DR §5 and §8. |
| Agent process is killed | Detached managed processes can survive; verify on the target OS. The detailed SIGKILL proof was run on macOS, separately from Linux/Docker reconstruction captures. |
| Agent host reboots | Process detachment does not survive host loss. Re-establish infrastructure and agent connectivity, then diagnose and recover the workload as required. |

For regional outages and loss of both sites, see [Disaster Recovery](DISASTER_RECOVERY.md).

---

## Verification

Check the intended topology and then run isolated failure drills. Readiness is necessary but does not qualify recovery.

```bash
# Expect exactly one backend and strategy Recreate
kubectl get deployment -n appcontrol appcontrol-backend \
  -o jsonpath='{.spec.replicas}{" "}{.spec.strategy.type}{"\n"}'

# Expect no HPA targeting appcontrol-backend; also inspect external scaling policies
kubectl get hpa -n appcontrol

# Inspect gateway placement and actual endpoint reachability
kubectl get pods -n appcontrol -l app.kubernetes.io/component=gateway -o wide

# One backend with minAvailable=1 can block voluntary eviction
kubectl get pdb -n appcontrol
```

For the current pilot, test backend loss as an **interruption and reconciliation** exercise, gateway loss as a reconnection exercise and database restore as a separate recovery exercise. Record operation UUIDs, provider job outcomes, fresh checks and the business acceptance result. Do not infer automatic recovery from pod restart or a lease test.

Before offering multiple backends, separately qualify command routing to a gateway connected elsewhere, events reaching a browser on another replica, loss of the connection owner, concurrent operations and deployment updates. These capabilities remain implementation/qualification work; the current examples do not enable them.

---

## Reference

- [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md) — initial deployment
- [DISASTER_RECOVERY.md](DISASTER_RECOVERY.md) — beyond single-pod failures
- [CAPACITY_PLANNING.md](CAPACITY_PLANNING.md) — sizing the cluster
- [Security Architecture §5](SECURITY_ARCHITECTURE.md) — Multi-Gateway Failover details
