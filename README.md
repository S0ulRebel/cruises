# Cruises

A Godot point-and-click comedy adventure: pirates arrive on a cruise ship through a crack in space and time. The current playable location is the captain's cabin.

Open project.godot in Godot 4.7.2. Open game/game.tscn to edit the default composition, or locations/captains_cabin/captains_cabin.tscn to edit the place. Press Play or run `godot --path .`. Click the floor to walk, an object to interact, or Santi to talk. I opens inventory. Continue/Space/Enter advances dialogue; the wheel scrolls. Game exposes skip_cold_open in the Inspector.

Fixed scenery, actors, interactions and UI/audio are saved scenes. Drag an instance to move it; its collider and interaction move with it. Reuse prefabs in another location. After changing solid geometry, select Navigation, bake its mesh in the editor and save the location. There are no packing or custom game flags.

Read [CONVENTIONS.md](CONVENTIONS.md), [AGENTS.md](AGENTS.md) and module instructions before editing. [HANDOFF.md](HANDOFF.md) indexes current work and art decisions. The prioritized [refactor plan](docs/REFACTOR_PLAN.md) records migration checks and progress. Separate branches/worktrees and ownership support parallel work; one integrator owns shared interfaces and each location.

Game wires the saved location, GameState, interactions, dialogue, HUD and audio. Character/item resources own IDs, prose and presentation. Locations own placement. Assemble characters with the **Character Workshop** editor dock: arbitrary editable parts, local rigs, bone attachments, reversible mesh exclusion and explicit prefab saves. See [the workshop guide](actors/assembly/README.md), [legacy fit compatibility](actors/outfit/README.md) and [donor rig rules](docs/RIGGING.md).

Conversations and screenplays live in screenplay/*.json. Conversation nodes contain lines, choices, goto/branch and exit. Node/choice set and clear modify shared flags; if/unless gate visibility; once hides a used choice; say provides its spoken line. Cutscene beats include location, enter, say, action, wait, sfx, shake, flicker and end.

Run checks with tests/run_checks.ps1 and the Godot executable argument documented there. Engine/script errors, failed assertions, timeouts and missing completion markers fail the run. Tests and offline tools are excluded from game exports.

Source/import settings are versioned; .godot/ regenerates on opening a clone. The migration baseline is in docs/migration/. Art acceptance and fitting backlogs remain documented separately from scene structure.

Try the 16 fake-lighting techniques in [materials/stylized_lighting/gallery/material_lab.tscn](materials/stylized_lighting/gallery/material_lab.tscn) with F6. Each has `_shader` and editable `_graph` materials, plus reusable scene parameter controls. [The material guide](materials/stylized_lighting/README.md) explains usage and limits. The lab is separate from the current game look.

## Reuse Character Workshop in another project

Copy only `addons/character_workshop/` and enable the plugin after Godot import.
Workshop **Settings** chooses project asset/template/save folders; no mandatory
asset layout or setup. The game owns identity, gameplay and portrait behavior around the saved visual
assemblies. Workshop has no adapter or game-specific actions. See [installation and workflow](addons/character_workshop/README.md)
and [using constructed characters](addons/character_workshop/CHARACTERS_IN_GAME.md).
Build a distributable ZIP with an explicit new output path:
`./tools/package_character_workshop.ps1 -OutputPath <absolute-new-zip>`.
