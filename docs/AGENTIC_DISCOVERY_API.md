# Agentic Discovery API

Base: `/api/v1/discovery/agentic`. This reference covers manual collection and execution through existing AppControl agents. See the [functional guide](AGENTIC_DISCOVERY.md) for the user journey and [native agent configuration](NATIVE_AGENT_DISCOVERY.md) for local consent, trust and installation settings.

## Access and revisions

All endpoints require an authenticated organisation administrator using a browser session. API keys are rejected. Application, site and organisation scope are checked in addition to the role. Native execution is refused on a read-only instance. JSON request objects reject unknown fields. Validation failures return HTTP 400, denied access 403, missing or out-of-scope resources 404, and revision, approval or integrity conflicts 409. An unavailable AI connector can return 503.

Preparation, approval and run creation do not execute a collector. Native execution starts only through the separate `POST /runs/:id/execute` action. Manual script execution remains outside AppControl. There is no fallback to a shell or legacy command execution for an incompatible agent.

Stored resource views include `id`, `name`, `revision` (integer), `status`, `created_by`, `created_at` and `updated_at`. These resource timestamps are Unix seconds. Approval `at`, result `collected_at` and run `cancel_requested_at` use RFC 3339 strings.

| Mutation | Resource supplying `expected_revision` |
| --- | --- |
| Update a skill or reusable agent profile | The skill or profile |
| Prepare a plan or cancel a mission | The mission |
| Approve/reject a plan or create a run | The plan |
| Execute, import or consolidate a run | The run |

Reload the relevant resource after a conflict. Native receipts can advance revisions. Resolve a lost execution response by reading the run and audit trail, not by blindly repeating a dispatch. Failed AI preparation preserves previous plans and run evidence.

## Capabilities

`GET /capabilities` returns:

```json
{
  "schema_version": "1.0",
  "execution_modes": ["manual", "appcontrol_agent"],
  "automatic_execution": false,
  "agent_execution": true,
  "approval_required": true,
  "manual_identity_verified": false,
  "supported_os": ["linux"],
  "collectors": ["processes", "listeners", "java_release", "tomcat_version", "tomcat_configuration", "deployed_apps"],
  "script_runtime": "Python 3.8+",
  "policy_limits": {"max_duration_seconds": 600, "max_output_bytes": 500000},
  "signing_key_id": null,
  "signing_public_key": null
}
```

The final two fields contain the configured dedicated key identifier and hex-encoded public key when available, otherwise `null`. No private key is exposed. `automatic_execution:false` means no implicit or autonomous launch; native execution is available through explicit actions. Global support does not establish availability of a particular target.

## Skills and reusable agents

- `GET /skills` → `{skills:[Skill]}`; `POST /skills` → `Skill`.
- `GET /skills/:id` and `PUT /skills/:id` → `Skill`.
- `GET /skills/:id/versions` → `{versions:[Skill]}`.

Skill input:

```text
{name,description,markdown,validation_status:"draft"|"validated",
 associations:{application_ids:[],catalog_type_keys:[],agent_ids:[]},
 expected_revision?:number}
```

An update requires `expected_revision`. Views add `version`, `sha256` and `owner_id`. Historical versions are immutable snapshots; a snapshot row ID can differ from the stable skill ID recorded as `skill_id`. Markdown has no required YAML schema. Mission creation requires validated skills.

- `GET /agents` → `{agents:[AgentProfile]}`; `POST /agents` and `PUT /agents/:id` → `AgentProfile`.

Profile input:

```text
{name,description,objective,skill_ids:[uuid],parameters:{string:string},
 policy:{max_duration_seconds:120,max_output_bytes:100000},expected_revision?:number}
```

These agents are reusable configurations, not new machine services. Updates require `expected_revision`. Objective length is limited to 4,000 bytes. Policy duration is 1–600 seconds and output budget 1,024–500,000 bytes; defaults are 120 seconds and 100,000 bytes. Parameters such as `tomcat_base`, `tomcat_home` and `java_home` identify reviewed installation directories; they do not authorize local access or arbitrary Markdown commands.

