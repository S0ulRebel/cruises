extends SceneTree
## Explicit authoring checks. Outputs are unique user:// directories, never source
## assets. Run again with -- cold <printed COLD_SCENE_PATH> for a process-cold reopen.
## Also run -- nested <printed COLD_NESTED_SCENE_PATH> for nested source compositions.

const STATIC := "res://tests/fixtures/assembly_static.tscn"
const HEAD := "res://art/characters/captain_live/pieces/head/head_face.glb"
const META := "res://tests/fixtures/assembly_metadata.tres"

var _failures := 0
var _checks := 0
var _detached: Array[Node] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "cold":
		await _cold(args[1])
		_finish()
		return
	if args.size() == 2 and args[0] == "nested":
		await _cold_nested(args[1])
		_finish()
		return
	var assembly := CharacterAssembly.new()
	assembly.name = "Assembly"
	assembly.assembly_id = AssemblyOperations.generate_id()
	assembly.transform = Transform3D(Basis.from_euler(Vector3(0.1, 0.3, -0.2)).scaled(Vector3(1.2, 0.9, 1.1)), Vector3(3, 1, -2))
	root.add_child(assembly)
	await process_frame
	_check("empty/static assembly opens without creating content", assembly.get_child_count() == 0)
	_check("missing source fails without mutation", not AssemblyOperations.create_part("res://not_a_part.glb").ok and assembly.get_child_count() == 0)
	_check("2D roots rejected without mutation", not AssemblyOperations.create_part("res://tests/fixtures/assembly_non_3d.tscn").ok and assembly.get_child_count() == 0)
	var made := AssemblyOperations.create_part(STATIC)
	if not _check("arbitrary root mesh scene imports", made.ok):
		assembly.free()
		_finish()
		return
	var first: AssemblyPart = made.part
	first.name = "First"
	assembly.add_child(first)
	AssemblyOperations.ensure_owned(first, assembly)
	first.transform = Transform3D(Basis.from_euler(Vector3(0.2, -0.4, 0.1)).scaled(Vector3(0.7, 1.3, 1.1)), Vector3(-1, 0.7, 2))
	_check("root MeshInstance3D remains selectable Model", first.get_node("Model") is MeshInstance3D)
	_check("part identity is generated independently of filename", not first.part_id.is_empty() and first.part_id != STATIC.get_file())
	first.binding_data = load(META)
	first.geometry_masks.append(load(META))
	var duplicate := AssemblyOperations.duplicate_part(first)
	_check("duplicate succeeds off-tree", duplicate.ok and duplicate.part.get_parent() == null)
	var second: AssemblyPart = duplicate.part
	second.name = "Second"
	assembly.add_child(second)
	AssemblyOperations.ensure_owned(second, assembly)
	_check("two copies retain unique identities", first.part_id != second.part_id and AssemblyOperations.collect_parts(assembly).size() == 2)
	_check("nearest_part includes root mesh", AssemblyOperations.nearest_part(second.get_node("Model")) == second)
	var first_mesh := first.get_node("Model") as MeshInstance3D
	var second_mesh := second.get_node("Model") as MeshInstance3D
	_check("meshes and surface materials are independent", first_mesh.mesh != second_mesh.mesh and first_mesh.mesh.surface_get_material(0) != second_mesh.mesh.surface_get_material(0))
	var original_clip := (first_mesh.get_node("AnimationPlayer") as AnimationPlayer).get_animation("gentle")
	var copied_clip := (second_mesh.get_node("AnimationPlayer") as AnimationPlayer).get_animation("gentle")
	copied_clip.loop_mode = Animation.LOOP_LINEAR
	_check("animation previews cannot mutate source/shared clip loops", original_clip != copied_clip and original_clip.loop_mode == Animation.LOOP_NONE)
	second_mesh.get_node("Timer").emit_signal("timeout")
	_check("duplicated prefab signals target the independent copy", second_mesh.tick_count == 1 and first_mesh.tick_count == 0)
	_check("external binding and nested resources are independent", first.binding_data != second.binding_data and first.binding_data.material != second.binding_data.material)
	_check("metadata array external entries are independent", first.geometry_masks[0] != second.geometry_masks[0] and first.geometry_masks[0].material != second.geometry_masks[0].material)
	second.binding_data.offset = Vector3(7, 8, 9)
	(second.binding_data.material as StandardMaterial3D).albedo_color = Color.GREEN
	_check("mutating duplicate leaves cached source binding unchanged", first.binding_data.offset == Vector3(0.1, 0.2, 0.3) and first.binding_data.material.albedo_color != Color.GREEN)
	_check("alias relationships inside cloned resource are retained", second.binding_data.related[0] == second.binding_data.material)
	var target := Node3D.new()
	target.name = "TransformedParent"
	assembly.add_child(target)
	target.transform = Transform3D(Basis.from_euler(Vector3(0.5, 0.2, -0.3)).scaled(Vector3(2, 0.7, 1.4)), Vector3(2, 3, 4))
	AssemblyOperations.ensure_owned(target, assembly)
	var original := first.global_transform
	var attached := AssemblyOperations.attach(first, target, AssemblyPart.AttachmentMode.PARENT, "", assembly)
	_check("parent attachment preserves full world matrix under rotated/nonuniform parents", attached.ok and first.global_transform.is_equal_approx(original))
	_check("target metadata identifies actual authored parent", first.get_node(first.target_path) == target)
	AssemblyOperations.restore_attachment(first, attached.before)
	_check("attachment undo restores original parent and world placement", first.get_parent() == assembly and first.global_transform.is_equal_approx(original))
	AssemblyOperations.restore_attachment(first, attached.after)
	_check("attachment redo restores target and placement", first.get_parent() == target and first.global_transform.is_equal_approx(original))
	second.top_level = true
	var top_world := second.global_transform
	var top_state := AssemblyOperations.capture_attachment(second)
	var top_attach := AssemblyOperations.attach(second, target, AssemblyPart.AttachmentMode.PARENT, "", assembly)
	_check("top-level part attaches without a position jump", top_attach.ok and not second.top_level and second.global_transform.is_equal_approx(top_world))
	AssemblyOperations.restore_attachment(second, top_state)
	_check("undo restores top-level flag and placement", second.top_level and second.global_transform.is_equal_approx(top_world))
	second.top_level = false
	var invalid_state := AssemblyOperations.capture_attachment(first)
	_check("cycle is rejected before scene mutation", not AssemblyOperations.attach(first, first_mesh, AssemblyPart.AttachmentMode.PARENT, "", assembly).ok and first.get_parent() == target and first.transform == invalid_state.transform)
	_check("skinning is never implicit", not AssemblyOperations.attach(first, target, AssemblyPart.AttachmentMode.SKINNED, "", assembly).ok)
	var bad := Node3D.new()
	bad.scale = Vector3.ZERO
	assembly.add_child(bad)
	_check("singular target is rejected without mutation", not AssemblyOperations.attach(first, bad, AssemblyPart.AttachmentMode.PARENT, "", assembly).ok and first.get_parent() == target)
	bad.free()
	_check("zero/nonfinite transforms rejected", not AssemblyOperations.validate_transform(Transform3D(Basis().scaled(Vector3(0, 1, 1)), Vector3.ZERO)).is_empty() and not AssemblyOperations.validate_transform(Transform3D(Basis(), Vector3(INF, 0, 0))).is_empty())
	_check("intentional nonzero mirrored transforms accepted", AssemblyOperations.validate_transform(Transform3D(Basis().scaled(Vector3(-1, 1, 1)), Vector3.ZERO)).is_empty())
	var skeleton := Skeleton3D.new()
	skeleton.name = "DonorSkeleton"
	skeleton.add_bone("DifferentHeadName")
	skeleton.set_bone_rest(0, Transform3D(Basis.from_euler(Vector3(0.1, 0.3, 0.2)), Vector3(0, 1.6, 0)))
	target.add_child(skeleton)
	AssemblyOperations.ensure_owned(skeleton, assembly)
	await process_frame
	_check("unknown bone rejected transactionally", not AssemblyOperations.attach(first, skeleton, AssemblyPart.AttachmentMode.BONE, "Missing", assembly).ok and first.get_parent() == target)
	var bone_attach := AssemblyOperations.attach(first, skeleton, AssemblyPart.AttachmentMode.BONE, "DifferentHeadName", assembly)
	_check("arbitrary named bone attachment preserves world placement", bone_attach.ok and first.global_transform.is_equal_approx(original))
	var carrier: BoneAttachment3D = bone_attach.carrier
	_check("bone target has owned explicit carrier", first.get_parent() == carrier and carrier.owner == assembly and first.get_node(first.target_path) == skeleton)
	skeleton.set_bone_pose_position(0, Vector3(0.3, 0.4, 0.5))
	skeleton.force_update_all_bone_transforms()
	await process_frame
	_check("bone-attached part actually follows animated pose", not first.global_transform.is_equal_approx(original))
	var animated_world := first.global_transform
	var detached := AssemblyOperations.attach(first, assembly, AssemblyPart.AttachmentMode.FREE, "", assembly)
	_check("detach preserves animated world placement", detached.ok and first.global_transform.is_equal_approx(animated_world))
	_check("empty carrier is detached, not destroyed", is_instance_valid(carrier) and carrier.get_parent() == null)
	_track(carrier)
	AssemblyOperations.restore_attachment(first, detached.before)
	_check("bone attachment undo reinstates carrier and metadata", first.get_parent() == carrier and carrier.get_parent() == skeleton and first.bone_name == "DifferentHeadName")
	AssemblyOperations.restore_attachment(first, detached.after)
	_check("bone detach redo remains editable", first.get_parent() == assembly and first.attachment_mode == AssemblyPart.AttachmentMode.FREE)
	_bound_reference_checks(assembly)
	var head_result := AssemblyOperations.create_part(HEAD)
	if _check("speaking head imports through unrestricted path", head_result.ok):
		var head: AssemblyPart = head_result.part
		head.name = "SpeakingHead"
		assembly.add_child(head)
		AssemblyOperations.ensure_owned(head, assembly)
		var head_rig := _skeleton(head)
		var shapes := _shape_count(head)
		_check("speaking head local bones/blend shapes preserved", head_rig != null and head_rig.get_bone_count() == 2 and shapes == 3)
		var head_attach := AssemblyOperations.attach(head, skeleton, AssemblyPart.AttachmentMode.BONE, "DifferentHeadName", assembly)
		_check("bone attaching speaking head does not convert its local rig", head_attach.ok and _skeleton(head) == head_rig and _shape_count(head) == shapes)
		var jaw_name := head_rig.get_bone_name(head_rig.find_bone("Jaw")) if head_rig.find_bone("Jaw") >= 0 else head_rig.get_bone_name(1)
		var second_world := second.global_transform
		var jaw_attach := AssemblyOperations.attach(second, head_rig, AssemblyPart.AttachmentMode.BONE, jaw_name, assembly)
		_check("another part can target the head's own Jaw", jaw_attach.ok and second.get_node(second.target_path) == head_rig and second.global_transform.is_equal_approx(second_world))
		if jaw_attach.ok:
			var copied_head := AssemblyOperations.duplicate_part(head)
			_check("duplicate does not recursively copy dependent accessories", copied_head.ok and AssemblyOperations.collect_parts(copied_head.part).size() == 1 and _shape_count(copied_head.part) == shapes)
			if copied_head.ok:
				var local_skin_valid := true
				for reference: Dictionary in copied_head.reference_states:
					if reference.key == &"skeleton":
						local_skin_valid = local_skin_valid and reference.base.get_node_or_null(reference.value) == _skeleton(copied_head.part) and reference.target == _skeleton(copied_head.part)
				_check("duplicate local-rig meshes reference the copied skeleton", local_skin_valid)
				copied_head.part.free()
	var output_dir := "user://assembly_check_" + str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + AssemblyOperations.generate_id().substr(0, 8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var output := output_dir + "/saved_assembly.tscn"
	var source_hash := FileAccess.get_sha256(ProjectSettings.globalize_path(HEAD))
	var owner_before := first.owner
	_check("invalid destination fails without changing ownership", not AssemblyOperations.save_scene(assembly, "").ok and first.owner == owner_before)
	_check("source scene overwrite is rejected", not AssemblyOperations.save_scene(assembly, STATIC).ok)
	var saved := AssemblyOperations.save_scene(assembly, output)
	_check("explicit reusable scene saves successfully", saved.ok and FileAccess.file_exists(output))
	_check("save does not rewrite imported head or live ownership", FileAccess.get_sha256(ProjectSettings.globalize_path(HEAD)) == source_hash and first.owner == owner_before)
	if saved.ok:
		var loaded := (ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
		root.add_child(loaded)
		await process_frame
		_validate_loaded(loaded)
		loaded.free()
		print("COLD_SCENE_PATH=" + output)
	var nested_output := await _nested_composition_checks(output_dir)
	if not nested_output.is_empty():
		print("COLD_NESTED_SCENE_PATH=" + nested_output)
	assembly.free()
	_cleanup()
	_finish()


func _cold(path: String) -> void:
	if not _check("cold saved assembly exists", FileAccess.file_exists(path)):
		return
	var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if not _check("cold saved scene loads", scene != null):
		return
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame
	_validate_loaded(instance)
	instance.free()


func _nested_composition_checks(output_dir: String) -> String:
	var source := CharacterAssembly.new()
	source.name = "TwoPartSource"
	source.assembly_id = AssemblyOperations.generate_id()
	root.add_child(source)
	var body: AssemblyPart = AssemblyOperations.create_part(STATIC).part
	body.name = "SourceBody"
	source.add_child(body)
	body.transform = Transform3D(Basis.from_euler(Vector3(0.2, -0.1, 0.3)).scaled(Vector3(1.2, 0.9, 0.8)), Vector3(0.1, 0.3, -0.2))
	var rig := Skeleton3D.new()
	rig.name = "SourceSkeleton"
	rig.add_bone("SourceSocket")
	rig.set_bone_rest(0, Transform3D(Basis.from_euler(Vector3(0.1, 0.2, 0)), Vector3(0, 1.7, 0)))
	body.get_node("Model").add_child(rig)
	var accessory: AssemblyPart = AssemblyOperations.create_part(STATIC).part
	accessory.name = "SourceAccessory"
	source.add_child(accessory)
	accessory.position = Vector3(0.2, 2.1, 0.3)
	accessory.binding_data = Resource.new()
	accessory.binding_data.set_meta("donor_path", accessory.get_path_to(rig))
	var mask := MeshExclusionMask.new()
	mask.source_node_path = NodePath("Model")
	accessory.geometry_masks.append(mask)
	AssemblyOperations.ensure_owned(source, source)
	await process_frame
	var attached := AssemblyOperations.attach(accessory, rig, AssemblyPart.AttachmentMode.BONE, "SourceSocket", source)
	_check("nested source prefab has authored bone attachment", attached.ok and accessory.get_node_or_null(accessory.target_path) == rig)
	var saved_source := output_dir + "/two_part_source.tscn"
	var authored_ids := [body.part_id, accessory.part_id]
	var saved := AssemblyOperations.save_scene(source, saved_source)
	if not _check("nested two-part source saves explicitly", saved.ok):
		source.free()
		return ""
	source.free()
	var source_hash := FileAccess.get_sha256(ProjectSettings.globalize_path(saved_source))
	var adopted := AssemblyPart.new()
	adopted.part_id = AssemblyOperations.generate_id()
	var adopted_model := (ResourceLoader.load(saved_source, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
	adopted_model.name = "Model"
	adopted.add_child(adopted_model)
	var adoption_before := AssemblyOperations.capture_source_composition(adopted)
	AssemblyOperations.initialize_source_composition(adopted)
	var adoption_after := AssemblyOperations.capture_source_composition(adopted)
	_check("explicit native adoption regenerates nested source identities", _ids_exclude(adopted, authored_ids) and _unique_ids(adopted))
	AssemblyOperations.restore_source_composition(adoption_before)
	_check("native adoption undo restores exact nested IDs and metadata presence", _source_snapshot_matches(adoption_before) and _named_part(adopted, "SourceBody").part_id == authored_ids[0] and _named_part(adopted, "SourceAccessory").part_id == authored_ids[1])
	AssemblyOperations.restore_source_composition(adoption_after)
	_check("native adoption redo restores the same new identities and source groups", _source_snapshot_matches(adoption_after) and _ids_exclude(adopted, authored_ids))
	adopted.free()
	var first_result := AssemblyOperations.create_part(saved_source)
	var second_result := AssemblyOperations.create_part(saved_source)
	if not _check("saved composition can be imported twice", first_result.ok and second_result.ok):
		if first_result.ok: first_result.part.free()
		if second_result.ok: second_result.part.free()
		return ""
	var assembly := CharacterAssembly.new()
	assembly.name = "NestedAssembly"
	assembly.assembly_id = AssemblyOperations.generate_id()
	root.add_child(assembly)
	var first: AssemblyPart = first_result.part
	first.name = "FirstComposition"
	assembly.add_child(first)
	var second: AssemblyPart = second_result.part
	second.name = "SecondComposition"
	assembly.add_child(second)
	second.position.x = 3
	_check("both imports retain two source parts and their carrier", AssemblyOperations.collect_parts(first).size() == 3 and AssemblyOperations.collect_parts(second).size() == 3 and _nested_references_valid(first) and _nested_references_valid(second))
	_check("imported nested IDs are new and disjoint", _unique_ids(assembly) and _ids_exclude(assembly, authored_ids))
	_check("separate imported compositions have independent mutable resources", first.get_node("Model/SourceBody/Model").mesh != second.get_node("Model/SourceBody/Model").mesh and _named_part(first, "SourceAccessory").binding_data != _named_part(second, "SourceAccessory").binding_data)
	var first_rig := first.get_node("Model/SourceBody/Model/SourceSkeleton") as Skeleton3D
	var external: AssemblyPart = AssemblyOperations.create_part(STATIC).part
	external.name = "ExternalAccessory"
	assembly.add_child(external)
	AssemblyOperations.ensure_owned(assembly, assembly)
	var external_attachment := AssemblyOperations.attach(external, first_rig, AssemblyPart.AttachmentMode.BONE, "SourceSocket", assembly)
	_check("external dependent added after import remains separate", external_attachment.ok and AssemblyOperations.collect_parts(first).size() == 4)
	var source_ids: Array = []
	for part in AssemblyOperations.collect_parts(assembly):
		source_ids.append(part.part_id)
	var nested_copy := AssemblyOperations.duplicate_part(_named_part(first, "SourceBody"))
	if _check("duplicating an inner source part retains composed accessory and excludes external one", nested_copy.ok and AssemblyOperations.collect_parts(nested_copy.part).size() == 2 and _nested_references_valid(nested_copy.part) and _ids_exclude(nested_copy.part, source_ids)):
		nested_copy.part.free()
	elif nested_copy.ok:
		nested_copy.part.free()
	var duplicated := AssemblyOperations.duplicate_part(first)
	if not _check("composition duplicate retains authored parts but excludes external accessory", duplicated.ok and AssemblyOperations.collect_parts(duplicated.part).size() == 3 and _named_part(duplicated.part, "ExternalAccessory") == null):
		if duplicated.ok: duplicated.part.free()
		assembly.free()
		return ""
	var copy: AssemblyPart = duplicated.part
	copy.name = "CopiedComposition"
	assembly.add_child(copy)
	copy.global_transform = duplicated.world_transform
	copy.position.x += 6
	AssemblyOperations.ensure_owned(copy, assembly)
	AssemblyOperations.rebase_references(duplicated.reference_states)
	_check("composition duplicate regenerates every nested part ID", _unique_ids(assembly) and _ids_exclude(copy, source_ids))
	_check("copied source attachment and binding paths resolve inside its own rig", _nested_references_valid(copy))
	var copied_body := _named_part(copy, "SourceBody")
	var original_body := _named_part(first, "SourceBody")
	var copied_model := copied_body.get_node("Model") as MeshInstance3D
	var original_model := original_body.get_node("Model") as MeshInstance3D
	_check("nested duplicate mutable meshes and binding masks remain independent", copied_model.mesh != original_model.mesh and _named_part(copy, "SourceAccessory").geometry_masks[0] != _named_part(first, "SourceAccessory").geometry_masks[0])
	var output := output_dir + "/nested_assembly.tscn"
	var saved_nested := AssemblyOperations.save_scene(assembly, output)
	_check("multiple imports and duplicate can save together with unique identities", saved_nested.ok)
	_check("source prefab is untouched by import duplicate and save", FileAccess.get_sha256(ProjectSettings.globalize_path(saved_source)) == source_hash)
	assembly.free()
	if not saved_nested.ok:
		return ""
	await _cold_nested(output)
	return output


func _cold_nested(path: String) -> void:
	var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if not _check("nested reusable scene opens", packed != null):
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	_check("cold nested scene retains all three compositions and one external accessory", AssemblyOperations.collect_parts(instance).size() == 10 and _unique_ids(instance))
	for node_name in ["FirstComposition", "SecondComposition", "CopiedComposition"]:
		var part := instance.get_node(node_name) as AssemblyPart
		_check("cold %s retains its local authored attachment paths" % node_name, _nested_references_valid(part))
		var copied := AssemblyOperations.duplicate_part(part)
		if _check("cold %s duplicate preserves source boundary" % node_name, copied.ok and AssemblyOperations.collect_parts(copied.part).size() == 3 and _named_part(copied.part, "ExternalAccessory") == null):
			copied.part.free()
		elif copied.ok:
			copied.part.free()
	instance.free()


func _nested_references_valid(part: AssemblyPart) -> bool:
	var body := _named_part(part, "SourceBody")
	var accessory := _named_part(part, "SourceAccessory")
	if body == null or accessory == null:
		return false
	var rig := body.get_node_or_null("Model/SourceSkeleton") as Skeleton3D
	return rig != null and accessory.get_parent() is BoneAttachment3D and accessory.get_node_or_null(accessory.target_path) == rig and accessory.get_node_or_null(accessory.binding_data.get_meta("donor_path")) == rig and accessory.get_node_or_null(accessory.geometry_masks[0].source_node_path) == accessory.get_node("Model")


func _named_part(root_node: Node, node_name: String) -> AssemblyPart:
	for part in AssemblyOperations.collect_parts(root_node):
		if part.name == node_name:
			return part
	return null


func _unique_ids(root_node: Node) -> bool:
	var seen := {}
	for part in AssemblyOperations.collect_parts(root_node):
		if part.part_id.is_empty() or seen.has(part.part_id):
			return false
		seen[part.part_id] = true
	return true


func _ids_exclude(root_node: Node, excluded: Array) -> bool:
	for part in AssemblyOperations.collect_parts(root_node):
		if part.part_id in excluded:
			return false
	return true


func _source_snapshot_matches(states: Array) -> bool:
	for state: Dictionary in states:
		var node: Node = state.node
		if not is_instance_valid(node) or node.has_meta(AssemblyOperations.SOURCE_GROUP_META) != state.had_source_group:
			return false
		if state.had_source_group and node.get_meta(AssemblyOperations.SOURCE_GROUP_META) != state.source_group:
			return false
		if state.has("part_id") and (node as AssemblyPart).part_id != state.part_id:
			return false
	return true


func _validate_loaded(instance: Node) -> void:
	var parts := AssemblyOperations.collect_parts(instance)
	_check("saved parts and arbitrary names retained", parts.size() == 6)
	var first: AssemblyPart
	var second: AssemblyPart
	var head: AssemblyPart
	for part in parts:
		if part.name == "First": first = part
		if part.name == "Second": second = part
		if part.name == "SpeakingHead": head = part
	if not _check("all authored part identities survive reopening", first != null and second != null and head != null and first.part_id != second.part_id):
		return
	_check("saved speaking head preserves local bones and facial shapes", _skeleton(head) != null and _skeleton(head).get_bone_count() == 2 and _shape_count(head) == 3)
	_check("saved attachment to local Jaw resolves", second.attachment_mode == AssemblyPart.AttachmentMode.BONE and second.get_node_or_null(second.target_path) == _skeleton(head))
	_check("binding provenance and nested masks survive", second.binding_data.offset == Vector3(7, 8, 9) and second.geometry_masks.size() == 1)
	_check("working resources remain independent after reopening", first.binding_data != second.binding_data and first.binding_data.material != second.binding_data.material)
	var model := second.get_node("Model") as MeshInstance3D
	var old := model.transform
	model.position += Vector3(0.5, 0.2, -0.1)
	model.rotation += Vector3(0.1, 0.2, 0.3)
	model.scale *= Vector3(1.1, 0.8, 1.2)
	_check("reopened root mesh remains transform editable", model.transform != old)
	var donor := instance.get_node("ReferenceDestination/ReferenceDonor") as AssemblyPart
	var bound := instance.get_node("ReferenceHolder/ReferenceGarment") as AssemblyPart
	var copied := instance.get_node("ReferenceCopy") as AssemblyPart
	if _check("reopened external-bound parts are present", donor != null and bound != null and copied != null):
		var donor_rig := donor.get_node("Model/ReferenceSkeleton") as Skeleton3D
		_check("cold bound source and duplicate skeleton paths resolve", bound.get_node("Model").get_node_or_null(bound.get_node("Model").skeleton) == donor_rig and copied.get_node("Model").get_node_or_null(copied.get_node("Model").skeleton) == donor_rig)
		_check("cold donor attachment and provenance references resolve", bound.get_node_or_null(bound.target_path) == donor_rig and copied.get_node_or_null(copied.binding_data.get_meta("donor_path")) == donor_rig)


func _bound_reference_checks(assembly: CharacterAssembly) -> void:
	var holder := Node3D.new()
	holder.name = "ReferenceHolder"
	assembly.add_child(holder)
	holder.transform = Transform3D(Basis.from_euler(Vector3(0.1, 0.2, 0.4)), Vector3(0.4, 0.2, -0.3))
	var destination := Node3D.new()
	destination.name = "ReferenceDestination"
	assembly.add_child(destination)
	destination.position = Vector3(2, 0.5, -3)
	var donor: AssemblyPart = AssemblyOperations.create_part(STATIC).part
	donor.name = "ReferenceDonor"
	assembly.add_child(donor)
	var skeleton := Skeleton3D.new()
	skeleton.name = "ReferenceSkeleton"
	skeleton.add_bone("ArbitraryDonorBone")
	donor.get_node("Model").add_child(skeleton)
	var part: AssemblyPart = AssemblyOperations.create_part(STATIC).part
	part.name = "ReferenceGarment"
	holder.add_child(part)
	var mesh := part.get_node("Model") as MeshInstance3D
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
	var weighted := ArrayMesh.new()
	weighted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.mesh = weighted
	mesh.skin = Skin.new()
	mesh.skin.add_named_bind("ArbitraryDonorBone", Transform3D.IDENTITY)
	mesh.skeleton = mesh.get_path_to(skeleton)
	part.attachment_mode = AssemblyPart.AttachmentMode.SKINNED
	part.target_path = part.get_path_to(skeleton)
	part.binding_data = Resource.new()
	part.binding_data.set_meta("donor_path", part.get_path_to(skeleton))
	var mask := MeshExclusionMask.new()
	mask.source_mesh = weighted
	mask.topology_fingerprint = MeshExclusionOperations.fingerprint(weighted)
	mask.source_node_path = part.get_path_to(mesh)
	part.geometry_masks.append(mask)
	AssemblyOperations.ensure_owned(assembly, assembly)
	var duplicate := AssemblyOperations.duplicate_part(part)
	var copy: AssemblyPart = duplicate.part
	copy.name = "ReferenceCopy"
	assembly.add_child(copy)
	copy.transform = assembly.global_transform.affine_inverse() * duplicate.world_transform
	AssemblyOperations.ensure_owned(copy, assembly)
	AssemblyOperations.rebase_references(duplicate.reference_states)
	var copied_mesh := copy.get_node("Model") as MeshInstance3D
	_check("bound duplicate keeps independent skin and original donor at different hierarchy depth", copy.attachment_mode == AssemblyPart.AttachmentMode.SKINNED and copied_mesh.skin != mesh.skin and copied_mesh.get_node_or_null(copied_mesh.skeleton) == skeleton)
	_check("bound duplicate provenance and metadata target are rebased after insertion", copy.get_node_or_null(copy.target_path) == skeleton and copy.get_node_or_null(copy.binding_data.get_meta("donor_path")) == skeleton)
	_check("duplicate mask references cloned mesh through independent resource", copy.geometry_masks[0] != mask and copy.get_node_or_null(copy.geometry_masks[0].source_node_path) == copied_mesh)
	var references := AssemblyOperations.capture_references(assembly)
	mesh.name = "RenamedModel"
	AssemblyOperations.rebase_references(references)
	_check("explicit native mesh rename rebases retained mask source path", part.get_node_or_null(mask.source_node_path) == mesh and mask.source_node_path == NodePath("RenamedModel"))
	mesh.name = "Model"
	AssemblyOperations.restore_references(references)
	_check("native mesh rename undo restores exact mask source path", mask.source_node_path == NodePath("Model") and part.get_node_or_null(mask.source_node_path) == mesh)
	var old_mesh_path := mesh.skeleton
	var old_donor_path: NodePath = part.binding_data.get_meta("donor_path")
	var moved := AssemblyOperations.attach(part, assembly, AssemblyPart.AttachmentMode.FREE, "", assembly)
	_check("bound mesh detach rebases its external skeleton and provenance", moved.ok and mesh.get_node_or_null(mesh.skeleton) == skeleton and part.get_node_or_null(part.binding_data.get_meta("donor_path")) == skeleton)
	AssemblyOperations.restore_attachment(part, moved.before)
	_check("bound detach undo restores exact skin paths and original mode", mesh.skeleton == old_mesh_path and part.binding_data.get_meta("donor_path") == old_donor_path and part.attachment_mode == AssemblyPart.AttachmentMode.SKINNED)
	AssemblyOperations.restore_attachment(part, moved.after)
	_check("bound detach redo resolves external donor", mesh.get_node_or_null(mesh.skeleton) == skeleton)
	AssemblyOperations.restore_attachment(part, moved.before)
	var moved_donor := AssemblyOperations.attach(donor, destination, AssemblyPart.AttachmentMode.PARENT, "", assembly)
	_check("moving donor rebases all incoming external skin paths", moved_donor.ok and mesh.get_node_or_null(mesh.skeleton) == skeleton and copied_mesh.get_node_or_null(copied_mesh.skeleton) == skeleton)
	_check("moving donor rebases incoming binding and attachment metadata", part.get_node_or_null(part.target_path) == skeleton and copy.get_node_or_null(copy.binding_data.get_meta("donor_path")) == skeleton)
	AssemblyOperations.restore_attachment(donor, moved_donor.before)
	_check("donor reparent undo restores incoming skin references", donor.get_parent() == assembly and mesh.skeleton == old_mesh_path and copied_mesh.get_node_or_null(copied_mesh.skeleton) == skeleton)
	AssemblyOperations.restore_attachment(donor, moved_donor.after)
	_check("donor reparent redo keeps both independent garments linked", donor.get_parent() == destination and mesh.get_node_or_null(mesh.skeleton) == skeleton and copied_mesh.get_node_or_null(copied_mesh.skeleton) == skeleton)


func _skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		# Dependent parts retain their own separate rig identities.
		if child is AssemblyPart:
			continue
		var found := _skeleton(child)
		if found != null:
			return found
	return null


func _shape_count(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D and node.mesh != null:
		count += node.mesh.get_blend_shape_count()
	for child in node.get_children():
		if not child is AssemblyPart:
			count += _shape_count(child)
	return count


func _track(node: Node) -> void:
	if node != null and node not in _detached:
		_detached.append(node)


func _cleanup() -> void:
	for node in _detached:
		if is_instance_valid(node) and node.get_parent() == null:
			node.free()


func _check(label: String, condition: bool) -> bool:
	_checks += 1
	if not condition:
		_failures += 1
	print(("PASS " if condition else "FAIL ") + label)
	return condition


func _finish() -> void:
	print(("CHECKS PASSED: " if _failures == 0 else "CHECKS FAILED: ") + "%d passed, %d failed" % [_checks - _failures, _failures])
	quit(1 if _failures > 0 else 0)
