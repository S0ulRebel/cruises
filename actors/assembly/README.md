# Character assembly

An assembly is an ordinary authored `CharacterAssembly` scene. Each freely named
`AssemblyPart` contains its complete imported scene under `Model`, including root
meshes, local skeletons, skins, blend shapes, animation players and materials.
Neither node creates content, resets transforms, binds clothing or saves at startup.
The editor plugin is an authoring aid; saved characters remain usable without it.

There are no fixed slots, filename restrictions, skeleton requirement for static
parts, automatic conflicts or one-per-category rules. Instance IDs are generated
only by explicit authoring operations. Hide uses native visibility. The editor owns
undo, dependency choices for removal/replacement, and native transform editing.

## Public operations

`AssemblyOperations` exposes the methods in
[the interface contract](../../docs/CHARACTER_WORKSHOP_INTERFACES.md). All mutating
methods return `ok` and `error`; failures validate before mutating the live scene.

- `generate_id()` returns a cryptographically random 32-character identity.
- `create_part(path)` returns an independent, off-tree `part`. Source must be a
  `PackedScene` with a 3D root; `.tscn`, `.scn`, `.glb` and `.gltf` sources are supported
  by Godot's normal scene importer. The root is retained and renamed `Model`.
- `collect_parts(root)` includes a part root itself; `nearest_part(node)` includes
  root `MeshInstance3D` models rather than searching descendants only.
- `ensure_owned(node, scene_root)` explicitly marks descendants owned for authored
  scene persistence. Call it after inserting an off-tree part into the edited scene.
- `validate_transform(value)` rejects nonfinite or singular matrices. Nonzero
  mirrored and sheared matrices are retained; transforms are not rounded/decomposed.
- `attach(part, target, mode, bone, scene_root)` keeps the complete world matrix.
  FREE targets the scene root, PARENT accepts any 3D node in the scene, and BONE
  accepts any named bone on any skeleton in the scene. Cycles, missing targets,
  unsupported modes and singular transforms fail before mutation. SKINNED requires
  the separate explicit binding service. The part's own rig is never converted.
- Successful attach returns `before`, `after`, `carrier`, `detached_carrier`.
  Bone carriers are explicit owned `BoneAttachment3D` nodes, not runtime builders.
- `duplicate_part(part)` returns an independent off-tree `part`, the source's
  `world_transform`, and `reference_states`. Parent/bone copies start FREE; already
  SKINNED copies retain their binding metadata and deformation. Insert under the scene root using its inverse world transform
  to keep visual placement, then attach explicitly if desired. Do not share a source
  part's generated bone carrier. Independently attached dependent parts are excluded
  from the duplicate; their removal/reconnection remains an explicit editor choice.
  **After insertion, explicitly call `rebase_references(result.reference_states)`**
  so external donor skin/provenance paths match the duplicate's new hierarchy depth.
- `save_scene(root, output_path)` requires an explicit existing folder and `.tscn`
  path (`res://`, `user://` or absolute). It validates IDs and attachment targets,
  saves a private expanded copy, and leaves live ownership/resources unchanged.
  It rejects saving over a part's own source scene. Mutable meshes, materials, skins,
  animations and metadata save inline alongside the complete owned hierarchy;
  explicit character identity/source, attachment, binding and masks remain editable.

Mutable resources are recursively cloned with alias preservation, including external
resources inside arrays/dictionaries; two copies cannot alter each other's fit,
material or animation. Script/PackedScene definitions and source textures remain
shared references. Imported assets themselves are never rewritten by these methods.

## Attachment snapshots and editor undo

`capture_attachment(part)` retains these keys: `parent`, `index`, `transform`,
`top_level`, `owner`, `attachment_mode`, `target_path`, `bone_name`, `carrier`,
`carrier_parent`, `carrier_index`, `carrier_transform`, `reference_states`. It does not overwrite part
identity, name, source, binding metadata, masks or visibility when restored.
`target_path` is always relative to the part, not the assembly root.

`restore_attachment(part, state)` restores parent order, authored matrix, top-level
flag, ownership and attachment metadata. It reuses the retained carrier and follows
its current skeleton pose. Empty generated carriers detach instead of `queue_free`.
The editor must retain them with undo references and clear them with the history.
Never use an unrelated authored target or scene root as an undo lifetime reference.
Callers must not free referenced parents/parts while their undo action is available.

`reference_states` captures the edited scene's target objects and exact relative paths
for `AssemblyPart.target_path`, `MeshInstance3D.skeleton`, and binding `donor_path`
metadata, plus each geometry mask's `source_node_path` relative to its part. Attach resolves them before movement and rebases them afterward; restore
undoes the path changes, including incoming references when a donor part moves.
Local skeleton references inside a part remain local. Save rejects unresolved skins
or donor provenance instead of silently exporting a broken character.

`capture_references(root)`, `rebase_references(states, skip_target_part = null)` and
`restore_references(states)` also support explicit editor hierarchy commands. These
helpers never run automatically at startup. Native editor rename/reparent behavior
and undo must be checked separately by the editor owner; metadata inside a Resource
does not receive native NodePath fixes automatically.

## Checks

From project root with Godot 4.7.2:

```powershell
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/assembly_check.gd
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/assembly_check.gd -- cold <printed-COLD_SCENE_PATH>
```

The first process deliberately saves to a unique `user://assembly_check_*` directory;
the second proves cold reopening. Checks cover static assembly, root meshes, arbitrary
names, independent mutable resources/signals/animations, transformed parents,
top-level nodes, rejected cycles/invalid scales, animated bone detach/undo/redo,
the actual speaking head's Head/Jaw rig and three blend shapes, accessories on its
local Jaw, authored provenance, explicit scene saves and source hash preservation.
Engine errors are failures even when an engine/launcher exits zero. Binding, geometry
exclusion and real native-editor undo are checked by their separately owned modules.
