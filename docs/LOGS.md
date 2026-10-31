# Component logs

AppControl can retrieve logs from the agent assigned to a component. Open an
application map, select a component, then open **Logs**.

## Choose the right source

| Source | Configuration | Persistence | Best use |
|---|---|---|---|
| Command output | None | Stored by AppControl | Inspect stdout/stderr and status returned by start, stop and custom commands |
| Live process output | None | In-memory agent buffer | Inspect recent stdout/stderr emitted while the agent is connected |
| Log file | Absolute path on the agent machine | Stored by the application | Tail Linux or Windows application logs |
| Windows Event Log | Log name, with optional source and level | Stored by Windows | Inspect Application, System or Security events |
| Diagnostic command | A read-only command | Result shown on demand | Query application or operating-system status through the agent |

Command output and live process output are different. Command output is the
audited history of commands executed by AppControl. The live process source is
the agent's bounded, in-memory buffer and is cleared when the agent restarts.

## Add a source in the UI

1. Assign an enrolled agent to the component.
2. Open the component's **Logs** tab.
3. Select **+**.
4. Choose **Log File**, **Windows Event Log** or **Diagnostic Command**.
5. Enter a display name and the source-specific values.

For a file source, use an absolute path that exists on the agent machine, such
as `/var/log/my-application/application.log` or
`C:\ProgramData\MyApplication\logs\application.log`.

For a Windows event source:

- **Event Log Name** is normally `Application`, `System` or `Security`.
- **Event Source** is optional and restricts results to one Windows provider.
- The agent service account must have permission to read the selected log.

The Logs tab supports a line limit, a time range and a text filter. Requests
are limited to 1,000 lines to protect the agent and backend.

Diagnostic commands run synchronously through the assigned agent and display
their exit code, duration, stdout and stderr in the same tab. Start and stop
commands use detached execution; their persisted return confirms whether the
process was launched, while subsequent application output must be read from
the application's file, Windows Event Log, or another configured source.

## Add a source with the API

Set the connection values once:

```bash
export APPCONTROL_URL="https://appcontrol.example.com"
export APPCONTROL_TOKEN="<access-token>"
export COMPONENT_ID="<component-uuid>"
```

Create a Linux file source from the supplied example:

```bash
curl --fail-with-body \
  -X POST "$APPCONTROL_URL/api/v1/components/$COMPONENT_ID/log-sources" \
  -H "Authorization: Bearer $APPCONTROL_TOKEN" \
  -H "Content-Type: application/json" \
  --data @examples/log-source-file.json
```

For Windows Event Log, adapt
`examples/log-source-windows-event.json`, especially
`event_log_source`, then send it to the same endpoint.

Retrieve live process output:

```bash
curl --fail-with-body \
  -H "Authorization: Bearer $APPCONTROL_TOKEN" \
  "$APPCONTROL_URL/api/v1/components/$COMPONENT_ID/logs?source=process&lines=100&since=1h"
```

Retrieve a configured file or event source by using the source UUID returned
when it was created:

```bash
SOURCE_ID="<log-source-uuid>"
curl --fail-with-body \
  -H "Authorization: Bearer $APPCONTROL_TOKEN" \
  "$APPCONTROL_URL/api/v1/components/$COMPONENT_ID/logs?source=$SOURCE_ID&lines=200&filter=ERROR&since=24h"
```

## Permissions and sensitive logs

- Viewing logs requires **Operate** permission on the component.
- Creating, changing or deleting a source requires **Edit** permission.
- Mark a source as sensitive when it can expose credentials, personal data or
  business data. Sensitive sources require **Edit** permission even for reads.
- Every log access is written to the AppControl audit trail.

## Troubleshooting

| Symptom | Check |
|---|---|
| `No agent is assigned` | Assign an enrolled agent to the component |
| HTTP 503 | Confirm that the agent and its gateway are connected |
| File cannot be read | Verify the absolute path and agent service-account permissions |
| Windows Event Log is empty | Verify the log name, provider filter, level and service-account permissions |
| Live process output is empty | Run a component command and confirm the agent has not restarted |

Log retrieval times out after 30 seconds. File and event-log errors returned by
the agent are surfaced by the API rather than replaced with empty results.
