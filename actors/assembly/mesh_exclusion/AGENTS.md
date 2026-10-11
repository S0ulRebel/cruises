# Mesh exclusion ownership

- Own this directory, `tests/mesh_exclusion_check.gd` and mesh-exclusion fixtures.
- Read `docs/CHARACTER_WORKSHOP_INTERFACES.md` before changing the public API.
- Masks retain original source resources and reference-pose triangle identities.
- Derivation is explicit authoring only. Never save or rebuild from `_ready` or
  resource setters, and never rewrite imported meshes.
- Invalid or stale masks must fail visibly before a caller changes its scene.
- Preserve vertex correspondence, skin influences and facial blend shapes.
- Editor integration owns undo, material overrides, collision invalidation and saves.
- Keep engine errors fatal and test saves in an explicit unique output directory.
