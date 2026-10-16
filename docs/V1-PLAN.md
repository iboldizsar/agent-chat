# Agent Chat 1.0 plan

Date: 2026-10-15  
Baseline: source and private package version 0.5.0  
Status: proposed implementation and release plan; planning only

This plan defines the work from the current candidate to 1.0. It does not authorize implementation, installation, backend requests, desktop restarts, commits, or publication. The original `noctalia-agent-chat-plan.md` and implementation record remain historical context; this document defines the proposed 1.0 scope where they differ. Subsequent user decisions take precedence.



## User-verified 1.0 recovery checks — 2026-10-16

The user confirmed item 1 of the 1.0 checklist: restart during generation or a pending approval and backend outage/recovery, with no lost drafts or duplicate prompts. Record these checks as passed by user confirmation, not newly executed agent tests. Exact backend/version combinations and interruption procedures were not separately reported; do not infer reboot, standalone helper-kill, or second-laptop coverage. Second-laptop validation, long-chat/keyboard/scaling/multi-monitor checks and final 1.0 release preparation remain open.

## 1. Product goal

Deliver a dependable native Noctalia desktop assistant for quick general questions and laptop assistance. Users should be able to install it, select their existing OpenCode or Codex setup, chat without losing work, attach useful context, and recover from an unavailable backend without duplicate prompts or unexplained states.

Coding remains in the user's development tools. Backend authentication, permissions and authoritative conversation history remain owned by OpenCode or Codex. No raw OpenAI API integration or duplicated provider credentials are required.

The 1.0 release remains an independently installable local plugin. Publishing to a catalog or repository is a separate decision.

## 2. Current baseline and evidence

### Implemented

- OpenCode v2 and direct Codex adapters with independent model selection, drafts and history.
- Direct Codex uses an owned helper and dedicated stdio app-server; shared-daemon transport is not a dependency of this architecture.
- Native themed centered/fullscreen panels, background service, bar widget and control-center shortcut.
- Header title dropdown selects OpenCode/Codex and is vertically centered. There is no subtitle.
- Model picker, OpenCode agents and Codex reasoning choices; grouped Chat options.
- Streaming Markdown, tool activity, Stop, permissions and questions.
- Searchable titles, paginated history, pins, rename and explicit deletion.
- Retained file/image attachments, clipboard images and Noctalia screenshot attachment on Hyprland.
- Generic completion/input-needed notifications with an Open chat action.
- Header Markdown export, Save As, remembered destination and a saved-path confirmation. Export does not open an application.
- Panel-local shortcuts with help and tooltips; an optional compositor-level open/hide shortcut.
- Codex admission pauses at 85% reported use; OpenCode handles reported quota/rate failures without claiming an equivalent remaining allowance.
- Private archive, checksum, dependency checker, owned installer/update/uninstall, backups and temporary-home packaging tests.

### User-confirmed working

File-picker cancellation and focus restoration, attachment handling, local shortcuts and normal editing, per-conversation drafts, image input/history, background generation, Stop, permissions, notifications and their Open chat action, native screenshot attachment, Save As and the redesigned options screen.

### Validation still outstanding

- Restart during generation or a pending interaction.
- Backend outage, helper termination and recovery under real runtime conditions.
- Large conversations, long-running sessions, multiple monitors and scaling.
- Real installation on the second laptop.
- Exact supported version combinations outside the tested development environment.

The user deferred these checks for now. They remain proposed 1.0 release gates, not work to execute automatically during planning.

### Known constraints to preserve or address

- Esc is reserved by Noctalia and hides the panel; custom views cannot intercept it to implement a back-stack.
- Native panels cannot become ordinary tiled desktop windows through the currently used API.
- The plugin controls its own fills; the underlying panel background also follows Noctalia transparency settings.
- File/Save As dialogs need an explicit focus handoff and a process transport without a short command deadline.
- Screenshot automation currently inspects Hyprland capture/annotation layers. An unchanged clipboard image is treated as cancellation; Paste image is the existing fallback.
- OpenCode service registration and install/helper paths assume the supported default home layout; custom XDG layouts are not yet generally supported.
- Backend feature parity must be verified; a feature supported by one adapter is not automatically available in the other.
- Source/package version and installed manifest metadata may differ after in-place UI updates; release validation must inspect both.

## 3. Release scope

P0 means required for 1.0. P1 means a committed product improvement, implemented after the reliability foundation. P2 is optional and must not delay the release or weaken P0/P1 behavior.

