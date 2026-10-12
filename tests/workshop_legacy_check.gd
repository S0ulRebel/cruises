extends "res://tests/check.gd"

const Service = preload("res://actors/assembly/legacy_outfit_service.gd")
var _folder := ""


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--cold-legacy":
		_cold(args[1])
		finish()
		return
	_folder = "user://workshop_legacy_check_" + Crypto.new().generate_random_bytes(8).hex_encode()
	if not check("legacy explicit unique output folder", DirAccess.make_dir_recursive_absolute(_folder) == OK):
		finish()
		return
	var body_path := _save_model("body.tscn", true, false)
	var face_path := _save_model("speaking_parts.tscn", true, true)
	var static_path := _save_model("arbitrary_object.tscn", false, false)
	var pin := _piece(face_path, OutfitPiece.Hold.PINNED)
	pin.bone = "Head"
	pin.skin = true
	var second_pin := _piece(face_path, OutfitPiece.Hold.PINNED)
	second_pin.role = "head"
	second_pin.position.x = -0.3
	var clothing := _piece(static_path, OutfitPiece.Hold.SKINNED)
	clothing.slot = "coat"
	clothing.position.y = 0.7
	var external_fit := _folder.path_join("authored_fit.tres")
	check("legacy authored fit save explicit", ResourceSaver.save(pin, external_fit) == OK)
	var original := Outfit.new()
	original.body = body_path
	original.skin_colour = Color(0.7, 0.8, 0.9)
	original.pieces = [load(external_fit) as OutfitPiece, second_pin, clothing]
	var path := _folder.path_join("authored_outfit.tres")
	check("legacy outfit save explicit", ResourceSaver.save(original, path) == OK)
	var source_hash := FileAccess.get_sha256(path)
	var fit_hash := FileAccess.get_sha256(external_fit)
	var body_hash := FileAccess.get_sha256(body_path)
	var face_hash := FileAccess.get_sha256(face_path)
	var root_scene := CWAssembly.new()
	root_scene.name = "AuthoredCharacter"
	root_scene.position = Vector3(3, 2, 1)
	root_scene.rotation_degrees.y = 37
	root_scene.scale = Vector3(1.3, 0.8, 1.1)
	var existing := Node3D.new()
	existing.name = "Body"
	root_scene.add_child(existing)
	var before := root_scene.transform
	var first := Service.prepare(root_scene, path)
	if check("legacy outfit converts privately", first.ok, first.error):
		check("legacy preparation leaves edited scene unchanged", root_scene.transform == before
			and root_scene.get_child_count() == 1 and root_scene.get_child(0) == existing)
		check("legacy returns root parts with nested pins", first.parts.size() == 2
			and first.parts[0].get_parent() == null and first.parts[1].get_parent() == null
			and _all(first.parts).size() == 4)
		check("legacy avoids name collision", first.parts[0].name == "Body2")
		var body: CWPart = first.parts[0]
		var converted := _all(first.parts)
		var pinned: Array[CWPart] = []
		var unbound: CWPart
		for part in converted:
			if part.attachment_mode == CWPart.AttachmentMode.BONE:
				pinned.append(part)
			elif part != body:
				unbound = part
		check("legacy duplicates same slot instead of replacing", pinned.size() == 2
			and pinned[0].part_id != pinned[1].part_id and pinned[0].source_path == pinned[1].source_path)
		var donor := body.get_node("Model").find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var frame := CWRigSpace.frame_of(donor, body.get_node("Model"))
		var fit: OutfitPiece = pinned[0].binding_data
		var expected := (frame * donor.get_bone_global_rest(donor.find_bone("Head"))).affine_inverse() * fit.fit()
		check("legacy fitted pin transform retained", pinned[0].transform.is_equal_approx(expected)
			and fit.position == pin.position and fit.rotation == pin.rotation and fit.scale == pin.scale and fit.fitted)
		check("legacy pin resolves real donor target", pinned[0].bone_name == "Head"
			and pinned[0].get_node(pinned[0].target_path) == donor and pinned[0].get_parent() is BoneAttachment3D)
		var head_model := pinned[0].get_node("Model")
		var head_skeleton := head_model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var head_mesh := head_model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var head_player := head_model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		check("legacy pin preserves complete speaking local rig", head_skeleton.get_bone_count() == 2
			and head_skeleton.find_bone("Jaw") >= 0 and head_mesh.mesh.get_blend_shape_count() == 3
			and head_mesh.skin.get_bind_count() == 2 and head_player.has_animation("speak"))
		check("legacy skin tint applied independently", head_mesh.get_active_material(0).albedo_color.is_equal_approx(Color(0.35, 0.4, 0.45)))
		check("legacy garment retains fit without unsafe binding", unbound != null
			and unbound.attachment_mode == CWPart.AttachmentMode.FREE and unbound.transform.is_equal_approx(clothing.fit())
			and unbound.binding_data is OutfitPiece and "Bind explicitly" in "\n".join(first.warnings))
		var second := Service.prepare(root_scene, path)
		if check("legacy repeated import succeeds", second.ok, second.error):
			var second_parts := _all(second.parts)
			fit.position.x += 5
			(body.binding_data as Outfit).pieces[0].position.z += 5
			check("legacy fit resources independent from source and other import", original.pieces[0].position == pin.position
				and (second_parts[1].binding_data as OutfitPiece).position == pin.position
				and (second.parts[0].binding_data as Outfit).pieces[0].position == pin.position
				and fit != original.pieces[0] and fit != second_parts[1].binding_data)
			_free_roots(second.parts)
		for part in first.parts:
			root_scene.add_child(part)
			CWAssemblyOperations.ensure_owned(part, root_scene)
		check("legacy insertion preserves pin paths", pinned[0].get_node(pinned[0].target_path) == donor)
		var saved := CWAssemblyOperations.save_scene(root_scene, _folder.path_join("converted.tscn"))
		if check("legacy explicit assembly save", saved.ok, saved.error):
			var loaded := (ResourceLoader.load(saved.path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
			var reloaded := CWAssemblyOperations.collect_parts(loaded)
			var valid := reloaded.size() == 4
			for part in reloaded:
				if part.attachment_mode == CWPart.AttachmentMode.BONE:
					valid = valid and part.get_node_or_null(part.target_path) is Skeleton3D and part.bone_name == "Head"
			check("legacy authored attachment and metadata reopen", valid)
			loaded.free()
	_test_single_fit(root_scene, external_fit, pin)
	_test_failures(root_scene, body_path, static_path, path, face_path)
	check("legacy source save files unchanged", source_hash == FileAccess.get_sha256(path)
		and fit_hash == FileAccess.get_sha256(external_fit) and body_hash == FileAccess.get_sha256(body_path)
		and face_hash == FileAccess.get_sha256(face_path))
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", "res://tests/workshop_legacy_check.gd", "--", "--cold-legacy", _folder]), output, true)
	var transcript := "\n".join(output)
	check("legacy separate-process authored scene cold load", code == 0 and transcript.contains("CHECKS PASSED")
		and not transcript.contains("ERROR:") and not transcript.contains("SCRIPT ERROR"), transcript)
	root_scene.free()
	print("Explicit legacy evidence: ", ProjectSettings.globalize_path(_folder))
	finish()


func _test_single_fit(scene: Node3D, path: String, source: OutfitPiece) -> void:
	var result := Service.prepare(scene, path)
	if not check("legacy individual fit imports", result.ok, result.error):
		return
	var part: CWPart = result.parts[0]
	check("individual fit stays free until explicit target selection", result.parts.size() == 1
		and part.get_parent() == null and part.attachment_mode == CWPart.AttachmentMode.FREE
		and part.transform.is_equal_approx(source.fit()) and not result.warnings.is_empty())
	check("individual fit preserves authored bone/role/provenance", part.binding_data.bone == "Head"
		and part.binding_data.role == source.role and part.get_meta("legacy_fit_path") == path)
	part.binding_data.scale.x += 2
	check("individual fit clone independent", (load(path) as OutfitPiece).scale == source.scale)
	_free_roots(result.parts)
	var cached := load(path) as OutfitPiece
	var saved_position := cached.position
	cached.position.x += 99
	var disk := Service.prepare(scene, path)
	check("individual fit reopening reads saved resource rather than mutable cache", disk.ok
		and disk.parts[0].binding_data.position == saved_position)
	cached.position = saved_position
	if disk.ok:
		_free_roots(disk.parts)
	var garment := source.duplicate(true) as OutfitPiece
	garment.hold = OutfitPiece.Hold.SKINNED
	garment.fitted = false
	var garment_path := _folder.path_join("individual_garment.tres")
	check("legacy garment fit save explicit", ResourceSaver.save(garment, garment_path) == OK)
	var standalone := Service.prepare(scene, garment_path)
	check("individual garment retains local rig and requests bind without auto guessing", standalone.ok
		and standalone.parts[0].transform.is_equal_approx(garment.fit())
		and "Bind explicitly" in "\n".join(standalone.warnings) and "without guessing" in "\n".join(standalone.warnings))
	if standalone.ok:
		_free_roots(standalone.parts)


func _test_failures(scene: Node3D, body_path: String, static_path: String, good_path: String, face_path: String) -> void:
	var before_count := scene.get_child_count()
	var before_transform := scene.transform
	var invalid := Outfit.new()
	invalid.body = static_path
	var path := _folder.path_join("invalid_outfit.tres")
	check("invalid test outfit save explicit", ResourceSaver.save(invalid, path) == OK)
	check("legacy rejects unrigged donor", not Service.prepare(scene, path).ok)
	invalid.body = body_path
	var missing := _piece(_folder.path_join("missing.tscn"), OutfitPiece.Hold.PINNED)
	invalid.pieces = [_piece(face_path, OutfitPiece.Hold.PINNED), missing]
	ResourceSaver.save(invalid, path)
	check("legacy missing later model rejects whole conversion", not Service.prepare(scene, path).ok)
	var wrong_pin := _piece(face_path, OutfitPiece.Hold.PINNED)
	wrong_pin.bone = "MissingBone"
	invalid.pieces = [_piece(face_path, OutfitPiece.Hold.SKINNED), wrong_pin]
	ResourceSaver.save(invalid, path)
	check("legacy missing explicit bone never silently falls back", not Service.prepare(scene, path).ok)
	wrong_pin.bone = "Head"
	wrong_pin.scale.y = 0
	ResourceSaver.save(invalid, path)
	check("legacy singular fit rejected", not Service.prepare(scene, path).ok)
	invalid.pieces = [null]
	ResourceSaver.save(invalid, path)
	check("legacy missing fit resource rejected", not Service.prepare(scene, path).ok)
	check("legacy wrong resource type rejected", not Service.prepare(scene, static_path).ok)
	check("legacy missing path rejected", not Service.prepare(scene, _folder.path_join("absent.tres")).ok)
	check("legacy missing edited scene rejected", not Service.prepare(null, good_path).ok)
	var roles_path := body_path.get_basename() + ".roles.json"
	var roles_file := FileAccess.open(roles_path, FileAccess.WRITE)
	roles_file.store_string('{"head": 7}')
	roles_file.close()
	check("legacy malformed donor role mapping rejects safely", not Service.prepare(scene, good_path).ok)
	roles_file = FileAccess.open(roles_path, FileAccess.WRITE)
	roles_file.store_string('{"head": "Head"}')
	roles_file.close()
	var declared_roles := Service.prepare(scene, good_path)
	check("legacy explicit donor roles resolve", declared_roles.ok)
	if declared_roles.ok:
		_free_roots(declared_roles.parts)
	check("all rejected legacy imports leave scene unchanged", scene.get_child_count() == before_count and scene.transform == before_transform)


func _piece(path: String, mode: int) -> OutfitPiece:
	var piece := OutfitPiece.new()
	piece.model = path
	piece.hold = mode
	piece.position = Vector3(0.1, 1.7, 0.2)
	piece.rotation = Vector3(7, 13, -4)
	piece.scale = Vector3(1.1, 0.9, 1.2)
	piece.fitted = true
	return piece


func _all(roots: Array[CWPart]) -> Array[CWPart]:
	var all: Array[CWPart] = []
	for part in roots:
		all.append_array(CWAssemblyOperations.collect_parts(part))
	return all


func _free_roots(roots: Array[CWPart]) -> void:
	for part in roots:
		part.free()


func _save_model(name: String, rigged: bool, speaking: bool) -> String:
	var model := Node3D.new()
	model.name = "SourceModel"
	var mesh := MeshInstance3D.new()
	mesh.name = "Geometry"
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([0.5, 0.5, 0, 0, 0.5, 0.5, 0, 0, 0.5, 0.5, 0, 0])
	var geometry := ArrayMesh.new()
	var shapes: Array[Array] = []
	if speaking:
		for label in ["Smile", "Blink", "MouthOpen"]:
			geometry.add_blend_shape(label)
			var shape: Array = []
			shape.resize(Mesh.ARRAY_MAX)
			shape[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3(0.1, 0.2, 0), Vector3(0.1, 0, 0)])
			shape[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
			shapes.append(shape)
	geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shapes)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.5, 0.5)
	geometry.surface_set_material(0, material)
	mesh.mesh = geometry
	if rigged:
		var skeleton := Skeleton3D.new()
		skeleton.name = "LocalRig"
		skeleton.add_bone("Head" if speaking else "Hips")
		skeleton.add_bone("Jaw" if speaking else "Head")
		skeleton.set_bone_parent(1, 0)
		skeleton.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 0)))
		skeleton.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0)))
		model.add_child(skeleton)
		skeleton.add_child(mesh)
		mesh.skin = Skin.new()
		for bone in 2:
			mesh.skin.add_named_bind(skeleton.get_bone_name(bone), skeleton.get_bone_global_rest(bone).affine_inverse())
		mesh.skeleton = NodePath("..")
	else:
		model.add_child(mesh)
	if speaking:
		var player := AnimationPlayer.new()
		player.name = "FaceAnimation"
		var library := AnimationLibrary.new()
		library.add_animation("speak", Animation.new())
		player.add_animation_library("", library)
		model.add_child(player)
	CWAssemblyOperations.ensure_owned(model, model)
	var packed := PackedScene.new()
	check("legacy source fixture packs: " + name, packed.pack(model) == OK)
	model.free()
	var path := _folder.path_join(name)
	check("legacy source fixture saves explicitly: " + name, ResourceSaver.save(packed, path) == OK)
	return path


