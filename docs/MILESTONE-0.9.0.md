# Milestone 0.9.0 — integration and submission readiness

Branch: `milestone/0.9.0`  
Baseline: accepted 0.8.0 merged into main  
Status: runtime milestone complete; installed 0.9.0 accepted by the user on 2026-10-15; submission thumbnail pending

## Completed

- Self-contained store initialization from a canonical in-payload assistant template. Exclusive publication, private files, preservation of existing/custom instructions, timeout and stale-callback guards.
- Public identity `iboldizsar/agent-chat`, chosen by the user. Installer accepts the previous owned payload but refuses upgrading legacy private data until it has been copied. No store-managed/foreign payload is overwritten.
- Private-state migration with source/cache preservation, private destination permissions, pending-write/symlink/special-file refusal, concurrent-change guards and no destination overwrites.
- Settings migration preserves comments/unrelated settings, backs up privately, validates semantic equivalence, detects conflicting namespaces and uses atomic replacement.
- Notification actions activate once, preserve a link when another conversation is busy, and route to the intended chat after work completes. Approval IDs are deduplicated individually across reconnect/reload with a bounded 128-entry private checkpoint. Completion remains transition-based; startup snapshots are baselines.
- Usage distinguishes current, stale (over five minutes/disconnected/read failure) and unavailable evidence. Timestamp and explicit serialized Refresh allowance; no prompt is sent. The helper still checks its 85% guard before each submitted turn.
- Export replacement/source/destination failures covered without partial success or overwriting the original. Stale export-prefetch failures cannot overwrite the new conversation error.
- Native button/tooltip and local-shortcut paths preserved in both layouts; preview/removal and options controls have fixture coverage. No new global shortcut.
- Public plugin README, license, explicit dependencies, catalog tags and nonstrict directives; allowlisted staging and packaging.

## Corrected API requirement

The installed and running Noctalia are the latest release **5.2.1**, supporting API **32**. API 33 is unreleased (`revealKey`); it is not needed here. API 27 was the original frameless-input minimum, but image/container tooltips introduced later require 32. The manifest, submission builder default and dependency guidance now consistently require 32. Earlier API-27/API-33 staging notes are superseded; no desktop upgrade or separate incompatible submission build is needed.

Verified sources:

- https://github.com/noctalia-dev/noctalia/releases/tag/v5.2.1
- https://github.com/noctalia-dev/noctalia/blob/v5.2.1/src/scripting/plugin_api.h
- https://docs.noctalia.dev/noctalia/plugins/development/plugin-api/

## Native migration and preflight — 2026-10-15

Both backends were idle with no pending interactions before deployment. Migrated into the public private-data namespace, installed/enabled `iboldizsar/agent-chat` 0.9.0/API32, moved the plugin settings/bar/control-center references, and changed only the existing Super+/ command in the controlling Hyprland Lua source. All other Noctalia settings and binding content compare unchanged with backup. Existing uncommitted dotfiles changes were preserved and not committed by this project.

Both layouts render and config validates without warnings; Hyprland reload/config checks pass. Codex connects with seven models and one saved conversation; OpenCode connects with 99 models. No provider prompts. Private comparison confirms backend/model/agent/effort, drafts, pins, favorites, export folder, setup completion and plugin settings preserved. Original private data/cache remains in place. Restored the original Codex selection.

Backups (private, outside source):

- Full migration backup: `~/.local/state/agent-chat/install-backups/public-id-20261015T115006Z/` (payload, preferences, Noctalia settings, binding).
- Installer payload backup: `~/.local/state/agent-chat/install-backups/20261015T115007015287Z/plugin/`.
- Settings transform backup: `~/.local/state/agent-chat/install-backups/identity-settings-20261015T115014610259Z/noctalia-settings.toml`.

The five-hour window reset before resuming. Work uses fixtures/read-only discovery, not live inference.

## Validation and remaining gates

56 Python tests and 14 Lua suites pass, including migration/upgrade/settings conflicts, notification routing/deduplication, usage freshness and export failures. Syntax, manifest lint and configuration validation pass. The upstream community validator reports only missing `thumbnail.webp` in the staged payload; the real 960×540 generator thumbnail and screenshot evidence remain required before submission.

Hands-on acceptance checklist:

1. Existing Super+/, bar and control-center tile open the public-ID plugin; settings/transparency remain as before.
2. Chat options → Usage: timestamp/Refresh works; reopening both layouts and normal editing/local shortcuts work. Check Tab/Shift+Tab navigation and long-name clipping at your normal display scale.
3. Image preview/remove, history refresh/pins and Save As still work. During an intended task, confirm notification Open chat and Stop behavior; no extra inference is needed just for this acceptance.

The user accepted the installed candidate with “looks good to me” on 2026-10-15 after the launch-control and usage-refresh checklist. This records user acceptance without claiming new agent-run checks or comprehensive scaling/focus certification. The submission thumbnail, restart/outage, second-laptop and other deferred 1.0 gates remain open. No community PR or Git push was performed.

## Rollback

Finish/Stop active work. Disable the public plugin, restore the payload and settings/binding from the full private backup, reload configuration, and enable local/agent-chat. Preserve new public state before rollback; old state/cache was not deleted. Never overwrite new drafts blindly. See MIGRATION.md.
