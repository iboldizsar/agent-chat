# Noctalia Agent Chat — implementation plan

Implementation started 2026-10-15 by explicit user request. The first candidate is now installed locally. Read `docs/IMPLEMENTATION.md` for completed work and outstanding acceptance checks; the original phased plan below remains the intended release scope. The user requested pausing near usage limits.

## Version 1.0 roadmap

The current source/private package is 0.5.0. The proposed full roadmap to 1.0, including preserved UI decisions, scope, milestones, migration, acceptance criteria and release gates, is in [docs/V1-PLAN.md](docs/V1-PLAN.md). It is planning only; it does not authorize implementation or deployment. The original implementation plan below remains historical context.

## Scope update: selectable OpenCode or direct Codex backend

Compatibility update, 2026-10-15: read `COMPATIBILITY.md` and `CODEX-COMPATIBILITY.md` for verified contracts and remaining gates. Codex stdio discovery works using existing ChatGPT authentication, including model/effort and skill discovery. A persistent helper is currently recommended for Codex's bidirectional protocol; existing-daemon proxy initialization remains unresolved. The initial CLI-only evidence below is superseded by the Codex inspection report.

User decision, 2026-10-15: support both OpenCode and Codex directly. This supersedes OpenCode-only wording and the exclusion of multiple backends later in this original plan. It authorizes updating the design; implementation and deployment have not started.

- Provide a backend selector for new conversations: **OpenCode** or **Codex**. Remember the choice. Opening an existing conversation selects its owning backend automatically. Changing the new-chat default must not interrupt existing work.
- **Model selection is required for both backends.** OpenCode lists models/providers discovered from OpenCode; direct Codex lists models discovered from Codex. Show the selected backend and model in the conversation header. Remember the preferred model separately for each backend, restore an existing conversation's actual model, and handle unavailable selections explicitly. Allow changing the model for subsequent turns where the backend supports it; verify each backend's semantics and never silently substitute a model. Model catalog visibility alone does not prove account access.
- OpenCode continues to use its existing local v2 service, agents, provider configuration, and conversation store. Codex connects directly through the installed `codex app-server`, using Codex's own authentication/configuration and thread store. No separate raw OpenAI API integration or copied provider credentials is required by this architecture; verify effective app-server authentication during compatibility work.
- Treat backend identity as part of every conversation key, pending interaction, request, and persisted selection. Histories remain in their respective backends. Show backend labels and filtering in history; do not silently migrate transcripts or switch the execution backend of an existing conversation.
- Share the panel and normalized UI state through two adapters. Each implements discovery, create/resume/list/rename/delete where supported, send/stream/stop, tools, approvals/questions, attachments, and recovery. Advertise capabilities explicitly; unavailable operations need an honest explanation. Codex need not expose an OpenCode-style agent selector.
- Verify Codex history deletion versus archival, search, file ingestion, skill discovery, and pending-request recovery independently. OpenCode feature support does not establish Codex parity.
- Codex app-server uses a bidirectional client protocol, unlike OpenCode HTTP/SSE. Evaluate a native host transport first; if unavailable, use a narrow persistent local helper for transport and process lifetime. It must survive panel dismissal and preserve recoverable work across Noctalia reloads. Never kill an unrelated shared Codex daemon.
- Extend Phase 1 to inspect the installed Codex protocol/schema, initialization, authentication status, models, skills, thread operations, approval requests, and transport/lifecycle. Extend Phase 2 to prove an end-to-end slice through **each** backend before building the complete UI. Repeat applicable acceptance scenarios for both and verify that an unavailable backend does not block the other.

