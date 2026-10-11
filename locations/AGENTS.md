# Location ownership

One integrator edits each location scene. Preserve authored transforms and appearance.
Wire exported camera, player and navigation_regions; include only components the
place needs. Walkable bodies use physics layer 2. Static navigation sources persist
in group nav_source. Bake navigation explicitly after geometry changes.
Place reusable instances; hotspot, collider, visual and approach marker travel together.
