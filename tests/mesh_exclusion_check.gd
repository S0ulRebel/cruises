extends "res://tests/check.gd"
## Real ArrayMesh derivation, source identity, selection and explicit cold saves.

const Operations = preload("res://actors/assembly/mesh_exclusion/operations.gd")
const Mask = preload("res://actors/assembly/mesh_exclusion/mask.gd")
const Fixture = preload("res://tests/fixtures/mesh_exclusion_fixture.gd")
# Godot re-encodes normals/tangents in octahedral packed formats. The maximum
# measured on both real assets is 0.00019712 / 0.011294 degrees. Only these two
# shading channels get a tolerance; vertex/shape positions, UVs and weights do not.
const SHADING_DISTANCE_LIMIT := 0.0003
const SHADING_ANGLE_LIMIT := 0.02
var _real_masks: Dictionary = {}


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--cold-mask":
		_cold_check(args[1])
		finish()
		return
	_test_correspondence(true, 4)
	_test_correspondence(false, 4)
	_test_correspondence(true, 8)
	_test_removal()
	_test_stale_masks()
	_test_selection()
	_test_unsupported()
	if args.has("--real-assets"):
		_test_real_assets()
	_test_explicit_save()
	finish()


func _test_correspondence(indexed: bool, influences: int) -> void:
	var source := Fixture.make(indexed, influences)
	var before := Operations.fingerprint(source)
	var result := Operations.build(source, {0: PackedInt32Array([0, 0])})
	var label := "%s/%d influences" % ["indexed" if indexed else "nonindexed", influences]
	if not check(label + " builds", result.ok, result.error):
		return
	var output: ArrayMesh = result.mesh
	check(label + " counts duplicate face IDs once", result.removed_faces == 1 and result.kept_faces == 2)
	check(label + " source/output surface correspondence", result.surface_map == {0: 0, 1: 1})
	check(label + " source/output face correspondence", result.face_map[0] == PackedInt32Array([1]))
	for surface in source.get_surface_count():
		var original := source.surface_get_arrays(surface)
		var derived := output.surface_get_arrays(surface)
		var identical := true
		for channel in Mesh.ARRAY_INDEX:
			if original[channel] != derived[channel]:
				identical = false
		check(label + " surface %d all vertex channels preserved" % surface, identical)
		check(label + " surface %d shapes preserved" % surface,
			source.surface_get_blend_shape_arrays(surface) == output.surface_get_blend_shape_arrays(surface))
		check(label + " material/name correspondence %d" % surface,
			output.surface_get_material(surface) == source.surface_get_material(surface)
			and output.surface_get_name(surface) == source.surface_get_name(surface))
	check(label + " retained original vertex IDs", output.surface_get_arrays(0)[Mesh.ARRAY_INDEX] == PackedInt32Array([3, 4, 5]))
	check(label + " shape names/mode preserved", output.get_blend_shape_count() == 3
		and output.get_blend_shape_name(2) == &"MouthOpen" and output.blend_shape_mode == source.blend_shape_mode)
	check(label + " eight-influence format preserved",
		bool(output.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) == (influences == 8))
	check(label + " custom byte/float formats preserved",
		(output.surface_get_format(0) >> Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) & Mesh.ARRAY_FORMAT_CUSTOM_MASK == Mesh.ARRAY_CUSTOM_RGBA_FLOAT)
	check(label + " LODs and stale shadow dropped", _lods(output, 0).is_empty() and output.shadow_mesh == null)
	check(label + " original LOD/shadow remain", (not indexed or not _lods(source, 0).is_empty()) and source.shadow_mesh != null)
	check(label + " authored bounds/hint preserved", output.custom_aabb == source.custom_aabb
		and output.lightmap_size_hint == source.lightmap_size_hint)
	var changed := output.surface_get_arrays(0)
	changed[Mesh.ARRAY_VERTEX][0] = Vector3(200, 200, 200)
	check(label + " changing extracted output arrays leaves original intact", before == Operations.fingerprint(source))
	check(label + " original unchanged", source != output and before == Operations.fingerprint(source))
	output.surface_set_material(0, StandardMaterial3D.new())
	output.clear_surfaces()
	check(label + " editing output resource never changes source surfaces/materials",
		source.get_surface_count() == 2 and source.surface_get_material(0).resource_name == "Material 0"
		and before == Operations.fingerprint(source))


