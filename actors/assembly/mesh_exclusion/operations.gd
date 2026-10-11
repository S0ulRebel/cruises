@tool
class_name MeshExclusionOperations
extends RefCounted
## Pure authoring operations: no scene mutation, resource saves or source mutation.

const Mask = preload("res://actors/assembly/mesh_exclusion/mask.gd")
const FINGERPRINT_VERSION := "mesh_exclusion_v1"
const EPSILON := 0.000001


static func fingerprint(mesh: Mesh) -> String:
	if not _mesh_error(mesh).is_empty():
		return ""
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes([FINGERPRINT_VERSION, mesh.get_surface_count()]))
	# Full attribute/shape correspondence avoids trusting only equal face counts.
	# Paths and instance IDs are excluded so embedded sources survive Save As.
	if mesh is ArrayMesh:
		var names: Array[StringName] = []
		for shape in mesh.get_blend_shape_count():
			names.append(mesh.get_blend_shape_name(shape))
		hash.update(var_to_bytes([mesh.blend_shape_mode, names]))
	for surface in mesh.get_surface_count():
		var data := _surface_data(mesh, surface)
		hash.update(var_to_bytes([data.primitive, data.format, data.name]))
		hash.update(var_to_bytes(mesh.surface_get_arrays(surface)))
		hash.update(var_to_bytes(mesh.surface_get_blend_shape_arrays(surface)))
	return FINGERPRINT_VERSION + ":" + hash.finish().hex_encode()


static func validate(mesh: Mesh, mask: MeshExclusionMask) -> String:
	var error := _mesh_error(mesh)
	if not error.is_empty():
		return error
	if mask == null:
		return "No mesh exclusion mask was provided."
	if mask.source_mesh == null:
		return "The mask has lost its original source mesh. Restore or reselect the source."
	if mask.topology_fingerprint.is_empty():
		return "The mask has no topology fingerprint. Review its faces before applying it."
	if fingerprint(mesh) != mask.topology_fingerprint:
		return "Stale mesh mask: source topology or vertex correspondence changed. Review or reset the mask."
	if fingerprint(mask.source_mesh) != mask.topology_fingerprint:
		return "The mask's retained source no longer matches its recorded fingerprint. Review or reset the mask."
	return _faces_error(mesh, mask.excluded_faces)


static func build(mesh: Mesh, excluded_faces: Dictionary) -> Dictionary:
	var error := _mesh_error(mesh)
	if error.is_empty():
		error = _faces_error(mesh, excluded_faces)
	if not error.is_empty():
		return {"ok": false, "error": error}
	var output := ArrayMesh.new()
	output.resource_name = mesh.resource_name + " Excluded"
	output.lightmap_size_hint = mesh.lightmap_size_hint
	if mesh is ArrayMesh:
		output.blend_shape_mode = mesh.blend_shape_mode
		output.custom_aabb = mesh.custom_aabb
		for shape in mesh.get_blend_shape_count():
			output.add_blend_shape(mesh.get_blend_shape_name(shape))
	elif mesh is PrimitiveMesh:
		output.custom_aabb = mesh.custom_aabb
	var surface_map := {}
	var face_map := {}
	var removed_faces := 0
	var kept_faces := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface).duplicate(true)
		var source_indices := _indices(arrays)
		var omitted := {}
		for face in excluded_faces.get(surface, PackedInt32Array()):
			omitted[face] = true
		var retained := PackedInt32Array()
		var retained_ordinals := PackedInt32Array()
		for face in source_indices.size() / 3:
			if omitted.has(face):
				removed_faces += 1
				continue
			retained.append(source_indices[face * 3])
			retained.append(source_indices[face * 3 + 1])
			retained.append(source_indices[face * 3 + 2])
			retained_ordinals.append(face)
			kept_faces += 1
		# An empty index buffer means NONINDEXED drawing in Godot; omit the
		# surface instead of accidentally drawing every supposedly removed face.
		if retained.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = retained
		var data := _surface_data(mesh, surface)
		var shapes: Array[Array] = mesh.surface_get_blend_shape_arrays(surface).duplicate(true)
		var output_surface := output.get_surface_count()
		# No compaction: every attribute, bone index and blend-shape vertex keeps
		# its original index. Decoded source attributes are not recompressed.
		# Original LOD indices and shadow geometry would resurrect removed faces.
		output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shapes, {}, data.flags)
		if output.get_surface_count() != output_surface + 1:
			return {"ok": false, "error": "Godot rejected derived surface %d." % surface}
		output.surface_set_name(output_surface, data.name)
		output.surface_set_material(output_surface, mesh.surface_get_material(surface))
		surface_map[surface] = output_surface
		face_map[surface] = retained_ordinals
	output.shadow_mesh = null
	return {"ok": true, "error": "", "mesh": output, "surface_map": surface_map,
		"face_map": face_map, "removed_faces": removed_faces, "kept_faces": kept_faces,
		"empty": output.get_surface_count() == 0, "collision_invalidated": true,
		"lods_dropped": true, "shadow_mesh_dropped": true}


static func faces_in_box(mesh: Mesh, bounds: AABB) -> Dictionary:
	if not _mesh_error(mesh).is_empty() or not bounds.position.is_finite() or not bounds.size.is_finite():
		return {}
	var selected := {}
	var box := bounds.abs()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := _indices(arrays)
		var faces := PackedInt32Array()
		for face in indices.size() / 3:
			if _triangle_in_box(vertices[indices[face * 3]], vertices[indices[face * 3 + 1]],
					vertices[indices[face * 3 + 2]], box):
				faces.append(face)
		if not faces.is_empty():
			selected[surface] = faces
	return selected


