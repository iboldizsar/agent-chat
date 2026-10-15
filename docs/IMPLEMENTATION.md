# First local candidate — 2026-10-15

The user authorized implementation with a request to conserve usage and pause near limits. The first candidate is now installed and enabled locally. This is not yet a fully validated first release.

## What is implemented

- Native Noctalia UI and theme roles, centered/fullscreen panels, keyboard composer, backend/model selectors, Codex reasoning selection, OpenCode primary-agent selection, Markdown/copy, bounded expandable tool details.
- Native authenticated OpenCode v2 HTTP/SSE with session recovery and directory-scoped history.
- A private persistent Codex transport helper with a dedicated stdio app-server. It reuses existing sign-in and leaves the global managed Codex daemon alone. Noctalia UI reloads do not own that process.
- Backend-owned history, title filtering, pagination, rename, explicit deletion, preferences and per-conversation drafts. No duplicate transcript database.
- Command/file approvals, scoped extra-permission grants, ordinary questions, primitive forms, and explicit consent-page handling. Unsupported advanced interactions remain blocked.
- File selection and explicit image-paste button, private retained attachment copies, model image-capability checks. Codex generic files are path references.
- Background working/waiting/finished status, bar widget, and Super + slash binding.
- Sanitized Codex usage reporting, a conservative 85% admission guard, and no automatic prompt replay. OpenCode projected quota/rate errors trigger an interrupt and block Send until explicit Retry.

## Source and live ownership

| Purpose | Controlling location |
| --- | --- |
| Plugin source | `plugin/` in this project |
| Codex transport | `plugin/helper/codex_bridge.py` |
| Explicit attachment capture | `plugin/helper/attachments.py` |
| Installer | `scripts/install.py` |
| Installed local payload | `~/.local/share/noctalia/plugins/agent-chat/` (copied, owned by installer marker) |
| Assistant context | `~/.local/share/agent-chat/assistant/AGENTS.md` (created once, future edits preserved) |
| UI state and attachments | `~/.local/state/noctalia/plugins/data/local/agent-chat/` |
| Codex helper registration/lock | `~/.local/state/agent-chat/codex/` |
| Shortcut source | `~/.cfgs/packages/hypr/.config/hypr/binds.lua`, through the existing live symlink |
| Plugin enablement/bar layout | Mutable `~/.local/state/noctalia/settings.toml` |

The shortcut adds one `hl.bind(mainMod .. "+slash", …)` calling `noctalia msg panel-toggle local/agent-chat:panel`. The bar change adds `agent_chat` before notifications in `bar.default.end`, with `[widget.agent_chat] type = "local/agent-chat:status"`. Existing dotfiles changes were checked before editing; the only resulting dotfiles diff is the two-line shortcut addition. No commits were made.

Settings and binding backups, plus previous owned plugin payloads from runtime fixes, are under `~/.local/state/agent-chat/install-backups/`. First enablement backup: `settings-before-enable-20261015T043732Z.toml`; widget/binding backup names use the `settings-before-widget-` and `binds-before-agent-chat-` prefixes.

## Verified

- Versions: Noctalia 5.2.1, Hyprland 0.56.2, OpenCode 2.0.29, Codex 0.162.1.
- Native plugin lint passes with zero warnings; Lua-compatible syntax checks pass for all Luau modules. Python helper tests and native-host boundary tests pass.
- Ten Python tests pass. Fake transport tests cover active-work shutdown protection, concurrent request correlation, private HTTP authentication/origin rejection, pending approval retention across UI clients, quota blocking before submission, preservation of a block during quota-read failure, event cursor reset after helper replacement, and foreign-thread rejection.
- Adapter fixtures cover stale resume responses, wrapped paginated Codex items, delta/final reconciliation, directory scoping, chronological OpenCode history/tool details, empty attachment omission, and idle nested-form events.
- Tiny live inference: one temporary Codex turn and one disposable OpenCode Go session succeeded; the temporary OpenCode session was renamed then removed. Two further tiny native-plugin requests verified actual adapter serialization: one Codex and one Go response. One native OpenCode attempt failed validation before inference due to an empty `files` object; this was fixed and tested before retrying.
- Actual Noctalia runtime discovers 98 enabled OpenCode model entries, two visible primary agents, and seven Codex models. Initial empty agent discovery is retried.
- Both backend conversations were recovered through actual plugin disable/re-enable without prompt replay or duplicate messages. Two small integration-check conversations are retained in backend history as examples, outside project source.
- An OpenCode test form created without inference was recovered and answered through the native adapter; no pending test interaction remains.
- Plugin surfaces open through Noctalia IPC. Centered panel geometry is reported by Hyprland. Config validation passes; Hyprland reports no configuration errors and an effective SUPER + `slash` binding.
- Codex helper endpoint permissions are 0600; runtime directories are private. Existing global backend daemons were not stopped. An idle owned transport was replaced during development after checking its authenticated endpoint and process identity.

