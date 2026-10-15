# Agent Chat

Native Noctalia desktop chat for general questions and laptop assistance, with selectable **OpenCode** and **direct Codex** backends. Each backend keeps its own models, preferences and conversation history. Coding projects remain in your normal development tools.

## Install on another laptop

See [installation, updates, uninstall and rollback](docs/INSTALL.md).

From an extracted release archive:

```sh
python3 scripts/doctor.py
python3 scripts/install.py              # preview
python3 scripts/install.py --apply
noctalia msg plugins enable iboldizsar/agent-chat
```

Requires Python 3.11+, Noctalia supporting plugin API 32+, and at least one configured backend. Tested with Noctalia 5.2.1, OpenCode 2.0.29 and Codex CLI 0.162.1. The dependency checker reports optional desktop tools separately. No provider credentials are included or duplicated.

The installer copies the plugin to `~/.local/share/noctalia/plugins/agent-chat/`, creates a portable assistant context only if missing, and preserves private state. Updates back up the previous owned payload. Disable the plugin and finish/Stop work before updating or uninstalling. Shell bindings and Noctalia layouts are not changed automatically.

Add Agent Chat to the bar/control center through Noctalia settings. Open manually with:

```sh
noctalia msg panel-toggle iboldizsar/agent-chat:panel
```

Fresh installations open a setup screen that checks tools from Noctalia’s environment and connects your chosen service without sending a test message. Existing installations keep their choices and skip onboarding. Reopen it from Chat options → Setup & dependencies. Optional tools do not block text chat.

## Daily use

- Choose OpenCode or Codex using the title dropdown, and a discovered model from the model picker. The panel title is the selected service name. OpenCode agent selection and Codex reasoning choices are in Chat options.
- The model picker groups favorites and up to five recent explicit choices per backend. Unavailable favorites remain visible and removable; models are never silently substituted.
- Enter sends, Shift+Enter adds a newline, Esc hides chat without stopping work. Stop cancels the current response.
- History supports title search, resume, rename, deletion and per-backend pins. Backend-owned conversations are not silently migrated.
- Attachment cards show names, sizes and file types. Supported images have thumbnails and an in-panel preview; Remove keeps the unsent draft. Screenshot capture explains Copy and close before opening Noctalia’s tools.
- History groups pinned chats and local dates, with All/Pinned filters and title-only search.
- Images and files use a private retained attachment cache. Image capability is checked before sending. Codex non-image files are local tool references rather than generic binary uploads.
- File selection and Save As temporarily hide chat to release keyboard focus, then restore the same layout after selection/cancellation.
- The screenshot button uses Noctalia's region capture and annotation tools. Choose Copy and close capture tools to attach the result. Automatic screenshot attachment currently uses Hyprland layer inspection. On another compositor, capture normally and use Paste image. For an unchanged/identical clipboard image, use Paste image explicitly.
- The main header's download icon exports all stored message pages to Markdown using Save As, remembers the folder, and shows a dismissible saved-path confirmation. Attachment contents are not embedded; activity summaries may be abbreviated. Saving does not launch another application.
- Completion and approval notifications contain generic status, with an Open chat action when `notify-send` is available. Separate toggles are in plugin settings.
- Permissions and agent questions remain explicit actions; unsupported interactions block rather than approve automatically.

Right-click the bar widget/control-center shortcut to configure transparency, notifications, initial history visibility and launch behavior. Chat colors follow Noctalia's theme. Background transparency also depends on Noctalia's panel transparency. True window tiling is unavailable through the native panel API.

## Keyboard shortcuts

All shortcuts below apply only while the chat panel is focused. Normal copy/paste/editing bindings remain available.

| Shortcut | Action |
| --- | --- |
| Enter / Shift+Enter | Send / newline |
| Esc | Hide chat (reserved by Noctalia) |
| Ctrl+N | New chat |
| Ctrl+H | Toggle history |
| Ctrl+M | Model selector |
| Ctrl+, | Chat options |
| Ctrl+Shift+A | Attach a file |
| Ctrl+Shift+V | Paste image |
| Ctrl+Shift+X | Stop response |
| Ctrl+Shift+F | Fullscreen/windowed |
| Ctrl+Shift+/ | Shortcut help |

