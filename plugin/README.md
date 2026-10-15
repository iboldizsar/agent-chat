# Agent Chat

Quick desktop chat and laptop assistance using your existing OpenCode or Codex setup. Select models, resume conversations and attach context in a native themed panel.

## Plugin

| Field | Value |
| --- | --- |
| ID | `local/agent-chat` |
| Entries | Bar widget: `status`; panels: `panel`, `fullscreen`; service: `service`; control-center shortcut: `chat` |

## Requirements

- `python3` (3.11+) and the `noctalia` host CLI on the desktop PATH.
- Either `opencode` (tested 2.0.29) or `codex` (tested 0.162.1), configured and signed in through that service. Both appear in dependency metadata; only one is needed for text chat. OpenCode requires its existing v2 service to be running.
- `chmod` for private state/export permissions.
- Optional `zenity`: file selection and Markdown Save As.
- Optional `wl-paste` (wl-clipboard): pasted images and screenshot attachment.
- Optional `hyprctl`: automatic attachment using Noctalia's screenshot/annotation tools on Hyprland. Other desktops can capture normally and use Paste image.
- Optional `notify-send` (libnotify): clickable notification actions; native plain notifications remain available.
- Optional `xdg-open` (xdg-utils): user-initiated consent links.

Missing optional tools do not block text chat. Executables must be accessible from Noctalia, which may have a different PATH from your terminal. No provider credentials are bundled or collected.

## Usage

Enable the plugin in Noctalia's plugin settings. Add `local/agent-chat:status` to a bar and `local/agent-chat:chat` to the control center if wanted. Their click opens chat; right-click opens plugin settings. The `local/agent-chat:service` entry runs in the background while enabled.

Open the centered panel:

```sh
noctalia msg panel-toggle local/agent-chat:panel
```

Open the fullscreen panel:

```sh
noctalia msg panel-toggle local/agent-chat:fullscreen
```

Fresh installations offer setup: check tools, connect a service and choose a discovered model. No test prompt is sent. Review setup later from Chat options → Setup & dependencies. The default assistant instructions are created only when missing; custom directories must already contain an `AGENTS.md` file.

Choose OpenCode/Codex in the title dropdown and a model in the main header. Favorites and five recent explicit choices are separate per backend. Agent/reasoning selection is in Chat options. History has title search, date groups and pins; it remains owned by the selected backend.

Enter sends; Shift+Enter inserts a newline. Esc hides without stopping work; Stop cancels a response. Ctrl+N starts a chat, Ctrl+H toggles history, Ctrl+M chooses a model, Ctrl+, opens options, Ctrl+Shift+A attaches a file, Ctrl+Shift+V pastes an image, Ctrl+Shift+X stops, Ctrl+Shift+F changes layout, and Ctrl+Shift+/ shows help. These shortcuts are panel-local. No compositor shortcut is registered automatically.

Attachments are limited to 8 MiB each. Supported images have thumbnails and larger previews. Other files are local references the assistant can read with its tools; arbitrary documents are not automatically ingested as text. For screenshots, choose Copy and close Noctalia's annotation editor; cancellation or identical clipboard content attaches nothing new. Markdown export is in the header, uses Save As, and never opens the file automatically.

## Settings

| Setting | Type | Default | Behavior |
| --- | --- | --- | --- |
| `assistant_dir` | string | `~/.local/share/agent-chat/assistant` | Dedicated chat context; reload plugin after changing, while idle. Existing instructions are preserved. |
| `open_fullscreen` | bool | false | Bar/control-center actions open fullscreen. |
| `history_open` | bool | false | Expand history when opening chat. |
| `show_bar_status` | bool | true | Show status text beside the bar icon. |
| `background_opacity` | int | 100 | Percent, 0–100. Controls plugin fill; the host panel still follows Noctalia transparency. Text stays opaque. |
| `card_opacity` | int | 100 | Percent, 0–100. Controls card fills without fading text. |
| `notify_completion` | bool | true | Generic completion notification outside the visible chat. |
| `notify_approvals` | bool | true | Generic input-needed notification outside the visible chat. |

## IPC

Open plugin settings:

```sh
noctalia msg settings-open-plugin local/agent-chat
```

Write metadata-only diagnostics into the plugin data directory:

```sh
noctalia msg plugin local/agent-chat:service all diagnose
```

The service also accepts an `action` event with a JSON command payload for internal panel routing. It includes mutating actions such as send, reply and delete; do not invoke commands from untrusted sources. Diagnostic metadata excludes prompt text, drafts and credentials.

## Notes

The native plugin talks to the existing authenticated loopback OpenCode service, or a private loopback Python helper that owns a dedicated `codex app-server --stdio` process. Authentication stays in the backend. The helper registration contains a private local token outside the plugin payload. Backend providers make network requests and tools can access files/run commands under their configured approval policy. The plugin does not download executable code or bypass that policy.

Preferences, drafts, pins, favorites, retained attachments, export staging and diagnostics are written beneath Noctalia's private plugin data directory. Default assistant instructions live at `~/.local/share/agent-chat/assistant/AGENTS.md`; helper state lives at `~/.local/state/agent-chat/codex/`. User-selected Markdown exports are written privately via atomic replacement. Retained attachments are not automatically deleted because resumed history may reference them.

The plugin spawns Python helpers, the backend CLI, optional desktop tools and host IPC commands listed above. Closing chat leaves backend work running. Disabling the plugin stops owned interactive helper streams; the Codex helper may outlive the panel/plugin for recovery. Shared OpenCode and unrelated Codex services are never terminated by the plugin. Native panels cannot be tiled like ordinary desktop windows. No restart/outage or second-laptop support claim is implied by the local validation.

MIT licensed; see LICENSE.
