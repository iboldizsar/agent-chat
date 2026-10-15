# Direct Codex compatibility inspection

Inspected 2026-10-15 using installed Codex CLI **0.162.1**, its generated protocol schemas, read-only app-server calls, and the official [app-server documentation](https://learn.chatgpt.com/docs/app-server).

## Result

Direct Codex integration is feasible, including the required model selector. Initialization, existing-account discovery, models, skills, permission profiles, and filtered history listing work through a temporary stdio app-server. The main unresolved integration detail is durable process/transport ownership across Noctalia reloads. No inference, chat creation, history mutation, desktop configuration change, or installation occurred.

## Installed state and authentication

- `codex login status` reports signed in using ChatGPT. Live `account/read` reports account type `chatgpt`; no auth file, email, account identifiers, or tokens were read or printed.
- `~/.codex/config.toml` is a regular file at its own resolved path. Inspected relevant settings have no explicit global model/provider/approval/sandbox selection; hooks are enabled. Do not inherit permissive shell aliases as plugin policy.
- `codex app-server daemon version` reports an existing managed daemon, CLI and server version 0.162.1, using the PID backend. Managed executable: `~/.codex/packages/app-server-daemon/current/bin/codex`; control socket: `~/.codex/app-server-control/app-server-control.sock`.
- The inspection did not restart or stop this daemon. Temporary discovery processes and their proxy clients were closed; the managed daemon still reports running.

## Live discovery

The temporary `codex app-server --stdio` process used normal existing Codex configuration. The inspection sent `initialize`, waited for the result, then sent `initialized`, followed by read-only requests. Initialization returned platform metadata and the expected Codex home. Framing is newline-delimited JSON; an implementation must handle multiple messages buffered in one pipe read.

| Request | Verified result |
| --- | --- |
| `account/read`, `refreshToken: false` | Existing ChatGPT account recognized. |
| `model/list`, hidden excluded | Seven models, no further cursor. |
| `skills/list` for this project | laptop-config enabled, resolving to its Stow source; no discovery errors. |
| `thread/list` filtered to proposed assistant directory | Empty page with forward/backward cursor fields. No unrelated histories requested. |
| `permissionProfile/list` for this project | Read-only, workspace, and full-access profiles reported allowed. This is availability, not a choice to enable full access. |

Returned models: `gpt-6.1-sol`, `gpt-6-astra`, `gpt-6-sol`, `gpt-6-luna`, `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.6-luna`. The catalog marks `gpt-6.1-sol` default. All seven report text/image inputs and supported reasoning options. Populate selectors from discovery rather than these snapshot names. No model-access or generation claim follows from catalog visibility.

## Version-specific protocol findings

Generated non-experimental schemas with `codex app-server generate-json-schema --out /tmp/agent-chat-codex-schema`. These temporary artifacts match the installed version and were not copied into project source.

| Feature | Installed contract / implication |
| --- | --- |
| New/resumed chat | `thread/start`, `thread/resume`; include explicit assistant `cwd`. Responses include effective model, provider, approval/sandbox settings, and instruction sources. |
| Model selection | Start/resume accept `model`; `turn/start` accepts `model` and `effort` for subsequent turns. Validate reasoning options against the chosen model and display backend-effective settings. |
| History | `thread/list` supports cursors and exact cwd filtering; `searchTerm` is explicitly a substring filter on the extracted title. Use `thread/read`, `thread/turns/list`, and `thread/items/list` for stored content. Existing transcript content was not inspected. |
| Rename/delete/archive | Separate `thread/name/set`, `thread/delete`, `thread/archive`, and `thread/unarchive` methods exist. Test behavior on disposable plugin-owned conversations before wiring UI actions. |
| Send/stop | `turn/start` requires `threadId` and `input`; `turn/interrupt` exists. No turn was started or interrupted. |
| Streaming | Notifications include `item/agentMessage/delta`, tool-output deltas, item lifecycle, `turn/completed`, and thread status changes. Schema support only; live inference streaming remains untested. |
| Approvals | Server-to-client requests include command execution, file changes, and additional permissions. Command/file decisions distinguish acceptance, session scope, decline, and cancellation; some command decisions can amend persistent policies. Preserve exact scope. |
| Questions | `item/tool/requestUserInput` and MCP elicitation are bidirectional server requests. Replies must correlate to the request ID; an SSE-only consumer cannot implement this protocol. |
| Images | Turn inputs include remote/image references and `localImage` with a local path. This matches reported model modalities, but actual image inference and history retention need tests. |
| General files | Turn input variants do not establish arbitrary binary/PDF upload. Skill and mention inputs carry name/path; separate thread attachment methods accept app-defined payloads. Their presence is not proof of provider ingestion. Define text/path handling and explain unsupported formats honestly. |

Codex can share the fixed assistant directory and reference the existing skill. At thread creation, check returned instruction sources to verify `AGENTS.md` loading; skill discovery was verified at this project path, not at the uncreated assistant path.

## Transport and lifecycle decision

Noctalia's inspected public runtime exposes subprocess output capture/streaming and HTTP/SSE, but no established general bidirectional stdin or WebSocket API. A detached stdio process cannot be driven using output-only `runStream`. A small persistent local helper is therefore the current design recommendation for direct Codex, subject to implementation verification. Keep OpenCode's native HTTP/SSE adapter direct.

`codex app-server proxy` was tested twice against the existing daemon with bounded initialization waits. Neither completed initialization; a corrected byte-buffered client succeeded immediately against a fresh stdio server but still timed out through the proxy. This isolates a shared-daemon transport gap without establishing its cause. Do not deploy based on assumed proxy compatibility. Further diagnosis should inspect proxy/control-socket behavior without restarting unrelated sessions.

The helper can own a dedicated app-server process if shared-daemon connectivity remains unsuitable. It must outlive panel visibility, retain subscriptions and pending server requests, and reconnect the UI without replaying prompts. Process separation from Noctalia is necessary to prove work survives shell reloads. Define authenticated/private local IPC, bounded output, request correlation, and ownership before deployment. Do not create a competing global Codex daemon or shut down an existing one.

The official documentation describes thread subscriptions and later unloading when the last subscriber leaves. Accordingly, panel hiding should retain the backend subscription. Actual disconnect/approval recovery requires a live-turn test; it was not inferred from process existence. [Lifecycle reference](https://learn.chatgpt.com/docs/app-server)

## Remaining end-to-end checks

1. Resolve shared-daemon transport or validate a separately owned persistent helper/app-server lifecycle, including Noctalia reload.
2. Create disposable assistant threads and verify persistence, pagination, rename/delete/archive, title search, instruction sources, and safe history scoping.
3. Complete a small turn, change model/effort for a later turn, and verify effective selection, streaming, stop, and resume.
4. Exercise command/file approvals, questions, MCP elicitation where relevant, and pending-request recovery without broadening permissions.
5. Send a generated test image, reload history, and establish local-file retention. Define and test supported general-file handling independently of OpenCode.

Only project documentation was changed. Temporary schema/probe files are under `/tmp/agent-chat-codex-*`; they contain no credentials or transcripts and are not deployment artifacts. Ordinary Codex startup/discovery may update runtime caches/logs. No auth/config files were edited. Documentation rollback consists of removing this report and its handoff references.
