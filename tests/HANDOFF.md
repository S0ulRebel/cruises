# Validation handoff

## 2026-10-12 — Approved usability follow-up

All 22 default checks, separate cold reopen routes and the deliberate engine-error
rejection self-test pass headlessly on Godot 4.7.2, with authored source unchanged.
The native fixture passes 213/213 assertions, including same-tab Save As/Save,
stale save-dialog identity, simultaneous hierarchy/drawer, filtered asset discovery,
hierarchy eyes/rename/reparent undo, private animation-track rebasing, attachment
banner/cancel, coordinate/snapping controls, inline fields, cursor origin preview
and insertion undo, four advanced tabs, source aliases and Focus restoration.
Evidence: `%TEMP%/cruises-checks-3a572b89171f4c5ba843ccc99d2f07f9/`.

Verbose diagnostics identified the cabin check's intermittent teardown leak as
Ogg playback resources. Its test now explicitly stops the authored audio service
and permits a mix interval after freeing the game; unthrottled headless process
frames alone were insufficient. Engine errors remain fatal.
No graphical checks ran during this follow-up, respecting active GPU training.
Revised layout sizing, overlay legibility and physical mouse flows remain a later
visual acceptance check; the earlier GPU evidence below covers the earlier UI.

## 2026-10-12 — Character Workshop visual workspace

All 22 default checks/cold reopen routes and the deliberate engine-error rejection
self-test pass on Godot 4.7.2. The native editor fixture now passes 174/174 assertions:
two real scene views, authored hierarchy/collapse retention, root selection,
viewport drags and cancellation, exact transform Apply/Cancel/undo, picked
attachments, project search, safe GLB import and existing source/save independence.
Evidence: `%TEMP%/cruises-checks-8886df44ee964b44917681864e669c83/`.

After asset-thumbnail layout/fallback changes, editor, workshop integration with
cold reopen, and authored-scene checks pass again with authored hashes unchanged:
`%TEMP%/cruises-checks-c4a8b69c52474907a6455d990aa0c8c2/`.
The optional `CRUISES_WORKSHOP_CAPTURE` destination exercises Compatibility GPU
rendering in the actual editor; it captures workspace, Assets and Fine adjust
externally. The final run passes 174/174 with no engine/script errors, and inspected
images show the real portrait assembly and hair/chair thumbnails.
Evidence: `%TEMP%/cruises-workshop-final-109c40bcbfd24286b2be2a64d43193f1/`.
Final coordinate-label correction also passes the native editor check with authored
hashes intact: `%TEMP%/cruises-checks-4176714cb41f45db9bd4db05e039ba4d/`.
This verifies the delivered UI; final body/clothing art and owner usability
acceptance remain separate from automated checks.

2026-10-11 owner corrections: `authored_scene_check.gd` now expects the lower
`cabin_reference_eye_level_v1` camera, actor heights 280–480px, and a deliberate
partial foreground crate crop (at least 35% of its projected width in frame).
Other full bounds, all baseline noncamera transforms, picking and floor checks
remain. Focused external graphical previews verified the UI changes, projection
measurements and eight hotspot rays without engine errors; the full suite was
not run at owner request. See UI/cabin module handoffs for evidence and limitations.

- Root harnesses moved into `tests/`; authored Game/Location checks replace the
  stale Main/builder introspection checks. See `README.md` for commands and coverage.
- The external PowerShell 7 runner requires successful exit and a completion marker,
  rejects engine errors/timeouts, isolates logs, and checks authored source hashes.
- The deliberate false-pass probe must be rejected with wrapper exit code 1.
- The outdoor fixture's saved navigation resource includes its two rotated crates.
  Normal checks rebake only in memory and never overwrite authored resources.
- Graphical head/hand/model diagnostics are retained as manual checks and now write
  to unique OS cache directories. They are excluded from the headless default suite.
- Shared API dependency changes belong to integration; keep tests on actual exported
  Game, Location, GameState, Hotspot and movement completion contracts.
- Failed transition coverage requires Game's rollback contract: preserve the old
  location, camera, navigation and session state on invalid references/type or an
  empty authored navigation mesh. A deliberately nonwalkable location is allowed.
- Material regression checks highlight two independent fishbowls, restore hover-off
  values, and free both with frame waits. Snapshots contain values only and cannot
  hide a renderer lifetime bug by retaining material references. Rollback also
  exercises a real hovered prop and compares its restored material values.
- Source hashes include import settings, script UIDs, textures/audio/fonts. Normalize
  only newline differences in text `.import` files; keep all other byte hashes exact.
- `portrait_check` adds actual speech/response portrait reuse, framing, jaw attachment,
  authored-transform and teardown checks. `portrait_capture` provides isolated GPU
  images of the actual Game panels and verifies speech changes visible pixels.
- Character Workshop is included in the default suite. Native editor tests
  launch an authored @tool fixture in the actual editor, not a second SceneTree loop.
  Assembly, nested composition, animation graphs, exported actor and head swap have
  explicit separate-process reopen routes. Mesh/legacy/editor checks spawn their own
  cold processes. Real source meshes are always selected for the mesh regression.
- Final Godot 4.7.2 run passes all 21 checks, 114 assembly assertions, 109 native
  editor assertions and all cold routes, with no engine/script errors. The deliberate
  false-pass self-test is rejected correctly. Tracked source hashes include `.res`
  and `.scn` along with the existing script/model/import/resource coverage.
  Evidence: `%TEMP%/cruises-checks-c672df683e5e4f13966fe5ac8e6f1f52/`.
- Template workflow follow-up passes 125/125 native editor assertions, including
  immediate unsaved creation, tab preservation, private template resources and
  Open/Save As dialogs. Authored-scene and workshop integration checks pass,
  including the separate exported-actor cold reopen; authored hashes remain intact.
  Evidence: `%TEMP%/cruises-checks-e4f55424f02b480eb0b0bafc1c525dfc/` and
  `%TEMP%/cruises-checks-ac9e3e05b0e144f38b82a54340b443a9/`.
- Binding integration verifies source snapshots/material independence, cancel/join,
  stale edits, malformed skins and unweighted rigged surfaces. Actual exported Mover
  playback retains borrowed walk alongside separate active local facial animation.
- Automated native command coverage does not constitute owner visual usability or
  final clothing/neck art acceptance; those remain in CHARACTER_WORKSHOP_PLAN.md.

## 2026-10-11 — cabin dressing validation

`cabin_dressing_check.gd` checks serialized dressing ownership, no added click/navigation blockers, no Light3D dependency, metre-density floor/rug materials, retained imported beam normal maps, independent roll bounds/origins/tabletop placement, and the existing crate hotspot after native visual adoption. It is included alongside the existing Character Workshop checks in the 22-check default runner.

With a rendering window, the same check renders normal-on/off frames and requires actual foreground-floor pixel changes. Compatibility/RTX 4060 Ti run passed with 4,323 changed samples. Captures use a unique OS cache folder and never save project resources. The existing graphical framing capture also passed all eight real hotspot clicks after the dressing changes.
