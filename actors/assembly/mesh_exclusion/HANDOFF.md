# Mesh exclusion handoff

2026-10-11. Backend implementation complete against the agreed
[workshop interface](../../../docs/CHARACTER_WORKSHOP_INTERFACES.md).

Mask and pure operations implement CW12 and the geometry portion of CW13. CW11 UI,
undo, material-override mapping, collision updates, explicit scene persistence and
CW14 art/neck acceptance belong to editor/integration owners. Do not mark those
complete based only on backend checks.

The module README documents exact selection semantics, result fields and limits.
All persistent edits must validate the retained original and fingerprint first,
derive from that original, apply deliberately, and save to a chosen authoring path.

Validation: Godot 4.7.2 headless in an isolated external project, including native
GLB import, actual Zombie donor (52 bones) and speaking head (2 bones/3 shapes),
indexed/nonindexed fixture meshes, 4/8 influences, custom byte/float attributes,
full/partial removal, stale masks, selection, source file hashes and a separate
cold save/load process. Engine errors are treated as failures. No project source
scenes, models, resources or import settings were written by these checks.

Maximum public-API normal/tangent encoding error across both real assets:
0.00019712 distance / 0.011294 degrees, tangent W exact. All non-shading vertex and
shape-position channels remain exact. Repeated builds from the original are equal;
derived-source iteration must not be introduced. No hidden mesh storage APIs used.

Integration details: fully removed surfaces are absent from `surface_map`; no
surface with empty indices is added. Fully removed mesh is a 0-surface ArrayMesh.
Source-space restore selection deliberately sees original faces. Assign/reset
mesh-instance overrides through the mapping, and do not leave source collision,
LOD or shadow geometry alive after exclusion.
