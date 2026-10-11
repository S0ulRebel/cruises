# Character Workshop editor ownership

- This module owns native editor integration, its authored dock and undoable commands.
- Read `docs/CHARACTER_WORKSHOP_PLAN.md` and `docs/CHARACTER_WORKSHOP_INTERFACES.md`.
- Use `actors/assembly` public operations; coordinate shared changes with its owner.
- Imported scenes retain their whole Model, local rigs, materials and blend shapes.
- Geometry and binding actions are explicit. Source models/resources are never saved.
- Save dialogs name a destination; normal startup performs no authoring saves.
- Native selection, scene-tree operations, Inspector transforms and undo remain available.
- Face selection consumes input only while the user deliberately enables that mode.
- Tests own unique external or `user://` outputs and treat engine errors as failures.
