# Game integration handoff

The initial cabin is a saved instance in Game. All fixed service/HUD/audio nodes are
saved alongside it. Game wires state, character metadata, dialogue and interactions;
it never imports tools, parses custom launch flags, or bakes/saves scene resources.

`change_location(PackedScene)` deliberately replaces one authored location and keeps
GameState alive. It waits for the new navigation polygons before releasing input.
Each location exports camera, player and navigation_regions. Floor clicks require
the nearest ray hit to be a walkable body; hotspot clicks remain available to picking.

InteractionController serializes movement and its entire response. Mover emits
movement_finished(success, reason) for arrival, unreachable/exhausted paths, timeout,
stalls and cancellation. Authoring geometry refresh is an explicit editor bake.

Integration baseline: `docs/migration/baseline_layout.json` and `baseline.png`.
Cabin positions/camera were preserved, while duplicate components and detached
hotspots were removed. Module ownership is recorded in root/module AGENTS files.

See `actors/HANDOFF.md`, `props/HANDOFF.md`, `items/HANDOFF.md`, UI's local handoff,
and `tests/README.md` for module details and validation. Art fitting is a separate
acceptance task; default world actors keep their current appearance.