| Workstream | Priority | Required 1.0 result |
| --- | --- | --- |
| Runtime lifecycle and recovery | P0 | Honest states, retained drafts, recovered approvals, no prompt replay |
| First-run setup | P0 | Choose an available backend/model and understand missing dependencies |
| Compatibility and packaging | P0 | Verified supported baseline, repeatable upgrade/uninstall and second-laptop install |
| Focus, keyboard and responsive layout | P0 | Predictable operation in supported native panel layouts/scales |
| Diagnostics and actionable errors | P0 | Troubleshoot without exporting credentials or conversation content |
| Attachment previews and capture feedback | P1 | Preview/remove supported inputs and clearly understand unsupported ones |
| Model favorites and recent choices | P1 | Faster selection without silent model substitution |
| History grouping and filters | P1 | Pinned and date-grouped conversations with consistent pagination |
| Existing feature polish | P1 | Notifications, usage, export and settings remain coherent and reliable |
| Edit/resend or regenerate | P2 | Only if backend semantics are verified and behavior is explicit |
| Explicit clipboard/selected-text attachment | P2 | Preview before sending; no automatic desktop collection |

If P1 scope needs to shrink, return to the user with concrete tradeoffs rather than quietly calling the work complete.

## 4. Preserve the approved interaction design

- The header starts with history and the OpenCode/Codex title dropdown. Keep the removed subtitle absent.
- Keep the model picker in the main header. Keep OpenCode agent and Codex reasoning controls in Chat options.
- Keep export as a header icon. Saving uses Save As and a dismissible confirmation; do not restore an Open action.
- Keep the redesigned options hierarchy: Assistant, Conversation, Usage when available, Connection & appearance, and separate destructive controls.
- Do not add global shortcuts. Preserve the existing Super+/ binding on this laptop and leave new-machine bindings to explicit setup.
- Keep normal text editing keys intact. Explain Esc as Hide, not Back.
- Keep centered and fullscreen behavior consistent, including dialogs, shortcuts and focus return.
- Use Noctalia theme roles and existing transparency controls, with no fixed palette.
- Avoid exposing directory paths, protocol names and implementation diagnostics in the main conversation flow unless needed to resolve a problem.

## 5. First-run setup

### Flow

1. Show a short welcome screen only when setup has not been completed. Existing installations must not be forced through onboarding.
2. Check executable availability from Noctalia's actual runtime environment, independently of terminal-only checks.
3. Present OpenCode and Codex with explicit states: available, backend not installed, service not connected, authentication needed when reliably reported, or unsupported version.
4. If exactly one backend is available, preselect it. If both are available, ask for the preferred initial service. Never silently change an existing preference.
5. Discover models using the selected backend. Let the user choose one and show which service/provider owns it.
6. Show optional capability checks for file selection/Save As, clipboard images, screenshots and actionable notifications. Missing optional tools do not block plain chat.
7. Explain bar/control-center placement and the optional compositor shortcut. Do not modify layouts or keybindings automatically.
8. Save completion and offer a way to reopen setup from options.

Use existing backend sign-in mechanisms. The plugin must not collect passwords or copy auth files. Starting a plugin-owned Codex transport is distinct from starting/stopping a shared service; make the necessary connection action clear. Do not issue a model prompt as a setup test.

### Acceptance

- Codex-only, OpenCode-only and dual-backend installations can complete setup.
- A missing optional picker still allows text chat and gives an actionable feature explanation.
- Cancelling setup preserves the current state and allows reopening it.
- Existing 0.5.0 preferences are retained and treated as an existing installation.
- Selected model/effort is supported by the selected service; unavailable saved choices require an explicit replacement.
- Version/PATH failures explain the issue without exposing environment dumps or credentials.

## 6. Runtime lifecycle and recovery

### State model

Separate connection state from conversation state rather than encoding both in a single ambiguous status.

| Connection state | Expected UI |
| --- | --- |
| Checking/connecting | Short status and bounded progress indication; no duplicate connection attempts |
| Connected | Normal chat; show busy/waiting/idle state separately |
| Reconnecting | Non-blocking banner, attempt state and manual Retry |
| Offline/authentication required | Explain the problem and the specific next action |
| Unsupported backend/API | Explain the compatibility boundary and retain all drafts/history references |