Initial Codex evidence: CLI 0.162.1 is installed; `codex app-server --help` exposes stdio, Unix sockets, and WebSocket transports, daemon/proxy commands, and protocol-schema generation. These are CLI capabilities, not completed functional validation. The official [app-server documentation](https://developers.openai.com/codex/app-server/) describes threads, turns, streaming events, and approvals. Exact installed protocol and lifecycle remain to be verified. No Codex server or inference turn was started for this design update.

Date: 2026-10-15  
Status: First local candidate implemented; acceptance validation remains in progress.  
Working name: Agent Chat.

## Objective

Adapt the quick desktop chat experience of [omarchy-agent-chat](https://github.com/RandintN/omarchy-agent-chat) into a native Noctalia plugin powered by the user's existing OpenCode installation.

The primary use is quick general conversation and desktop/laptop assistance. Project development remains in OpenCode inside Herdr, alongside Neovim. This plugin is not intended to become a development environment or a project dashboard.

This document records the agreed product scope and proposes technical details to verify during implementation. Creating this plan does not authorize implementation, installation, publishing, or changes to the laptop configuration.

## Confirmed decisions

| Area | Decision |
| --- | --- |
| Backend | Existing OpenCode installation, using the user's OpenCode Go subscription and Codex integration |
| Agents | Existing configured agents, with an agent selector; compatible plugins should continue to work |
| Purpose | General chat and laptop assistance; no project workspace selector |
| Context | A dedicated assistant directory containing concise laptop context and instructions for relevant skill use |
| Presentation | Large centered panel with optional fullscreen |
| Shortcut | Prefer Super + /, after checking conflicts and keyboard behavior |
| Dismissal | Esc hides the panel without cancelling running work |
| Cancellation | A separate Stop action cancels the active response |
| History | Persistent, searchable conversations with resume, rename, and delete |
| Interaction | Streaming Markdown, tool details, permission requests, and agent questions |
| Attachments | File attachments and pasted screenshots/images in the first release |
| Background status | Bar indicator for working, waiting for input, and finished |

## Observed environment and verification limits

- Noctalia package version observed: 5.2.1-1.
- OpenCode CLI version observed: v2.0.29. Its `serve --help` advertises a v2 API/web server, including hostname and port options.
- The laptop-config inventory describes an earlier OpenCode V1 installation. That inventory is stale for the executable version and must not determine the implementation API.
- Existing OpenCode integration inventory mentions oh-my-openagent and Herdr-related files. Their current configuration and server-mode compatibility have not yet been established.
- Noctalia v5 documentation describes Lua/Luau plugins, native declarative UI, asynchronous HTTP, and streaming HTTP. These capabilities must be matched to the installed release and supported plugin API level.
- No server was started and no provider request, authentication test, or session mutation was performed during planning.
- The user's subscription and Codex integration are requirements supplied by the user; their availability through the installed server still needs a functional check.

## Product behavior

### Opening and composing

The shortcut opens the panel on the appropriate active monitor and focuses the composer. Opening restores the last selected conversation and any unsent draft. A New chat action creates a separate conversation in the fixed assistant directory.

The header shows the conversation title, selected agent, selected model/provider, and current state. The directory/context should be discoverable in an information view without occupying the main conversation interface.

Proposed keyboard behavior:

- Super + / toggles visibility.
- Esc dismisses transient menus first, then hides the panel.
- Enter sends; Shift + Enter inserts a newline.
- A visible Stop action cancels generation independently of hiding.
- All essential controls remain keyboard accessible.

Do not bind additional global shortcuts until their need and availability are established. Check non-US keyboard behavior for the slash binding.

### Conversation history

OpenCode is the authoritative conversation store. The plugin stores only preferences and UI state, such as the selected session, draft, and panel mode; it does not create a second transcript database.

The history view supports titles, timestamps, search, resume, rename, and explicit deletion. Prefer showing assistant conversations by default, using their directory or another supported marker. Do not mix coding sessions into the default list. Optional access to other sessions can be considered later.

Verify whether native OpenCode search exists. If not, define honest search behavior: title search first, with bounded or paginated message search where practical. Do not label title-only filtering as full transcript search.

Deleting a conversation must clearly identify the target and account for active work. Hiding the panel, stopping generation, and deleting history are distinct actions.

### Models, agents, and existing integrations

Discover available models and agents from OpenCode. Reuse its existing authentication and provider configuration; do not ask the user to duplicate credentials in Noctalia settings.

Verify both a preferred Go model and a Codex-backed model. Display their actual provider/model identifiers or useful labels without assuming subscription billing details or reporting unsupported quota information.

Determine the initial agent/model from OpenCode's effective defaults, with a remembered selection if appropriate. Agent and model changes must respect the installed API's semantics, particularly within existing sessions.

Existing agent plugins may affect tools, instructions, or delegation. Verify headless behavior rather than assuming terminal-specific integrations apply. Do not automatically use permissive CLI aliases or bypass approval settings.

### Laptop context

Use a fixed assistant directory, with its final path selected according to repository and configuration ownership conventions. Keep it distinct from active coding projects.

Provide a concise instruction file describing:

- The assistant's purpose: general chat and laptop help.
- Basic verified system facts, with a date and instructions to recheck live state.
- How to locate and apply the existing laptop-config skill for relevant tasks.
- The need to inspect controlling configuration and preserve intentional customization.

Verify which instruction filename and skill discovery mechanism OpenCode v2 actually supports in this directory. Do not assume Codex skill discovery automatically transfers to OpenCode. Reference the existing skill rather than maintaining a divergent copy where possible.

The context must not force laptop inspection for unrelated general questions. It must not contain credentials, private histories, or broad filesystem dumps. Refreshing system facts should be an intentional maintenance operation rather than silently rewriting instructions on every launch.

### Attachments

Support a file picker and clipboard image paste. Provide attachment previews or clear file chips, removal before sending, upload/read errors, and sensible size limits based on actual API and provider constraints.

Check model capabilities before sending images. Explain unsupported attachments and allow model switching or attachment removal. File support must be described accurately: direct multimodal input, text extraction, and granting a tool access to a local path are different behaviors.

Verify clipboard MIME support and image access in the installed Noctalia API. If a small helper is required for clipboard image capture, keep its role narrow and document the dependency.

Place temporary attachment data in an appropriate user-private cache/data location. Establish when OpenCode copies attachment content and when local temporary files can safely be removed. Resumed history must not reference prematurely deleted images. Do not persist attachment bytes in plugin settings or logs.

### Tool activity, permissions, and questions

Render tool calls with clear pending/running/succeeded/failed states, concise summaries, and expandable arguments/output. Bound large output rendering and preserve useful error details.

Render OpenCode permission requests and agent questions as actionable UI. Support the choices actually exposed by the API, with their scope clearly shown. Never silently approve a request or convert a missing dialog implementation into unrestricted access.

If a required interaction cannot be represented, show an explicit blocked/waiting state and an actionable explanation. Do not leave the conversation appearing to generate indefinitely.

### Background work and lifecycle

The panel's visibility must not own the conversation's lifetime. A background plugin service maintains connection and status while the panel is hidden.

The bar indicator distinguishes idle, running, waiting for input, finished/unread, and connection error. Optional completion/input notifications should avoid exposing conversation content unnecessarily and should not repeat on every reconnect.

When Noctalia reloads, reconnect and reconstruct state from OpenCode. Do not resend the last user prompt automatically. If OpenCode remains alive, ongoing work should remain recoverable. If the backend stops, show the interruption honestly; do not automatically retry a potentially mutating task.

## Proposed architecture

```text
Hyprland shortcut / Noctalia bar action
                  |
           Noctalia chat panel
                  |
      Plugin background service and state
                  |
         Local OpenCode v2 server
                  |
    Existing agents, tools, providers, sessions
```

### Native plugin components

- A manifest declaring the required installed plugin API and settings.
- A background service responsible for API requests, events, reconnection, and normalized session state.
- A panel responsible for chat, history, selectors, attachments, and interactive requests.
- A bar entry showing status and toggling the panel.
- Small modules separating API adaptation, state reduction, and UI rendering where the runtime permits.

Use native Noctalia HTTP and streaming APIs if supported by the installed version. Avoid introducing a bridge merely to translate HTTP. A helper is justified only by a verified missing capability, such as clipboard image handling or backend lifecycle control.

The original Omarchy QML interface and host lifecycle are not directly reusable in Noctalia v5. Reuse interaction ideas and applicable protocol normalization concepts. Review the MIT license and preserve required notices for any copied code.

### Backend ownership

Recommended approach: an explicitly managed local OpenCode service, started on demand and independent of panel visibility. Determine whether the installed OpenCode service facilities or a user systemd unit provide the cleanest lifecycle.

Before choosing:

1. Inspect existing OpenCode service ownership and avoid creating competing instances.
2. Verify fixed assistant-directory routing and compatibility with separate Herdr/TUI sessions.
3. Check startup latency, idle resource use, shutdown semantics, and supported authentication.
4. Bind locally; use the installed server's supported authentication and avoid credential exposure in process arguments or committed settings.
5. Ensure disabling/removing the plugin affects only backend processes it owns, never unrelated OpenCode sessions.

Do not require an always-running service if an on-demand arrangement is reliable. Do not change the user's normal Herdr launch flow merely to make the plugin work.

### API contract to establish

Inspect the installed v2 source/schema/help or supported API specification for:

- Server version/health and connection authentication.
- Workspace/directory routing and effective configuration.
- Model/provider and agent discovery.
- Session creation, listing, loading, rename, deletion, and pagination/search.
- Message submission, attachment representation, and cancellation.
- Streaming text, tool state, errors, permission requests, and question/answer events.
- Recovery after disconnect, event ordering, and deduplication.
- Session visibility or handoff to other OpenCode clients, as an optional future feature.

Document actual request/event shapes and version requirements. Do not implement v1 endpoint assumptions against v2.

### State and recovery

Maintain normalized session/message/tool/request state, indexed by stable IDs from OpenCode. Update text incrementally without rebuilding the whole transcript for every token. Preserve the user's scroll position and autoscroll only when already near the bottom.

On reconnect, fetch authoritative state and reconcile it before consuming further events. Account for repeated or out-of-order updates, pending approvals, finished sessions, and events belonging to other sessions. Use bounded reconnect backoff and a visible manual retry action.

## Implementation phases

### Phase 1 — compatibility and design check

- Read applicable repository instructions and the relevant laptop-config references.
- Recheck executable paths, versions, package ownership, Noctalia API level, and existing service ownership.
- Inspect only the relevant non-secret OpenCode configuration and integration code.
- Verify Super + / is available in the active Hyprland Lua configuration.
- Establish the v2 API contract above and Noctalia attachment/clipboard support.
- Select source repository, assistant directory, runtime state paths, and backend lifecycle.
- Record capability gaps and adjust the design before building dependent UI.

Deliverable: verified compatibility notes and concrete component/file layout. Any feature blocked by the installed APIs must be surfaced explicitly rather than silently dropped.

### Phase 2 — end-to-end core

- Connect to or start the owned local backend.
- Discover models/agents and create an assistant session.
- Send one text message and stream its response into a minimal panel.
- Implement Stop and separate visibility from work lifetime.
- Verify the chosen Go and Codex model paths with small functional requests during authorized implementation.
- Recover an existing session after closing/reopening the panel and after reconnecting.

Deliverable: a working vertical slice proving the native integration.

### Phase 3 — daily-use interface

- Add centered/fullscreen layouts, keyboard focus, and theme integration.
- Add persistent history, search, rename, delete, and draft restoration.
- Add agent/model selectors, Markdown, copy actions, and expandable tool output.
- Implement permission requests and agent questions.
- Add file attachments and pasted images with capability checks and durable references.
- Add connection/error/empty states and background bar status.

Deliverable: feature-complete first-release candidate.

### Phase 4 — laptop integration and packaging

- Create the dedicated assistant context using verified instruction and skill discovery behavior.
- Package source separately from generated data, transcripts, caches, and credentials.
- Follow current Stow ownership conventions if deploying through the dotfiles repository; dry-run before linking and preserve existing changes.
- Add the verified Hyprland Lua shortcut and supported Noctalia activation steps.
- Document dependencies, settings, data ownership, install/update/uninstall, and rollback.

Deliverable: locally installed, documented plugin with recoverable configuration changes.

### Phase 5 — validation and release readiness

- Run relevant syntax/manifest/config validation supported by installed tools.
- Test the acceptance scenarios below.
- Inspect relevant logs for errors without collecting conversation or credential contents unnecessarily.
- Fix failures, document known limitations, and record the versions actually tested.
- Leave publishing, marketplace submission, and Git commits outside scope unless requested.

Deliverable: validated local first release and concise handover notes.

## Acceptance criteria

| Scenario | Expected result |
| --- | --- |
| Shortcut and focus | Super + / opens/toggles the panel without a binding conflict and focuses input |
| General question | Replies without unnecessary laptop inspection |
| Laptop request | Uses the assistant context and can discover/apply laptop-config appropriately |
| Go and Codex models | Both configured paths complete a small request; selection is visible |
| Agent selection | Uses the chosen configured agent with verified server-mode behavior |
| Streaming | Text appears incrementally; Markdown and long responses remain usable |
| Hide while running | Work continues; reopening shows current state |
| Stop | Cancels only the intended session/turn and leaves history available |
| New chat and history | Conversations remain separate and can be resumed, renamed, searched, and deleted |
| Restart | History survives Noctalia restart and reboot; selection restores where possible |
| Permissions/questions | Requests can be answered and resolve correctly, including while previously hidden |
| Tool details | Success, failure, arguments, and output are inspectable without freezing the UI |
| Clipboard image | Pasted image previews, sends to a compatible model, and survives history reload |
| File attachment | File selection, removal, errors, and supported ingestion behave accurately |
| Unsupported model | Clear attachment incompatibility feedback before sending |
| Stream interruption | Reconnection reconciles state without duplicate messages or prompt replay |
| Backend failure | Clear error and recovery action; no automatic replay of mutating work |
| Multiple monitors/scaling | Panel opens on the intended output and remains readable at actual display scales |
| Existing coding workflow | Herdr/OpenCode and Neovim continue to work without changed launch behavior |
| Disable/uninstall | Removes only owned integration and preserves history unless explicitly deleted |

Use focused automated tests for meaningful parsing/state/recovery behavior where practical, plus real integration checks for the installed APIs. Avoid tests that merely mirror UI implementation. Live-session verification remains necessary for clipboard, focus, shortcuts, and display behavior.

## First-release boundaries and later improvements

The first release does not need project switching, an editor, repository browsing, inline code review, multiple agent backends, or a recreated terminal UI.

Possible follow-ups after daily use:

- Open the same session in an OpenCode terminal client, if supported by v2.
- Drag-and-drop attachments and direct screenshot capture.
- Conversation export, pinned chats, and richer history organization.
- Explicit selection/context capture from desktop applications.
- Accurate usage display where OpenCode provides reliable data.

Do not add these at the expense of reliable history, approvals, attachments, and recovery.

## Remaining technical decisions

No additional product-scope answer is currently required. Resolve these through inspection and routine implementation judgment, asking the user only if a material tradeoff emerges:

- Final plugin name and source repository location.
- Assistant directory and plugin data/cache paths.
- OpenCode server lifecycle and supported authentication.
- Actual v2 API routes/event formats and integration compatibility.
- Native image clipboard support versus a narrowly scoped helper.
- Search implementation and history pagination.
- Default agent/model resolution and selection persistence.
- Active-session deletion behavior and notification defaults.

## Rollback and reporting

Keep a record of installed plugin files, any owned service definition, assistant-context files, and the exact shortcut/configuration edits. Preserve recoverable copies or tracked diffs before changes, following laptop-config instructions.

Rollback should disable the plugin, remove its shortcut, stop/remove only its owned backend integration, and restore the affected configuration. Preserve OpenCode history by default. Report any remaining assistant-directory or attachment data rather than deleting it implicitly.

The final implementation report should list controlling files, tested versions and scenarios, known limitations, any pending activation, and concrete rollback steps.

## References

- [Original Omarchy Agent Chat](https://github.com/RandintN/omarchy-agent-chat)
- [Noctalia v5 plugin declarative UI](https://docs.noctalia.dev/noctalia/plugins/development/declarative-ui/)
- [Noctalia v5 plugin runtime API](https://docs.noctalia.dev/noctalia/plugins/development/runtime-api/)
- [OpenCode server documentation](https://opencode.ai/docs/server/) — orientation only; verify against the installed v2 API.
- Local laptop-config skill: `/home/ionut/.cfgs/packages/laptop-config/.agents/skills/laptop-config/SKILL.md`, including its Noctalia, OpenCode, mise, Hyprland, services, and Stow references as applicable.