func _test_removal() -> void:
	var source := Fixture.make()
	var first := Operations.build(source, {0: PackedInt32Array([0, 1])})
	check("complete surface omitted without drawing nonindexed vertices", first.ok and first.mesh.get_surface_count() == 1
		and first.surface_map == {1: 0} and first.mesh.surface_get_name(0) == "Back"
		and first.mesh.surface_get_material(0) == source.surface_get_material(1))
	var all := Operations.build(source, {0: PackedInt32Array([0, 1]), 1: PackedInt32Array([0])})
	check("complete mesh safely empty", all.ok and all.empty and all.mesh.get_surface_count() == 0
		and all.surface_map.is_empty() and all.removed_faces == 3 and all.kept_faces == 0)
	check("empty mesh queries safely empty", Operations.ray_face(all.mesh, Vector3(0, 0, 1), Vector3.FORWARD).is_empty()
		and Operations.faces_in_box(all.mesh, AABB(Vector3.ZERO, Vector3.ONE)).is_empty())
	check("complete removal keeps original shapes available for reset", source.get_surface_count() == 2
		and source.get_blend_shape_count() == 3 and all.mesh.get_blend_shape_count() == 3)
	var restored := Operations.build(source, {})
	check("reset builds all original faces", restored.ok and restored.kept_faces == 3 and restored.removed_faces == 0)
	var empty := Operations.build(ArrayMesh.new(), {})
	check("empty source handled", empty.ok and empty.empty)
	for invalid in [{-1: PackedInt32Array([0])}, {2: PackedInt32Array([0])}, {"0": PackedInt32Array([0])},
		{0: [0]}, {0: PackedInt32Array([-1])}, {0: PackedInt32Array([2])}]:
		var rejected := Operations.build(source, invalid)
		check("invalid surface/face input rejected", not rejected.ok and not rejected.error.is_empty())
	check("null source rejected", not Operations.build(null, {}).ok)


func _test_stale_masks() -> void:
	var source := Fixture.make()
	var mask := _mask(source)
	check("new mask valid", Operations.validate(source, mask).is_empty())
	var changed := Fixture.make()
	var arrays := changed.surface_get_arrays(0)
	arrays[Mesh.ARRAY_VERTEX][0] = Vector3(-1.5, -1, 0)
	_replace_surface(changed, arrays)
	check("same triangle count different geometry stale", not Operations.validate(changed, mask).is_empty())
	changed = Fixture.make()
	arrays = changed.surface_get_arrays(0)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([3, 4, 5, 0, 1, 2])
	_replace_surface(changed, arrays)
	check("same counts reordered triangle identities stale", not Operations.validate(changed, mask).is_empty())
	changed = Fixture.make()
	arrays = changed.surface_get_arrays(0)
	arrays[Mesh.ARRAY_TEX_UV][0] = Vector2(0.7, 0.8)
	_replace_surface(changed, arrays)
	check("same topology different asset correspondence stale", not Operations.validate(changed, mask).is_empty())
	changed = Fixture.make()
	changed.set_blend_shape_name(0, &"DifferentFace")
	check("changed facial-shape identity stale", not Operations.validate(changed, mask).is_empty())
	changed = Fixture.make()
	var shapes: Array[Array] = changed.surface_get_blend_shape_arrays(0).duplicate(true)
	shapes[0][Mesh.ARRAY_VERTEX][0] = Vector3(0.4, 0.2, 0.1)
	_replace_surface(changed, changed.surface_get_arrays(0), shapes)
	check("changed facial-shape vertex correspondence stale", not Operations.validate(changed, mask).is_empty())
	mask.source_mesh = changed
	check("lost retained-source correspondence rejected", not Operations.validate(source, mask).is_empty())
	mask = _mask(source)
	mask.topology_fingerprint = ""
	check("missing fingerprint rejected", not Operations.validate(source, mask).is_empty())
	mask = _mask(source)
	mask.source_mesh = null
	check("missing retained source rejected", not Operations.validate(source, mask).is_empty())
	check("missing mask rejected", not Operations.validate(source, null).is_empty())