## Usage

Before implementation, Codex reported 15% five-hour / 5% weekly used. The final check reported **41% five-hour / 9% weekly** (an intermediate check was 35% / 8%); that includes this development session as well as the small tests. No exact per-test attribution is available. No usage credit resets, purchases, or billing/auth configuration changes were performed. Further model requests were stopped after the basic integration tests; remaining checks use fixtures/read-only discovery where possible.

## Remaining acceptance work

- Visual review on the real theme and scaling, physical keyboard focus/Enter/Esc/slash behavior on both US and Romanian layouts, multi-monitor behavior.
- Live Stop during generation and active-turn/approval recovery across a full Noctalia process restart; the helper/UI separation is implemented and idle reconnection tested, but a running reload test is still outstanding.
- Full image inference/history retention and real file-picker/clipboard interactions. Attachment code is present, but these should not be claimed as end-to-end validated.
- Rich/conditional form coverage, actual command/file approval execution, MCP server integrations, and large transcript/tool-output performance.
- Long-term reboot persistence, native error/connection loss recovery, and a full disable/uninstall rehearsal.
- Inference with OpenCode's OpenAI/Codex provider route, as distinct from Go and direct Codex. Catalog discovery alone does not prove every model's account access.

Noctalia's panel host fixes size per entry, so fullscreen uses a separate entry sharing the same panel module. The original Codex shared-daemon proxy gap remains; the implementation deliberately owns a separate stdio transport instead.

## Focused rollback

1. Finish/Stop active turns, then disable `local/agent-chat`. The helper refuses idle shutdown when active work or pending interactions remain.
2. Remove the `agent_chat` entry from `bar.default.end` and its `[widget.agent_chat]` table; validate and run `noctalia msg config-reload`.
3. Remove the one Agent Chat `hl.bind` from the controlling Lua source; validate, run `hyprctl reload config-only`, and check `hyprctl configerrors`.
4. Remove only the owned `~/.local/share/noctalia/plugins/agent-chat/` payload. Keep assistant context, backend conversations, and attachment/draft data by default.

Use focused edits rather than restoring an old whole settings file over newer user preferences. For code-only rollback, restore the desired payload backup while the plugin is disabled, then enable it. Do not stop the shared OpenCode service or global Codex daemon.

## Blank-panel correction — 2026-10-15

The user reported a black panel. The shared panel module had assigned `onOpen`/`onClose` inside its own environment; Noctalia only discovers these lifecycle callbacks in the entry environment. The surface existed and the backend was healthy, but initial content never rendered while idle. The module now exports handlers, and both entry scripts explicitly forward their lifecycle callbacks. A rendering failure also produces an error view instead of a silent blank panel.

Added `tests/test_panel.lua`, which isolates module globals like the actual host and verifies entry callbacks render the header/composer in both layouts. The regression test, native plugin lint, and syntax checks pass. Native metadata diagnostics report `rendered: true` for centered and fullscreen panels, and the corrected payload is installed. The centered panel was reopened. No model requests were sent for this fix.

## Interface refresh — 2026-10-15

The user requested a more modern, streamlined interface using the original Omarchy preview as a visual reference. The preview was inspected directly. The panel now has one compact header with a model pill and icon actions, a collapsible history sidebar, right-aligned user bubbles, lighter assistant responses, and a single rounded composer. Backend, agent/reasoning, usage, rename/delete, and reconnect controls remain available in Chat options. Errors and quota pauses remain visible in the main view. Empty messages cannot be submitted.

