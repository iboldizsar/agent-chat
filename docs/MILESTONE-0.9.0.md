# Milestone 0.9.0 — integration and submission readiness

Branch: `milestone/0.9.0`  
Baseline: accepted 0.8.0 merged into main  
Status: first slice complete; implementation remains in progress

## User decisions

The user asked to assess the community submission requirements, then authorized this milestone. Publishing identity is **iboldizsar/agent-chat**, confirmed by the user through https://github.com/iboldizsar. No publication or submission is authorized. Preserve the installed `local/agent-chat` until a concrete migration has been tested.

## First implemented slice

- Ship a canonical portable assistant template inside the plugin payload. Both the local installer and plugin-owned setup use it; the previous docs location links to that source.
- A store-installed plugin can prepare the missing default context with no separate installer. Existing instructions remain untouched, including permissions; custom missing contexts and broken symlinks produce guidance.
- Publish complete private instructions with a temporary file and exclusive hard link. Concurrent existing files are preserved, and failure leaves no partial instructions or staging debris.
- Coalesce context setup requests, bound them at eight seconds, and ignore callbacks after timeout or runtime teardown. Backend connection follows successful preparation.
- Add a plugin-level public README with every entry, settings, optional/alternative dependencies, IPC, filesystem/network/process behavior and privacy notes. Include the MIT license in the runtime directory.
- Declare shell commands in manifest dependency metadata, explaining that either backend suffices and desktop utilities are optional. Add permitted catalog tags and nonstrict directives.
- Add `scripts/community.py`: stage only allowlisted runtime payload under `agent-chat/`, substituting the public namespace and author in the staged copy. Default submission API is 33; the working local manifest remains API 27. The staging tool never installs, overwrites an existing stage, commits, pushes or opens a PR.

## Validation and staged output

45 Python tests and 13 Lua suites pass, including private fresh-context initialization, existing/custom context preservation, concurrent creation, failure cleanup, stale callbacks, isolated install/update/uninstall and community identity staging. Lua syntax, manifest lint (zero warnings/errors) and diff whitespace checks pass.

Review folder: `dist/community-0.9-work/agent-chat/` (ignored by Git). Source/staged version is still 0.8.0 pending final milestone completion. Structural checks identify the missing 960×540 thumbnail. They are partial local checks, not upstream CI certification or a claim that the other release gates are closed.

Reported usage rose from 77% to 79% five-hour, weekly 12%. No model prompt, local deployment, private-state change, desktop restart or archive release rebuild occurred. Work stopped at this bounded slice to conserve allowance.

## Remaining work

- Prepare and test public-ID migration: backup preferences, preserve drafts/pins/favorites/settings and existing retained attachment paths; disable the old plugin before enabling the new namespace. Do not silently relocate backend history or delete old attachment files referenced by it.
- Resolve staged API 33 against the locally installed host before deployment; do not force an unsupported API or upgrade the desktop implicitly.
- Capture an appropriate real screenshot and generate the required 960×540 WebP thumbnail. Include visual evidence in the eventual PR.
- Run current community CI checks against the final staged directory; prepare a PR description accounting for every network call, filesystem write and spawned process. Publishing is a separate user action/request.
- Complete notification routing/deduplication, stale usage feedback, export failure cases and focus/accessibility/scaling checks from the 1.0 roadmap.
- Final candidate version/package update and native validation after implementation, followed by user acceptance.

Deferred restart/outage, second-laptop and other 1.0 release gates remain open. Existing accepted 0.8.0 installation is unchanged.