func _test_selection() -> void:
	var source := Fixture.make()
	var hit := Operations.ray_face(source, Vector3(0, 0, 2), Vector3(0, 0, -10))
	check("ray selects nearest source face with normalized distance", hit.get("surface") == 0
		and hit.get("face") == 0 and is_equal_approx(hit.get("distance", 0), 2.0))
	check("ray supports reverse face selection", Operations.ray_face(source, Vector3(4, 0, -2), Vector3.BACK).get("face") == 1)
	check("ray miss/zero direction clean", Operations.ray_face(source, Vector3(20, 0, 2), Vector3.FORWARD).is_empty()
		and Operations.ray_face(source, Vector3.ZERO, Vector3.ZERO).is_empty())
	var excluded := Operations.build(source, {0: PackedInt32Array([0])})
	var output_hit := Operations.ray_face(excluded.mesh, Vector3(0, 0, 2), Vector3.FORWARD)
	check("derived ray never picks excluded front face", output_hit.get("surface") == 1 and is_equal_approx(output_hit.get("distance", 0), 3.0))
	var crossing := Operations.faces_in_box(source, AABB(Vector3(-0.05, -0.05, -0.05), Vector3(0.1, 0.1, 0.1)))
	check("box picks crossing triangle with no contained vertices", crossing == {0: PackedInt32Array([0])})
	var false_overlap := Operations.faces_in_box(source, AABB(Vector3(0.85, 0.8, -0.05), Vector3(0.1, 0.1, 0.1)))
	check("box rejects bounding-box-only false overlap", false_overlap.is_empty())
	var both := Operations.faces_in_box(source, AABB(Vector3(-2, -2, -2), Vector3(8, 4, 4)))
	check("box spans source surfaces", both == {0: PackedInt32Array([0, 1]), 1: PackedInt32Array([0])})
	check("negative box extent normalized", Operations.faces_in_box(source,
		AABB(Vector3(0.05, 0.05, 0.05), Vector3(-0.1, -0.1, -0.1))) == crossing)
	check("nonfinite query rejected", Operations.ray_face(source, Vector3(INF, 0, 0), Vector3.UP).is_empty()
		and Operations.faces_in_box(source, AABB(Vector3(INF, 0, 0), Vector3.ONE)).is_empty())


func _test_unsupported() -> void:
	var lines := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.ONE])
	lines.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	check("unsupported primitive fails before derivation", not Operations.build(lines, {}).ok
		and Operations.fingerprint(lines).is_empty())
	var primitive := BoxMesh.new()
	var built := Operations.build(primitive, {0: PackedInt32Array([0])})
	check("ordinary primitive mesh supported", built.ok and built.removed_faces == 1 and built.kept_faces == 11)
	check("point primitive rejected", not Operations.build(PointMesh.new(), {}).ok)


