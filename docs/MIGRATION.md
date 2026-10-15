# Local-to-public plugin identity migration

Old ID: `local/agent-chat`  
New ID: `iboldizsar/agent-chat`  
Status: private-state copy tool prepared and fixture-tested; live activation not performed

The community identity changes Noctalia’s per-plugin data namespace. Backend conversations remain owned by OpenCode/Codex in the same assistant directory; do not rewrite their history or move retained attachment paths.

## Preparation and preview

```sh
python3 scripts/migrate.py
```

Preview reports source/destination and a file count without printing private contents or writing files. This is only the data-copy portion of migration, not an installer or activation command. The source remains unchanged, including cached attachments and recoverable preference files. Existing public state, symlinks/special files and pending preference writes are refused. Ordinary changes detected during copying abort the operation; this is an extra guard, not a substitute for disabling both runtimes.

## Before applying

1. Finish/Stop active backend work and resolve pending dialogs/approvals.
2. Preserve a separate private copy of the Noctalia settings file and current owned payload. Use the laptop’s controlling configuration source; do not blindly edit generated configuration.
3. Record the old plugin’s settings, bar/control-center placement and any opening shortcut. This tool does not migrate those integration settings.
4. Verify the public payload/API can run on the host. The API-33 submission stage must not be enabled on a host that rejects that API. Do not install both payloads into the same owned local-installer path or use the local installer to overwrite a store-managed payload.
5. Disable both plugin IDs before copying. Do not enable either until copying and integration review are complete.

Then, only when ready:

```sh
python3 scripts/migrate.py --apply
```

The destination is created exclusively and copied files/directories receive private permissions. If interrupted after destination reservation, a partial destination can remain: inspect and preserve it before retrying. The tool refuses to overwrite it. Do not enable the public plugin from a partial migration.

## Integration and acceptance

Recreate the plugin settings under the public ID in Noctalia, especially the same assistant directory. Replace widget/shortcut types with `iboldizsar/agent-chat:status` and `iboldizsar/agent-chat:chat`. Update an existing compositor opening shortcut to `iboldizsar/agent-chat:panel` through its controlling configuration, preserving the user’s key combination. Do not add a second global shortcut.

Enable only the public plugin and verify drafts, pins, favorites, model choices, export folder and history. Check retained images from older conversations. Leave the old private data/cache intact; backend history can still reference those exact old paths. No automatic cleanup is safe yet.

These integration edits and native checks remain pending. Successful fixture copying does not certify the full migration.

## Rollback

Disable the public plugin, restore the recorded old integration settings and payload if needed, and enable the old ID. Both original private state and backend history remain intact. Preserve any new public drafts/state for review before rollback; do not copy them over old preferences blindly.