## Missions and history

- `GET /missions` → `{missions:[Mission]}`.
- `POST /missions` with the following body → `Mission`:

```text
{name,agent_profile_id,
 targets:{application_ids:[],catalog_type_keys:[],agent_ids:[],
          manual_hosts:[{hostname,os:"linux"}]}}
```

The mission snapshots the profile, selected skill versions and resolved targets. Its view adds `agent_profile_id`, `context`, `application_ids` and, after preparation, `latest_plan_id`. Initial status is `draft`.

The current scope accepts one application per mission. Application and catalog type filters form an intersection. A catalog type shared by several applications requires an explicit application choice. Resolution uses existing component agents, cluster members and configured site bindings within the user's scope. Several explicit servers can be investigated without an application; evidence is then retained without insertion into an arbitrary application's Knowledge. No machine agent is enrolled.

`GET /missions/:id?history_offset=0&history_limit=100` returns:

```text
{mission,plans:[up to 20 latest full PlanView],
 plan_history:[paged PlanView metadata],runs:[paged RunView metadata],
 history_offset,history_limit,history_truncated,next_history_offset}
```

Maximum history page size is 100. Plan metadata omits `plan`; run metadata omits `results`, `import_hashes` and `errors`, and adds `results_available`. The `plans` compatibility field contains the latest full plans independently of the history offset. Use `GET /plans/:id` and `GET /runs/:id` for full historical payloads. Pagination does not delete history.

## Plan preparation and approval

`POST /missions/:id/plans` → `{mission,plan}`:

```text
{expected_revision,source:"ai"|"manual",ai_source?:string,
 execution_mode?:"manual"|"appcontrol_agent",operations?:[Operation]}
```

`source` selects preparation, independently of execution mode. `source:"ai"` uses explicit `ai_source` when supplied or the organisation connector for compatibility when omitted; it refuses operation replacements. `source:"manual"` requires explicit operations and refuses `ai_source`.

Execution mode defaults to `manual` and must be chosen before preparation and approval. Mode, operations, targets, pinned skills, budgets and runtime are part of the immutable hashed plan. Changing them requires a new version and approval. Only the two listed modes are implemented; SSH/WinRM, ephemeral runners and WebAssembly remain unsupported.

Successful preparation appends a `pending_approval` plan and advances the mission revision. `GET /plans/:id` returns full `PlanView`, including `mission_id`, `version`, `sha256`, `plan`, `ai_source` and any approval.

`POST /plans/:id/approval` with `{expected_revision,sha256,decision:"approved"|"rejected"}` → `PlanView`. The decision binds the exact pending plan ID/version/hash. Approval contains flat `decision`, `actor_id`, `sha256` and `at` fields, together with:

```text
payload:{organization_id,plan_id,mission_id,version,sha256,decision,actor_id,at}
signature?:{algorithm,key_id,public_key,signature}
```

Without the dedicated signing key, a manual decision can remain a recorded unsigned approval. Native execution requires a valid signed approval and local trust in the dedicated key. A digest alone is never authorization.

### Immutable payload

```text
PlanContext = {mission_id:uuid,version:number,objective:string,
 skills:[{id,version,name,sha256,markdown}],
 targets:[{id:uuid,hostname,agent_id?:uuid,application_id?:uuid,
           component_id?:uuid,catalog_type?:string,os:string}],
 parameters:{string:string},policy:{max_duration_seconds,max_output_bytes}}

Plan = {schema_version:"1.0",canonicalization:"x4b-json-v1",
 runner_sha256:string,execution_mode?:"appcontrol_agent",
 context:PlanContext,operations:[Operation],warnings:[string]}

Operation = {id:string,target_id:uuid,skill_id:uuid,skill_version:number,
 collector:string,paths:[string],timeout_seconds:number,max_output_bytes:number,
 information:[string],expected_results:[string],command:string,
 arguments:[string],required_privilege:"current_user"}
```

An omitted plan mode means manual and is omitted when canonically serializing manual plans, preserving existing hashes. The server derives accepted commands/arguments from typed collectors; AI text is not evaluated as shell code.