func _test_real_assets() -> void:
	for path in ["res://art/models/characters/body_zombie.glb",
		"res://art/characters/captain_live/pieces/head/head_face.glb"]:
		var file := FileAccess.open(path, FileAccess.READ)
		if not check("real source readable: " + path.get_file(), file != null):
			continue
		var before_file := FileAccess.get_sha256(path)
		var scene := load(path) as PackedScene
		if not check("real source scene loads: " + path.get_file(), scene != null):
			continue
		var model := scene.instantiate()
		var skeletons := model.find_children("*", "Skeleton3D", true, false)
		var total_bones := 0
		for skeleton in skeletons:
			total_bones += skeleton.get_bone_count()
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		if model is MeshInstance3D:
			meshes.push_front(model)
		var checked_meshes := 0
		for instance in meshes:
			if instance.mesh == null or instance.mesh.get_surface_count() == 0:
				continue
			var source: ArrayMesh = instance.mesh
			var mask := _mask(source)
			mask.source_node_path = model.get_path_to(instance)
			var before_mesh := Operations.fingerprint(source)
			var skin: Skin = instance.skin
			var result := Operations.build(source, mask.excluded_faces)
			if not check("real mesh exclusion: " + path.get_file(), result.ok, result.error):
				continue
			checked_meshes += 1
			var output: ArrayMesh = result.mesh
			var faithful := true
			var normal_distance := 0.0
			var normal_degrees := 0.0
			var tangent_distance := 0.0
			var tangent_degrees := 0.0
			for surface in result.surface_map:
				var original := source.surface_get_arrays(surface)
				var derived := output.surface_get_arrays(result.surface_map[surface])
				faithful = faithful and _faithful_channels(original, derived)
				var normal_error := _normal_error(original[Mesh.ARRAY_NORMAL], derived[Mesh.ARRAY_NORMAL])
				var tangent_error := _tangent_error(original[Mesh.ARRAY_TANGENT], derived[Mesh.ARRAY_TANGENT])
				normal_distance = maxf(normal_distance, normal_error.distance)
				normal_degrees = maxf(normal_degrees, normal_error.degrees)
				tangent_distance = maxf(tangent_distance, tangent_error.distance)
				tangent_degrees = maxf(tangent_degrees, tangent_error.degrees)
				var original_shapes := source.surface_get_blend_shape_arrays(surface)
				var derived_shapes := output.surface_get_blend_shape_arrays(result.surface_map[surface])
				faithful = faithful and original_shapes.size() == derived_shapes.size()
				for shape in original_shapes.size():
					faithful = faithful and _faithful_channels(original_shapes[shape], derived_shapes[shape])
					var shape_normal_error := _normal_error(original_shapes[shape][Mesh.ARRAY_NORMAL], derived_shapes[shape][Mesh.ARRAY_NORMAL])
					var shape_tangent_error := _tangent_error(original_shapes[shape][Mesh.ARRAY_TANGENT], derived_shapes[shape][Mesh.ARRAY_TANGENT])
					normal_distance = maxf(normal_distance, shape_normal_error.distance)
					normal_degrees = maxf(normal_degrees, shape_normal_error.degrees)
					tangent_distance = maxf(tangent_distance, shape_tangent_error.distance)
					tangent_degrees = maxf(tangent_degrees, shape_tangent_error.degrees)
			check("real vertex/skin/shape correspondence with bounded shading encoding: " + path.get_file(), faithful,
				"normal %.8f / %.6f degrees; tangent %.8f / %.6f degrees" % [normal_distance, normal_degrees, tangent_distance, tangent_degrees])
			var repeated := Operations.build(source, mask.excluded_faces)
			check("real repeated derivation from original cannot accumulate rounding: " + path.get_file(),
				output.surface_get_arrays(0) == repeated.mesh.surface_get_arrays(0)
				and output.surface_get_blend_shape_arrays(0) == repeated.mesh.surface_get_blend_shape_arrays(0))
			check("real source mesh and local skin unchanged: " + path.get_file(),
				before_mesh == Operations.fingerprint(source) and instance.skin == skin and instance.mesh == source)
			if path.ends_with("head_face.glb"):
				check("speaking-head three facial shapes and local two-bone rig retained",
					source.get_blend_shape_count() == 3 and output.get_blend_shape_count() == 3 and total_bones == 2)
			_real_masks[path.get_file().get_basename()] = mask
		check("real asset has tested meshes and bones: " + path.get_file(), checked_meshes > 0 and total_bones > 0,
			"%d meshes, %d bones" % [checked_meshes, total_bones])
		check("real source file hash unchanged: " + path.get_file(), before_file == FileAccess.get_sha256(path))
		model.free()