All fills/borders/text use Noctalia palette roles; no reference-image palette or bitmap was copied. `plugin_api` is now 27 for the native frameless composer input. Updated the existing isolated-module panel check to cover collapsed history, the composer surface, and access to backend options. Native lint/syntax/config checks pass, and both panel layouts report successful rendering. The updated candidate is installed and the centered panel reopened. The previous payload is backed up under the installer backup directory. No backend inference requests were sent; the read-only allowance check at the start of this refresh reported 49% five-hour / 10% weekly used.


## Control-center integration — 2026-10-15

Added and deployed a native `local/agent-chat:chat` shortcut. Left click opens chat, right click opens Noctalia's plugin settings. Native settings now include opening full screen from the tile/bar, showing history on open, and showing status text in the bar, alongside the existing assistant directory. The bar also opens settings on right click, and Chat options includes a Plugin settings button. Model/backend preferences remain backend-discovered choices in chat.

The live control-center list uses the five existing default Wi-Fi/Bluetooth/caffeine/night-light/DND shortcuts plus Agent Chat, replacing the power-profile shortcut within the six-slot limit. Power profiles remain in System. Settings backup is under `~/.local/state/agent-chat/install-backups/control-center-20261015T053308Z.toml` (check actual timestamp). Previous payload was backed up by installer. No backend inference requests were made. Native shortcut initialization wrote `shortcut-diagnostic.json` with loaded=true; manifest lint, panel fixtures, configuration validation and native panel diagnostic passed. Shortcut runtimes do not register with the host's plugin IPC dispatcher, so entry IPC is not a valid shortcut health check on this release.

Settings are under Settings → Plugins → Agent Chat gear; direct IPC `noctalia msg settings-open-plugin local/agent-chat` opens them. Assistant-directory changes still require a plugin disable/enable to recreate adapters; do not change while work is running. Rollback: restore the previous payload and control-center settings backup, then reload config/re-enable plugin; preserve backend history and private state.


## Transparency controls — 2026-10-15

Added native plugin settings for chat background opacity and card opacity (0–100%, default 100). Both chat layouts share these controls; alpha is applied to theme-role fills, preserving text opacity. The chat background setting controls the plugin overlay: 0 follows the host panel background, 100 is solid. The host still draws its own background, controlled by Noctalia panel transparency; the installed plugin API cannot override that independently. No global shell settings were changed. Native setting descriptions disclose this limitation. Manifest lint and panel regression fixtures passed; installed with previous payload backup 20261015T053614323731Z after both backends reported idle. No inference requests.


## Panel-local keyboard shortcuts — 2026-10-15

Implemented native capture_keys and entry-level onKey forwarding in both panel layouts, with shared handlers and a keyboard help view/button. Ctrl+N new chat; Ctrl+H history; Ctrl+M models; Ctrl+comma options; Ctrl+Shift+A attach; Ctrl+Shift+V paste image; Ctrl+Shift+X stop; Ctrl+Shift+F fullscreen; Ctrl+Shift+slash help (question/uppercase shifted keysym aliases included). Enter/Shift+Enter remain composer bindings. No Hyprland/global bindings changed. Handlers ignore releases, hidden panels, and busy-state new/model changes. Tooltips expose shortcuts.

Correction to the proposed behavior: Noctalia reserves Cancel/Esc and does not deliver it to plugin key handlers. Esc hides chat; custom model/options/help views provide Back buttons. No custom Escape interception was added.

Offline panel tests cover both entries, dispatch, busy guards, normal editing keys, key releases, hidden state, help, history and layout switching. Manifest lint and live configuration validation passed. Installed with backup 20261015T054417353467Z. No model inference requests. Physical key presses, keyboard-layout differences, and focused-input host routing still need user validation. Rollback uses the installer backup and plugin re-enable; preserve private state.


## External attachment picker focus handoff — 2026-10-15

User reported the chat dismissing when the file picker takes focus. Both paperclip and Ctrl+Shift+A now explicitly close the panel to release layer-shell keyboard focus, pass the originating layout to the background service, and reopen that layout after selection, cancellation, helper error or launch failure. Clipboard image capture stays in-panel. The service guards duplicate attachment operations and validates return-panel IDs. Existing session matching prevents attaching a selection to another conversation. Zenity exit 1 is cancellation; other failures now produce a visible error rather than silently cancelling.