| Mode | `command` | `arguments` |
| --- | --- | --- |
| `manual` | `python3` | `['-I','-S','appcontrol-discovery.py','--target',target_id,'--operation',operation_id]` |
| `appcontrol_agent` | `native:<collector>` | The operation's reviewed `paths` |

The native command describes an internal typed collector, not a shell executable. Each operation permits 1–30 seconds and 256–50,000 bytes; at most 100 operations are allowed. Sums across all targets must fit the approved mission policy.

`runner_sha256` pins the selected collector implementation. Historical plans/evidence remain readable after an upgrade. A changed runtime can require a new approved plan before script export or native execution. Native backend and agent implementations must agree.

## Per-target availability

`GET /plans/:id/execution-options` is read-only and available before approval:

```text
{manual:{available:boolean},
 appcontrol_agent:{available:boolean,reason:string|null,requires_approval:boolean,
                  targets:[{target_id,agent_id:uuid|null,available:boolean,reason:string|null}]}}
```

Checks include plan mode/current version, recent authenticated capabilities, enrolled route, active state, mTLS identity, local opt-in, trusted signing key, collectors, runtime and local budgets. Capabilities expire after 120 seconds; compatible agents refresh them every 60 seconds. Pending plans can have compatible targets while still requiring approval. Availability is not authorization: the server rechecks at run creation and dispatch; the agent enforces local policy independently.

Reason codes: `plan_superseded`, `plan_mode_mismatch`, `signing_key_unavailable`, `no_agent`, `inactive_agent`, `capabilities_missing`, `capabilities_expired`, `disconnected`, `identity_unverified`, `agent_not_opted_in`, `protocol_mismatch`, `runtime_mismatch`, `key_not_pinned`, `policy_limit`, `collector_unsupported`, `unsigned_approval`.

When a newer plan exists, an earlier native version cannot start a new dispatch; history remains readable. Old agents/gateways are unavailable for this mode; there is no implicit command fallback.

## Runs

`POST /plans/:id/runs` with `{expected_revision,sha256,mode:"manual"|"appcontrol_agent"}` → `RunView`. The revision is the **plan** revision. Its approved mode/hash must match exactly. Native runs additionally require available targets. Initial status is `approved`; creation does not dispatch.

`GET /runs/:id` returns full evidence. Run views contain common fields plus:

```text
{mission_id,plan_id,plan_sha256,mode,results:[ValidatedResult],
 manual_identity_verified:false,import_hashes?:object,
 collected_targets?:number,expected_targets?:number,
 target_states?:[{target_id,agent_id,request_id,status,error,
                  cancel_requested:boolean,stop_confirmed:boolean}],
 error?:string,outcome_unconfirmed?:boolean,
 cancel_requested_at?:string,stop_confirmed?:boolean,consolidation?:object}
```

Run states include `approved`, `running`, `completed`, `failed`, `cancelled`. Target dispatch states include `queued`, `dispatched`, `completed`, `failed`, `uncertain`, `cancelled`. Dispatch/connection alone does not prove collection completed. Evidence uses plural `results`, not `result.targets`.

### Installed-agent execution

`POST /runs/:id/execute` with `{expected_revision}` → `RunView` is the separate launch action for an approved native run. The revision is the **run** revision. It rechecks scope, active mission, latest plan, signed approval, mode, runtime and every target. Signed per-target dispatches are recorded durably before submission through the existing gateway/agent connection. The agent independently validates them under its local policy. Fixed native collectors run without Python, a shell, network discovery or privilege escalation.

Poll `GET /runs/:id` about every 1–2 seconds while active. Authenticated receipts update states, evidence and revision. A refusal can leave `results` empty with a target error. Resolve a lost execute response through run/audit reads, not blind retry. Expired/interrupted dispatches are not automatically replayed: `failed` with `outcome_unconfirmed:true` reports an unknown outcome, not proof of worker termination. A late authenticated receipt can resolve an unconfirmed outcome; transitions remain audited.

