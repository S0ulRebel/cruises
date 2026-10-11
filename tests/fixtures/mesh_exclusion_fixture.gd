extends RefCounted
## In-memory authored test data; never writes a project resource.


static func make(indexed := true, influences := 4, custom := true, shapes := true) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.resource_name = "Mesh exclusion correspondence fixture"
	mesh.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(10, 10, 10))
	mesh.lightmap_size_hint = Vector2i(64, 32)
	mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_RELATIVE
	if shapes:
		for shape in ["Smile", "Blink", "MouthOpen"]:
			mesh.add_blend_shape(shape)
	var first := PackedVector3Array([Vector3(-1, -1, 0), Vector3(1, -1, 0), Vector3(0, 1, 0),
		Vector3(3, -1, 0), Vector3(5, -1, 0), Vector3(4, 1, 0)])
	if indexed:
		first.append(Vector3(99, 99, 99)) # Deliberately unused: correspondence must survive.
	var second := PackedVector3Array([Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(0, 1, -1)])
	for surface in 2:
		var vertices := first if surface == 0 else second
		var arrays := attributes(vertices, influences, custom)
		var lods := {}
		if indexed:
			arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 4, 5]) if surface == 0 else PackedInt32Array([0, 1, 2])
			if surface == 0:
				lods[10.0] = PackedInt32Array([0, 1, 2])
		var blends: Array[Array] = []
		if shapes:
			for shape in 3:
				var blend: Array = []
				blend.resize(Mesh.ARRAY_MAX)
				var deltas := PackedVector3Array()
				var normals := PackedVector3Array()
				var tangents := PackedFloat32Array()
				for vertex in vertices.size():
					deltas.append(Vector3(0.02 * (vertex + 1), 0.03 * (shape + 1), -0.01 * vertex))
					normals.append(Vector3(0, 0, 1))
					tangents.append_array(PackedFloat32Array([1, 0, 0, 1]))
				blend[Mesh.ARRAY_VERTEX] = deltas
				blend[Mesh.ARRAY_NORMAL] = normals
				blend[Mesh.ARRAY_TANGENT] = tangents
				blends.append(blend)
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if influences == 8 else 0
		if custom:
			flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blends, lods, flags)
		mesh.surface_set_name(surface, "Front" if surface == 0 else "Back")
		var material := StandardMaterial3D.new()
		material.resource_name = "Material %d" % surface
		material.albedo_color = Color(0.2 + 0.2 * surface, 0.6, 0.4)
		mesh.surface_set_material(surface, material)
	var shadow := ArrayMesh.new()
	var shadow_arrays: Array = []
	shadow_arrays.resize(Mesh.ARRAY_MAX)
	shadow_arrays[Mesh.ARRAY_VERTEX] = first
	shadow_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 4, 5])
	shadow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, shadow_arrays)
	mesh.shadow_mesh = shadow
	return mesh


static func attributes(vertices: PackedVector3Array, influences: int, custom: bool) -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var custom_bytes := PackedByteArray()
	var custom_floats := PackedFloat32Array()
	for vertex in vertices.size():
		normals.append(Vector3(0, 0, 1))
		tangents.append_array(PackedFloat32Array([1, 0, 0, 1]))
		colors.append(Color(0.1 * vertex, 0.6, 0.4, 1))
		uvs.append(Vector2(0.11 * vertex, 0.17 * vertex))
		uv2s.append(Vector2(0.05 * vertex, 0.08 * vertex))
		for influence in influences:
			bones.append(influence + vertex % 2)
			weights.append(1.0 / influences)
		custom_bytes.append_array(PackedByteArray([vertex, 20 + vertex, 50, 255]))
		custom_floats.append_array(PackedFloat32Array([0.25 * vertex, 0.125, 0.375, 1]))
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	if custom:
		arrays[Mesh.ARRAY_CUSTOM0] = custom_bytes
		arrays[Mesh.ARRAY_CUSTOM1] = custom_floats
	return arrays