Panel fixtures, three new attachment helper tests (cancel/error/private durable copy), service syntax, manifest lint and live configuration validation passed. Installed with backup 20261015T061003663588Z. No inference calls; physical picker interaction remains to verify. The deliberate temporary hide is expected; the panel should reopen after selecting/cancelling. Restore installer backup and re-enable for rollback, preserving private data.


## Attachment picker host timeout correction — 2026-10-15

The previous focus handoff still used callback runAsync, which applies a host process deadline and reported timedOut during interactive file browsing. File selection now uses lifecycle-managed runStream through lib/attachments.luau; dynamic paths are shell-quoted and completion is delivered once. The helper no longer applies its own 180-second picker deadline. Clipboard capture retains bounded runAsync. Same-layout restore and draft/session handling remain. Tests cover streaming selection, late callback completion, quoting apostrophes, duplicate callback suppression, clipboard routing, cancellation/error/private cache, and panel behavior. Lint and syntax pass. Installed with payload backup 20261015T061153182432Z, both backends idle. No inference requests; real file selection remains user validation.


## User validation and desktop improvements — 2026-10-15

User confirmed checks 1–7 passed: picker cancellation/fullscreen, attachment removal/names/size errors, local shortcuts/editing, per-chat drafts, image input/history, background work/Stop and permissions. Restart/during-turn recovery, outages, long conversations and multi-monitor checks are explicitly deferred at the user's request.

Implemented generic completion/approval notifications for work outside the currently visible backend. Native plugin settings provide independent toggles. Notification actions use existing notify-send via lifecycle-managed streams and open the originating backend/conversation; missing notify-send falls back to native generic notifications. Initial snapshots, visible chat and repeated request IDs do not notify. No prompt/response content appears in notification text.

Added a screenshot button to the composer using existing Noctalia screenshot-region and annotation tools, not grim/slurp. The helper observes Hyprland's native capture/annotation layers, waits for them to close, then captures a fresh PNG clipboard image into the existing private attachment cache. Choose Copy in the capture/annotation flow; merely saving does not attach. Chat restores on completion/cancellation/error. Clipboard unchanged after capture is treated as cancellation, preventing stale screenshot attachment; an identical screenshot can be attached with Paste image instead. Screenshot flow currently depends on Hyprland layer introspection (hyprctl), which must be adapted for other compositors during portability work. No global screenshot settings or new packages were installed.

Notification transition/privacy/action/toggle fixtures, six attachment helper tests including native screenshot cancellation/layer detection, panel fixtures, attachment transport fixtures, lint and configuration validation pass. Installed with previous payload backup 20261015T061849842546Z. Native screenshot gestures and notification action clicks remain physical validation; no inference requests. Restore installer backup/re-enable for rollback, preserving private data.


## Pinned chats and Markdown export — 2026-10-15

Added per-backend pinned conversations, stored as ID/title metadata in private preferences. Pin/unpin is available on every history row and in Chat options; pinned chats sort above the current backend's normal history and remain available outside the fetched page. Pins participate in title filtering, refresh titles from backend metadata, and are removed after successful app-driven deletion. They do not merge backends or copy transcripts.

Chat options → Export Markdown reads every message page from the selected backend without replacing the live transcript or invoking a model. The collector deduplicates IDs, restores chronological order, rejects repeated cursors/backend errors and fails rather than saving a partial export at its 500-page safety bound. Message text is exported without the UI's text-length clipping; activity summaries retain adapter bounds. Attachment contents are not embedded. Exports live under the plugin's private data directory, `exports/`, with a collision-safe title/timestamp filename and mode 600. The UI shows the path and an Open Markdown file action. Export requires an idle saved conversation; generated Markdown remains outside source payloads.

Tests cover pinned ordering/search/deduplication, both backend export pagination and transcript isolation, collector errors/cursor loops, and safe activity code fences. Existing panel/adapter tests and manifest lint pass. Native pin/unpin persisted successfully and original pin state was restored; a real selected-backend export produced a valid private Markdown file (10 message sections). Native panel/config checks passed. Installed with previous payload backup 20261015T062610090676Z. No model calls.

User also confirmed both notification display/Open chat and native screenshot attachment work. Previously confirmed daily-use checks remain passed; recovery/outage checks remain deferred. Rollback: restore installer payload backup and re-enable, preserving preferences/exports/backend history.


