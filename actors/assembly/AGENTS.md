# Character assembly ownership

- Read ../../docs/CHARACTER_WORKSHOP_PLAN.md and CHARACTER_WORKSHOP_INTERFACES.md.
- Nodes contain authoring metadata only. Never build parts, rebind, restore transforms
  or save on opening, startup, _ready, or property setters.
- Source assets remain intact. Operations are explicit, validated and transactional.
- Keep local rigs, animation references, meshes, skinning and facial blend shapes.
- Stable IDs identify instances; filenames/categories never replace another part.
- Attachment snapshots retain detached carriers for editor undo; never queue_free them.
- Assembly owns this directory except mesh_exclusion/ and binding_service.gd, which
  have separate owners. Coordinate shared API changes before editing.
- Checks: tests/assembly_check.gd. Save checks use unique explicit user:// outputs,
  and cold reopening is a separate process. Engine errors are failures.

Canonical generic implementation now lives in `addons/character_workshop/runtime/`
and `core/`. Old paths here are compatibility shims only; do not add implementation
or global classes to them. This module owns Cruises templates, exports and the
optional project adapter. Coordinate portable API changes with the addon owner.
