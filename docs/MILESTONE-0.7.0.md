# Milestone 0.7.0 — setup and selection

Branch: `milestone/0.7.0`  
Baseline: 0.6.0 merged into main at user request  
Status: complete; installed 0.7.0 accepted by the user on 2026-10-15

## Progress

- [x] Backend-scoped favorites with stable model keys and persisted display-label fallback.
- [x] Five most recent explicit model selections per backend; discovery never updates recents.
- [x] Searchable Favorites / Recently used / All models sections, deduplicated.
- [x] Unavailable favorites remain visible and removable; returning models use authoritative names.
- [x] Validate model choices in the service, including active work and unavailable selections.
- [x] Preserve existing preferences; validate optional model-choice metadata under schema 1.
- [x] First-run setup that preserves existing installations and can be reopened from options.
- [x] Runtime executable/version/dependency checks and actionable optional-feature guidance.
- [x] Single-backend setup flows and explicit setup/model/effort validation.
- [x] Native metadata/rendering preflight and final version update.
- [x] Hands-on setup/favorites acceptance on the installed candidate (user: “looks good to me”, 2026-10-15).

The model picker keeps the existing header design and theme roles. Favorite metadata does not make an unavailable model selectable. Selection clears model-scoped reasoning so the backend can use its supported default; discovery remains authoritative. No credentials or additional transcript storage are introduced.

## Validation

All 34 Python tests and 12 Lua suites pass, including setup timeout/stale callbacks, CLI version failures, fresh single/dual/missing-backend installs, cancellation, existing-install preservation, unsupported effort and Codex sign-in gating. Lua syntax, Noctalia manifest lint (zero warnings/errors), configuration validation and diff whitespace checks pass.

Native 0.7.0 preflight: existing preferences migrated with setup marked complete, no onboarding forced. Private comparison confirmed backend, selections, drafts, pins and export folder preserved; no pending write remained. Reopened setup discovered OpenCode 2.0.29, Codex 0.162.1 and all optional tools from Noctalia’s environment. Both layouts report successful rendering. Codex connected, listed seven models and reported existing sign-in ready. Original OpenCode selection and centered chat restored. No model prompts, desktop restart or layout/keybinding edits.

Private backups (outside source):

- Payload: `~/.local/state/agent-chat/install-backups/20261015T090459744628Z/plugin/`
- Preferences: `~/.local/state/agent-chat/install-backups/validate-0.7.0-20261015T090459Z/preferences.json`

Reported usage during this work: 63% five-hour, 10% weekly, below the existing 85% admission guard. No extra inference tests were run.

## Hands-on acceptance checklist

1. Open Chat options → Setup & dependencies → Review setup. Confirm the service descriptions and optional tools are readable in both layouts. Later returns to chat; reopening setup preserves choices.
2. In the model picker, favorite/unfavorite a model. Select a model explicitly; verify it appears in Recently used. Switch backend and confirm independent lists.
3. Reopen/reload when idle; favorites and recent choices persist, and setup does not appear automatically after completion.

Fresh installations and unavailable models/tools are covered by isolated fixtures rather than by damaging the working laptop. Second-laptop runtime acceptance, restart/outage and other deferred 1.0 gates remain open. The user accepted the installed 0.7.0 candidate with “looks good to me” on 2026-10-15. This records product acceptance without claiming additional agent-run tests or execution of the deferred 1.0 gates.

## Rollback

Finish/Stop any active work, disable local/agent-chat, restore the previous owned payload backup, then enable it again. Preserve current private preferences and assistant context. Schema remains 1 with backward-compatible optional setup/model-choice fields; do not overwrite newer drafts with the pre-validation copy.
