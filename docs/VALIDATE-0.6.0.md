# Validate the 0.6.0 candidate

Status: implementation candidate staged; native migration/discovery/rendering preflight passed. User-facing outcomes pending. Source branch: `milestone/0.6.0`.

## Stage safely

Confirm both backends are idle with no pending approvals before replacing the payload. Preserve the owned payload and private preferences outside source. The installer backs up the payload; take a private preference copy before the first real schema-1 migration. Do not print or attach that file to reports. Disable/install/enable the candidate through the supported commands. Preserve the existing assistant instructions, layout and shortcut.

If work is active, leave the current installation alone until it finishes or the user explicitly chooses Stop. Do not terminate shared services or unrelated Codex processes for testing.

## Check in this order

1. Open both layouts. Verify backend/model controls, the absence of a subtitle, options, keyboard editing and existing theme/transparency behavior.
2. Confirm existing drafts, selected model/agent/effort, pins and remembered export folder remain. Reopen the panel and confirm new drafts persist. Do not deliberately corrupt the real preferences file; malformed/newer-schema and interrupted-write cases are covered with fixtures.
3. Open a file picker and leave it open longer than 20 seconds. Select or cancel; chat must return once. Repeat Save As. These dialogs must remain usable despite the connection-startup timeout and liveness checks.
4. Start a picker, manually reopen chat or change backend, then finish selection. It must not attach to another chat or steal focus back to an old layout. An attachment for the same currently selected chat may be retained without reopening it.
5. Capture/copy a screenshot using the existing Noctalia tools. Confirm cancel does not attach a previous image.
6. For each available backend, run one short request. Reuse it to check hidden generation, notifications, history and Stop; avoid redundant inference. Confirm a notification opens the originating chat.
7. Exercise an approval/question during an actual intended task. Rapidly pressing a reply twice must not create duplicate replies. After a failed transport reply, recover authoritative pending state before making another explicit choice.
8. Press Reconnect repeatedly while idle. Only one attempt should be active. The current chat should show restoration before Send becomes available, retain the draft and never resend a prompt.
9. Confirm read-only history/export still works, and changing chats while a rename/delete response is pending cannot clear or rename the new chat. Prefer disposable fixture-created chats for destructive checks.
10. Review metadata-only diagnostics for version 0.6.0, schema 1, writable preferences, no pending desktop job and sensible connection/activity state. No raw error text, drafts or transcript content should be in the report.

An actual backend outage, helper kill or full Noctalia restart is a separate scheduled check. Agree on the exact owned process and expected interruption before doing it. Automatic retries, timeout/stale callbacks, child-process crashes and recovery-state gates already have offline coverage, but those tests do not replace native lifecycle evidence.

## Completion

Record each outcome, any regression and the environment/version. If a blocker appears, keep the branch unmerged and restore the owned payload backup as needed. A 0.6.0 preference file is readable by the previous implementation, but preserve the private pre-validation copy rather than overwriting newer user edits blindly during rollback.

After checks pass: record acceptance, build/audit the 0.6.0 archive and checksum from the final committed state, and merge only when requested. No publication is implied.


Preflight recorded: both layouts render, schema-1 preferences are writable, saved state was preserved, OpenCode connected, Codex discovered seven models, and the original selected backend was restored. Continue with user-facing checks above; do not count discovery/rendering as successful generation or dialog testing.
