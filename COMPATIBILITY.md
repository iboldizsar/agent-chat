# Compatibility inspection

Inspected 2026-10-15. Static inspection and read-only live discovery complete. The access restrictions encountered initially were removed and the checks retried successfully; the live findings below supersede those initial limitations. Implementation and deployment have not started.

## Live retry results

- `opencode --version` confirms **v2.0.29**. `serve --help` confirms hostname, port, CORS, service, and stdio options.
- An existing shared service is registered at `~/.local/state/opencode/service.json`, version 2.0.29. `opencode service status` agrees with registration, listener inspection, and `/api/info`. Its only observed listening address is `127.0.0.1:49374` (ephemeral, do not hardcode). No matching user systemd units are loaded. Reuse the native service lifecycle rather than adding a second daemon.
- Authentication was tested using the service registration password in memory, without printing it. Missing authentication and Bearer authentication return 401; HTTP Basic with username `opencode` succeeds. Do not copy this password into plugin source, settings, logs, or command arguments.
- `/api/info` returns top-level `version`, `pid`, `urls`, `paths`, and `capabilities`. Discovery endpoints return `{location, data}` envelopes. `/api/location` defaults to `/home/ionut`; `location[directory]` successfully selects this project directory. Explicit location routing is essential for the future assistant directory.
- `/api/agent` initially returned an empty array, then returned seven agents on subsequent reads, matching `opencode debug agents`: build, plan, general, explore, compaction, summary, title. Build and Plan are visible primary agents; General/Explore are subagents and the others are hidden. The cause of the initial empty result is unconfirmed. Discovery needs retry/empty-state handling, not a permanent inference that no agents exist.
- `/api/model` returns 98 model entries, including `opencode-go` and `openai` providers. The observed default is Go's `gemini-4-argon-contributor`; reported input capabilities include text, image, video, audio, and PDF. Model metadata is not proof of successful inference or subscription access. Only useful selection/capability fields should reach the UI; raw metadata can include application headers.
- `/api/skill` discovers the existing symlinked `laptop-config` skill at `~/.agents/skills/laptop-config/SKILL.md`, alongside built-in OpenCode and Report skills. This confirms discovery for the tested default location; repeat at the final assistant path.
- `/api/plugin` reports the built-in agent plugin active. No reload, update, or plugin activation was performed.
- `/api/event` returns HTTP 200 with `text/event-stream` and an initial `data:` JSON envelope containing `id`, `type: server.connected`, and `data`. The inspection closed its own connection immediately afterward; it did not capture conversation events.
- The actual server serves its OpenAPI document at **`/openapi.json`**, with 118 path entries; `/api/openapi.json` returns 404. A temporary copy was used for schema inspection, not committed to the project. This installed schema takes precedence over the evolving upstream document.
- Installed schema confirms `session.create` accepts `location`, `agent`, and `model`; model references require `id` and `providerID`, with optional `variant`. Prompt submission requires `text`, with optional `files`; a file attachment requires `uri` and optionally `name`, `description`, and `mention`. URI scheme support and content retention remain untested.
- History messages use `GET /api/session/{sessionID}/message`. Stop uses `POST /api/session/{sessionID}/interrupt`, with optional `resume` in the query, not a JSON body. Form replies have an `answer` field; permission reply values include `once`, `always`, and `reject`. No mutating route was called.
- `hyprctl configerrors` returns no errors. Effective bindings contain no `/`, `slash`, or `question` binding. No shortcut was added or triggered, and physical slash behavior on US/Romanian layouts remains untested.
- Noctalia plugin IPC works; its catalog reports API-33 plugins held back, consistent with keeping this implementation within the installed API range. Zenity reports 4.2.2; `wl-paste` advertises MIME selection. No clipboard data or dialogs were opened.

Remaining live acceptance work requires implementation: actual panel loading/focus, file dialogs and image paste, history search semantics, attachment durability, and permission/question interactions. Small Go/Codex inference requests, cancellation, and reconnect behavior belong to the end-to-end phase. The inspection did not create/delete sessions, call a model, start/stop/reload services, or modify desktop configuration. Ordinary CLI logs and server discovery initialization may have updated normal runtime state.

The sections below preserve the initial static evidence and design proposals; statements about blocked access describe that first attempt, not the successful retry above.

## Assessment

The proposed native integration remains feasible. Use the OpenCode **v2 HTTP API**, not the older v1 server examples. No HTTP bridge is currently justified. A narrow clipboard/file-dialog helper is likely useful. Do not treat route strings in a binary or current upstream schemas as proof of a successful installed-server request.

## Installed environment and ownership

| Component | Evidence |
| --- | --- |
| OpenCode | Mise resolves the install to `~/.local/share/mise/installs/opencode/2.0.29`; platform package and executable exist there. CLI execution fails before printing version/help because its log destination is read-only in this session. |
| Noctalia | `noctalia --version`: v5.2.1; pacman: 5.2.1-1. `noctalia config validate` passes. |
| Hyprland | Pacman: 0.56.2-4. Live socket queries fail here. |
| Helpers | `/usr/bin/wl-paste` and `/usr/bin/zenity` are installed. Clipboard contents were not read. |
| Hyprland source | Entrypoint resolves to `~/.cfgs/packages/hypr/.config/hypr/hyprland.lua`, requiring `binds`, `input`, and other Lua modules. |
| Existing local plugin | Arch Updater's files link into `~/.cfgs/packages/noctalia-local-plugins/`. This provides a packaging precedent, not a deployment instruction. |

