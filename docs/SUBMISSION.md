# Community submission preparation

Target rules: https://github.com/noctalia-dev/community-plugins/blob/main/README.md  
Public README template: https://github.com/noctalia-dev/community-plugins/blob/main/README_TEMPLATE.md  
Author chosen by the user: `iboldizsar`; public id: `iboldizsar/agent-chat`.

Stage an isolated directory for review (choose a new output path each time):

```sh
python3 scripts/community.py --output-dir dist/community-review --author iboldizsar --plugin-api 32
```

This copies the explicit runtime allowlist under `agent-chat/`, rewrites the namespace in that copy, and reports partial structural blockers. It does not install or publish. Both the source and staged manifests require API 32, matching image tooltips and the latest released Noctalia 5.2.1. API 33 is unreleased. Staged code remains readable; no runtime logic is downloaded or generated.

Remaining submission items include a real 960×540 thumbnail.webp, visual evidence, the final bumped milestone version, current upstream CI and user acceptance of the tested public-ID migration. Do not submit a development stage merely because its local structural check lists only a thumbnail blocker.

## Side-effect inventory for the eventual PR

- Native HTTP/SSE goes to the existing authenticated loopback OpenCode service or the private loopback Codex helper. Backend credentials are reused, never shipped. The helper launches a dedicated stdio app-server and only exposes its allowlisted operations.
- Agent providers and configured tools perform network requests/process/file actions under backend permissions. The plugin does not introduce a raw provider credential flow or download and execute remote plugin logic.
- Filesystem reads include service/helper registration, assistant instructions, selected files and plugin templates. Private writes include preferences/recovery copies, drafts/pins/favorites, diagnostics, retained attachments, helper token/lock state, default instructions and temporary export staging. Explicit Save As writes to the chosen destination by atomic replacement.
- Spawned commands: `python3`, `codex app-server --stdio`, version-only backend checks, `noctalia` IPC, `chmod`, and optional `zenity`, `wl-paste`, `hyprctl`, `notify-send`, `xdg-open`. Stream supervision owns and terminates only its interactive child process group. Shared OpenCode/unrelated Codex instances are preserved.
- No automatic compositor keybindings or shell-layout changes. Capture automation uses existing Noctalia tools and Hyprland layers; other desktops retain Paste image.

The final PR must match the final source inventory and explain ownership/lifecycle accurately. No community PR has been created. The user created and pushed https://github.com/iboldizsar/agent-chat; origin uses git@github.com:iboldizsar/agent-chat.git. This is separate from community-store submission.