func _cold(folder: String) -> void:
	if not check("cold legacy output constrained", folder.begins_with("user://workshop_legacy_check_")):
		return
	var packed := ResourceLoader.load(folder.path_join("converted.tscn")) as PackedScene
	if not check("cold legacy scene exists", packed != null):
		return
	var scene := packed.instantiate()
	var parts := CWAssemblyOperations.collect_parts(scene)
	check("cold legacy four independent parts", parts.size() == 4)
	var ids := {}
	var valid := true
	var pinned := 0
	for part in parts:
		valid = valid and not part.part_id.is_empty() and not ids.has(part.part_id)
		ids[part.part_id] = true
		if part.attachment_mode == CWPart.AttachmentMode.BONE:
			pinned += 1
			valid = valid and part.get_node_or_null(part.target_path) is Skeleton3D and part.bone_name == "Head"
			var mesh := part.get_node("Model").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			valid = valid and mesh.mesh.get_blend_shape_count() == 3 and mesh.skin.get_bind_count() == 2
	check("cold legacy local rigs, facial shapes and donor pins persist", valid and pinned == 2)
	check("cold legacy authored transformed root persists", (scene as Node3D).position.is_equal_approx(Vector3(3, 2, 1))
		and (scene as Node3D).scale.is_equal_approx(Vector3(1.3, 0.8, 1.1)))
	scene.free()