An optional global open/hide binding is configured through your compositor. The installer does not add one.

## Usage limits and privacy

Discovery and startup do not call models. Prompts require an explicit Send action and are never automatically replayed after errors or reconnection.

The direct Codex helper checks reported usage before new turns and pauses at **85% use** in any reported window, or when ordinary usage is disallowed. It does not purchase credits, reset limits or switch providers. A known block survives a failed quota read. OpenCode does not expose a verified comparable allowance API here; reported quota/rate errors stop generation and retain drafts. Provider retry policy remains controlled by OpenCode.

Private preferences, drafts, pins, attachments and diagnostic metadata live in Noctalia's plugin data directory, outside the source payload. The Codex helper's registration/token and lock live in `~/.local/state/agent-chat/codex/`. OpenCode and Codex retain their own histories. Never package runtime data, authentication, local transcripts or attachment caches.

The portable [assistant context](docs/assistant-AGENTS.md) assumes no particular distribution, compositor, username or dotfiles layout. It references an existing laptop-config skill only if available. Existing customized context files are preserved on update.

## Build a private release

```sh
python3 scripts/package.py
cd dist
sha256sum -c agent-chat-0.9.0.tar.gz.sha256
```

The builder uses the explicit [release file allowlist](PACKAGE-FILES.txt), normalizes archive metadata, and emits a reproducible `.tar.gz` plus SHA-256 checksum. It excludes local conversation/handoff records and implementation notes as well as runtime state. It does not publish or commit anything. Copy the archive and checksum to the target laptop, then follow the included installation guide.

## Checks

```sh
python3 -m unittest discover -s tests -v
lua tests/test_adapters.lua "$PWD"
lua tests/test_panel.lua "$PWD"
lua tests/test_attachment_runner.lua "$PWD"
lua tests/test_conversations.lua "$PWD"
lua tests/test_notifications.lua "$PWD"
lua tests/test_preferences.lua "$PWD"
lua tests/test_jobs.lua "$PWD"
lua tests/test_connection.lua "$PWD"
lua tests/test_activity.lua "$PWD"
lua tests/test_service.lua "$PWD"
lua tests/test_models.lua "$PWD"
lua tests/test_setup.lua "$PWD"
noctalia plugins lint plugin
```

Fixtures use fake transports and never invoke provider inference. Packaging tests perform isolated install/update/uninstall and failure recovery in a temporary home. Daily-use validation passed on the development laptop; a second-laptop runtime test is still needed. Restart-during-work, outages, long-history performance and multi-monitor checks remain deferred.

MIT licensed; see [LICENSE](LICENSE).


The 0.6.0 candidate adds versioned/recoverable preference saves, supervised interactive helpers with liveness checks, navigation-aware dialog completion, independent connection/activity state, bounded reconnect attempts and restored-session admission gates. Corrupt or interrupted preference saves are preserved for explicit recovery; newer schemas remain read-only. Metadata diagnostics exclude backend error text. The 0.6.0 checklist was accepted by user confirmation. The 0.7.0 candidate adds first-run setup, runtime dependency guidance, Codex sign-in status and favorite/recent model selection; the installed 0.7.0 candidate was accepted by the user.


The 0.8.0 candidate adds attachment previews/capture feedback and grouped history with guarded pagination. Failed saved-chat opens preserve the current draft. Implementation checks pass; the user accepted the installed preview/capture/history behavior.


The 0.9.0 candidate uses the public ID `iboldizsar/agent-chat` and plugin API 32 (Noctalia 5.2.1 tested). It adds self-contained context setup, safe identity migration, durable approval-notification deduplication, deferred notification links and timestamped usage refresh. Existing local users must follow [the migration guide](docs/MIGRATION.md) before upgrading. Community submission preparation is documented [here](docs/SUBMISSION.md); a real thumbnail is still required.

The user accepted the installed 0.9.0 runtime and public-ID migration. Community submission assets and deferred 1.0 validation remain separately tracked.
