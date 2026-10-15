# Local-to-public plugin identity migration

Old ID: `local/agent-chat`  
New ID: `iboldizsar/agent-chat`  
Status: migration implemented and applied on the development laptop; candidate validation pending

The community identity changes Noctalia’s per-plugin data namespace. Backend conversations remain owned by OpenCode/Codex in the same assistant directory; do not rewrite their history or move retained attachment paths.

## Preparation and preview

```sh
python3 scripts/migrate.py
```

Preview reports source/destination and a file count without printing private contents or writing files. Without --settings this is only the data-copy portion of migration, not an installer or activation command. The source remains unchanged, including cached attachments and recoverable preference files. Existing public state, symlinks/special files and pending preference writes are refused. Ordinary changes detected during copying abort the operation; this is an extra guard, not a substitute for disabling both runtimes.

## Before applying

1. Finish/Stop active backend work and resolve pending dialogs/approvals.
2. Preserve a separate private copy of the Noctalia settings file and current owned payload. Use the laptop’s controlling configuration source; do not blindly edit generated configuration.
3. Record the old plugin’s settings, bar/control-center placement and any opening shortcut. This tool does not migrate those integration settings.
4. Verify the public payload/API can run on the host. The current payload requires API 32, supported by the tested Noctalia 5.2.1. API 33 is unreleased and is not required. Do not install both payloads into the same owned local-installer path or use the local installer to overwrite a store-managed payload.
5. Disable both plugin IDs before copying. Do not enable either until copying and integration review are complete.

Then, only when ready:

```sh
python3 scripts/migrate.py --apply
```

The destination is created exclusively and copied files/directories receive private permissions. If interrupted after destination reservation, a partial destination can remain: inspect and preserve it before retrying. The tool refuses to overwrite it. Do not enable the public plugin from a partial migration.

## Integration and acceptance

To prepare only the Noctalia settings transformation, use `python3 scripts/migrate.py --settings ~/.local/state/noctalia/settings.toml` (preview), then add `--apply` after disabling the old plugin. It preserves unrelated settings/comments, keeps a private backup and refuses conflicting identities. This does not edit compositor bindings.

Retain plugin settings under the public ID in Noctalia, especially the same assistant directory. Replace widget/shortcut types with `iboldizsar/agent-chat:status` and `iboldizsar/agent-chat:chat`. Update an existing compositor opening shortcut to `iboldizsar/agent-chat:panel` through its controlling configuration, preserving the user’s key combination. Do not add a second global shortcut.

Enable only the public plugin and verify drafts, pins, favorites, model choices, export folder and history. Check retained images from older conversations. Leave the old private data/cache intact; backend history can still reference those exact old paths. No automatic cleanup is safe yet.

On the development laptop, the state/settings/placement/binding migration has been applied and metadata/config/rendering preflight passed. User-facing acceptance and deferred lifecycle tests remain pending; see MILESTONE-0.9.0.md.

## Rollback

Disable the public plugin, restore the recorded old integration settings and payload if needed, and enable the old ID. Both original private state and backend history remain intact. Preserve any new public drafts/state for review before rollback; do not copy them over old preferences blindly.