Conversation states include idle, submitting, running, waiting for input, stopping, completed, interrupted and usage-paused. Display only states supported by evidence; do not infer successful cancellation from a disconnected transport.

### Required behavior

- Reconnects reconcile authoritative backend messages, active work and pending requests before accepting new input.
- A connection retry never resends a user prompt or repeats an approval reply.
- Ambiguous submission outcomes tell the user to inspect recovered history before deciding to send again.
- Stop targets the correct backend/session/turn, remains distinct from Hide and resolves to a visible outcome.
- Older callbacks cannot overwrite a newly selected conversation or backend.
- Background state and notifications identify the originating conversation and do not steal focus on reconnect.
- Reconnection uses bounded exponential backoff with jitter and a single in-flight attempt; define caps during implementation and expose manual recovery when retries are exhausted.
- Keep drafts and selected models after connection/authentication failures.
- Preserve the current rule that a different chat on the same backend cannot replace active work without an explicit supported transition; switching backend may leave the other working.

### Interactive jobs

Treat file picking, screenshot selection, Save As and notification actions as lifecycle-managed jobs, with one completion path and an identifiable originating chat/layout. Define behavior for helper crashes, plugin disable/reload and manual chat switching. A process that exits without a result must not leave a permanent pending flag. Do not auto-restore a stale chat over a newer user choice.

Use isolated replay/fault fixtures before interrupting live desktop/backend processes. Any deliberate desktop restart must be separately scheduled with the user when implementation reaches that gate.

### Acceptance

- Repeated/out-of-order events never duplicate completed messages or tool results.
- Disconnecting while running does not falsely produce a success notification.
- A pending approval is recovered once and resolves once.
- Restoring the panel or reloading the plugin never causes inference on its own.
- Helper crashes, cancelled dialogs and stale callbacks all leave a usable UI.

## 7. Attachment previews and screenshot polish

### Composer

- Show thumbnails for supported image attachments, plus filename and size.
- Show a clear icon/type, filename and size for other files.
- Allow inspection of a larger image preview inside the panel and removal before sending.
- Keep capability feedback close to the attachment; preserve the draft when a model cannot accept it.
- Keep the current 8 MiB bound unless backend inspection justifies a change; display the limit before selection rather than only after failure.
- Explain direct image input versus local file references. Do not imply that every PDF/archive/document is ingested as text.
- Preserve original retained files for resumed history; thumbnails are derived, disposable cache assets.

### Capture and external dialogs

- Reuse Noctalia's existing screenshot and annotation tools; do not introduce a second screenshot stack by default.
- Explain Copy versus Save before capture and restore the correct layout afterward.
- Detect capture completion/cancellation using the most reliable available host signal. Inspect Noctalia capabilities first; if no completion API exists, retain a tested compositor-specific adapter with a clear fallback.
- Address identical clipboard images without accidentally attaching a stale screenshot after cancellation.
- On unsupported compositors, disable automatic attachment with a useful message and preserve Paste image.
- Keep the working focus handoff and avoid command deadlines for user-controlled dialogs.

### Acceptance

Preview/remove/send works for supported images and files, including Unicode/spaces in names. Cancel, invalid input, oversize files, missing source files, helper errors and unsupported models all retain the draft. Resuming a chat still resolves its retained images. A screenshot cancelled after a previous image must not attach the previous image.

Do not automatically garbage-collect retained attachments in 1.0 without a verified reference/ownership model.

## 8. Model favorites and recent choices

- Keep backend-discovered models authoritative; decorate the existing searchable picker.
- Add a favorite toggle, Favorites section and Recently used section, followed by the searchable available catalog.
- Store keys by backend/provider/model identity. A display label is not a stable identifier.
- Keep recent choices bounded (proposed maximum: five per backend).
- Update recents on an explicit successful model selection, not startup or unrelated discovery.
- Show the current selection and unavailable saved favorites explicitly. Do not silently replace a missing model or switch to another provider.
- Keep supported effort choices scoped to their model; switching models validates any retained effort.
- Do not make claims about price, quality or available credit from model names. Show capability metadata only when the backend reports it.

### Acceptance

Favorites and recents persist through reload/upgrade, do not collide across backends, survive renamed display labels, and behave sensibly when a model disappears and returns. Search includes provider labels. A model selection cannot leak into a different backend or an active incompatible turn.

## 9. History organization

