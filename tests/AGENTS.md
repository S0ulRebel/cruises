# Validation ownership

- This module owns check harnesses, fixtures, reporting and the external runner.
- Exercise public Game, Location, content, state and interaction APIs. Avoid
  inspecting retired Main scripts, builder constants or fallback scenery.
- Tests may instantiate saved prefabs in memory. Normal checks must not save over
  project assets; author fixture edits explicitly through a named resource path.
- Capture logs/art outside the imported project tree, in a unique directory per run.
- Keep engine errors fatal even when Godot exits zero or a check prints success.
- The outdoor fixture deliberately proves that Location does not require a cabin
  shell. Navigation is authored only where the fixture's gameplay needs it.