## Save As and explicit Markdown editor — 2026-10-15

User reported Open Markdown file appearing to do nothing and requested choosing the save location. Read-only MIME inspection found text/markdown mapped to Obsidian. Export now hands off panel focus to a Zenity Save As dialog using the same unbounded streaming transport as the working attachment picker, then restores the originating layout after success/cancel/error. The dialog confirms overwrites and seeds the last chosen folder (stored privately in preferences), or home on first use. A private staging file is removed after the dialog. The helper atomically writes/replaces the selected destination with mode 600 and does not follow destination symlinks. The chosen filename is preserved exactly; the default suggestion ends in .md.

When Neovim is installed, the action explicitly reads Open in Neovim and calls Noctalia runInTerminal with a safely quoted path after closing chat to release keyboard focus. Other systems fall back to xdg-open with captured failure reporting. Global MIME associations are unchanged.

Four new Save As tests cover cancellation, confirmed replacement/symlink safety, Unicode/spaces/apostrophes, private permissions, and dialog failure. Interactive transport tests cover save-result handling and quoting. Panel fixtures, manifest lint, service syntax and native configuration validation passed. Installed with previous payload backup 20261015T063807733935Z. Physical Save As selection and terminal editor opening await user validation. No inference requests. Rollback uses installer backup/re-enable; preserve chosen exports and private preferences.


## Export action placement — 2026-10-15

User requested the main chat header placement and removal of the Open action. Export Markdown is now a download icon beside New chat/Chat options in both layouts, disabled for unsaved or busy chats and during export. The duplicate options button is removed. Save As remains, followed by a dismissible saved-path confirmation in the main view. All export editor-opening UI and service actions are removed; no application launches after saving. Previous Neovim/default-opener notes are superseded. Panel tests, lint and service syntax pass. Installed with payload backup 20261015T064059295909Z; no inference calls.


## Chat options redesign — 2026-10-15

Reworked options into a centered 740px reading column with sentence-case cards and labeled description/control rows. Assistant combines backend selection, visible model/Change, and native agent/reasoning dropdowns. Conversation provides pin and inline rename with Save/Cancel; blank renamed titles are ignored. Codex usage shows bounded progress bars and the existing 85% pause policy. Connection & appearance groups reconnect and native plugin preferences. Destructive deletion is isolated at the bottom with the specific chat title, permanent-deletion explanation, and Keep conversation action. Busy-state controls remain disabled, and export stays exclusively in the main header. Existing Noctalia theme-role fills and background/card opacity settings are preserved. Both entries support opening with context `options` for native inspection.

Panel regression tests cover native zero-based dropdown mapping for OpenCode agents/Codex effort in both layouts, in addition to existing keyboard/composer checks. Manifest lint/config validation and native centered options rendering passed. Updated entry/module files in place to preserve backend connections, with recoverable prior files in `~/.local/state/agent-chat/install-backups/options-redesign-20261015/`. Options opened for user review. No inference calls. User confirmed Save As works as expected. Rollback copies those prior entry/module files back into the installed payload.


## Portable package — 2026-10-15

Built `dist/agent-chat-0.1.0.tar.gz` and companion `.sha256` for private transfer, without publishing/commits or altering the running plugin/desktop. `PACKAGE-FILES.txt` allowlists 35 source/documentation/test files. Builder normalizes tar/gzip metadata and rejects source symlinks/path traversal; reproducibility and extracted installation are tested. Archive audit found no local username paths, runtime data, private context/history, caches, ownership markers or development handoff records. The checksum is integrity metadata, not a publisher signature.

Added `scripts/doctor.py`: read-only PATH/version/dependency checks, explicit backend selection, known OpenCode V1 rejection and optional-tool reporting; no provider/auth/service calls. Installer now uses the allowlist, reads version from manifest, supports --home offline staging and --uninstall, checks dependencies on real install (explicit --skip-checks for staging), preserves custom assistant instructions/private state, refuses foreign/symlink destinations, backs up owned payloads and restores the prior payload if replacement fails. Uninstall backs up/removes only the owned payload after the documented manual disable step.

