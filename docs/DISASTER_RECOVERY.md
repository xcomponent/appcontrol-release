# Disaster Recovery Playbook

This page documents how to recover AppControl itself from infrastructure-level failures, and how to recover **applications managed by AppControl** when their primary site is lost.

!!! warning "Current reconstruction boundary — 12 September 2026"
    Use one backend, with autoscaling disabled and planned interruption for updates. Persistent records survive a backend restart when the database survives; executing operations do not automatically resume. Reconcile commands and external jobs before retrying. Site reconstruction does not itself restore application data or change traffic. See [High Availability](HIGH_AVAILABILITY.md) and the [reconstruction improvement plan](../demo-rebuild/AMELIORATIONS-PRODUIT.fr.md).

For ongoing-incident triage (a single agent down, slow API), see [Troubleshooting](TROUBLESHOOTING.md) and [Runbooks](RUNBOOKS.md). For backup procedures referenced below, see [Backup & Restore](BACKUP_RESTORE.md).

!!! danger "Definitions"
    - **RTO (Recovery Time Objective):** maximum acceptable downtime.
    - **RPO (Recovery Point Objective):** maximum acceptable data loss in time.
    - **Doomsday scenario:** primary site **and** DR site simultaneously lost.

## Scenario index

| # | Scenario | RTO (target) | RPO (target with WAL archiving) |
|--:|----------|-------------:|-------------------------------:|
| 1 | [Backend total loss (DB intact)](#1-backend-total-loss-db-intact) | 30 min | 0 |
| 2 | [Backend + DB total loss](#2-backend--db-total-loss) | 2 h | 5–15 min |
| 3 | [Gateway loss — single-gateway deployment](#3-gateway-loss--single-gateway-deployment) | 30 min | 0 |
| 4 | [Gateway loss — HA deployment](#4-gateway-loss--ha-deployment) | < 1 min | 0 |
| 5 | [Network partition between site A and site B](#5-network-partition-between-sites) | varies | varies |
| 6 | [Database corruption](#6-database-corruption) | 1–4 h | depends on PITR |
| 7 | [Mass agent disconnection (>50% offline)](#7-mass-agent-disconnection-50-offline) | 1 h | 0 |
| 8 | [Site loss requiring full DR switchover](#8-site-loss-requiring-full-dr-switchover) | measure end-to-end | application data recovery contract |
| 9 | [Doomsday — primary + DR simultaneously lost](#9-doomsday-primary--dr-simultaneously-lost) | days | last backup |

!!! note "Honest disclaimer"
    The table contains planning targets, not measured guarantees. AppControl has no independent point-in-time recovery engine for `action_log`; PostgreSQL PITR requires configured and tested base backups/WAL archiving. Measure the actual recovery point and event gaps, including bounded agent buffers. The control-plane backup does not restore the managed application's data. See [Backup & Restore](BACKUP_RESTORE.md).

---

## 1. Backend total loss (DB intact)

The backend pods are gone; the PostgreSQL instance is healthy and reachable.

### Symptoms

- Frontend returns 502 / 503.
- Agents stay connected to the gateway but commands fail.
- `kubectl get pods -n appcontrol -l app.kubernetes.io/component=backend` returns empty or `CrashLoopBackOff`.

### Recovery procedure

1. **Confirm DB is intact.**
   ```bash
   psql $DATABASE_URL -c "SELECT count(*) FROM applications;"
   psql $DATABASE_URL -c "SELECT count(*) FROM action_log;"
   ```
2. **Restore backend secrets.** Ensure `appcontrol-jwt` and `appcontrol-db` exist:
   ```bash
   kubectl get secret -n appcontrol appcontrol-jwt appcontrol-db
   ```
   If any secret is missing, restore it from your secrets backup or regenerate (note: regenerating `JWT_SECRET` invalidates all sessions).
3. **Redeploy the backend.**
   ```bash
   helm upgrade --install appcontrol ./helm/appcontrol \
     --namespace appcontrol --values production-values.yaml \
     --set backend.replicaCount=1 --set backend.strategy.type=Recreate \
     --set backend.image.tag=$(yq '.backend.image.tag' production-values.yaml)
   ```
4. **Wait for `/ready`.**
   ```bash
   kubectl wait -n appcontrol --for=condition=ready pod \
     -l app.kubernetes.io/component=backend --timeout=120s
   kubectl exec -n appcontrol deploy/appcontrol-backend -- curl -s localhost:3000/ready
   ```
5. **Recover records, then collect fresh evidence.** Database records are retained, but cached component state is not proof of current health. Wait for agent registration and fresh checks. Consult affected reconstruction records (`GET /api/v1/apps/<app>/rebuilds/<operation>`); the current implementation marks a recorded running operation without a live owner as interrupted when inspected. There is no durable worker resuming its steps. An external command/job may still be running or may have completed without its result reaching AppControl: reconcile it before a fresh diagnosis, reviewed plan and retry.
6. **Verify connectivity and operation outcomes.** The query below is a connectivity check, not proof that reconstruction completed.
   ```sql
   -- No agents in UNREACHABLE > 5 min
   SELECT count(*) FROM agents
   WHERE last_heartbeat_at < now() - interval '5 minutes' AND is_active = true;
   ```

**RTO:** measure through fresh checks and reconciliation, not only backend readiness. An intact database preserves the records already persisted there; commands/results in flight still require investigation.

---

## 2. Backend + DB total loss

The entire control plane is gone: backend pods and the PostgreSQL instance.

### Symptoms

- Frontend, backend, and DB are all unreachable.
- Agents disconnect from the gateway after the heartbeat timeout, but their managed processes continue running thanks to process detachment.

### Recovery procedure

1. **Provision new PostgreSQL.** Same major version (16), same auth method.
2. **Restore from backup.**
   ```bash
   # Latest pg_dump
   pg_restore --verbose --clean --no-acl --no-owner \
     -h new-pg-host -U appcontrol -d appcontrol backup.dump
   ```
   See [Backup & Restore — PostgreSQL](BACKUP_RESTORE.md#postgresql) for cadence and verification.
3. **Update `DATABASE_URL` secret.**
   ```bash
   kubectl create secret generic appcontrol-db --namespace appcontrol \
     --from-literal=database-url="postgres://appcontrol:PASSWORD@new-pg-host:5432/appcontrol?sslmode=require" \
     --dry-run=client -o yaml | kubectl apply -f -
   ```
4. **Deploy one backend.** Migrations run automatically. Keep backend autoscaling disabled; use the planned-update topology in [Production Deployment](PRODUCTION_DEPLOYMENT.md).
5. **Re-enroll agents whose certificates expired during the outage.** Most agents will reconnect using their stored cert. Agents whose cert expired during the outage need re-enrollment:
   ```bash
   appctl pki create-token --name "post-dr" --max-uses 1000 --scope agent
   # Distribute the token via configuration management
   ```
6. **Replay the agent offline buffer.** When agents reconnect, they replay their local sled buffer in chronological order. Check progress:
   ```bash
   sudo journalctl -u appcontrol-agent | grep "buffer replay" | tail
   ```
7. **Re-establish baseline.** Obtain fresh component checks through the normal agent/API workflow; a direct SQL state change is not a new observation. Compare their timestamps with the restore time. Reconcile operations and external jobs whose latest records may have been lost before issuing new actions.

**Time window without audit:** the gap between your last backup and the current time **cannot** be recovered for `action_log`, `state_transitions`, and `check_events`. Agents replay their local buffer, but the buffer only contains messages the agent itself produced. Operator actions performed via the UI during the outage are **lost**.

**RTO:** 1–2 h depending on backup size. **RPO: 5–15 min with WAL archiving, last backup interval otherwise.**

---

## 3. Gateway loss — single-gateway deployment

The only gateway is down. Every agent in that zone is unreachable.

### Symptoms

- All agents in the zone go `UNREACHABLE` after the heartbeat timeout (default 180 s).
- The backend continues serving the API but no commands reach agents.

### Emergency gateway provisioning

1. **Spin up a replacement gateway pod or VM.**
   ```bash
   # If using Helm/Kubernetes, scale the gateway replica count up
   kubectl scale -n appcontrol deployment/appcontrol-gateway --replicas=1
   ```
2. **Restore TLS cert and key** from your secrets backup (the gateway cert is a *server* cert; agents must trust its CA). If lost, re-enroll the gateway via:
   ```bash
   appctl pki create-token --name "gw-replacement" --max-uses 1 --scope gateway
   curl -k -X POST https://new-gateway:4443/enroll \
     -H "Content-Type: application/json" \
     -d '{"token":"ac_enroll_...", "hostname":"gateway.example.com", "san_dns":["gateway.example.com"]}'
   ```
3. **Verify agents reconnect.** Agents automatically reconnect with exponential backoff (1, 2, 4, … 60 s). Check:
   ```bash
   curl -k https://gateway.example.com:4443/health
   # ok agents=42 backend=connected
   ```

**RTO:** 15–30 min including cert re-issuance. **RPO: 0** — agents buffered locally.

!!! warning "Prevent this scenario"
    Single-gateway deployments are a SPOF. See [§4 below](#4-gateway-loss--ha-deployment) and [High Availability](HIGH_AVAILABILITY.md). Always deploy at least two gateways and configure `gateway.urls` (plural) on every agent.

---

## 4. Gateway loss — HA deployment

One of multiple gateways is down. Agents are configured with `gateway.urls` listing all gateways.

### Symptoms

- Half the agents drop their connection to the failed gateway.
- Agents with `failover_strategy: ordered` retry the next gateway in their list after `reconnect_interval_secs` (default 10 s).

### What happens automatically

1. Agent detects WebSocket close on the failed gateway.
2. Agent retries gateway `urls[1]`, succeeds, re-registers.
3. Backend marks the agent as connected via the new gateway.
4. Components remain in their pre-failure state (no FSM transitions triggered).

### What you do

```bash
# Identify the failed gateway pod
kubectl get pods -n appcontrol -l app.kubernetes.io/component=gateway

# Delete the failed pod — the Deployment recreates it
kubectl delete pod <failed-pod> -n appcontrol

# Once recovered, agents with strategy=ordered return to the primary
# after primary_retry_secs (default 300 s)
```

**Expected reconnect time:** 10–20 s per agent (one `reconnect_interval_secs` cycle). **RTO < 1 min for the whole fleet. RPO: 0.**

See [Configuration — Gateway HA](CONFIGURATION.md#gateway-network-architecture) and [High Availability](HIGH_AVAILABILITY.md).

---

## 5. Network partition between sites

The link between site A (primary control plane) and site B (DR site) is severed.

### Symptoms

- Agents in site B go `UNREACHABLE` from the backend's perspective.
- Locally, agents in site B continue running checks (autonomous scheduler) and buffer events.

### Split-brain prevention

The current reconstruction deployment has one backend and one authoritative database endpoint. It cannot fail over the control plane across the partition automatically. Database operation ownership does not fence an already dispatched command or prevent an isolated application from continuing to write; external neutralization/fencing needs its own verified contract.

Two things to verify during a partition:

1. **No accidental dual-site startup.** The cross-site probe (every 5 min, see [User Guide — Cross-Site Probe](USER_GUIDE.md#cross-site-probe)) detects components running on the wrong site. Inspect `applications` for `cross_site_alert`:
   ```sql
   SELECT a.name, c.name AS component, cs.detected_at
   FROM cross_site_alerts cs
   JOIN components c ON c.id = cs.component_id
   JOIN applications a ON a.id = c.application_id
   WHERE cs.resolved_at IS NULL;
   ```
2. **Operators on both sides should NOT initiate switchovers.** Switchover is the wrong operation here — it migrates an application, but here the application is fine; only the control link is broken.

### Manual reconcile after partition heals

1. Agents in site B reconnect; the offline buffer replays.
2. Obtain fresh checks and compare them with the last recorded state; distinguish buffered observations from new evidence.
3. Inspect affected operation/command histories and the external provider's current job/resource state. Record the reconciliation before retrying an action with an unknown effect. Do not infer an automatic reconciliation workflow or task resume from event replay.

**RTO/RPO:** measure reconnection, new checks, reconciled operations and missing events. A bounded offline buffer cannot guarantee zero loss for an arbitrary partition. Database records and external effects have separate recovery boundaries.

---

## 6. Database corruption

PostgreSQL reports `invalid page header`, `tuple concurrently updated`, or refuses to start. Append-only tables show inconsistencies.

### Diagnosis

```bash
# Verify corruption with a PostgreSQL self-check
psql $DATABASE_URL -c "SELECT count(*) FROM action_log;"
# If this errors with relation-block corruption, escalate.

# Recommended: pg_amcheck (PostgreSQL 14+)
pg_amcheck --all $DATABASE_URL > amcheck.log 2>&1
grep -i error amcheck.log
```

### Read-only fallback

Until corruption is resolved, switch the backend into a read-only failsafe by setting `READ_ONLY=true`. In that mode the backend keeps serving authentication, all `GET` requests, health probes and the break-glass endpoint, but rejects every state-mutating request (`POST`/`PUT`/`PATCH`/`DELETE`) with HTTP `503 Service Unavailable` and `Retry-After: 60`. Authentication endpoints under `/api/v1/auth/`, `/api/v1/oidc/`, `/api/v1/saml/` and `/api/v1/break-glass/` are exempted so an operator can still log in. Otherwise:

1. Scale backend to 0 to prevent writes.
   ```bash
   kubectl scale -n appcontrol deployment/appcontrol-backend --replicas=0
   ```
2. Take a fresh `pg_dump` even of the corrupted DB, to preserve the maximum possible data:
   ```bash
   pg_dump -Fc -f preserve_before_pitr.dump $DATABASE_URL
   ```

### Point-in-time recovery (PITR)

If WAL archiving is enabled:

```bash
# Restore base backup
pg_basebackup -h archive-host -D /var/lib/postgresql/data -X stream

# Configure recovery target time
cat > /var/lib/postgresql/data/recovery.signal <<EOF
EOF
echo "recovery_target_time = '2026-05-13 10:30:00 UTC'" >> /var/lib/postgresql/data/postgresql.auto.conf
echo "restore_command = 'aws s3 cp s3://wal/%f %p'" >> /var/lib/postgresql/data/postgresql.auto.conf

# Start PostgreSQL — it replays WAL up to the target
systemctl start postgresql
```

### Validation queries

```sql
-- Count rows in append-only tables — must match the last known-good values
SELECT
  (SELECT count(*) FROM action_log)        AS action_log,
  (SELECT count(*) FROM state_transitions) AS state_transitions,
  (SELECT count(*) FROM switchover_log)    AS switchover_log,
  (SELECT count(*) FROM check_events)      AS check_events;

-- Last action_log entry should be ≤ recovery_target_time
SELECT max(created_at) FROM action_log;

-- Verify FK integrity
SELECT al.id FROM action_log al
LEFT JOIN users u ON u.id = al.user_id
WHERE u.id IS NULL LIMIT 5;
```

### Bring the system back up

```bash
kubectl scale -n appcontrol deployment/appcontrol-backend --replicas=1
kubectl exec -n appcontrol deploy/appcontrol-backend -- curl -s localhost:3000/ready
```

**RTO:** 1–4 h depending on backup size and WAL volume. **RPO: WAL archiving interval** (typically 1–5 min) or backup cadence.

---

## 7. Mass agent disconnection (>50% offline)

A large fraction of agents goes offline at once — usually after a network event, a DNS outage, or a corporate firewall rule change.

### Triage

```sql
-- Count agents by connection state
SELECT
  count(*) FILTER (WHERE last_heartbeat_at > now() - interval '5 minutes') AS connected,
  count(*) FILTER (WHERE last_heartbeat_at <= now() - interval '5 minutes') AS disconnected
FROM agents WHERE is_active = true;

-- Identify common pattern (subnet, label)
SELECT labels->>'datacenter' AS datacenter, count(*) AS offline_agents
FROM agents
WHERE last_heartbeat_at <= now() - interval '5 minutes'
GROUP BY 1 ORDER BY offline_agents DESC;
```

### Prioritize critical apps

```sql
-- Which applications have ≥ 1 component on a disconnected agent?
SELECT DISTINCT a.id, a.name, a.tags->>'criticality' AS criticality
FROM applications a
JOIN components c ON c.application_id = a.id
JOIN agents ag ON ag.id = c.agent_id
WHERE ag.last_heartbeat_at <= now() - interval '5 minutes'
ORDER BY criticality DESC NULLS LAST;
```

### Batch reconnection

Most agents recover on their own once the network event clears. For agents that do not:

```bash
# Distribute a re-enrollment script via your config-management tool
# (Ansible, Puppet, SaltStack)

# Each host runs:
sudo appcontrol-agent --enroll https://gateway.example.com:4443 --token <token>
sudo systemctl restart appcontrol-agent
```

### Lessons learned

After a mass disconnection, file an incident report and inspect:

```sql
-- What did the heartbeat monitor do?
SELECT count(*), trigger FROM state_transitions
WHERE next_state = 'UNREACHABLE' AND created_at > now() - interval '1 hour'
GROUP BY trigger;
```

**RTO:** typically self-healing within 5–30 min. **RPO: 0** thanks to the agent offline buffer.

---

## 8. Site loss requiring full DR switchover

The primary site is completely unavailable for one or more applications. The DR site is healthy.

The engine can sequence configured source/target procedures and collect their results. A real site-loss procedure also needs recoverable data, target capacity, a safe source-stop/neutralization contract and an explicit traffic step. If the required evidence cannot be obtained, do not proceed merely because the source agent is unreachable. The local simulation does not qualify those infrastructure/data guarantees. See [User Guide — DR Switchover](USER_GUIDE.md#dr-site-switchover).

### The 6 phases and rollback semantics

| Phase | Current behavior | Cancellation / return |
|------:|------------------|-----------------------|
| 1 | PREPARE — record the selected source/target and intent | Cancellation before operational changes |
| 2 | VALIDATE — check target mapping, agents and required recovery contract | Cancellation before operational changes |
| 3 | STOP_SOURCE — execute source stop and positive stop checks | Automatic rollback is refused from this phase onward |
| 4 | SYNC — currently returns `skipped`; no data replication or restore is performed | Verify the external data-recovery procedure before advancing |
| 5 | START_TARGET — execute verified target restart, then activate its component/site contract | Reconcile partial changes; a source return needs an explicit verified procedure |
| 6 | COMMIT — recheck target infrastructure, integrity, network, health and post-start evidence | No automatic traffic switch or reverse recovery |

The site/component contract becomes active after verified START_TARGET; COMMIT supplies another set of fresh checks. Neither step changes the client's load balancer/DNS. A completed AppControl switchover is therefore distinct from confirmed client traffic on the target.

Cancellation is supported only while the recorded phase is PREPARE or VALIDATE. It journals `ROLLBACK/completed` for the same UUID with `operational_changes=false` and `source_restored=false`: the source was left unchanged, not restored. After operational changes, verify/reconstruct the source and use an explicit reverse switchover and traffic procedure. Automatic data synchronization, external fencing and post-change rollback remain integration/implementation work.

### Step-by-step from a site-loss event

1. **Confirm the site is lost.** Distinguish from a transient network partition (§5). If unsure, **wait** — never switch over on a flapping primary.
2. **Verify DR agents are healthy.**
   ```sql
   SELECT count(*) FROM agents WHERE is_active = true AND labels->>'site' = 'dr';
   ```
3. **Review the target recovery contract.** Verify the profile/site mappings and preview the target recovery plan before starting the switchover. Confirm all required checks, source-stop evidence, the external data procedure and traffic/return procedures with their owners. SYNC does not enforce a data-recovery gate today; do not treat an unimplemented check as passed.
4. **Launch the switchover with explicit mode.**
   - `FULL` for total migration.
   - `SELECTIVE` if only a subset of components is recoverable on DR.
   The current API accepts `FULL` or a nonempty `SELECTIVE` scope. `PROGRESSIVE` is not supported by this path. Nested applications, `fan_out` and manual-task components are blocked by the recovery contract.
5. **Monitor each phase in the UI or via API.**
   ```bash
   curl -s https://appcontrol.example.com/api/v1/apps/<id>/switchover/status \
     -H "Authorization: Bearer $TOKEN" | jq
   ```
6. **Commit when validated.** Once START_TARGET succeeds, COMMIT collects fresh target checks. Verify the terminal `COMMIT/completed` history and the associated recovery operation outcomes.
7. **Route and verify traffic explicitly.** Execute the client's authorized network step, observe the target from the actual client entry point, and validate the business transaction and recovered data. Record its result separately; a failed route change is not successful service recovery.

### Roll back at each step

| Recorded phase | Available action |
|----------------|------------------|
| PREPARE / VALIDATE | `POST /api/v1/apps/<id>/switchover/rollback` cancels before operational changes; source/traffic stay unchanged |
| STOP_SOURCE / SYNC / START_TARGET | Automatic rollback is refused; reconcile changes and follow the verified source recovery/return procedure |
| COMMIT / completed | Verify the source and perform an explicit reverse switchover plus the separate traffic/data procedure |

**RTO/RPO:** measure from the incident through accepted client traffic and recovered data. The phase count or completion record does not establish a production RTO/RPO; application-data loss depends on the actual backup/replication procedure and its measured recovery point.

---

## 9. Doomsday — primary + DR simultaneously lost

Both sites are gone. The backend, both gateways, and both replicas of every application are unavailable.

### Recovery sequence

1. **Provision new infrastructure.** Order: PostgreSQL → backend → at least one gateway → frontend.
2. **Restore PostgreSQL from off-site backup.** See [Backup & Restore](BACKUP_RESTORE.md). Verify cross-region or cold-storage backups; if your only backups were on the lost sites, AppControl audit history is lost.
3. **Restore the CA private key.** The CA is stored in `pki_authorities` (encrypted). If the CA is lost, **all agents must be re-enrolled from scratch**.
4. **Bring up the backend.** Migrations run automatically.
5. **Provision a fresh gateway.** Issue a new gateway cert (CLI: `appctl pki issue-gateway`).
6. **Distribute agent binaries and re-enrollment tokens via your config-management tool.**
7. **Reconnect agents and verify each application.**

### What you cannot recover without backups

- `action_log`, `state_transitions`, `check_events`, `switchover_log` — these are append-only audit; if your last backup was T-24 h, everything after T-24 h is gone.
- `config_versions` — same.
- Component state caches will be rebuilt by the next health check, so this is recoverable.

### Cross-region backup is mandatory

To make this scenario survivable, your PostgreSQL backups **must** be replicated off-site (different region/provider). A backup co-located with the primary site does not help.

**RTO:** days. **RPO:** last off-site backup (typically 24 h for cold-storage daily, 1 h for cross-region streaming).

---

## DR drill checklist (run quarterly)

Practicing recovery is the only way to verify your RTO/RPO claims. Run this drill on a non-production AppControl instance every 3 months.

### Quarter N — drill agenda

- [ ] **§3 — Single-gateway loss.** Kill the only gateway pod; verify all agents reconnect within 1 min.
- [ ] **§4 — HA gateway failover.** Kill one of two gateways; measure agent reconnect time.
- [ ] **§7 — Mass disconnection.** Block egress from a subnet for 10 min; verify agents recover from offline buffer.
- [ ] **§8 — Full switchover.** Run a `FULL` switchover on a non-prod app; measure RTO end-to-end.
- [ ] **§8 — Cancellation before changes.** Cancel in PREPARE and VALIDATE; verify the same UUID has terminal cancellation evidence, source/route remain unchanged and advancing is refused.
- [ ] **§8 — Return after changes.** Verify automatic rollback is refused after STOP_SOURCE; rehearse the explicit source recovery, reverse switchover and traffic procedure.
- [ ] **§1 — Backend interruption.** Stop the backend during an isolated recovery exercise; reconcile the external job and recorded operation before any retry. Do not expect automatic task resume.
- [ ] **§2 — Backend + DB recovery.** Restore a backup into a staging cluster; verify row counts, FK integrity, and agent reconnection.
- [ ] **§6 — PITR drill.** Restore PostgreSQL to T-1h on a sandbox; run the validation queries.
- [ ] **Document RTO/RPO achieved.** Compare to last quarter; investigate regressions.

### Reporting

After each drill, export the audit trail and file it for regulatory evidence:

```bash
curl https://appcontrol.example.com/api/v1/reports/dora-drill \
  -H "Authorization: Bearer $TOKEN" \
  -o "dr-drill-$(date +%Y-Q%q).pdf"
```

The drill record is itself evidence under DORA Article 11 (continuity testing). See [Compliance — DORA / NIS2](COMPLIANCE_DORA_NIS2.md).

---

## Reference

- [Backup & Restore](BACKUP_RESTORE.md) — how to take, verify, and restore backups
- [High Availability](HIGH_AVAILABILITY.md) — preventing some of these scenarios
- [Runbooks](RUNBOOKS.md) — incident-scoped step-by-step procedures
- [Troubleshooting](TROUBLESHOOTING.md) — symptom-to-fix mapping for non-DR issues
- [Compliance — DORA / NIS2](COMPLIANCE_DORA_NIS2.md) — what regulators expect from DR documentation
