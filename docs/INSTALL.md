# Install Agent Chat on another laptop

This is a private local plugin package, not a published Noctalia catalog entry. It includes no authentication, chat history, personal instructions, settings, or attachment caches from the development laptop.

## Requirements

- Linux with a working Noctalia v5 session. Tested with Noctalia 5.2.1 and plugin API 27; use a release supporting API 27 or newer.
- Python 3.11 or newer (standard library only).
- At least one configured backend, accessible from Noctalia's desktop PATH:
  - OpenCode v2: tested with 2.0.29 and its native local service. V1 is unsupported.
  - Codex CLI: tested with 0.162.1 and its stdio app-server.
- Sign in/configure providers on the target laptop through the backend itself. Do not transfer authentication files in this archive.

Optional features:

| Tool | Feature |
| --- | --- |
| `zenity` | File picker and Markdown Save As |
| `wl-paste` (`wl-clipboard`) | Clipboard images and screenshot attachment |
| `hyprctl` | Automatic attachment from Noctalia's screenshot/annotation tools; currently Hyprland only |
| `notify-send` (`libnotify`) | Clickable completion/approval notifications; otherwise plain notifications remain |
| `xdg-open` | Opening user-selected consent links |

On other compositors, chat, file selection and export remain usable; use your screenshot tools followed by Paste image. True desktop-window tiling is not supported by the native Noctalia panel API. Transparency follows both the plugin controls and Noctalia's panel settings.

## Extract, check, install

Copy both the archive and its `.sha256` file to the other laptop. From that folder:

```sh
sha256sum -c agent-chat-0.7.0.tar.gz.sha256
tar -xzf agent-chat-0.7.0.tar.gz
cd agent-chat-0.7.0
python3 scripts/doctor.py
python3 scripts/install.py
python3 scripts/install.py --apply
noctalia msg plugins enable local/agent-chat
```

The checksum verifies that the archive matches the checksum you copied; it is not a publisher signature.

`doctor.py --backend codex` or `--backend opencode` checks for a particular backend. It invokes only executable version commands, never a prompt, sign-in flow, or backend service. It reports optional tools independently. Installation stops if required dependencies are missing. `--skip-checks` is for offline staging, not a substitute for a compatible runtime.

The executable PATH seen in a terminal can differ from Noctalia's desktop PATH, particularly with version managers. If backend launch fails from the plugin, make the executable accessible to the shell session that launches Noctalia using that laptop's normal environment configuration.

## First launch

1. In Noctalia settings, add the `local/agent-chat:status` bar widget if wanted.
2. In Settings → Control Center, add the Agent Chat shortcut (`local/agent-chat:chat`). Noctalia has a limited number of slots; choose which existing shortcut to replace yourself.
3. Open Agent Chat. On a fresh installation, setup checks the desktop PATH, preselects the only available backend if there is one, and lets you connect OpenCode or Codex and choose a discovered model. Finish setup when connected. Use the backend’s normal CLI sign-in if needed; no test prompt is sent. Existing installations retain their choices and skip setup. Review it later from Chat options → Setup & dependencies. Missing optional tools do not block text chat.
4. Configure appearance and notifications through the plugin's settings page, or right-click its shortcut/bar icon.

To open directly:

```sh
noctalia msg panel-toggle local/agent-chat:panel
noctalia msg settings-open-plugin local/agent-chat
```

For OpenCode, start its existing native service when needed:

```sh
opencode service start
```

The adapter reads `~/.local/state/opencode/service.json` and communicates with its authenticated loopback server. That path is the currently tested contract. Custom state layouts need adapting; do not copy a registration/password from another laptop.

Codex starts an owned stdio app-server on demand, using its existing local configuration/authentication. It does not require a shared daemon, raw API key, or a second provider setup. Shared-daemon transport was not adopted for this package.

A global shortcut is optional. Bind this command using the target compositor's supported configuration:

```sh
noctalia msg panel-toggle local/agent-chat:panel
```

The installer does not edit compositor bindings or Noctalia layouts. Super+/ is a suggestion, not installed automatically. On this development laptop it already exists and is preserved.

## Files and ownership

| Location | Purpose |
| --- | --- |
| `~/.local/share/noctalia/plugins/agent-chat/` | Replaceable owned plugin payload |
| `~/.local/share/agent-chat/assistant/AGENTS.md` | Portable assistant context; created once and preserved on updates |
| Noctalia's `pluginDataDir()` | Private preferences, drafts, pins, attachment cache and diagnostics |
| `~/.local/state/agent-chat/codex/` | Private helper registration/token and lock |
| `~/.local/state/agent-chat/install-backups/` | Previous payload backups |
| Save As destination | User-selected Markdown exports |

The install paths above are the supported default home layout. The installer does not migrate custom XDG directory layouts. `--home PATH` stages into an alternate home for isolated tests and does not configure the running desktop.

The portable context does not assume Arch, Hyprland, a username, dotfiles, or a laptop-config skill. It uses an existing skill if available. Edit it for the new laptop if desired; the installer will preserve edits. Existing assistant files on the development laptop are not overwritten by the portable template.

## Update and rollback

Finish/Stop running work before replacing the payload, then:

```sh
noctalia msg plugins disable local/agent-chat
python3 scripts/install.py --apply
noctalia msg plugins enable local/agent-chat
```

Updates require Agent Chat's ownership marker, preserve assistant instructions and private state, and print a backup path. Unmanaged destinations, symlinked destinations and leftover staging paths are refused. Backend history is not copied or migrated.

To roll back, disable the plugin, move the current owned payload aside, copy the printed backup's `plugin/` directory back to the normal payload location, then enable. Preserve private state and later Noctalia settings edits. Rolling code back does not roll back conversations.

## Uninstall without deleting history

Finish/Stop work and disable the plugin first:

```sh
noctalia msg plugins disable local/agent-chat
python3 scripts/install.py --uninstall
python3 scripts/install.py --uninstall --apply
```

The uninstall command removes only the owned plugin payload, after backing it up. It preserves assistant instructions, drafts, attachments, helper state, exports and backend history. Remove your bar/control-center placements and compositor shortcut through their normal settings.

Disabling asks the owned Codex helper to stop if idle. If necessary, stop an idle helper before removing the payload:

```sh
python3 ~/.local/share/noctalia/plugins/agent-chat/helper/codex_bridge.py stop \
  --state-dir ~/.local/state/agent-chat/codex \
  --cwd ~/.local/share/agent-chat/assistant
```

Use your configured assistant directory if changed. The helper refuses shutdown while work/approvals remain. Never stop the shared OpenCode service or unrelated Codex daemons as part of uninstall.

## Validation limits

Daily-use checks passed on the development laptop, including both backends, models, attachments/images, keyboard shortcuts, background responses, Stop, permissions, notifications, native screenshots, Save As and the redesigned options screen. Packaging tests cover isolated install/update/uninstall, preservation and archive contents. A clean staging test is not a second-laptop desktop integration test. Restart-during-work, outage/recovery, large-history performance and multi-monitor validation remain deferred.
