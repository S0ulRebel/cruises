@tool
extends RefCounted
## Pure binding arrays and explicit source-rig sampling; no legacy outfit dependency.

static func bind_surface_data(arrays: Array, own: Dictionary, to_fit: Transform3D,
		into_skeleton: Transform3D, copier: CWSkinCopy, step := Callable()) -> bool:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return false
	var normals := PackedVector3Array()
	if arrays[Mesh.ARRAY_NORMAL] != null:
		normals = arrays[Mesh.ARRAY_NORMAL]
	var tangents := PackedFloat32Array()
	if arrays[Mesh.ARRAY_TANGENT] != null:
		tangents = arrays[Mesh.ARRAY_TANGENT]
	var own_rest: Array[Transform3D] = []
	var own_bones := PackedInt32Array()
	var own_weights := PackedFloat32Array()
	var stride := 0
	if not own.is_empty():
		# Already rigged to the same bone names: keep its weights, and stand it in its own
		# T-pose the same way the body is stood in its own.
		own_rest = own["rest"]
		own_bones = arrays[Mesh.ARRAY_BONES]
		own_weights = arrays[Mesh.ARRAY_WEIGHTS]
		stride = own_bones.size() / vertices.size()
	if own.is_empty() and copier == null:
		return false
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(vertices.size() * 4)
	weights.resize(vertices.size() * 4)
	var placed := (into_skeleton * to_fit).basis
	for i in vertices.size():
		if step.is_valid() and i % 256 == 0 and not step.call(i, vertices.size()):
			return false
		var at: Vector3
		var packed: Array
		# What happens to this vertex's directions on the way into the skeleton's space. For a
		# rigged piece that includes its own bind, which on a Tripo rig is itself a quarter turn.
		var turn := placed
		if own.is_empty():
			at = to_fit * vertices[i]
			packed = copier.weights_at(at)
		else:
			var rest_at := Vector3.ZERO
			var rest_turn := Basis()
			var heaviest := 0.0
			var influences := {}
			var bone_map: PackedInt32Array = own["bone_map"]
			for k in stride:
				var w := own_weights[i * stride + k]
				if w <= 0.0:
					continue
				var bind := own_bones[i * stride + k]
				rest_at += (own_rest[bind] * vertices[i]) * w
				# Every bind turns directions the same way at rest; the heaviest one will do.
				if w > heaviest:
					heaviest = w
					rest_turn = own_rest[bind].basis
				var bone := bone_map[bind]
				influences[bone] = influences.get(bone, 0.0) + w
			at = to_fit * rest_at
			turn = placed * rest_turn
			packed = CWSkinCopy.top_four(influences)
		vertices[i] = into_skeleton * at
		for k in 4:
			bones[i * 4 + k] = (packed[0] as PackedInt32Array)[k]
			weights[i * 4 + k] = (packed[1] as PackedFloat32Array)[k]
		# Normals by the inverse transpose, so a coat stretched wider than it was modelled
		# still shades as if its surface faces the way it now does.
		if i < normals.size():
			normals[i] = (turn.inverse().transposed() * normals[i]).normalized()
		if i * 4 + 2 < tangents.size():
			var t := (turn * Vector3(tangents[i * 4], tangents[i * 4 + 1],
					tangents[i * 4 + 2])).normalized()
			tangents[i * 4] = t.x
			tangents[i * 4 + 1] = t.y
			tangents[i * 4 + 2] = t.z
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if not normals.is_empty():
		arrays[Mesh.ARRAY_NORMAL] = normals
	if not tangents.is_empty():
		arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	return true


## For a piece that arrived rigged: its bind transforms at rest, its fit space, and which of
## the body's bones each of its binds means. Empty when it is not rigged, or not to anything
## this body has.
##
## A bone the body lacks - a jaw, say - hands its weight to the nearest ancestor the body does
## have, so the piece moves with the head rather than tearing loose.
static func own_weights(source: MeshInstance3D, skeleton: Skeleton3D, model_root: Node = null) -> Dictionary:
	if source.skin == null:
		return {}
	var own_skeleton := source.get_node_or_null(source.skeleton) as Skeleton3D
	if own_skeleton == null:
		return {}
	var rest: Array[Transform3D] = []
	var bone_map := PackedInt32Array()
	var matched := 0
	for bind in source.skin.get_bind_count():
		var own_bone := source.skin.get_bind_bone(bind)
		if own_bone == -1:
			own_bone = own_skeleton.find_bone(source.skin.get_bind_name(bind))
		rest.append(own_skeleton.get_bone_global_rest(maxi(own_bone, 0))
				* source.skin.get_bind_pose(bind))
		var body_bone := -1
		var walk := own_bone
		while walk != -1 and body_bone == -1:
			body_bone = skeleton.find_bone(own_skeleton.get_bone_name(walk))
			walk = own_skeleton.get_bone_parent(walk)
		if body_bone != -1:
			matched += 1
		bone_map.append(maxi(body_bone, 0))
	if matched == 0:
		return {}
	var root := model_root if model_root != null else source.owner if source.owner != null else own_skeleton.get_parent()
	return {"rest": rest, "bone_map": bone_map, "frame": CWRigSpace.frame_of(own_skeleton, root)}