Native evidence arrives only through authenticated transport; HTTP import refuses native runs. The backend sets `identity_verified:true` only after matching the enrolled identity, certificate and recorded signed dispatch. Receipt attribution does not guarantee every observation or replace human review. Legacy run field `manual_identity_verified:false` is retained and never authenticates a manual file.

### Manual export and import

`GET /runs/:id/script?target_id=uuid` returns the target-specific Linux Python 3.8+ script named `appcontrol-discovery.py`. It requires a manual run, approved plan and current runtime. Export advances the run revision and marks it `running`, meaning awaiting a manual result; it proves no execution. Re-download remains available until completion/cancellation. The operator runs under a non-root account with isolated Python startup:

```text
python3 -I -S appcontrol-discovery.py > discovery-result.json
```

`POST /runs/:id/import` with `{expected_revision,result:<single-target JSON>}` → `RunView`. The revision is the run revision. The script emits:

```text
ValidatedResult = {schema_version:"1.0",mission_id,plan_id,run_id,plan_sha256,
 target_id,declared_hostname,collected_at,identity_verified:false,
 results:[{operation_id,status:"completed"|"failed",duration_ms,
           observations:[{field,value:string,evidence:string,kind:"observed"}],
           error?:string}]}
```

Every approved operation for the target requires exactly one result, including failures. IDs, hash, operations, limits and evidence fields are validated. Fields depend on the collector and include `software_version`, `configuration`, `rebuild_parameter`, `listening_port`, `deployed_application`, `process`, `information_missing`. Declared hostnames/JSON do not prove machine identity; manual identity remains unverified after content review.

Import one file per target. The run becomes completed after all target results arrive, or failed if any approved operation failed. Identical reimports are idempotent. A different file for an imported target returns 409 and requires a new run. Invalid imports preserve earlier evidence. Import never executes commands.

## Knowledge consolidation

`POST /runs/:id/consolidate` with `{expected_revision,knowledge_revision?:number}` → `RunView`. This explicitly validates observation content after a terminal run; it is neither a transport acknowledgement nor identity proof. Before review, read `GET /api/v1/apps/:application_id/knowledge` and pass its current document revision when Knowledge exists. On a stale revision, retain observations, reload the document and review again.

Consolidation summary:

```text
{application_id:uuid|null,knowledge_revision:number|null,observations:number,
 reused:boolean,retained_without_application:boolean}
```

The existing Knowledge pipeline preserves evidence, skill/version, target, mission/run and collection provenance. Contradictory observations do not silently overwrite validated values. Native receipt attribution and unverified manual origin remain distinct. Evidence without an application is retained without application consolidation. This action does not publish maps, deploy components or invoke application operations.

## Cancellation

`POST /missions/:id/cancel` with `{expected_revision}` → `Mission`. The revision is the mission revision. Preparation and nonterminal runs close while plans, results and audit history remain. A downloaded manual script cannot be recalled.

Native cancellation is signed and bound to the exact dispatch. Run status `cancelled` and `cancel_requested_at` mean cancellation was requested; they do not prove termination. Inspect target `cancel_requested`/`stop_confirmed` and aggregate `stop_confirmed`. Positive confirmation requires an authenticated acknowledgement that execution stopped or was prevented. A deadline, disconnect or timeout is not confirmation. Unconfirmed and later confirmed receipts are both retained. Late evidence does not turn a cancelled workflow into success.

## Installation and update compatibility

PostgreSQL and SQLite use additive migration `V082__agentic_discovery.sql` followed by `V083__agentic_discovery_execution.sql` for capabilities, dispatches and cancellation receipts. Preserve the database, PKI, enrolments and configuration during updates. Portable distributions need matching backend/gateway/agent release artifacts and both migration dialects.

Manual use remains available without native opt-in. Native execution also requires backend `APPCONTROL_DISCOVERY_SIGNING_SEED` and explicit local agent consent, pinned public key, installation roots and limits described in the [native configuration guide](NATIVE_AGENT_DISCOVERY.md). An update does not enable this policy on existing agents. No standalone replacement agent is installed; existing maps and ordinary agent operations retain their identifiers.
