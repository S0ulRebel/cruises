@tool
class_name CharacterLegacyOutfitService
extends RefCounted
## Explicit compatibility importer. Never mutates the edited scene or source saves.
## Returns OFF-TREE ROOT parts, with pinned parts nested under the new body.
## The editor inserts these roots atomically and assigns authored ownership.
## Legacy fits use metres/+Z forward in the donor's CWRigSpace reference frame.


static func prepare(scene_root: Node3D, outfit_path: String) -> Dictionary:
	if not is_instance_valid(scene_root):
		return _failure("Open a 3D character scene before importing a legacy fit or outfit.")
	if not CWAssemblyOperations.validate_transform(scene_root.transform).is_empty():
		return _failure("The edited scene root has an invalid transform.")
	if outfit_path.is_empty() or not ResourceLoader.exists(outfit_path):
		return _failure("Choose an existing legacy Outfit or OutfitPiece resource.")
	# Reopening means the saved fit, not unsaved mutations to a cached resource.
	var source := ResourceLoader.load(outfit_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if source is OutfitPiece:
		return _prepare_fit(scene_root, source, outfit_path)
	if not source is Outfit:
		return _failure("This resource is not a legacy Outfit or OutfitPiece. Add ordinary models through Add part.")
	var original := source as Outfit
	if original.body.is_empty():
		return _failure("This legacy outfit does not name a donor body.")
	if not is_finite(original.skin_colour.r) or not is_finite(original.skin_colour.g) or not is_finite(original.skin_colour.b) or not is_finite(original.skin_colour.a):
		return _failure("The legacy skin tint contains nonfinite values.")
	for index in original.pieces.size():
		var error := _fit_error(original.pieces[index])
		if not error.is_empty():
			return _failure("Legacy piece %d: %s" % [index + 1, error])
	var body_result := CWAssemblyOperations.create_part(original.body)
	if not body_result.ok:
		return _failure("Legacy donor: " + body_result.error)
	var body: CWPart = body_result.part
	var model := body.get_node("Model") as Node3D
	if not CWAssemblyOperations.validate_transform(model.transform).is_empty():
		body.free()
		return _failure("The legacy donor's source transform is invalid.")
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if model is Skeleton3D:
		skeletons.push_front(model)
	if skeletons.size() != 1 or (skeletons[0] as Skeleton3D).get_bone_count() == 0:
		body.free()
		return _failure("Legacy outfit conversion requires one unambiguous donor skeleton with bones. Add static models as ordinary parts.")
	var skeleton := skeletons[0] as Skeleton3D
	var frame_error := CWRigSpace.validate_frame(skeleton, model)
	if not frame_error.is_empty():
		body.free()
		return _failure(frame_error)
	for bone in skeleton.get_bone_count():
		if not CWAssemblyOperations.validate_transform(skeleton.get_bone_global_rest(bone)).is_empty():
			body.free()
			return _failure("The legacy donor has an invalid bone rest transform.")
	var frame := CWRigSpace.frame_of(skeleton, model)
	var chain := CWRigSpace.chain(skeleton, model)
	if not CWAssemblyOperations.validate_transform(frame).is_empty() or not CWAssemblyOperations.validate_transform(chain).is_empty():
		body.free()
		return _failure("The legacy donor's fit frame is invalid; review its skeleton and scale before conversion.")
	var roles_result := _roles(original.body)
	if not roles_result.ok:
		body.free()
		return roles_result
	# Compatibility authoring reproduces the legacy reference pose once, in private
	# state. Nothing resets the saved character on opening or during gameplay.
	for bone in skeleton.get_bone_count():
		if skeleton.get_bone_parent(bone) == -1:
			skeleton.set_bone_pose(bone, chain.affine_inverse() * frame * skeleton.get_bone_rest(bone))
	var stage := Node3D.new()
	var roots: Array[CWPart] = [body]
	var warnings: Array[String] = []
	var names := _existing_names(scene_root)
	body.name = _unique_name("Body", names)
	body.binding_data = original.working_copy()
	body.set_meta("legacy_outfit_path", outfit_path)
	body.set_meta("legacy_skin_colour", original.skin_colour)
	stage.add_child(body)
	_tint(model, original.skin_colour, true, warnings)
	for original_piece in original.pieces:
		var piece := original_piece.duplicate(true) as OutfitPiece
		var result := CWAssemblyOperations.create_part(piece.model)
		if not result.ok:
			stage.free()
			return _failure("Legacy part %s: %s" % [piece.model.get_file(), result.error])
		var part: CWPart = result.part
		part.name = _unique_name(piece.model.get_file().get_basename().to_pascal_case(), names)
		part.binding_data = piece
		part.set_meta("legacy_outfit_path", outfit_path)
		part.set_meta("legacy_donor_part_id", body.part_id)
		part.set_meta("legacy_fit_space", "CWRigSpace: metres, reference pose, Y up, +Z forward")
		part.set_meta("legacy_skin_colour", original.skin_colour)
		if piece.skin:
			_tint(part.get_node("Model"), original.skin_colour, false, warnings)
		if not piece.fitted:
			warnings.append("%s was not marked fitted; its stored transform is retained without guessing a replacement." % part.name)
		if piece.hold == OutfitPiece.Hold.PINNED:
			var bone_name := _bone_for(piece, skeleton, roles_result.roles)
			if bone_name.is_empty():
				part.free()
				stage.free()
				return _failure("Legacy pinned part %s has no matching donor bone. Review its explicit bone/role before importing." % piece.model.get_file())
			var bone := skeleton.find_bone(bone_name)
			var socket := BoneAttachment3D.new()
			socket.name = "Attachment" + part.part_id.substr(0, 8)
			socket.set_meta(CWAssemblyOperations.CARRIER_META, true)
			skeleton.add_child(socket)
			socket.bone_name = bone_name
			socket.bone_idx = bone
			socket.transform = skeleton.get_bone_global_pose(bone)
			socket.add_child(part)
			part.transform = (frame * skeleton.get_bone_global_rest(bone)).affine_inverse() * piece.fit()
			part.attachment_mode = CWPart.AttachmentMode.BONE
			part.bone_name = bone_name
			part.target_path = part.get_path_to(skeleton)
		else:
			part.transform = piece.fit()
			stage.add_child(part)
			roots.append(part)
			warnings.append("%s retains its authored fit and original local rig. Select the intended donor and use Bind explicitly; legacy skin weights are not regenerated." % part.name)
	for part in roots:
		stage.remove_child(part)
		CWAssemblyOperations.ensure_owned(part, part)
	stage.free()
	return _success(roots, warnings)


static func _prepare_fit(scene_root: Node3D, original: OutfitPiece, path: String) -> Dictionary:
	var error := _fit_error(original)
	if not error.is_empty():
		return _failure(error)
	var result := CWAssemblyOperations.create_part(original.model)
	if not result.ok:
		return _failure(result.error)
	var part: CWPart = result.part
	part.name = _unique_name(original.model.get_file().get_basename().to_pascal_case(), _existing_names(scene_root))
	part.transform = original.fit()
	part.binding_data = original.duplicate(true)
	part.set_meta("legacy_fit_path", path)
	part.set_meta("legacy_fit_space", "CWRigSpace: metres, reference pose, Y up, +Z forward")
	var warnings: Array[String] = []
	if original.hold == OutfitPiece.Hold.SKINNED:
		warnings.append("This individual fit has no donor reference. Select the intended donor and use Bind explicitly; the original local rig is retained.")
	else:
		warnings.append("This individual fit has no donor reference. Its saved bone/role remains in binding_data; choose an attachment target explicitly.")
	if not original.fitted:
		warnings.append("This fit was not marked fitted; its stored transform is retained without guessing a replacement.")
	return _success([part], warnings)


static func _fit_error(piece: OutfitPiece) -> String:
	if piece == null:
		return "A piece resource is missing; the outfit was not partially converted."
	if piece.model.is_empty() or not ResourceLoader.exists(piece.model, "PackedScene"):
		return "Its source model is missing. Restore or choose the intended source model."
	if piece.hold not in [OutfitPiece.Hold.PINNED, OutfitPiece.Hold.SKINNED]:
		return "Its legacy attachment mode is unsupported."
	if not piece.position.is_finite() or not piece.rotation.is_finite() or not piece.scale.is_finite():
		return "Its stored fit contains nonfinite values."
	return CWAssemblyOperations.validate_transform(piece.fit())


static func _roles(body_path: String) -> Dictionary:
	var path := body_path.get_basename() + ".roles.json"
	if not FileAccess.file_exists(path):
		return {"ok": true, "error": "", "roles": {}}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return _failure("The legacy donor role map is invalid: " + path)
	for role in parsed:
		if not parsed[role] is String or parsed[role].is_empty():
			return _failure("The legacy donor role map must name bones with nonempty strings: " + path)
	return {"ok": true, "error": "", "roles": parsed}


static func _bone_for(piece: OutfitPiece, skeleton: Skeleton3D, roles: Dictionary) -> String:
	# An explicitly stored pin must not silently fall back to a different target.
	if not piece.bone.is_empty():
		return piece.bone if skeleton.find_bone(piece.bone) >= 0 else ""
	if roles.has(piece.role):
		var declared := String(roles[piece.role])
		return declared if skeleton.find_bone(declared) >= 0 else ""
	for candidate in OutfitPiece.ROLE_BONES.get(piece.role, []):
		if skeleton.find_bone(candidate) >= 0:
			return candidate
	return ""


static func _tint(root: Node, colour: Color, only_skinned: bool, warnings: Array[String]) -> void:
	if colour == Color.WHITE:
		return
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.push_front(root)
	for node in meshes:
		var instance := node as MeshInstance3D
		if instance.mesh == null or (only_skinned and instance.skin == null):
			continue
		if instance.material_override is BaseMaterial3D:
			var material := instance.material_override.duplicate(true) as BaseMaterial3D
			material.albedo_color *= colour
			instance.material_override = material
			continue
		for surface in instance.mesh.get_surface_count():
			var material := instance.get_active_material(surface)
			if material is BaseMaterial3D and instance.material_override == null:
				var tinted := material.duplicate(true) as BaseMaterial3D
				tinted.albedo_color *= colour
				instance.set_surface_override_material(surface, tinted)
			elif material != null:
				warnings.append("%s uses a custom material; its legacy skin tint needs material review." % instance.name)


static func _existing_names(root: Node) -> Dictionary:
	var names := {}
	for child in root.get_children():
		names[String(child.name)] = true
	return names


static func _unique_name(requested: String, names: Dictionary) -> String:
	var base := requested if not requested.is_empty() else "Part"
	var value := base
	var suffix := 2
	while names.has(value):
		value = base + str(suffix)
		suffix += 1
	names[value] = true
	return value


static func _failure(error: String) -> Dictionary:
	var parts: Array[CWPart] = []
	var warnings: Array[String] = []
	return {"ok": false, "error": error, "parts": parts, "warnings": warnings}


static func _success(parts: Array[CWPart], warnings: Array[String]) -> Dictionary:
	return {"ok": true, "error": "", "parts": parts, "warnings": warnings}