Replaced future-install assistant template with generic laptop guidance: no Arch/Hyprland/version/username/dotfiles assumptions, optional existing laptop-config discovery. The current laptop's installed customized assistant file was preserved. Screenshot helper now explains the Hyprland requirement before attempting capture on unsupported hosts. Runtime helper change is packaged in source, not deployed locally during packaging.

Rewrote portable README and added docs/INSTALL.md for dependencies, first launch, per-backend setup, PATH, bar/control-center/optional shortcut placement, update/uninstall/rollback, private data ownership and known limits. Default home layout and OpenCode registration path remain the supported tested layout; custom XDG paths and non-Hyprland automatic screenshot attachment are documented rather than claimed supported.

Validation: Python suite passed (26 tests), then the added unsupported-OpenCode-V1 case and all seven packaging cases passed; all five Lua fixture suites and Noctalia lint passed. The extracted release CLI passed preview/install/update/uninstall under a temporary home with spaces, preserving assistant instructions. Archive is reproducible and checksum verified. A real second-laptop desktop test remains pending; restart/outage/long-history/multi-monitor checks stay deferred by user choice. No inference requests. Existing local Noctalia settings, shortcuts, backend authentication and installed assistant context were untouched.

Usage read through the owned helper was unavailable because no helper registration existed; no backend was started just to query it.


## Agent picker in main header — 2026-10-15

Moved OpenCode agent selection from Chat options into the main header. The selected agent's name replaces Agent Chat as the title and doubles as a chevron picker using the same interaction/pill style as model selection. The selection view lists available primary agents and marks the active choice. It is disabled during generation/submission. Subtitle retains backend/conversation context without repeating the agent. Direct Codex has no separate agent list and uses Codex as its title. Missing discovery falls back to the backend label rather than showing Agent Chat.

Panel regression checks cover both layout entrypoints, selected-agent title, picker dispatch and existing options/reasoning/keyboard behavior. Lint, config validation and native rendering passed. Installed the shared panel module in place, preserving backend connections, with prior file at `~/.local/state/agent-chat/install-backups/agent-header-20261015T073620Z/panel.luau`. Refreshed the portable archive/checksum with this change. No inference requests.


## Backend title dropdown correction — 2026-10-15

User clarified that “agent” meant OpenCode/Codex, not configured OpenCode agents. Header title dropdown now selects OpenCode or Codex, matching the model picker style, and the title reflects the selected backend. Removed duplicate service switching from Chat options and restored its OpenCode agent dropdown. Background work continues when switching backends; submission-in-flight guards remain. Both-layout fixtures verify backend dispatch/title and native agent/reasoning controls. Installed shared module in place with backend connections preserved; refreshed portable archive. No inference calls. This supersedes the previous agent-title behavior.


Header refinement, 2026-10-15: removed the subtitle under the backend dropdown and made the dropdown a direct child of the vertically centered header row. Shared by centered/fullscreen layouts; prior module backed up outside source. Portable archive refreshed.


Version bump, 2026-10-15: manifest and Codex helper client metadata now use 0.5.0. Updated README/install examples and built dist/agent-chat-0.5.0.tar.gz plus SHA-256 checksum. Manifest lint and archive version/checksum validation passed. Older archives retained; running plugin was not restarted for repackaging.


## 0.6.0 implementation candidate and validation staging — 2026-10-15

Continued per user request and completed the planned implementation foundation on `milestone/0.6.0`. Added supervised interactive helper process groups/liveness/once-only results, backend/session/navigation job ownership, failure cleanup, connection attempt generations, bounded jittered backoff (eight failures, 30-second delay cap), 20-second startup timeout, authoritative session/pending-request restoration gates, independent activity states, duplicate-reply prevention, stale search/rename/delete/agent guards, and sanitized version/schema/job/retry diagnostics. Explicit recovery now also preserves interrupted pending preference files. Candidate manifest/helper metadata is 0.6.0; existing release archives remain unchanged.

User requested implementation completion before joint checks. After all 30 Python tests, 10 Lua suites, syntax and lint passed, committed the main runtime work as `2e5eab2` and staged the candidate while both backends were idle with no pending requests. Backed up private pre-migration preferences outside source and preserved the prior owned payload. Native checks confirmed schema 1 writable, no pending file, retained drafts/pins/choices/export destination, both layouts rendered, configuration valid, OpenCode connected, and Codex discovery returned seven models. Restored original selected backend. A brief initial Codex registration race was fixed by waiting for detached-helper readiness inside the bounded connection attempt; targeted startup tests pass. Final helper result validation rejects incomplete objects as errors. No inference, full desktop restart, shared-service shutdown, release archive rebuild, merge or publication. Read-only usage check reported 54% five-hour / 8% weekly.