- Keep separate backend histories, with the selected service visible in the title dropdown.
- Show a Pinned section above date groups: Today, Yesterday, Previous 7 days, Older. Use a defined fallback for missing timestamps.
- Add All/Pinned filtering without creating a second transcript database.
- Keep search labeled as title search; do not advertise full conversation search.
- Normalize backend timestamp units/timezones before grouping; date groups use the user's local date.
- Preserve scroll position while loading more chats and deduplicate repeated page results.
- Keep pins available outside the latest fetched page and synchronize titles after rename.
- Handle externally deleted/stale pins honestly: mark unavailable until verified and provide Unpin. Do not delete history because a page did not include an item.
- Distinguish no chats, no matches, still loading and history-load failure.

### Acceptance

Stable groups and pins with pagination, midnight/date boundaries and missing timestamps. Search/filter combinations do not make stale old results look current. Rename/delete update only the intended backend/conversation, and failure leaves the original state recoverable.

## 10. Existing feature polish

### Notifications

Keep generic content and independent completion/approval toggles. Verify Open chat routes to the correct backend/session, including when the user is currently working elsewhere. Define deduplication across reconnects and Noctalia restarts. Suppress completion on failures/disconnection and avoid silently approving anything on notification interaction.

### Usage

Keep the existing 85% reported-use guard for Codex; show when usage is unavailable or stale. Separate local admission from provider/server retry behavior. Do not fabricate OpenCode allowance figures or auto-purchase/reset usage. Improving OpenCode quota visibility requires a newly verified API contract and is not a release dependency.

### Export

Keep header placement, full pagination, Save As, overwrite confirmation, remembered location, private file permissions and no Open action. Preserve attachment-not-embedded/activity-summary disclosure. Handle cancellation, helper failure, invalid destinations, unavailable folders and conversation changes during export. Never save an incomplete conversation as a successful full export.

### Settings and accessibility

Preserve the approved options hierarchy and theme roles. Audit tab order, focus return after dialog/model/options interactions, scaling, icon tooltips and clipped controls. Use keyboard-accessible actions for attachment removal, pins and destructive confirmations. Keep existing shortcuts local and avoid adding bindings without a clear need. Audit native control semantics instead of assuming browser behavior; module callbacks must remain forwarded by actual entry scripts.

## 11. Architecture and data changes

Keep native Noctalia UI and HTTP/SSE for OpenCode, plus the existing private Codex stdio helper. Do not replace either transport simply to unify implementation details.

### Proposed responsibilities

| Component | Responsibility |
| --- | --- |
| Backend adapters | Verified discovery, capabilities, sessions, messages, pending interactions, cancellation and reconciliation |
| Background service | Selected backend, independent background state, operation routing, persistence and notification policy |
| Setup view | Runtime availability, model choice and optional feature guidance |
| Model/history modules | Presentation ordering, filters and preference metadata |
| Attachment/job modules | External-dialog lifecycle, preview metadata and focus return |
| Entry scripts | Host callbacks forwarded into modules; visible rendering fallback |
| Packaging tools | Dependency checks, allowlisted archive, upgrade/uninstall and integrity metadata |

Split the growing service/panel modules along these boundaries only where useful. Keep behavior intact before extracting code; avoid a wholesale rewrite.

### Preference migration

Introduce a schema version and a one-time migration from 0.5.0. Preserve backend selections, session references, drafts, pins, export folder and unknown fields where practical. Add setup completion, model favorites and bounded recents. New fields use explicit defaults.

Use recoverable/atomic preference writes where supported. Test interrupted writes, older schemas, missing fields and malformed data. A malformed preference file must not be silently overwritten with empty drafts; preserve a private recoverable copy and explain recovery.

Do not store a duplicate transcript database. Keep credentials, helper registrations, generated exports, attachments and preferences outside release payloads. Do not put prompt text, file contents or tokens in diagnostic output.

### Compatibility

Record capabilities independently for each backend and desktop. Recheck installed contracts when implementation begins. First test the current minimum environment; raise Noctalia's plugin API requirement only for a demonstrated need and record that change. Do not promise every newer backend version works based on executable presence alone.

## 12. Diagnostics and portability

