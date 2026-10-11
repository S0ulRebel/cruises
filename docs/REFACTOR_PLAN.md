# Scene Authoring and Agent Collaboration Plan

Created 2026-10-11. Status: implementation integrated on `codex/modular-scenes`; final lifecycle checks and clean-checkout verification are in progress.

The game must open with its default environment already visible in the editor.
Every fixed object must be an editable, reusable Godot scene instance, with placement
stored in the location scene. Scripts provide behavior and must preserve authored
transforms and settings. Module boundaries and file ownership come first so multiple
agents can implement the remaining work without overwriting one another.

This is the combined project audit and implementation plan. Follow the phases in
order and run the relevant checks as each change lands; Priority 4 consolidates
validation rather than postponing it. Keep checkboxes open until their completion
checks pass, and record the relevant commit and validation result when completing a phase.

## Confirmed scene naming

- `game/game.tscn`, with root `Game`, is the startup and session scene.
- `locations/<location_id>/<location_id>.tscn` contains one playable place, indoors,
  outdoors or otherwise. Names describe the place; examples include `captains_cabin`,
  `main_deck` and `island_beach`.
- The cabin target is `locations/captains_cabin/captains_cabin.tscn`, with root
  `CaptainsCabin`. The former `rooms/` path has been retired.
- Use `snake_case` for files/folders and `PascalCase` for nodes/classes.
- Location contents depend on the place. Walls, ceilings and navigation are included
  where appropriate. Generic location code must not construct an indoor room shell.

## Rules for the migration

- Preserve the current default composition, dimensions, materials and transforms.
  Correct broken interaction locations without moving the visible objects to match them.
- Do not run `--pack` or `tools/make_prefabs.gd` during this migration. Both overwrite
  authored scenes. Remove their implementations once their dependencies are replaced.
- Fixed scenery, actor components, interaction zones, default UI/audio and portrait
  accessories belong in saved scenes. Movement, animation, dialogue, puzzles and
  deliberate gameplay spawning remain behavior scripts.
- One integration owner handles shared path/schema changes and location composition.
  Parallel contributors own separate modules; shared API and scene edits are coordinated.
- Normal game startup and verification must never rewrite scene, prefab, model or
  authored resource files. Authoring saves are explicit and target one owned asset.

## Priority 0 Preserve the starting point

- [x] **1. Preserve required assets before creating worktrees.** Identify and version
  the runtime assets, import settings and script UIDs currently untracked, including
  the working `head_face.glb` and modular body. Review the files individually; do not
  add generated caches, recordings or unrelated scratch outputs.
- [x] **2. Record the default layout and known failures.** Capture the saved and runtime
  transforms, camera framing, materials and component counts. Preserve a reference
  image in a dedicated migration output directory. Record existing failures so later
  checks distinguish regression from defects being fixed.

Completion check: the starting scene can be recovered from versioned source assets,
and the reference layout exists before any construction code is deleted.

## Priority 1 Establish modular ownership before parallel implementation

- [x] **3. Define the module boundaries and folder destinations.** Each location, actor,
  prop and UI feature owns its scenes, behavior and local resources. Shared components
  stay with their domain. Keep the existing outfit engine as one coherent module.
- [x] **4. Define small public interfaces.** Agree on exported node references, stable
  content IDs, local coordinates, navigation/collision groups, movement result
  signals, and dialogue/puzzle APIs. Components operate on their own children;
  their owner wires communication. Add editor configuration warnings for missing
  dependencies instead of silently doing nothing.
- [x] **5. Rename the startup wrapper to Game and reduce it to wiring.** Separate
  location interactions, dialogue
  orchestration, inventory/flag state, UI and audio. Give shared session state one
  owner and pass it explicitly to consumers. Move diagnostics into test harnesses.
  Avoid introducing a broad global manager or event bus.
- [x] **6. Move content definitions out of shared registries.** Replace hardcoded
  `Inventory.ITEMS`, the shared cast/placement table and shared portrait fitting
  table with per-item/per-character resources. Preserve screenplay IDs and asset
  IDs as separate identifiers. Put world placement exclusively in location scenes.
  Expose input through InputMap and audio settings through scene properties.
- [x] **7. Establish agent instructions and handoffs.** Document each module's allowed
  files, interfaces and checks in root/module agent instructions. Keep `HANDOFF.md`
  as an index and integration summary; move detailed work logs into module handoffs.
  Update its current rules when this change is implemented.
- [x] **8. Isolate editing agents.** After task 1 and the ownership/path decisions,
  use separate branches and worktrees for independent changes. The integration owner
  coordinates merges and shared-file changes. Worktrees isolate edits; they do not
  eliminate merge conflicts when agents change the same files.

Proposed ownership boundaries:

- **Integration:** Game, project settings, shared interfaces, folder/path migration,
  and composition of each location. Assign one owner per location scene.
- **Props:** each `props/<id>/` prefab, its colliders, hotspot, approach markers and
  local resources. Location-specific instance settings stay with the location owner.