Physical dialogs, generation/Stop, keyboard and permissions under 0.6.0 still need joint acceptance. Track outcomes in `docs/VALIDATE-0.6.0.md`; implementation readiness is not full release acceptance. Rollback payload: `~/.local/state/agent-chat/install-backups/20261015T084236550981Z/plugin/`. Private original preferences: `~/.local/state/agent-chat/install-backups/validate-0.6.0-20261015T084236Z/preferences.json`. Do not copy those private files into Git or reports.


## Milestone 0.7.0 — 2026-10-15

Implemented and staged the setup/selection milestone on milestone/0.7.0. Fresh installs receive a bounded metadata-only runtime check, backend connection/model selection and optional-tool guidance. Existing preferences skip onboarding and preserve choices; Chat options can reopen setup. Codex account status is sanitized through the existing helper. Favorite models and five recent explicit selections persist independently per backend, with unavailable favorites removable. Service validates model/effort changes and active-work constraints.

34 Python tests, 12 Lua suites, syntax/lint/config checks pass. Native runtime checks found both installed backends, preserved preferences, rendered both layouts and confirmed Codex sign-in/seven models without prompts. Restored OpenCode and centered chat. See docs/MILESTONE-0.7.0.md for backups and remaining physical UI acceptance; no new restart/outage checks were performed.


## Milestone 0.8.0 candidate — 2026-10-15

Finished and staged attachment previews, file metadata, screenshot instructions/fallback feedback and local-date history groups/filters. Added bounded input/signature checks and pre-send file metadata checks. Fixed draft loss when an asynchronous saved-chat open fails: restore the target draft only after confirmed metadata, and preserve the original idle chat on a missing pin. History has loading/error/no-match states, stable page scroll identity and bounded deduplicated pagination.

39 Python tests and 12 Lua suites pass; native version/rendering/config/preference-preservation preflight passed. Installed candidate 0.8.0; user acceptance remains pending. Source docs/MILESTONE-0.8.0.md records backup paths and the physical checklist. No provider inference, desktop restart, unrelated configuration edits or merge.


## Milestone 0.9.0 public-ID candidate — 2026-10-15

Runtime changes and public-ID migration are installed: iboldizsar/agent-chat 0.9.0/API32. Latest released Noctalia 5.2.1 supports API32; API33 is unreleased, and the old API27 minimum overlooked newer image tooltips. Corrected source/builder/dependency guidance accordingly. Notifications defer blocked navigation and deduplicate approval IDs durably; usage has freshness/timestamp/manual refresh; export failure fixtures protect originals. Store installs initialize the portable context safely. Migration preserves old caches and all settings/private selections; native preflight and both layouts pass. 56 Python tests/14 Lua suites pass. No provider inference or push. User-facing candidate acceptance and submission thumbnail remain pending. See MILESTONE-0.9.0.md for exact backup/rollback paths and current checklist.


## 0.9.1 history-row deletion — 2026-10-15

Added a trash button beside Pin on every history row and a named inline confirmation. Both adapters accept an explicit target ID; deleting another row leaves the selected chat/draft intact. Duplicate deletion requests are suppressed, active/offline states are guarded, and pins/drafts are removed only on success. Focused adapter/service/panel and packaging checks pass; installed candidate 0.9.1 renders both layouts. Previous payload: ~/.local/state/agent-chat/install-backups/20261015T120223306202Z/plugin/. No actual user chat was deleted during verification.


## 0.9.2 compact activity — 2026-10-15

Consecutive command/tool entries now appear as one collapsed Activity indicator, showing count and known running/failure state. Expand for full retained command/result details. OpenCode tool-only assistant records are grouped and empty assistant placeholders hidden. Approvals/questions remain separate and visible; export/history storage is unchanged. Focused grouping/adapter/panel/packaging tests and syntax/lint pass. Installed while idle; rollback payload ~/.local/state/agent-chat/install-backups/20261015T120753760109Z/plugin/.
