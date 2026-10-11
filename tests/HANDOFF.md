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
