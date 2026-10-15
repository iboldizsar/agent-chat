# Milestone 0.8.0 — attachments and history

Branch: `milestone/0.8.0`  
Baseline: accepted 0.7.0 merged into main  
Status: complete; installed 0.8.0 accepted by the user on 2026-10-15

## Implemented in source

- Image thumbnails and a larger in-panel preview, with explicit removal before sending.
- Scrollable attachment cards with filename, size, image capability feedback and file MIME/reference descriptions.
- Native image controls scale retained originals; no new image-processing dependency or attachment cleanup is introduced.
- The file picker displays the 8 MiB limit before selection.
- Screenshot instructions explain region/annotation → Copy → close, with success/cancel feedback. Identical clipboard images still attach nothing; Paste image remains the fallback.
- History sections: Pinned, Today, Yesterday, Previous 7 days, Older, Unknown date.
- Local calendar-day comparison handles DST without assuming every day lasts 24 hours. Backend timestamps and legacy pin values normalize to seconds.
- All/Pinned filtering and consistent title-only search for both fetched chats and saved pins.
- Pins outside loaded results remain accessible and removable, with an explicit unverified-availability tooltip. Absence from a page never deletes a pin.
- History loading, empty, no-match and failure states; refresh clears stale rows and late searches cannot replace current results.
- Serialized pagination, row deduplication and repeated-cursor detection. Stable scroll identity across pages; backend/query/filter changes get separate scroll identities.
- Rename/delete refreshes retain the active title query.

## Verification

All 35 Python tests and 12 Lua suites pass. Fixtures cover screenshot cancellation metadata, retained source files, both panel layouts, preview/removal, incompatible image models, history filtering/date boundaries/missing dates, both backend timestamp units, repeated pages, loading/error transitions and stale queries. Lua syntax, Noctalia manifest lint (zero errors/warnings), and diff whitespace checks pass.

No provider inference, local deployment, private-state changes, desktop configuration changes or archive rebuild in this slice. Source manifest and installed plugin remain 0.7.0 until candidate staging.

## Final implementation and native preflight

- No screenshot completion callback is exposed in the inspected host runtime API. Keep the existing Hyprland overlay/clipboard observer; do not add another capture stack.
- Capture checks required tools before opening an overlay; instructions disable automatic capture when required executables are absent. Paste image remains available.
- Validate common raster signatures before caching; other image formats remain local file references. PNG preview dimensions are bounded at 32 megapixels. Signature checks are not a full image decoder/integrity guarantee.
- Bounded file reads, missing/oversize/invalid-file fixtures and pre-send file metadata checks preserve the draft on error.
- Opening a chat now restores its draft only after the backend confirms the target. Failed pin lookups preserve the current chat, draft and attachments, leave Unpin available, and do not strand a different idle chat behind recovery gates.
- Candidate manifest/helper metadata updated to 0.8.0; portable archive and checksum built and verified. OpenCode connected and Codex discovered seven models with sign-in ready; restored OpenCode afterward. Both native layouts report successful rendering, configuration/lint pass, preferences remain writable and the original selections/drafts/pins/export folder/favorites/setup state compare unchanged with a private backup.
- All 39 Python tests and 12 Lua suites pass. No provider prompt, desktop restart or global configuration edit.

Private backups: previous payload `~/.local/state/agent-chat/install-backups/20261015T091912168375Z/plugin/`; pre-update preferences `~/.local/state/agent-chat/install-backups/validate-0.8.0-20261015T091911Z/preferences.json`. Preserve these outside Git/releases.

Reported usage: 72% five-hour / 11% weekly during staging, below the 85% guard. No inference tests were run.

## Hands-on acceptance checklist

1. Attach an image: check thumbnail, name/size, larger preview, Back and Remove in both layouts. Try a text-only model and confirm the compatibility hint retains the draft.
2. Attach a file with a long/Unicode name; check type/size and removal. Missing/invalid/oversize cases have isolated fixtures.
3. Start a screenshot, choose Copy and close annotation; verify attachment and focus return. Cancel a second capture and confirm no stale image is attached.
4. Open history: check date groups, All/Pinned and title search. Load more pages if available and confirm scroll stays usable. A missing saved pin should show an opening error and remain removable without losing the current draft.

The user confirmed “works” after the installed-candidate preview, screenshot and history checks on 2026-10-15. Recorded hands-on acceptance based on that confirmation; no additional agent-run tests or inference were performed. Fresh-install/second-laptop/restart/outage gates remain separately tracked for 1.0.

## Rollback

Finish/Stop active work, disable the plugin, restore the previous owned payload backup, and enable it again. Preserve current private preferences and assistant context; do not overwrite new drafts with the pre-update copy. Schema remains 1.

Keep the accepted header/options design, existing screenshot stack, panel-local shortcuts, per-backend histories, usage guard and private retained attachments. No automatic attachment garbage collection or new global keybindings.
