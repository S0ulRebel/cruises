# Reversible mesh exclusion

Canonical code: `addons/character_workshop/runtime/mesh_mask.gd` and
`addons/character_workshop/core/mesh_operations.gd` (`CWMeshOperations`).
Old path compatibility shims have been removed.

This authoring module removes selected triangles from an independent derived mesh.
It never saves, changes scene nodes, modifies imported sources or runs reconstruction
on startup. The editor owns selection presentation, undo, collision updates and saves.

## Mask and reference space

`CWMeshMask` retains `source_mesh`, a versioned SHA-256
`topology_fingerprint`, `excluded_faces` and the authored `source_node_path`.
`excluded_faces` maps an integer original surface index to a `PackedInt32Array` of
triangle ordinals. Indexed triangles follow triples in the original index buffer;
nonindexed triangles follow consecutive triples of original vertices. Duplicate
face entries are harmless and count once.

Fingerprinting includes surface order, primitive, format/custom/influence layout,
surface names, every original vertex attribute and index, blend-shape names/mode
and each shape's vertex data. Equal triangle counts alone are insufficient.
Resource paths and process IDs are excluded so embedded sources survive Save As;
the retained mesh reference and full content establish asset correspondence.

Always call `validate(source_mesh, mask)` before applying a saved mask. A nonempty
error indicates a missing, invalid or stale mask. Review/reset it explicitly; never
apply old face ordinals to changed topology. Fingerprinting and selection work on
the original reference-pose mesh, independently of live skeleton or facial animation.

## Operations

- `fingerprint(mesh) -> String`: versioned digest, or empty for unsupported input.
- `validate(mesh, mask) -> String`: empty when usable, actionable error otherwise.
- `build(mesh, excluded_faces) -> Dictionary`: `ok`/`error`; on success, `mesh`
  is an independent `ArrayMesh` and `surface_map` maps retained original surfaces
  to output surfaces. Fully removed surfaces are absent from this mapping.
  `face_map` maps original surfaces to source face ordinals in output triangle
  order. Results also include `removed_faces`, `kept_faces`, `empty`,
  `collision_invalidated`, `lods_dropped` and `shadow_mesh_dropped`.
- `faces_in_box(mesh, bounds) -> Dictionary`: source triangles touching/intersecting
  the AABB, including triangles crossing it without a contained vertex. Negative
  extents are normalized. This selects whole triangles, without cutting new edges.
- `ray_face(mesh, origin, direction) -> Dictionary`: closest two-sided hit with
  `surface`, `face`, normalized reference-space `distance` and `position`, or empty
  for a miss/invalid query. Transform the editor ray into reference mesh space first.

Readable 3D triangle `ArrayMesh` and `PrimitiveMesh` resources are supported. Lines,
points, strips, 2D/unreadable or nonfinite geometry fail derivation before scene
mutation. Unsupported selection queries return no faces. No automatic Head-bone
weight trimming is provided; actual source triangles determine exclusion.

## Fidelity and integration responsibilities

Retain all original vertices, including unused ones. Only the drawing index buffer
changes, preserving all vertex/shape correspondence and four/eight skin influences.
Nonindexed surfaces become indexed. Material references, names, authored bounds,
lightmap hints, custom channel formats, influence and dynamic-update flags are kept.
The caller remaps **per-instance surface material overrides** with `surface_map`;
the module has no access to a scene instance. Materials remain original references,
so make a separate material copy before deliberately editing a shared material.

The public `ArrayMesh.add_surface_from_arrays` API re-encodes normals and tangents.
Positions, UVs, bone indices/weights, custom attributes and facial-shape positions
are retained; shading vectors can differ within the engine's packed precision.
The tested donor/head maximum error is 0.00019712 in vector distance and 0.011294
degrees. Checks allow shading-only limits of 0.0003 and 0.02 degrees and require
tangent handedness W exactly. Every command rebuilds from the immutable original,
preventing repeated edits from accumulating rounding. Decoded attributes are not
recompressed with optional `ARRAY_FLAG_COMPRESS_ATTRIBUTES`.

Stale LOD index buffers and shadow meshes are deliberately discarded. Normal shadow
rendering therefore uses the derived visible geometry. Skeleton nodes, Skin resources
and animation references belong to the model and are untouched. The editor must
invalidate/rebuild collision and other picking geometry using the returned mesh,
preserving their original state for undo. Source-space face selection remains able
to select excluded faces for restoration; ordinary derived-space picking cannot.

An entirely removed mesh has zero surfaces, retains shape names and is safe to save.
Skip `get_aabb`, `create_trimesh_shape` and other operations requiring render geometry
when `empty` is true. Mesh exclusion does not cap holes or produce watertight necks.

## Checks

Run `Godot_v4.7.2-stable_win64_console.exe --headless --path <project> --script
res://tests/mesh_exclusion_check.gd`. Add `-- --real-assets` after importing the
project to also test the actual Zombie donor and speaking Captain head.

The harness includes indexed/nonindexed and multi-surface geometry, complete
removal, original/output isolation, all vertex channels, four/eight skin influences,
byte/float custom attributes, three blend shapes, stale same-count/shape masks,
ray/AABB intersection and LOD/shadow invalidation. Explicit test-only saves use a
unique `user://mesh_exclusion_check_<random>/` directory. A separate engine process
checks cold mask/source/derived correspondence, including imported real sources when
requested. External runners must reject engine/script errors even with exit zero.
