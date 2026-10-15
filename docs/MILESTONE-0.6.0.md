# Milestone 0.6.0 — lifecycle foundation

Branch: `milestone/0.6.0`  
Baseline: 0.5.0  
Status: implementation complete; checklist accepted by user confirmation on 2026-10-15; merged into main

This is the first milestone from [the 1.0 plan](V1-PLAN.md). Keep existing UI decisions and private state. No live backend inference, desktop restart, migration of the real preferences file, release rebuild or deployment is needed for its initial implementation slices. Manifest/helper metadata now identify the 0.6.0 candidate; release packaging follows validation. Existing 0.5.0 release archives are unchanged.

## Progress

- [x] Create the milestone branch from the recorded 0.5.0 work.
- [x] Inventory current backend/desktop capabilities and state ownership.
- [x] Add preference schema 1 and a migration for legacy 0.5.0 preferences.
- [x] Preserve unreadable originals, future-version files and interrupted writes.
- [x] Use a same-directory pending file plus rename for recoverable preference saves.
- [x] Expose persistence failures/recovery without overwriting backend errors.
- [x] Test preference failure paths without touching real private data.
- [x] Add interactive-job ownership, process-exit recovery and stale-focus guards.
- [x] Separate connection/recovery state from conversation activity.
- [x] Guard concurrent/stale connect/discovery/history callbacks consistently.
- [x] Introduce bounded reconnect/backoff behavior without prompt replay.
- [x] Expand metadata-only diagnostics for operations and connection state.
- [x] Complete milestone-wide adapter/fault tests.
- [x] Complete user-facing dialog/generation/approval validation (user confirmation, 2026-10-15).

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

An interrupted `.writing` file is copied privately before explicit recovery can discard the pending file. Recovery refuses if that file changed since the copy, and does not automatically merge drafts from the previous and pending snapshots. The original/pending recovery copies remain available for private inspection. Read failures or backups that cannot be written never enable a destructive reset; newer schemas remain read-only.

The existing data-directory privacy setup remains in effect. Same-directory rename is a recoverable replacement strategy, not a guarantee against power loss without filesystem flushes. Do not claim power-loss durability from these tests.

## Fault-driven verification

`tests/test_preferences.lua` covers legacy migration and unknown-field retention, schema-1 reload, malformed nested data, corrupt JSON, backup/read failure, failed writes, failed rename, restart with a pending file, explicit recovery retaining the current draft, and refusal to downgrade newer schemas. Fixtures contain synthetic metadata only.

Run existing Python, adapter, panel, notification, attachment and export suites as regression checks. The package allowlist includes the preference module/test, but the released 0.5.0 archives remain unchanged during development.

Native fault testing, app restarts and deployment remain separate from this offline development slice. Preserve the user's currently working desktop session.

## Completed runtime work

Interactive helpers now run under `interactive_job.py`, which returns a single result for success, cancellation, launch failure, invalid output or a child crash. It owns the child process group and terminates it on supervisor teardown. Heartbeats distinguish a live user-controlled dialog from a helper that has stopped responding: the Lua runner has a 15-second liveness bound, not a total browsing deadline. It ignores duplicate/late completion after failure. An ownership registry serializes desktop dialogs and records backend/session/navigation identity. A late result cannot attach to a different selected conversation, and completion cannot reopen a view after a newer user navigation.

Connection controllers serialize attempts, invalidate expired generations and apply exponential backoff with jitter, capped at 30 seconds and eight failed attempts before manual recovery. Connection attempts have a 20-second startup deadline. Stale health/HTTP/SSE/history callbacks cannot revive an old connection or replace newer search results. Mutating submissions and exports get an ambiguous-outcome error rather than a replay or permanently stuck callback. Backend conversations remain authoritative.

Restored conversations stay gated until messages, activity and pending permissions/questions have been read. Recovery failure retains the draft and leaves explicit Reconnect available. Repeated in-flight permission replies are suppressed, while an explicit retry is allowed after a failure. Late rename/delete/agent operations cannot overwrite newly selected chat state.

Activity is represented separately from connection state, including submitting, recovering, running, waiting, stopping, completed, interrupted and usage-paused. Disconnect/recovery does not emit false success notifications or turn the bar into an unread-finished state. IPC diagnostics add candidate version, schema/write status, pending operation, retry/recovery/activity fields and error presence; raw backend error text is excluded.

## Joint validation next

The user requested completing implementation before live checks. The candidate was staged after implementation/offline checks and confirmation that both backends were idle. Follow [VALIDATE-0.6.0.md](VALIDATE-0.6.0.md). Tests run during development are offline fixtures, fake processes and isolated installation checks, not real provider inference.

Do not merge this branch or label the release fully validated until the native checks have outcomes. Native process/compositor behavior is not proven by fixture tests.


## Native preflight outcomes

- Candidate 0.6.0 installed with previous payload backup `~/.local/state/agent-chat/install-backups/20261015T084236550981Z/plugin/`.
- Private pre-migration preferences saved at `~/.local/state/agent-chat/install-backups/validate-0.6.0-20261015T084236Z/preferences.json` (never commit or include in reports).
- Schema 1 is writable; no pending preference file remains. Compared preserved drafts, pins, backend choices and export destination with the private pre-migration copy without printing contents.
- OpenCode connected normally. Direct Codex discovery connected and reported seven models without inference; selected backend restored afterward.
- Both panel layouts report successful rendering; Noctalia configuration validates.
- Cold Codex startup now waits for registration readiness within the existing bounded connection attempt, rather than treating the detached helper's startup race as an immediate error. Targeted readiness fixture passes.
- All 30 Python tests and 10 Lua suites, syntax checks and Noctalia lint pass; the final helper-result/startup refinements also pass their targeted suites.
- Read-only account usage reported 54% of the five-hour window and 8% weekly during preflight. No model prompt was sent.

The remaining validation is physical picker/Save As, keyboard/UI, generation/Stop and permission behavior under this candidate. No full Noctalia restart, shared-service shutdown, destructive fault injection on real preferences, archive rebuild, merge or publication was performed.


## Acceptance update — 2026-10-15

The user requested merging into main and starting milestone/0.7.0, then instructed marking the remaining checklist checks as done. This supersedes pending-acceptance/merge restrictions above. Native restart/outage exercises remain separately scheduled; no new agent-run validation or release archive rebuild is implied.