static func ray_face(mesh: Mesh, origin: Vector3, direction: Vector3) -> Dictionary:
	if not _mesh_error(mesh).is_empty() or not origin.is_finite() or not direction.is_finite():
		return {}
	if direction.length_squared() <= EPSILON * EPSILON:
		return {}
	var ray := direction.normalized()
	var nearest := INF
	var hit := {}
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := _indices(arrays)
		for face in indices.size() / 3:
			var point = Geometry3D.ray_intersects_triangle(origin, ray,
				vertices[indices[face * 3]], vertices[indices[face * 3 + 1]], vertices[indices[face * 3 + 2]])
			if point == null:
				continue
			var distance := origin.distance_to(point)
			if distance < nearest:
				nearest = distance
				hit = {"surface": surface, "face": face, "distance": distance, "position": point}
	return hit


static func _surface_data(mesh: Mesh, surface: int) -> Dictionary:
	if mesh is ArrayMesh:
		var format: int = mesh.surface_get_format(surface)
		# Format-version/compression/presence bits are not creation flags.
		var custom_bits := ((1 << Mesh.ARRAY_COMPRESS_FLAGS_BASE) - 1) & ~((1 << Mesh.ARRAY_FORMAT_CUSTOM_BASE) - 1)
		var flags := format & (custom_bits | Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS | Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
		return {"primitive": mesh.surface_get_primitive_type(surface), "flags": flags,
			"format": format & ((1 << Mesh.ARRAY_COMPRESS_FLAGS_BASE) - 1) | (format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS),
			"name": mesh.surface_get_name(surface)}
	# Godot's concrete PrimitiveMesh types expose triangles except PointMesh.
	# They have no custom channels, skin or blend shapes requiring format flags.
	return {"primitive": Mesh.PRIMITIVE_POINTS if mesh is PointMesh else Mesh.PRIMITIVE_TRIANGLES,
		"flags": 0, "format": 0, "name": ""}


static func _mesh_error(mesh: Mesh) -> String:
	if mesh == null:
		return "No source mesh was selected."
	if not (mesh is ArrayMesh or mesh is PrimitiveMesh):
		return "Mesh exclusion supports readable ArrayMesh or PrimitiveMesh resources. Convert this mesh explicitly first."
	for surface in mesh.get_surface_count():
		if _surface_data(mesh, surface).primitive != Mesh.PRIMITIVE_TRIANGLES:
			return "Surface %d is not a triangle surface; exclusion cannot preserve its primitive safely." % surface
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			return "Surface %d has no readable 3D vertex array." % surface
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vertices.is_empty():
			return "Surface %d has no vertices." % surface
		var indices := _indices(arrays)
		if indices.size() % 3 != 0:
			return "Surface %d does not contain complete triangles." % surface
		for index in indices:
			if index < 0 or index >= vertices.size():
				return "Surface %d contains an out-of-range vertex index." % surface
		for vertex in vertices:
			if not vertex.is_finite():
				return "Surface %d contains a nonfinite vertex." % surface
	return ""


static func _faces_error(mesh: Mesh, faces: Dictionary) -> String:
	for surface in faces:
		if not surface is int or surface < 0 or surface >= mesh.get_surface_count():
			return "Excluded surface %s is not a valid integer source surface index." % str(surface)
		if not faces[surface] is PackedInt32Array:
			return "Excluded faces for surface %d must be a PackedInt32Array of triangle ordinals." % surface
		var count := _indices(mesh.surface_get_arrays(surface)).size() / 3
		for face in faces[surface]:
			if face < 0 or face >= count:
				return "Excluded face %d is outside source surface %d (%d triangles)." % [face, surface, count]
	return ""


static func _indices(arrays: Array) -> PackedInt32Array:
	if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array and not arrays[Mesh.ARRAY_INDEX].is_empty():
		return arrays[Mesh.ARRAY_INDEX]
	var indices := PackedInt32Array()
	indices.resize(arrays[Mesh.ARRAY_VERTEX].size())
	for index in indices.size():
		indices[index] = index
	return indices


static func _triangle_in_box(a: Vector3, b: Vector3, c: Vector3, bounds: AABB) -> bool:
	# Separating-axis test includes triangles crossing a box with no vertices in
	# it, and rejects triangles whose bounding box overlaps but geometry does not.
	var center := bounds.get_center()
	var extent := bounds.size * 0.5
	var points: Array[Vector3] = [a - center, b - center, c - center]
	var edges: Array[Vector3] = [b - a, c - b, a - c]
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK, edges[0].cross(edges[1])]
	for edge in edges:
		axes.append(edge.cross(Vector3.RIGHT))
		axes.append(edge.cross(Vector3.UP))
		axes.append(edge.cross(Vector3.BACK))
	for axis in axes:
		if axis.length_squared() <= EPSILON * EPSILON:
			continue
		var projection_a := points[0].dot(axis)
		var projection_b := points[1].dot(axis)
		var projection_c := points[2].dot(axis)
		var radius := extent.dot(axis.abs())
		if minf(projection_a, minf(projection_b, projection_c)) > radius + EPSILON:
			return false
		if maxf(projection_a, maxf(projection_b, projection_c)) < -radius - EPSILON:
			return false
	return true
