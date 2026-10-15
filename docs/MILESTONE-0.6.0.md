# Milestone 0.6.0 — lifecycle foundation

Branch: `milestone/0.6.0`  
Baseline: 0.5.0  
Status: in progress; development changes are not installed into the live plugin

This is the first milestone from [the 1.0 plan](V1-PLAN.md). Keep existing UI decisions and private state. No live backend inference, desktop restart, migration of the real preferences file, release rebuild or deployment is needed for its initial implementation slices. Bump the manifest/helper metadata together when the milestone is ready, rather than labeling incomplete work a 0.6.0 release.

## Progress

- [x] Create the milestone branch from the recorded 0.5.0 work.
- [x] Inventory current backend/desktop capabilities and state ownership.
- [x] Add preference schema 1 and a migration for legacy 0.5.0 preferences.
- [x] Preserve unreadable originals, future-version files and interrupted writes.
- [x] Use a same-directory pending file plus rename for recoverable preference saves.
- [x] Expose persistence failures/recovery without overwriting backend errors.
- [x] Test preference failure paths without touching real private data.
- [ ] Add interactive-job ownership, process-exit recovery and stale-focus guards.
- [ ] Separate connection/recovery state from conversation activity.
- [ ] Guard concurrent/stale connect/discovery/history callbacks consistently.
- [ ] Introduce bounded reconnect/backoff behavior without prompt replay.
- [ ] Expand metadata-only diagnostics for operations and connection state.
- [ ] Complete milestone-wide adapter/fault tests and targeted native UI validation.

## Capability inventory

This table describes the current verified adapter implementation. It is not a claim about all versions of either backend.

| Capability | OpenCode adapter | Direct Codex adapter | Ownership/limit |
| --- | --- | --- | --- |
| Connection | Authenticated loopback HTTP and SSE | Private loopback helper to owned stdio app-server | Backend credentials stay outside plugin state |
| Discovery | Enabled models and visible primary agents | Models, supported effort and sanitized usage | Availability comes from backend; never infer price/credit |
| History | Assistant-directory session listing and message cursors | Assistant-cwd-scoped threads and item cursors | Backend authoritative; title search only |
| Live updates | Events trigger authoritative message/pending refresh | Item/turn events, reconciliation and pending snapshot | Must suppress stale callbacks and duplicate items |
| Stop | Session interrupt | Explicit thread/turn interrupt | Hide is independent; reconnect is not Stop |
| Interactive requests | Permissions and forms | Command/file/additional permissions, questions and supported elicitation | Unsupported interactions remain blocked |
| File input | Adapter-native file representation | Local file mentions/references for tools | Files are not universally ingested binary content |
| Image input | Capability-gated native input | Capability-gated local image input | Retained private files support resumed history |
| Usage | Reported rate/quota errors only | Account-window guard at 85% reported use | No purchases/resets/provider substitution |
| Delete/rename/export | Supported through native v2 APIs | Supported through current app-server methods | Export uses read-only pagination and explicit Save As |
| Runtime ownership | Shared existing OpenCode service | Plugin-owned helper/app-server | Never terminate unrelated processes |

Desktop dependencies: native Noctalia panel/control APIs; Zenity for picker/Save As; wl-paste for clipboard images; existing Noctalia screenshot tools plus Hyprland layer inspection for automatic attachment; notify-send for actionable notifications, with native plain-text fallback. Do not replace the user's screenshot stack or compositor configuration as part of this milestone.

## State contracts to implement

Keep state dimensions independent. Existing `connected`, `busy` and `status` fields remain compatible until their consumers have been migrated and tested.

| Dimension | Proposed values | Source of truth |
| --- | --- | --- |
| Connection | checking, connecting, connected, reconnecting, offline, unsupported | Adapter/transport evidence |
| Conversation | idle, submitting, running, waiting, stopping, completed, interrupted, usage-paused | Backend session/turn/request state |
| Persistence | writable, write-failed, recovery-required, newer-schema | Preference store |
| Interactive job | pending, completed, cancelled, failed, obsolete | Explicit operation identity and process result |

Rules: a disconnected transport does not prove completion or cancellation; a connection attempt cannot overwrite a newer successful one; a recovered pending approval is not a new approval; a late picker result cannot attach to a different chat; and persistence failure must not clear backend errors or drafts. Snapshot data stays serializable and excludes API credentials.

## First implemented slice: preference integrity

`plugin/lib/preferences.luau` owns loading, legacy-to-schema-1 migration, validation and saving. The service keeps using the returned mutable preference value, preserving its existing selection/draft/pin/export behavior.

- Validate known nested structures before consuming them. Preserve unknown root fields in valid files.
- Migrate missing/zero schema versions to schema 1 without resetting backend selections, drafts, pins, effort or export destination.
- An unreadable/malformed original is never replaced automatically. When readable, make a separate private recovery copy first.
- The main panel shows a persistence warning. Chat options offers a two-step explicit recovery choice only if the original could be preserved. Recovery saves the current in-memory choices/drafts and retains the recovery copy.
- A newer schema remains read-only and cannot be reset through this version.
- Save through `preferences.json.writing`, then rename over the destination only after a successful write.
- Preserve a failed/interrupted pending file. Do not overwrite it blindly on restart or on another save attempt.
- Backups and pending files live within the existing private plugin-data directory, outside source and release payloads.
- Metadata diagnostics report schema and writable status, never draft contents or recovery-file contents.

### Recovery boundaries

This slice does not automatically merge an interrupted `.writing` file with the original. Both are preserved and saving remains blocked; inspect/recover them privately while the plugin is disabled. A dedicated interrupted-write recovery interaction can be added in the next slice. Likewise, original reads that fail and backups that cannot be written do not enable a destructive reset.

The existing data-directory privacy setup remains in effect. Same-directory rename is a recoverable replacement strategy, not a guarantee against power loss without filesystem flushes. Do not claim power-loss durability from these tests.

## Fault-driven verification

`tests/test_preferences.lua` covers legacy migration and unknown-field retention, schema-1 reload, malformed nested data, corrupt JSON, backup/read failure, failed writes, failed rename, restart with a pending file, explicit recovery retaining the current draft, and refusal to downgrade newer schemas. Fixtures contain synthetic metadata only.

Run existing Python, adapter, panel, notification, attachment and export suites as regression checks. The package allowlist includes the preference module/test, but the released 0.5.0 archives remain unchanged during development.

Native fault testing, app restarts and deployment remain separate from this offline development slice. Preserve the user's currently working desktop session.

## Next slice

Introduce an operation registry for picker/capture/Save As jobs. It must deliver completion once, detect helpers that exit without JSON, clear pending state on failure, retain originating backend/session/layout, and avoid reopening stale chat views after a newer user navigation. Reuse the proven unbounded interactive transport rather than reintroducing the captured-command timeout.

Initial-slice verification: all 27 Python tests, six Lua fixture suites (including preference faults), Noctalia manifest lint and service syntax checks passed. No live desktop/backend state was modified.
