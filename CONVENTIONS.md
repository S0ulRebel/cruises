# Project conventions

Fixed content belongs in saved Godot scenes. Opening `game/game.tscn` shows the default cabin. Play wires behavior without replacing its contents. The owner's instructions take precedence over these conventions.

## Structure and naming

- `game/`: startup composition and session wiring; root Game.
- `locations/<location_id>/`: indoor and outdoor places. The initial place is captains_cabin, root CaptainsCabin.
- `locations/components/`: reusable authored environment pieces.
- `props/<prop_id>/`: prefab, materials, collider and local interaction.
- `actors/<actor_id>/`: actor prefab, character metadata and fitted outfits.
- `actors/outfit/`: shared fitting; `actors/mover/`: movement.
- `items/<item_id>/`: inventory definition resources; no placement.
- `ui/`: authored components, entry prefabs and character portraits.
- `systems/`: focused content, state, interaction and audio services.
- `dialogue/`, `cutscene/`, `stage/`, `screenplay/`: storytelling.
- `art/`: source models, textures, fonts, provenance and reference art.
- `tests/`: checks and fixtures; `tools/`: explicit offline authoring.

Use snake_case for files/folders and PascalCase for nodes/classes. Keep a feature's script, scene and local resources together. Stable screenplay IDs (live, santi) are distinct from art IDs (captain_live, santi_wong) and node names.

## Authored scenes and behavior

Every fixed object is a reusable scene instance, including simple floors and walls. Prefab roots have neutral placement; location instances carry transforms. Local colliders, clickable shapes and approach Marker3D nodes travel with the object. Hotspots export local visual/marker references. Avoid whole-location name searches.

Components operate on their own subtree. Their owner wires references/signals. Missing required dependencies produce editor warnings or a clear error. Variable choice/inventory entries, animation and deliberate gameplay scene changes may instantiate saved prefabs. They must not recreate default composition or override authored camera, material and component settings.

GameState owns flags, held items and selection. UI presents state; dialogue and puzzles share it explicitly. Movement reports success, cancellation or failure. Interactions remain busy through the complete walk and response and cannot act after failed movement.

## Navigation and assets

Walkable bodies use physics layer 2. Static bake sources persist in nav_source. Bake authored NavigationRegion3D geometry in the editor after moving solid objects; save the mesh with the location. Startup waits for synchronization and does not bake. Dynamic character avoidance uses saved NavigationAgent3D settings; obstacle carving affects baking.

One model metre equals one world metre; actor origins are at the feet. Existing actors face +Z to match measured donor clips and Mover. Props preserve their measured orientation as editable model-child transforms. No script guesses orientation or rescales source art at startup.

New skinned parts follow [RIGGING.md](docs/RIGGING.md): reuse the pinned donor armature and fit the mesh without changing donor rest bones. Imported scale is 1.0 when dimensions are baked. Unrigged garments require measured fitting before replacing the default world actor.

Version sources, .import settings and .gd.uid files. .godot/ is a cache. Offline converters require explicit destinations. Normal startup/tests never save over scenes, models or resources. There are no project-defined game/packing flags.

## Parallel ownership

Read AGENTS.md and module instructions. One integrator owns shared paths, interfaces, project settings and each location scene. Parallel agents use separate branches/worktrees and assigned file scopes. Coordinate shared API edits first. Detailed handoffs stay in modules; HANDOFF.md indexes current integration and art decisions.

Run relevant module checks and the integration runner. Engine/script errors fail even when Godot exits zero. Diagnostic output uses a unique run directory. Comments explain measured constraints and reasons.

References: [Godot scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) and [project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html).
