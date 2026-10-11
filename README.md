# Cruises

A Godot point-and-click comedy adventure: pirates arrive on a cruise ship through a crack in space and time. The current playable location is the captain's cabin.

Open project.godot in Godot 4.7.2. Open game/game.tscn to edit the default composition, or locations/captains_cabin/captains_cabin.tscn to edit the place. Press Play or run `godot --path .`. Click the floor to walk, an object to interact, or Santi to talk. I opens inventory. Continue/Space/Enter advances dialogue; the wheel scrolls. Game exposes skip_cold_open in the Inspector.

Fixed scenery, actors, interactions and UI/audio are saved scenes. Drag an instance to move it; its collider and interaction move with it. Reuse prefabs in another location. After changing solid geometry, select Navigation, bake its mesh in the editor and save the location. There are no packing or custom game flags.

Read [CONVENTIONS.md](CONVENTIONS.md), [AGENTS.md](AGENTS.md) and module instructions before editing. [HANDOFF.md](HANDOFF.md) indexes current work and art decisions. The prioritized [refactor plan](docs/REFACTOR_PLAN.md) records migration checks and progress. Separate branches/worktrees and ownership support parallel work; one integrator owns shared interfaces and each location.

Game wires the saved location, GameState, interactions, dialogue, HUD and audio. Character/item resources own IDs, prose and presentation. Locations own placement. Outfit authoring requires explicit outputs; see [the workshop guide](actors/outfit/README.md) and [donor rig rules](docs/RIGGING.md).

Conversations and screenplays live in screenplay/*.json. Conversation nodes contain lines, choices, goto/branch and exit. Node/choice set and clear modify shared flags; if/unless gate visibility; once hides a used choice; say provides its spoken line. Cutscene beats include location, enter, say, action, wait, sfx, shake, flicker and end.

Run checks with tests/run_checks.ps1 and the Godot executable argument documented there. Engine/script errors, failed assertions, timeouts and missing completion markers fail the run. Tests and offline tools are excluded from game exports.

Source/import settings are versioned; .godot/ regenerates on opening a clone. The migration baseline is in docs/migration/. Art acceptance and fitting backlogs remain documented separately from scene structure.
