# Milestone 0.7.0 — setup and selection

Branch: `milestone/0.7.0`  
Baseline: 0.6.0 merged into main at user request  
Status: in progress; first model-selection slice implemented, not deployed

## Progress

- [x] Backend-scoped favorites with stable model keys and persisted display-label fallback.
- [x] Five most recent explicit model selections per backend; discovery never updates recents.
- [x] Searchable Favorites / Recently used / All models sections, deduplicated.
- [x] Unavailable favorites remain visible and removable; returning models use authoritative names.
- [x] Validate model choices in the service, including active work and unavailable selections.
- [x] Preserve existing preferences; validate optional model-choice metadata under schema 1.
- [ ] First-run setup that preserves existing installations and can be reopened from options.
- [ ] Runtime executable/version/dependency checks and actionable optional-feature guidance.
- [ ] Single-backend setup flows and explicit setup/model/effort validation.
- [ ] Native validation and final version/package update after milestone implementation.

The model picker keeps the existing header design and theme roles. Favorite metadata does not make an unavailable model selectable. Selection clears model-scoped reasoning so the backend can use its supported default; discovery remains authoritative. No credentials or additional transcript storage are introduced.

## Validation

Focused model, preference, service and both-layout panel suites pass. All 30 Python tests pass; Lua syntax, native plugin manifest lint (zero warnings/errors), and diff whitespace checks pass. No provider prompts, desktop configuration changes, local deployment or release rebuild were performed. Installed candidate remains 0.6.0.

## Next slice

Inspect the installer dependency checks and native process result contract, then add a bounded runtime check from the Noctalia environment. Keep optional utilities independent of basic text chat and avoid requiring both backends. Setup must not silently switch an existing backend/model or issue a test prompt.