func _test_explicit_save() -> void:
	# Only tests author to this unique user:// directory, never res:// source art.
	var token := Crypto.new().generate_random_bytes(8).hex_encode()
	var folder := "user://mesh_exclusion_check_%s" % token
	if not check("unique explicit output directory", DirAccess.make_dir_recursive_absolute(folder) == OK):
		return
	var source := Fixture.make(true, 8)
	var mask := _mask(source)
	var derived := Operations.build(source, mask.excluded_faces)
	var mask_path := folder.path_join("mask.tres")
	var derived_path := folder.path_join("derived.res")
	var empty_path := folder.path_join("empty.res")
	var before := Operations.fingerprint(source)
	check("explicit mask save", ResourceSaver.save(mask, mask_path) == OK)
	check("explicit derived save", ResourceSaver.save(derived.mesh, derived_path) == OK)
	check("explicit empty derived save", ResourceSaver.save(Operations.build(source,
		{0: PackedInt32Array([0, 1]), 1: PackedInt32Array([0])}).mesh, empty_path) == OK)
	check("save leaves original mesh intact", before == Operations.fingerprint(source))
	for name in _real_masks:
		check("explicit imported-source mask save: " + name,
			ResourceSaver.save(_real_masks[name], folder.path_join(name + "_mask.tres")) == OK)
		check("explicit real derived output save: " + name,
			ResourceSaver.save(Operations.build(_real_masks[name].source_mesh, _real_masks[name].excluded_faces).mesh,
				folder.path_join(name + "_derived.res")) == OK)
	# A new engine process proves persistence independently of resource caches.
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", "res://tests/mesh_exclusion_check.gd",
		"--", "--cold-mask", folder]), output, true)
	var transcript := "\n".join(output)
	check("cold-process load checks pass without engine errors", code == 0
		and transcript.contains("CHECKS PASSED") and not transcript.contains("ERROR:")
		and not transcript.contains("SCRIPT ERROR"), transcript)
	print("Explicit mesh-exclusion evidence: ", ProjectSettings.globalize_path(folder))


