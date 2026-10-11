# Checks

Run the full suite from PowerShell 7:

```powershell
pwsh -NoProfile -File tests/run_checks.ps1 -RunnerSelfTest
```

Use `-Godot <absolute executable path>` on another machine. The runner imports with
`--editor --import --quit`, then launches each check in a separate process. Import
has a 300-second deadline; individual checks have a 45-second deadline. Override
these with `-ImportTimeoutSeconds` and `-TimeoutSeconds` when needed. After the first
successful import, `-SkipImport` is available for focused iteration:

```powershell
& ./tests/run_checks.ps1 -SkipImport -Checks @('movement_check', 'navcheck')
```

Every check must exit zero, print a success marker and produce no `ERROR:` or
`SCRIPT ERROR:` lines. A timeout or a reported failure also fails the runner.
`-RunnerSelfTest` confirms that an intentional engine error with exit zero and a
false success marker is rejected. To prove the wrapper's process exit is nonzero:

```powershell
pwsh -NoProfile -File tests/run_checks.ps1 -SkipImport -ProbeFailure
# Expected exit code: 1. This is an intentional failure, not a passing check.
```

Each run writes logs to a new directory under the OS temporary directory and prints
its absolute path. The runner hashes tracked authored scripts, scenes, resources,
models, JSON, project/import settings, UIDs, textures, audio and fonts before import
and after all checks; unexpected source changes fail validation. Only line endings
in textual `.import` settings are normalized for comparison; all other files use
exact-byte hashes. Import caches and generated untracked preview textures are not
authored test outputs.

The default suite covers interaction wording and combinations, speech timing,
role-based outfit attachment/refit, animation filters, shared inventory/dialogue
flags including choice `clear`, serialized interaction success/failure/cancellation,
bounded movement completion, actual authored puzzle data, navigation through saved
geometry and explicit rebaking, baseline cabin composition, startup component
counts, local prefab references, independent instance materials and persistent
session state through an indoor-to-outdoor location transition. Transition checks
also reject wrong scene types, missing camera/player references and unusable authored
navigation without destroying the current location or state, while allowing places
that deliberately have no navigation regions. Hover checks compare per-instance
fishbowl emission, restore material values through a failed transition, then free
highlighted and formerly highlighted instances and allow renderer teardown to finish.

`fixtures/outdoor_location.tscn` reuses the real crate and humanoid actor prefabs
without walls or a ceiling. Its saved `outdoor_navigation.tres` was explicitly baked
from the floor and two rotated crate instances. Normal checks never save these
resources. After editing the fixture's static geometry, use Godot's explicit Bake
NavigationMesh action and save the fixture's navigation resource before testing.

Legacy root harnesses now live here. `hotcheck.gd` delegates to
`state_dialogue_check.gd`; the stale builder-based navigation and Main introspection
checks were replaced by checks against Game, Location and content resources.

The manual rendering harnesses `headcheck.tscn`, `handcheck.tscn` and `glbtest.tscn`
need a rendering window, so they are not in the headless default suite. For example:

```powershell
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --path . res://tests/headcheck.tscn
```

They save frames to a unique directory under `OS.get_cache_dir()/cruises-tests`,
print its absolute path, and report actual rig/clip/frame assertions. `hymocheck`
and `prof` remain optional import/profile diagnostics and can be selected with
`-Checks`. No harness writes PNGs into `res://` or shares a fixed output directory.