- Extend the read-only doctor to distinguish installed executables, Noctalia runtime PATH, supported/unsupported/unknown versions and optional feature availability.
- Add an in-app status view with backend connection state, app/plugin versions and actionable next steps.
- Provide an explicit metadata-only diagnostic report, with clear contents and no automatic upload.
- Reconcile source version, manifest, helper client metadata, ownership marker, documentation examples and archive naming at release time.
- Decide the supported path policy explicitly: implement and test custom XDG/registration overrides, or retain the documented default layout with an early explanation. Do not partially migrate only one component.
- Preserve existing assistant instructions and user's compositor/layout changes on every upgrade.
- Keep the explicit release allowlist, deterministic archive/checksum and refusal to replace unmanaged destinations.
- Test from the extracted archive, not only from the working directory.
- A second-laptop install must use that laptop's backend authentication and must not depend on the development laptop's home paths, skills or services.

Publishing, signing infrastructure and automatic plugin updates are separate follow-up decisions. The checksum remains integrity metadata, not a signature.

## 13. Optional work: explicit gates

### Edit/resend and regenerate

Before implementing, inspect each backend for native edit, retry, fork and truncation behavior. Define whether an action creates a new branch or appends a message. Show the consequence clearly and never silently overwrite an existing transcript or replay tool actions. Each action is an explicit new model request subject to the usage guard.

If one backend lacks safe semantics, show capability-specific availability or defer the feature entirely. This is not required for 1.0.

### Clipboard or selected text

Only explicit capture with preview/removal and the normal Send action. Do not monitor clipboard contents or selection in the background. Verify compositor/portal behavior and dependencies first. This is not required for 1.0.

## 14. Milestones and dependencies

Versions below are proposed stable-number milestones. Use numeric patch versions for release candidates because the current manifest tooling expects numeric MAJOR.MINOR.PATCH versions; do not assume prerelease labels are supported.

| Milestone | Work | Exit gate | Relative effort |
| --- | --- | --- | --- |
| 0.6.0 — foundation | Capability inventory, state model, preference migration, interactive-job lifecycle and diagnostics | Recovery/fault fixtures pass; no regressions in existing flows | Large |
| 0.7.0 — setup and selection | First-run flow, runtime dependency guidance, favorite/recent models | Fresh and existing installs pass; single-backend setups work without prompts | Medium–large |
| 0.8.0 — attachments and history | Image/file previews, screenshot completion feedback, date grouping and filters | Core preview/cancel/history/pagination scenarios pass on both adapters | Large |
| 0.9.0 — integration | Accessibility/focus/scaling, notification/export/usage polish, package update/uninstall | Full offline matrix and native UI checks pass | Medium |
| 0.9.x — release candidates | Deferred lifecycle/outage checks when scheduled, second-laptop validation, fixes and documentation | All required 1.0 acceptance rows have evidence or an approved scope reduction | Depends on runtime findings |
| 1.0.0 — release artifact | Final versions, allowlist/privacy audit, checksum, migration/rollback guide | Release checklist complete; archive tested from extraction | Small after gates pass |

Do not treat these as calendar estimates. The recovery and second-laptop findings determine the schedule. Optional features must not be inserted into the critical path.

## 15. Verification strategy and usage budget

### Default to offline work

Use fixture HTTP/SSE/stdio boundaries, synthetic histories, fake process exits and isolated homes. Cover actual state transitions and data preservation rather than tests that mirror layout implementation. No model calls for rendering, setup, migration, favorites, sorting, packaging or most error tests.

### Small live checks

Reuse existing conversations for read-only history/discovery. When inference is necessary, use one short explicit request per new behavior and reuse the result for hide/restore, notification and history verification. Avoid duplicate provider checks after unchanged code.

Read reported usage when available. Pause live inference at the existing 85% guard or a lower threshold the user requests. If the coding session's allowance cannot be read, say so rather than claiming it is safe; keep work staged and avoid open-ended live tests. Do not buy credits, bypass limits or auto-switch providers/models.

### Evidence

For each acceptance row record version/environment, test type, result and a concise reference to the fixture or user confirmation. Do not collect transcripts or credentials as test evidence. User confirmations already recorded for 0.5.0 remain evidence; rerun affected scenarios when implementation changes their behavior.

## 16. 1.0 acceptance matrix