func _cold_check(folder: String) -> void:
	if not check("cold output constrained to unique user path", folder.begins_with("user://mesh_exclusion_check_")):
		return
	var mask = ResourceLoader.load(folder.path_join("mask.tres"), "", ResourceLoader.CACHE_MODE_IGNORE)
	if not check("cold mask loads", mask is MeshExclusionMask):
		return
	check("cold source/mask fingerprint correspondence", Operations.validate(mask.source_mesh, mask).is_empty())
	check("cold source faces/shapes recoverable", mask.source_mesh.get_surface_count() == 2
		and mask.source_mesh.get_blend_shape_count() == 3 and mask.source_node_path == NodePath("Model/Mesh"))
	var saved := ResourceLoader.load(folder.path_join("derived.res"), "", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
	if not check("cold derived loads independently", saved != null):
		return
	var rebuilt := Operations.build(mask.source_mesh, mask.excluded_faces)
	check("cold saved output matches deliberate derivation", saved.get_surface_count() == 2
		and saved.surface_get_arrays(0) == rebuilt.mesh.surface_get_arrays(0)
		and saved.surface_get_blend_shape_arrays(0) == rebuilt.mesh.surface_get_blend_shape_arrays(0))
	check("cold skin/custom/blend features present", bool(saved.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		and saved.surface_get_arrays(0)[Mesh.ARRAY_BONES].size() == 56 and saved.get_blend_shape_name(2) == &"MouthOpen"
		and saved.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0].size() == 28)
	check("cold removed geometry absent from ray picking", Operations.ray_face(saved, Vector3(0, 0, 2), Vector3.FORWARD).get("surface") == 1)
	var empty := ResourceLoader.load(folder.path_join("empty.res"), "", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
	check("cold fully excluded mesh loads", empty != null and empty.get_surface_count() == 0)
	for name in ["body_zombie", "head_face"]:
		var real_mask_path := folder.path_join(name + "_mask.tres")
		if not FileAccess.file_exists(real_mask_path):
			continue
		var real_mask = ResourceLoader.load(real_mask_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if not check("cold real original resource retained: " + name, real_mask is MeshExclusionMask):
			continue
		check("cold imported topology fingerprint valid: " + name,
			Operations.validate(real_mask.source_mesh, real_mask).is_empty())
		var real_output := ResourceLoader.load(folder.path_join(name + "_derived.res"), "", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		var real_expected := Operations.build(real_mask.source_mesh, real_mask.excluded_faces)
		check("cold real saved output matches original-based derivation: " + name,
			real_output != null and real_output.surface_get_arrays(0) == real_expected.mesh.surface_get_arrays(0)
			and real_output.surface_get_blend_shape_arrays(0) == real_expected.mesh.surface_get_blend_shape_arrays(0))


func _mask(source: Mesh) -> MeshExclusionMask:
	var mask := Mask.new()
	mask.source_mesh = source
	mask.topology_fingerprint = Operations.fingerprint(source)
	mask.excluded_faces = {0: PackedInt32Array([0])}
	mask.source_node_path = NodePath("Model/Mesh")
	return mask


func _replace_surface(mesh: ArrayMesh, arrays: Array, shape_override: Array[Array] = []) -> void:
	var shapes: Array[Array] = mesh.surface_get_blend_shape_arrays(0) if shape_override.is_empty() else shape_override
	var material := mesh.surface_get_material(0)
	var name := mesh.surface_get_name(0)
	var second_arrays := mesh.surface_get_arrays(1)
	var second_shapes: Array[Array] = mesh.surface_get_blend_shape_arrays(1)
	var second_material := mesh.surface_get_material(1)
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shapes, {}, flags)
	mesh.surface_set_name(0, name)
	mesh.surface_set_material(0, material)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, second_arrays, second_shapes, {}, flags)
	mesh.surface_set_name(1, "Back")
	mesh.surface_set_material(1, second_material)


func _lods(mesh: ArrayMesh, surface: int) -> Array:
	return RenderingServer.mesh_get_surface(mesh.get_rid(), surface).get("lods", [])


func _normal_error(original: PackedVector3Array, derived: PackedVector3Array) -> Dictionary:
	var distance := 0.0
	var angle := 0.0
	for vertex in original.size():
		distance = maxf(distance, original[vertex].distance_to(derived[vertex]))
		angle = maxf(angle, rad_to_deg(atan2(original[vertex].cross(derived[vertex]).length(), original[vertex].dot(derived[vertex]))))
	return {"distance": distance, "degrees": angle}


func _tangent_error(original: PackedFloat32Array, derived: PackedFloat32Array) -> Dictionary:
	var distance := 0.0
	var angle := 0.0
	var w_exact := true
	for vertex in original.size() / 4:
		var a := Vector3(original[vertex * 4], original[vertex * 4 + 1], original[vertex * 4 + 2])
		var b := Vector3(derived[vertex * 4], derived[vertex * 4 + 1], derived[vertex * 4 + 2])
		distance = maxf(distance, a.distance_to(b))
		angle = maxf(angle, rad_to_deg(atan2(a.cross(b).length(), a.dot(b))))
		w_exact = w_exact and original[vertex * 4 + 3] == derived[vertex * 4 + 3]
	return {"distance": distance, "degrees": angle, "w_exact": w_exact}


func _faithful_channels(original: Array, derived: Array) -> bool:
	for channel in Mesh.ARRAY_INDEX:
		if original[channel] == derived[channel]:
			continue
		if channel == Mesh.ARRAY_NORMAL and original[channel] is PackedVector3Array and derived[channel] is PackedVector3Array:
			if original[channel].size() != derived[channel].size():
				return false
			var error := _normal_error(original[channel], derived[channel])
			if error.distance > SHADING_DISTANCE_LIMIT or error.degrees > SHADING_ANGLE_LIMIT:
				return false
		elif channel == Mesh.ARRAY_TANGENT and original[channel] is PackedFloat32Array and derived[channel] is PackedFloat32Array:
			if original[channel].size() != derived[channel].size():
				return false
			var error := _tangent_error(original[channel], derived[channel])
			if error.distance > SHADING_DISTANCE_LIMIT or error.degrees > SHADING_ANGLE_LIMIT or not error.w_exact:
				return false
		else:
			return false
	return true