- **Actors:** each actor's scene, portrait, metadata and fitted outfit resources.
  The outfit engine has a separate shared-module owner.
- **UI:** individual caption, choices, inventory, pointer and portrait components.
- **Systems:** focused dialogue, speech, game state, interaction and audio modules.
- **Validation:** module checks and integration tests, coordinated with API owners.
- **Art:** each asset's source model, textures and provenance; import changes target
  one asset and are handed to its prefab owner for integration.

Completion check: each implementation task has an owner and file scope. Integrate one
location/prop/actor example using the agreed interfaces before broad parallel migration.

## Priority 2 Make saved scenes the source of layout

- [x] **9. Populate the entry scene.** Save the cabin instance and fixed service/UI
  instances in Game. Opening the default game scene must show its environment.
  Preserve scene transitions and the authored cold-open setting.
- [x] **10. Remove duplicate startup construction.** Bind the saved cabin camera,
  floor, backdrop, shell and navigation region instead of rebuilding them in
  `room3d.gd`. Bind each actor's saved Agent and Obstacle instead of creating new
  copies in `mover.gd`. Save any missing defaults at their current exact transforms.
  Other locations supply only the components they need.
- [x] **11. Make interactions part of their object.** Move hotspots, clickable
  shapes and local approach markers into reusable prop/actor scenes. Replace whole-location
  name searches with explicit local visual references. Fix the fishbowl's obsolete
  desk hotspot, the inkwell name mismatch and the missing rapier highlight reference.
  Resolve authored approach points into world space when used.
- [x] **12. Make prefab transforms and appearance reusable.** Remove cabin positions
  from actor prefab roots while preserving location instance placement. Give reusable
  roots consistent origins. Save editable glass/unlit materials or editor-visible
  material components. Animate the fish relative to its authored rest transform,
  preferably through a visual child, so authored rotation survives.
- [x] **13. Finish scene authoring for remaining fixed content.** Extract reusable
  floor/wall/ceiling pieces for the cabin, name anonymous nodes, and save cutscene locations,
  default HUD/audio nodes and per-character portrait accessories as scene instances.
  Preserve designer control over layout, sound levels and accessory fitting.
- [x] **14. Remove both regeneration paths and all custom game flags.** Extract the
  cast loader from `build_cabin.gd`; replace tests that read its placement/hotspot
  tables with authored-scene checks. Delete the `--pack` handler and retire
  `build_cabin.gd` and `make_prefabs.gd` after their remaining defaults are saved and
  replacement authored-scene tests pass. Begin the test repairs in task 21 here:
  a script error must fail validation before the old data tables are deleted.
  Remove game parsing of `--look`, `--auto`, `--skip`, `--shot`, `--record`,
  `--hover`, `--bag` and `--talking`. Put development actions in dedicated test/render
  harnesses and remove runtime imports from `tools/`. Keep Godot's own launch/export
  options; this task concerns project-defined switches and scene regeneration.
- [x] **15. Prevent authoring output collisions.** Retained asset converters require
  explicit destinations and target one asset. Replace tools that silently overwrite
  their input or a fixed shared asset. Use separate diagnostic directories per run
  or agent. Use unique IDs and per-character outfit fitting paths rather than model
  basenames such as `hat.glb`; saving one outfit must not refit other outfits.

Completion check: opening the game shows the complete default scene before Play.
Starting it creates no duplicate fixed content and cannot repack authored scenes.
Moving, rotating or duplicating a prefab carries its collision and interaction with it.

## Priority 3 Repair gameplay and character authoring

- [x] **16. Repair navigation from authored geometry.** Persist the floor/solid-prop
  `nav_source` groups, remove the cabin's duplicate navigation region, and bake the
  actual authored geometry. Other locations may have zero, one or multiple authored
  regions as needed for movement. Fix synchronization before querying the map. Correct character avoidance:
  carving flags affect baking, rather than dynamically cutting paths around moving
  actors. Make baking an explicit editor workflow or documented geometry refresh,
  with no placement changes. Verify moved furniture blocks paths correctly.
- [x] **17. Make interactions complete reliably.** Distinguish successful arrival
  from an exhausted/unreachable path. Handle cancellation and stuck movement without
  activating objects remotely or waiting forever. Keep interaction state busy until
  the complete speech/dialogue/puzzle response finishes, preventing overlapping lines.
- [x] **18. Finish dialogue and input behavior.** Implement choice `clear`, bounded
  text/response scrolling, keyboard focus and selection. Advance only on intended
  input; the mouse wheel must scroll without skipping dialogue. Keep the portrait
  visible during responses where the approved layout requires it. Follow
  [the UI integration specification](../art/ui/ENGINE_INTEGRATION.md) for frame
  dimensions, fonts, Continue/confirm controls and scrolling hit areas.
- [x] **19. Complete the modular actor workflow.** Discover delivered pieces under
  current `art/characters/.../pieces/` paths. Use the resolved bone consistently for
  role-based clothing attachment, fitting and refitting. Save assembled default actor
  scenes and portrait scenes with editable parts. Keep deliberate gameplay outfit
  changes separate from default startup assembly.