`~/.config/opencode/{opencode.jsonc,cli.json,service.json,tui.json,tui.jsonc}` are regular files. Provider credentials and transcripts were not inspected. Only the key names of `service.json` were reported: it contains a password field. Its value was not printed or recorded; a configuration password file is not proof that a service is running.

## Existing OpenCode integrations

- `oh-my-openagent@latest` is commented out in `opencode.jsonc`, `tui.json`, and `cli.json`. It must not be described as an active agent source.
- `tui.jsonc` references `./herdr-tui-session.js`. Actual precedence between legacy TUI files and v2 CLI configuration is still unverified.
- `package.json` declares the old `@opencode-ai/plugin` 1.18.34 dependency. Its presence does not establish v2 plugin compatibility.
- Herdr-managed integration version 13 is present. The backend plugin checks launch mode and Herdr environment; its lifecycle logic excludes shared `serve`, `web`, and `attach` modes. The TUI integration includes both `setup` and `tui` entries. Do not modify these files or enable older plugins for this project.

## Noctalia contract

Native HTTP/SSE, shared entry state, and persistent plugin data are documented. Entries have isolated VMs; the service should publish plain state to the panel/widget. Stream lifetime follows the entry runtime, so the service must own the connection. Clipboard reading exposes text, making `wl-paste` a candidate for images. Use argv subprocess calls. These functions also have matching symbols in the installed executable. [Runtime API](https://docs.noctalia.dev/noctalia/plugins/development/runtime-api/)

Markdown, multiline Enter-to-send, focus, keyed controls, and follow-scroll are documented. Preserve composer keys across streaming renders: inputs are uncontrolled. No native file-picker or image-paste contract was established; evaluate Zenity and a paste action before promising Ctrl+V image behavior. [Declarative UI](https://docs.noctalia.dev/noctalia/plugins/development/declarative-ui/)

Proposed minimum `plugin_api = 24`: covers chat controls (21), modules (22), and safe argv subprocesses (24). API 33 `revealKey` is documented as unreleased and should be avoided. Installed 5.2.1 is newer than the releases introducing the required features; runtime plugin loading remains untested. [API versions](https://docs.noctalia.dev/noctalia/plugins/development/plugin-api/)

## OpenCode contract

The following route names are present in the installed binary and correspond to the current [v2 API reference](https://opencode.ai/v2/docs/api):

| Purpose | Route family |
| --- | --- |
| Identity | `/api/info` |
| Selection | `/api/agent`, `/api/model`, `/api/model/default` |
| History | `/api/session`, `/api/session/{sessionID}` |
| Messages | `/api/session/{sessionID}/message` |
| Send / stop | `/api/session/{sessionID}/prompt`, `/interrupt` |
| Change selection | `/api/session/{sessionID}/agent`, `/model` |
| Questions | `/api/session/{sessionID}/form`, `/{formID}/reply` |
| Permissions | `/api/session/{sessionID}/permission`, `/{requestID}/reply` |
| Events / skills | `/api/event`, `/api/skill` |

Upstream describes prompt input as `text` plus `files`, and session creation with `location.directory`. Listing offers directory filtering, search, and cursors; search semantics need checking. Payloads, attachment durability, event envelopes, and authentication must be tested against 2.0.29 before freezing the adapter. Do not substitute `/context` for full history.

The official client documents service discovery/ensure and authentication-header construction. Prefer checking this existing lifecycle before inventing a systemd unit. Event subscriptions are live-only, requiring explicit recovery. A discovered shared service must never be stopped by plugin disable/uninstall. [Client/service API](https://opencode.ai/v2/docs/build/client)

Installed executable source also contains discovery of `~/.agents`, project `.agents`/`.opencode` directories, `SKILL.md` scanning, and directory `AGENTS.md` loading. This supports referencing the existing skill, but effective discovery of its symlink must be checked with `/api/skill` in the chosen assistant location.

## Desktop integration

No Super + slash binding appears in the inspected binding module. Input is `us,ro`, Romanian variant `std`. This is a static conflict check only: effective bindings and slash behavior on both layouts remain pending. Existing bindings use `noctalia msg panel-toggle author/plugin:entry`, providing the intended integration pattern.

User systemd enumeration and listening-socket inspection are blocked by this environment. No dedicated OpenCode unit was found in the inspected unit directories; this does not establish that no backend exists. No server was started, no model call made, and no session created.

## Proposed implementation layout and paths

Keep source here, with `plugin/plugin.toml`, `service.luau`, `panel.luau`, `widget.luau`, and modules for API, SSE parsing, state reduction, and rendering. Add narrowly scoped helper code only for a confirmed host gap. Add focused parsing/recovery tests and installation documentation during implementation.

Proposed assistant location: `~/.local/share/agent-chat/assistant/`, with an `AGENTS.md` referencing the existing laptop-config skill. Persist UI preferences/drafts through `noctalia.pluginDataDir()`. Keep private attachment data outside source and retain it until backend ownership is verified. These paths are proposals; none were created.

## Remaining verification gate

Before building dependent UI, a session with normal runtime/desktop access must:

1. Verify CLI help, existing registered service identity, authentication, and loopback binding without exposing the password.
2. Query identity, agents, models, skills, and effective location; verify actual response/event schemas against the installed version.
3. Establish history pagination/search behavior, pending forms/permissions, event resynchronization, and attachment encoding/retention.
4. Verify panel loading, focus, image capture, file picker, and effective shortcut on both layouts.
5. During the authorized end-to-end phase, test Go/Codex requests, cancellation, background execution, and recovery.

Only this report and the handoff update were added to the project. No laptop settings, service, shortcut, plugin, credentials, or runtime data were changed. Rollback of these documentation changes is simply removal of the report and its handoff entry.
