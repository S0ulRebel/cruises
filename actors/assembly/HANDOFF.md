# Assembly foundation handoff

2026-10-11. Owner: assembly implementation, branch `codex/workshop-assembly`.

Implemented `CharacterAssembly`, `AssemblyPart`, `AssemblyOperations` and the
published API. Complete imported hierarchy/local rigs are retained; static assembly
works without a skeleton. Source assets and accepted actors/portrait remain intact.
Authoring only creates parts/carriers; ordinary startup loads authored scene content.

Validation: 51 authoring checks and 9 separate cold-reopen checks pass under Godot
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
- Duplicate returns an off-tree FREE part and `world_transform`; place under scene
  root and attach explicitly, never share the original part's generated carrier.
- Duplicate excludes separately attached dependent parts. Editor removal/replacement
  prompts own dependent choices. Native editing remains available on saved scenes.
- Binding is integration-owned; geometry masks/exclusion and native editor commands
  have separate owners. Their metadata slots are present; no conversion is automatic.
- Resource cloning shares immutable definitions/source textures and independently
  clones mutable meshes/skins/materials/animations/resources, including external array
  entries. Large derived meshes save inline; asset footprint optimization is later.
- No promise of generic unsupported-rig garment binding or automatic neck capping.