| Scenario | Required outcome | Verification |
| --- | --- | --- |
| Fresh install: Codex only / OpenCode only / both | Setup reaches an available model; no unnecessary backend required | Fixtures + extracted install + target laptop |
| Upgrade from 0.5.0 | Context, drafts, pins, selections and export folder retained | Isolated migration/installer tests |
| Corrupt or interrupted preference write | Recoverable state; no silent draft replacement | Fault injection |
| Backend title/model switching | Correct backend identity, history and remembered selections | Both-layout fixtures + native UI |
| Favorite/recent model unavailable | Visible unavailable state; explicit replacement | Fixtures |
| Stream interrupted or backend unavailable | Honest status, retained draft, bounded retry, no resend | Fault fixtures + scheduled live check |
| Hide/reopen during response | Work continues and reconciles without duplicate messages | Existing user evidence + targeted regression |
| Stop while running/waiting | Intended turn/request stops; history remains | Fixtures + tiny live check |
| Restart while running/awaiting approval | Recovered state; no duplicated prompt/reply | Scheduled desktop validation |
| Stale callback after chat/backend switch | Cannot mutate the newly selected chat | Delayed-callback fixtures |
| Picker/Save As/capture cancel or helper crash | Correct focus return, no stale attachment, no permanent pending flag | Process fixtures + native UI |
| Image/file preview and unsupported model | Accurate preview/type/size, removal and useful error | Fixtures + native input |
| Same image and cancelled screenshot | Intentional image can attach; previous image never attaches on cancel | Capture fixtures + native screenshot |
| Pinned/date-grouped history across pages | Stable grouping, title filtering and deduplication | Synthetic histories + native scroll |
| Large transcript/tool output | Responsive scroll/copy/Stop; no freeze while loading older pages | Bounded fixture benchmark + native check |
| Notification route and deduplication | Opens intended backend/chat; no private content or false success | Fixtures + native notification |
| Markdown export | Full ordered pages; successful Save As; no automatic Open | Export fixtures + existing user evidence |
| Limits and unavailable usage | Guard remains effective; no fabricated allowance | Existing guard fixtures + simulated failures |
| Both layouts, scales, monitors and keyboard layouts | No clipped essentials; predictable focus and local shortcuts | Native desktop matrix |
| Missing optional utilities/non-Hyprland capture | Plain chat remains usable; clear disabled feature/fallback | Capability fixtures + supported-host check |
| Uninstall/rollback | Only owned payload affected; private state/history preserved | Extracted-archive tests + documented runtime rehearsal |
| Release contents | No credentials, runtime state, private transcripts or developer home paths | Allowlist and artifact audit |

Define concrete performance bounds before benchmarking on the target machines. Proposed fixture sizes: 1,000 conversation headers, 500 message blocks and a large bounded tool result. These are test workloads, not a promise of unlimited retention or rendering capacity.

## 17. Release checklist

- Every P0/P1 workstream is complete or the user has explicitly approved a narrower scope.
- Both backend adapters pass the shared contract suite plus their protocol-specific tests.
- Deferred runtime checks have been revisited and scheduled; unresolved release blockers are visible.
- The second laptop has completed installation, backend/model selection, a tiny chat, an attachment and export using its own configuration.
- Installed metadata, source and archive identify 1.0.0 consistently.
- Upgrade from 0.5.0 and rollback from the candidate have been rehearsed with private state preserved.
- Noctalia lint/config validation and relevant Python/Lua checks pass.
- Feature availability and supported versions/platform limits are documented accurately.
- Export is still header-only with Save As and no Open action; header still has no subtitle.
- Archive is reproducible, audited and checksum-verified from extraction.
- Release notes distinguish new features, fixes, migration steps and remaining limitations.
- No publishing, commits or unrelated desktop configuration changes are performed without a new instruction.

## 18. Decisions to make during implementation

No answer is needed to complete this plan. Use the defaults below unless implementation reveals a material tradeoff.

| Topic | Proposed default |
| --- | --- |
| Initial backend | Existing choice; otherwise preselect the only available backend, or ask when both are available |
| Model recents | Maximum five per backend |
| Notification privacy | Generic status only, existing notification toggles preserved |
| Attachment size | Keep 8 MiB until verified backend limits justify changing it |
| Attachment cleanup | Explicit/manual; no automatic deletion of files needed by history |
| Supported desktops | Keep current tested default layout and Hyprland capture; expand claims only with tests |
| New optional dependencies | Prefer existing Noctalia/native APIs; introduce a library only after a concrete need is shown |
| New global shortcuts | None |
| Regenerate/edit-resend | Deferred unless capability inspection proves a safe, clear implementation |
| Publishing | Not part of the plan's implementation authorization |

The recommended first implementation task is the **0.6.0 foundation**: document the adapter capabilities and state transitions, then fix lifecycle gaps with fault-driven tests before adding more UI features.
