# Fan-out clusters

Use fan-out mode when every instance of a clustered component must be checked
and operated independently. Each member has its own agent, commands and state;
AppControl derives the parent component state from those member states.

Use aggregate mode instead when one command already checks or operates the
whole cluster, such as a vendor cluster-management command.

## Health policies

Set `cluster_mode` to `fan_out`, then choose `cluster_health_policy`:

| Policy | Parent is running when |
| --- | --- |
| `all_healthy` | every active member is running |
| `any_healthy` | at least one active member is running |
| `quorum` | a strict majority of active members is running |
| `threshold_pct` | the configured `cluster_min_healthy_pct` is reached |

Members intentionally stopped by an operator are excluded from the active
health denominator. When every member is stopped, the parent is stopped.

## Commands and state

The parent component can define the default check, start and stop commands.
A member can override each command. Both shell and native commands are
supported; a member override takes precedence over the parent command.
Inherited native commands are templated with the member hostname and optional
installation path.

The backend marks a member `STARTING` or `STOPPING` when its command is
dispatched. The next member health check confirms `RUNNING` or `STOPPED`.
A failed ordinary health check first produces `DEGRADED`, then `FAILED`;
a failed check after Stop confirms `STOPPED`.

## Operating members

From a component's **Members** tab:

- Start or Stop one member to operate and wait for that member independently.
- Select members and use the bulk buttons to dispatch them in parallel.
- Start or Stop the parent component to use the application's normal
  dependency sequencing across all eligible members.

A parent can already be `RUNNING` under `any_healthy`, `quorum`, or
`threshold_pct` while some members are stopped. Starting the parent still
starts those stopped members.

## Limiting concurrency

The default `parallel` mode dispatches all eligible members immediately.
For large tiers, set:

```json
{
  "cluster_mode": "fan_out",
  "cluster_concurrency_mode": "batched",
  "cluster_batch_size": 3
}
```

AppControl dispatches one wave, waits for the members in that wave to reach
their target state (or time out), and then dispatches the next wave. It does
not wait for the parent aggregate between waves, because later members have
not received their commands yet.

Importable examples are listed in the repository's
[`examples/README.md`](https://github.com/xcomponent/appcontrol-release/tree/main/examples).
