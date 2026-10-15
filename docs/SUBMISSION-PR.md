<!-- noctalia-pr-template:v1 -->

## Plugin

- **Id:** `iboldizsar/agent-chat`
- [x] New plugin
- [ ] Update to an existing plugin (version bumped in `plugin.toml`)

## What it does

Native desktop chat with the user's configured OpenCode v2 service or a dedicated Codex app-server, independent model selection, persistent backend-owned history, file/image attachments, approvals, generic notifications and Markdown Save As. This is for general chat/laptop assistance, with a fixed assistant context rather than a coding workspace UI.

The plugin uses authenticated loopback HTTP/SSE for OpenCode and a private loopback Python helper for Codex's stdio transport. Providers and tools operate through the backend's existing authentication and permission policy. No raw provider credentials or downloaded executable plugin logic are introduced.

Private writes include preferences/recovery copies, drafts/pins/favorites, notification IDs, retained attachments, export staging, helper token/lock state, diagnostics and missing default assistant instructions. User-selected exports use atomic replacement. Histories stay in the backends; old attachment cache paths are preserved during identity migration. Existing assistant instructions/settings are not overwritten.

## External dependencies

`python3` 3.11+; either configured `opencode` or `codex`; the `noctalia` host CLI and `chmod`. Optional `zenity` for picker/Save As; `wl-paste` for clipboard images; `hyprctl` for automatic capture attachment on Hyprland; `notify-send` for clickable notifications; `xdg-open` for explicit consent links. Spawned helpers and backend processes are included in the payload's documented behavior. Only owned interactive child groups are terminated; the persistent Codex helper can outlive the panel/plugin for recovery. Shared services remain untouched.

## Testing

- [ ] Tested on Niri
- [x] Tested on Hyprland
- [ ] Tested on Sway
- [ ] Tested on another compositor:
- **Noctalia version tested against:** 5.2.1
- **Plugin API level:** 32

Development candidate 0.9.0: 56 Python tests and 14 Lua suites pass; syntax/lint/config checks pass. Native preflight connects both backends, renders both layouts, and preserves private settings/state across local→public identity migration. Existing bar/control-center and Super+/ integration were migrated with private backups. New candidate hands-on acceptance, focus/scaling and deferred lifecycle/second-laptop checks remain open. No inference is needed for setup, migration or most tests. The thumbnail is now included; final structural validation is recorded in the milestone notes. Complete the review attestations before submission.

## Screenshots / Videos

Included: user-created 960×540 thumbnail.webp showing the actual plugin with compact Activity. Add the repository image to the PR description when submitting.

## Checklist

- [x] The directory name matches the part of `id` after the `/` in `plugin.toml` exactly.
- [x] It ships `plugin.toml`, `README.md`, `thumbnail.webp`, and `translations/en.json`.
- [x] `README.md` follows the README template, documents every entry/dependency, and includes exact panel IPC commands.
- [x] `thumbnail.webp` is present and relevant; user-provided generator artwork has been visually reviewed.
- [x] `version` follows semver and is bumped; `plugin_api` is the oldest API level required (image tooltips require 32).
- [x] Only the English translation source is included; no unreviewed translated locales.
- [x] `catalog.toml` is unchanged.
- [x] The staged contribution touches exactly one plugin directory.

## Code review attestation

Leave these for final maintainer review before marking a PR ready. No PR has been opened.

- [ ] The code is readable and not obfuscated, minified, or generated.
- [ ] It does not download and execute remote code.
- [ ] Every network call, filesystem write, and spawned process is accounted for above.
- [ ] I have the right to publish this code under the declared MIT license.