- [x] **20. Normalize asset orientation and scale.** Reconcile the documented forward
  axis, dimensions and donor-rig rules. Correct source orientation/scale once where
  needed, preserving the current location composition; remove compensating construction
  guesses. Use measured engine fitting for modular pieces and record unresolved art
  acceptance issues separately from this structural migration.

Completion check: walking, talking, taking/combining items and fitting outfits work
with moved and reused instances. Dialogue remains readable and interactions recover
cleanly when movement cannot complete.

## Priority 4 Validate integration and finish documentation

- [x] **21. Repair misleading tests.** Fix `navcheck` reading removed Main constants
  and reporting success after a script error. Update flag/combo checks to use authored
  scenes and real shared state. Make script errors and failed assertions fail the run
  with a nonzero exit code; verify this with a deliberately failing test.
  Repair navigation verification alongside task 16 rather than relying on its old pass.
- [x] **22. Add focused migration checks.** Verify component counts, transform
  preservation, local approach/highlight references, movement failure recovery,
  role-based outfit fitting and choice flag clearing. Check that ordinary startup/tests
  leave tracked scenes, models and authored resources unchanged. Test modules and
  repeated prefab instances independently, then test their integration.
- [x] **23. Finish folder and documentation cleanup.** Move root test/profiling
  harnesses into `tests/`, migrate `rooms/` to `locations/` and the startup wrapper
  to `game/`, retire obsolete 2D/demo paths and update every resource
  reference. Align README, conventions, pipeline, outfit and audio documentation with
  the implemented architecture. Remove obsolete `--pack`, `--room`, `--talk` and
  `--room3d` instructions, nonexistent tool links, and contradictory rig/scale/import
  statements. Update export rules so developer tools/tests are excluded while runtime
  resources remain included.
- [ ] **24. Verify a clean checkout and the editing workflow.** Confirm required
  assets load from versioned files and imports regenerate correctly. Open Game and
  reusable scenes in the editor, run them, and verify no `ERROR` or `SCRIPT ERROR`
  output. Compare the default composition with the reference. Test a different outdoor
  location, such as a deck or beach, with moved, rotated and duplicate props/actors;
  test navigation, interaction and material
  independence. Record results and complete the relevant handoff items.

Completion check: all earlier phase checks pass, a clean checkout works, and the owner
can construct indoor and outdoor locations by placing prefabs without changing placement code.

## Implementation record

Tasks 1–23 are integrated and verified by module and integration checks. Task 24
remains open until the fresh worktree's import, complete strict suite and final
lifecycle checks pass. Commits and visual evidence are indexed in
[the migration record](migration/README.md); module handoffs contain API details.

- Priority 0: source assets, settings and UIDs versioned; baseline image/tree saved.
- Priority 1: explicit GameState/content/interaction contracts, module ownership and
  three separate editing worktrees. Game wires saved service prefabs and location.
- Priority 2: all fixed environment, actor, prop, interaction, UI/audio and portrait
  content saved as editable scenes. Both builders, old Main/Room paths and custom
  switches removed. Definitions and authoring outputs are owned per content item.
- Priority 3: cabin bake contains 63 polygons; outdoor fixture contains 31. Map
  synchronization, failure/cancellation, dialogue input/scrolling, choice clear and
  role-based outfit export/fitting verified. Invalid location changes roll back.
- Priority 4: checks moved under tests, false-pass runner repaired, baseline and
  reuse/teardown coverage added; documentation and export exclusions updated.

Remaining art/composition work is separate and documented rather than silently
changing the baseline: choose a camera/placement that exposes every prop, and bind
and fit delivered unrigged modular clothing before replacing the default actor.

## Audit evidence to preserve

- Runtime inspection found two room cameras, two navigation regions, and two Agents
  and two Obstacles on each humanoid actor. Only the generated floor belonged to
  `nav_source`; a path across the crate remained straight.
- The visible fishbowl is at `(-2.9, 0.65, 1.5)` while its hotspot remains at
  `(-3.3, 0.95, -1.2)`.
- Startup queries navigation before synchronization. `navcheck` accesses removed
  `main.gd.FURNITURE`, then prints `ALL CHECKS PASSED` and exits successfully.
- `--pack` saves over the cabin and cast actor scenes. Launching `make_prefabs.gd`
  directly rebuilds the prop prefabs and fish/bowl scenes without that flag.
- UI/audio trees and portrait accessories are assembled in scripts. Workshop discovery
  uses obsolete directories, and pinned fitting ignores the resolved role bone.

Primary references: [Godot scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html),
[project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html),
[scene state and shared resources](https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html),
[navigation obstacles](https://docs.godotengine.org/en/stable/classes/class_navigationobstacle3d.html),
[persistent groups](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-add-to-group),
and [Git worktrees](https://git-scm.com/docs/git-worktree).
