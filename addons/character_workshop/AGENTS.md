# Character Workshop editor ownership

- This module owns native editor integration, its authored dock and undoable commands.
- Read `docs/CHARACTER_WORKSHOP_PLAN.md` and `docs/CHARACTER_WORKSHOP_INTERFACES.md`.
- Own portable `runtime/` metadata and `core/` services; coordinate their shared API changes.
- Never depend on project actors, UI, art or systems; optional project adapters stay outside.
- Project settings are read-only on load and saved only through explicit Settings action.
- Imported scenes retain their whole Model, local rigs, materials and blend shapes.
- Geometry and binding actions are explicit. Source models/resources are never saved.
- Save dialogs name a destination; normal startup performs no authoring saves.
- Native selection, scene-tree operations, Inspector transforms and undo remain available.
- Face selection consumes input only while the user deliberately enables that mode.
- Tests own unique external or `user://` outputs and treat engine errors as failures.
