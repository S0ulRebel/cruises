# Validation handoff

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
