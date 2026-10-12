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

The 22-check default suite covers interaction wording and combinations, speech timing,
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

The seven Character Workshop checks cover assembly identities and attachments,
source-composed prefab copies, real skinned mesh exclusions, backend weight search,
transactional/cancellable binding, legacy conversion, native editor commands/undo,
and the reversible Captain head-swap demonstration. Assembly, nested composition,
exported actor and head-swap saves are reopened in separate processes. The mesh and
editor harnesses also perform their own cold checks. Outputs use unique explicit
temporary/user paths; no test saves over a source scene or model.

`workshop_references_check` exercises isolated reference preferences, independent
unsaved/saved character contexts, Save As path association, thumbnail selection,
missing files, removal without source deletion, drawer exclusivity, pointer-anchored
zoom, pan/Fit and rejection of stale file dialogs. Images are written only to unique
explicit `user://` fixture paths. The native editor fixture also checks the genuine
reference/3D mode controls and preserves the detail camera. Optional graphical capture
adds `references.png` alongside the normal workspace/asset/fine-adjust screenshots.

`portrait_storage_check` verifies compact authored scenes, independent external
mesh/material instances, geometry/shape preservation, explicit binary destinations,
ordinary-save ownership and refusal to overwrite unrelated resources. Native editor
coverage saves a full portrait into its uniquely owned ignored `test_results/` folder,
reopens its camera/speech targets, edits a private material and saves again. Production
portrait/template/resource hashes must remain unchanged. Native overwrite guards also
reject a bare assembly at the game renderer's destination.

`workshop_editor_check` runs an actual headless Godot editor using its authored
`fixtures/workshop_editor_check.tscn` and a process-local test environment variable.
Do not launch it as `--editor --script`: that creates a second editor main loop.
The fixture also checks the main-screen workspace, actual-world view cameras,
nested hierarchy/collapse, native viewport transforms/undo, whole-assembly edits,
target picking, fine adjustments, asset filtering and import validation.
The usability follow-up checks native Save As/Save continuity, stale save-dialog
context, canonical source aliases, inline fields, hierarchy actions/cycles/undo,
private animation-path rebasing, word/type/folder filters, cursor placement and
focus restoration. Unique `user://` save outputs retain source hash protection.
These tests run without a graphical window or GPU rendering. Visual acceptance of
the follow-up layout, overlays and placement marker remains a separate GPU review.
For graphical review, set `CRUISES_WORKSHOP_EDITOR_CHECK=1` and
`CRUISES_WORKSHOP_CAPTURE` to an explicit external PNG path, then launch
`--editor --rendering-method gl_compatibility --single-window
res://tests/fixtures/workshop_editor_check.tscn` without `--headless`.
It captures the workspace, Assets and Fine adjust states beside the selected path;
check its complete log for engine errors even if assertions report success.
Binding checks compare worker/synchronous geometry, cancellation/teardown, stale
input rejection, original-material independence and saved refit provenance. Export
checks exercise the actual Mover with borrowed idle/walk and separate facial trees.

`portrait_check` exercises the fitted Captain portrait through actual Caption and
Choices panels. It checks frontal orientation, authored transform preservation,
independent/reused rigs, jaw-driven chin-tuft motion, settling, framing and teardown.
To capture the actual Game dialogue/response panels and verify visible speech motion:

```powershell
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --path . --rendering-method gl_compatibility --resolution 1920x1080 --script res://tests/portrait_capture.gd
```

This manual GPU harness writes native portrait frames and complete panel screenshots
to a unique external cache directory, prints its path and fails if speech produces
no visible pixel changes. It does not save project resources or change the cold-open
setting in the authored scene.

`stylized_lighting_check` covers the 16 code/graph material pairs, graph connectivity,
matching controls, texture/tint preservation, local material independence, explicit
scene-light targeting, live template edits, cleanup and authored lab placement.
For actual GPU compilation, image equivalence and original-albedo comparisons run:

```powershell
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --path . --rendering-method gl_compatibility --script res://tests/stylized_lighting_render_check.gd
```

The GPU harness writes a unique report/image directory outside the project and
checks 64 rendered comparisons. It requires a graphical renderer; headless dummy
rendering cannot validate shader compilation or pixels. Compatibility is validated;
Forward+ and Mobile remain untested.

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

## Cabin dressing and normal-map rendering

The default suite now includes 22 checks. `cabin_dressing_check` verifies authored texture/prop adoption without altering source assets. To additionally prove that the normal maps affect actual shader lighting, run without `--headless`:

```powershell
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --path . --resolution 1920x1080 --script res://tests/cabin_dressing_check.gd
```

The normal on/off frames and result are written to the printed unique cache directory. This check requires visible foreground-floor pixel changes and the source hash protections of the normal runner still apply. Ordinary startup and tests never author or resave scene placement.

## Portable Workshop check

`workshop_portability_check` is included in the 25-check suite and can also be run
with `./tests/workshop_portability_check.ps1 -Godot <executable>`. It installs a ZIP
containing only the addon into an external temporary project, checks native setup
and assembly authoring, then checks cold runtime with the plugin disabled and from
an exported PCK. Each phase has a 90-second deadline and separate logs in that
fixture. The standard runner's TimeoutSeconds covers the ordinary engine checks;
portability phases use their own deadline. Fixtures remain outside project assets.
