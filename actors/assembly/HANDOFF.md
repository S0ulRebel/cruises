# Assembly foundation handoff

2026-10-11. Owner: assembly implementation, branch `codex/workshop-assembly`.

Implemented `CharacterAssembly`, `AssemblyPart`, `AssemblyOperations` and the
published API. Complete imported hierarchy/local rigs are retained; static assembly
works without a skeleton. Source assets and accepted actors/portrait remain intact.
Authoring only creates parts/carriers; ordinary startup loads authored scene content.

Validation: 67 authoring checks and 12 separate cold-reopen checks pass under Godot
4.7.2. The real `head_face.glb` retains 2 local bones and 3 blend shapes, including a
dependent arbitrary root-mesh part attached to local Jaw. Rotated/nonuniform parents,
top-level parts, animated detach, snapshots, external resource aliases, clip-loop
isolation, prefab signal targets and source hashes are verified.

Test outputs live in unique explicit `user://assembly_check_*` folders. Last authoring
logs: `%TEMP%/cruises-assembly-check.log`; cold log `%TEMP%/cruises-assembly-cold.log`.
Headless editor import generated script UIDs. Imported art/settings and embedded
texture extraction in this isolated worktree are not staged or part of this change.

Integration notes:

- Target paths are relative to the part. Snapshots do not replace IDs/source paths.
- Generated carriers must be retained by editor undo. Detached carriers are not freed.
- Duplicate returns an off-tree part, `world_transform` and `reference_states`; place
  under scene root and explicitly call `rebase_references(reference_states)` after
  insertion. Parent/bone copies start FREE; skinned copies preserve their deformation.
  Never share the original part's generated carrier.
- Duplicate excludes separately attached dependent parts. Editor removal/replacement
  prompts own dependent choices. Native editing remains available on saved scenes.
- Binding is integration-owned; geometry masks/exclusion and native editor commands
  have separate owners. Their metadata slots are present; no conversion is automatic.
- Resource cloning shares immutable definitions/source textures and independently
  clones mutable meshes/skins/materials/animations/resources, including external array
  entries. Large derived meshes save inline; asset footprint optimization is later.
- No promise of generic unsupported-rig garment binding or automatic neck capping.

Follow-up correctness fix: snapshots now retain whole-scene `reference_states`.
Attachments/undo rebase external `MeshInstance3D.skeleton`, part targets and binding
`donor_path` before/after moving bound garments or donors. Independent bound copies
at a different hierarchy depth retain the actual donor; copied local rigs point to
the copy's skeleton. Checks include both skins/provenance after cold saving/reopening.
Unresolved skin/donor paths fail explicit saves. Native editor rename/reparent metadata
tracking remains an editor integration concern, not an automatic runtime repair.
Mask `source_node_path` now participates in the same snapshot/rebase system;
duplicates map the reference to their own independent mask Resource and model mesh.
