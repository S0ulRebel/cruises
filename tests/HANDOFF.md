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
