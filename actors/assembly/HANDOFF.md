# Assembly foundation handoff

2026-10-11. Owner: assembly implementation, branch `codex/workshop-assembly`.

Implemented `CharacterAssembly`, `AssemblyPart`, `AssemblyOperations` and the
published API. Complete imported hierarchy/local rigs are retained; static assembly
works without a skeleton. Source assets and accepted actors/portrait remain intact.
Authoring only creates parts/carriers; ordinary startup loads authored scene content.

Validation: 106 authoring checks, 12 separate main cold-reopen checks, 8 separate
nested-composition cold-reopen checks and 5 separate animation-graph cold-reopen
checks pass under Godot
4.7.2. The real `head_face.glb` retains 2 local bones and 3 blend shapes, including a
dependent arbitrary root-mesh part attached to local Jaw. Rotated/nonuniform parents,
top-level parts, animated detach, snapshots, external resource aliases, clip-loop
isolation, prefab signal targets and source hashes are verified.

Test outputs live in unique explicit `user://assembly_check_*` folders. Last authoring
logs: `%TEMP%/cruises-assembly-check.log`; cold log `%TEMP%/cruises-assembly-cold.log`.
Nested cold log: `%TEMP%/cruises-assembly-nested-cold.log`.
Graph cold log: `%TEMP%/cruises-assembly-graphs-cold.log`.
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
- `create_part` gives every nested imported AssemblyPart a new identity and records
  the complete imported Model hierarchy with `assembly_source_group` metadata.
  Duplicate retains nested source-composed parts/carriers, regenerates their IDs,
  and remaps the retained group to its new independent wrapper. Later separately
  attached parts/carriers are outside that group and are omitted. This boundary
  persists in saved scenes and also works when duplicating an inner imported part.
- Native adoption uses `capture_source_composition(part)` after placing the selected
  node under its wrapper as Model, then `initialize_source_composition(part)` once,
  then captures the after state. `restore_source_composition(states)` restores exact
  nested IDs and previous metadata presence/value: before on undo before unwrapping,
  after on redo. Reinitializing on each redo would change identities unnecessarily.
  These APIs are explicit authoring operations; opening scenes never assigns IDs.
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

Animation graph cloning regression: mutable Resources are now constructed fresh,
registered in the shared clone cache, then populated with each storage property
exactly once. Rewriting properties on an already populated `duplicate(true)` had
replayed AnimationNodeBlendTree's additive node/connection setters and emitted
engine errors. Scripted resources use their script constructor; built-ins use their
registered class. Script/PackedScene/Texture definitions remain shared. Resources
must be constructible without required constructor arguments, as with Godot's
[Resource duplication API](https://docs.godotengine.org/en/stable/classes/class_resource.html#class-resource-method-duplicate).

Regression coverage includes active AnimationTrees, nested BlendTrees, a StateMachine
with shared transitions/Curve and named BlendSpace1D points, graph positions/scalar
properties, per-tree parameters, leaf/graph/resource metadata aliases, independent
duplicate edits, source preservation, saved scene reimport and separate cold reopen.
Use `-- graphs <COLD_GRAPH_SCENE_PATH>` for the graph cold marker printed by the
authoring check. No animation graphs are built or repaired by gameplay startup.
