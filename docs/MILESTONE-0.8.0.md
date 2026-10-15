# Milestone 0.8.0 — attachments and history

Branch: `milestone/0.8.0`  
Baseline: accepted 0.7.0 merged into main  
Status: first implementation slice complete; native validation and final polish pending

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

## Remaining work

- Inspect the installed host for a more direct screenshot completion signal before finalizing the current compositor-based fallback.
- Refine screenshot availability/fallback feedback for missing clipboard tools or unsupported desktops.
- Native checks for image decoding/layout, long names/multiple attachments, local date groups, picker/capture focus and pagination scroll preservation. Fixture rendering cannot prove native geometry or scroll behavior.
- Validate missing/invalid/oversize image inputs and history pins whose backend conversation was removed externally; retain drafts and avoid destructive assumptions.
- Update version and build/stage the candidate after implementation checks; obtain user acceptance of the new behavior.

Keep the accepted header/options design, existing screenshot stack, panel-local shortcuts, per-backend histories, usage guard and private retained attachments. No automatic attachment garbage collection or new global keybindings.
