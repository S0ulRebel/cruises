extends SceneTree
## Explicit authoring checks. Outputs are unique user:// directories, never source
## assets. Run again with -- cold <printed COLD_SCENE_PATH> for a process-cold reopen.
## Also run -- nested <printed COLD_NESTED_SCENE_PATH> for nested source compositions.
## Animation graph regression: -- graphs <printed COLD_GRAPH_SCENE_PATH>.

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
	if args.size() == 2 and args[0] == "graphs":
		await _cold_graphs(args[1])
		_finish()
		return
	var assembly := CWAssembly.new()
	assembly.name = "Assembly"
	assembly.assembly_id = CWAssemblyOperations.generate_id()
	assembly.transform = Transform3D(Basis.from_euler(Vector3(0.1, 0.3, -0.2)).scaled(Vector3(1.2, 0.9, 1.1)), Vector3(3, 1, -2))
	root.add_child(assembly)
	await process_frame
	_check("empty/static assembly opens without creating content", assembly.get_child_count() == 0)
	_check("missing source fails without mutation", not CWAssemblyOperations.create_part("res://not_a_part.glb").ok and assembly.get_child_count() == 0)
	_check("2D roots rejected without mutation", not CWAssemblyOperations.create_part("res://tests/fixtures/assembly_non_3d.tscn").ok and assembly.get_child_count() == 0)
	var made := CWAssemblyOperations.create_part(STATIC)
	if not _check("arbitrary root mesh scene imports", made.ok):
		assembly.free()
		_finish()
		return
	var first: CWPart = made.part
	first.name = "First"
	assembly.add_child(first)
	CWAssemblyOperations.ensure_owned(first, assembly)
	first.transform = Transform3D(Basis.from_euler(Vector3(0.2, -0.4, 0.1)).scaled(Vector3(0.7, 1.3, 1.1)), Vector3(-1, 0.7, 2))
	_check("root MeshInstance3D remains selectable Model", first.get_node("Model") is MeshInstance3D)
	_check("part identity is generated independently of filename", not first.part_id.is_empty() and first.part_id != STATIC.get_file())
	first.binding_data = load(META)
	first.geometry_masks.append(load(META))
	_independent_snapshot_checks(first)
	var duplicate := CWAssemblyOperations.duplicate_part(first)
	_check("duplicate succeeds off-tree", duplicate.ok and duplicate.part.get_parent() == null)
	var second: CWPart = duplicate.part
	second.name = "Second"
	assembly.add_child(second)
	CWAssemblyOperations.ensure_owned(second, assembly)
	_check("two copies retain unique identities", first.part_id != second.part_id and CWAssemblyOperations.collect_parts(assembly).size() == 2)
	_check("nearest_part includes root mesh", CWAssemblyOperations.nearest_part(second.get_node("Model")) == second)
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
	CWAssemblyOperations.ensure_owned(target, assembly)
	var original := first.global_transform
	var attached := CWAssemblyOperations.attach(first, target, CWPart.AttachmentMode.PARENT, "", assembly)
	_check("parent attachment preserves full world matrix under rotated/nonuniform parents", attached.ok and first.global_transform.is_equal_approx(original))
	_check("target metadata identifies actual authored parent", first.get_node(first.target_path) == target)
	CWAssemblyOperations.restore_attachment(first, attached.before)
	_check("attachment undo restores original parent and world placement", first.get_parent() == assembly and first.global_transform.is_equal_approx(original))
	CWAssemblyOperations.restore_attachment(first, attached.after)
	_check("attachment redo restores target and placement", first.get_parent() == target and first.global_transform.is_equal_approx(original))
	second.top_level = true
	var top_world := second.global_transform
	var top_state := CWAssemblyOperations.capture_attachment(second)
	var top_attach := CWAssemblyOperations.attach(second, target, CWPart.AttachmentMode.PARENT, "", assembly)
	_check("top-level part attaches without a position jump", top_attach.ok and not second.top_level and second.global_transform.is_equal_approx(top_world))
	CWAssemblyOperations.restore_attachment(second, top_state)
	_check("undo restores top-level flag and placement", second.top_level and second.global_transform.is_equal_approx(top_world))
	second.top_level = false
	var invalid_state := CWAssemblyOperations.capture_attachment(first)
	_check("cycle is rejected before scene mutation", not CWAssemblyOperations.attach(first, first_mesh, CWPart.AttachmentMode.PARENT, "", assembly).ok and first.get_parent() == target and first.transform == invalid_state.transform)
	_check("skinning is never implicit", not CWAssemblyOperations.attach(first, target, CWPart.AttachmentMode.SKINNED, "", assembly).ok)
	var bad := Node3D.new()
	bad.scale = Vector3.ZERO
	assembly.add_child(bad)
	_check("singular target is rejected without mutation", not CWAssemblyOperations.attach(first, bad, CWPart.AttachmentMode.PARENT, "", assembly).ok and first.get_parent() == target)
	bad.free()
	_check("zero/nonfinite transforms rejected", not CWAssemblyOperations.validate_transform(Transform3D(Basis().scaled(Vector3(0, 1, 1)), Vector3.ZERO)).is_empty() and not CWAssemblyOperations.validate_transform(Transform3D(Basis(), Vector3(INF, 0, 0))).is_empty())
	_check("intentional nonzero mirrored transforms accepted", CWAssemblyOperations.validate_transform(Transform3D(Basis().scaled(Vector3(-1, 1, 1)), Vector3.ZERO)).is_empty())
	var skeleton := Skeleton3D.new()
	skeleton.name = "DonorSkeleton"
	skeleton.add_bone("DifferentHeadName")
	skeleton.set_bone_rest(0, Transform3D(Basis.from_euler(Vector3(0.1, 0.3, 0.2)), Vector3(0, 1.6, 0)))
	target.add_child(skeleton)
	CWAssemblyOperations.ensure_owned(skeleton, assembly)
	await process_frame
	_check("unknown bone rejected transactionally", not CWAssemblyOperations.attach(first, skeleton, CWPart.AttachmentMode.BONE, "Missing", assembly).ok and first.get_parent() == target)
	var bone_attach := CWAssemblyOperations.attach(first, skeleton, CWPart.AttachmentMode.BONE, "DifferentHeadName", assembly)
	_check("arbitrary named bone attachment preserves world placement", bone_attach.ok and first.global_transform.is_equal_approx(original))
	var carrier: BoneAttachment3D = bone_attach.carrier
	_check("bone target has owned explicit carrier", first.get_parent() == carrier and carrier.owner == assembly and first.get_node(first.target_path) == skeleton)
	skeleton.set_bone_pose_position(0, Vector3(0.3, 0.4, 0.5))
	skeleton.force_update_all_bone_transforms()
	await process_frame
	_check("bone-attached part actually follows animated pose", not first.global_transform.is_equal_approx(original))
	var animated_world := first.global_transform
	var detached := CWAssemblyOperations.attach(first, assembly, CWPart.AttachmentMode.FREE, "", assembly)
	_check("detach preserves animated world placement", detached.ok and first.global_transform.is_equal_approx(animated_world))
	_check("empty carrier is detached, not destroyed", is_instance_valid(carrier) and carrier.get_parent() == null)
	_track(carrier)
	CWAssemblyOperations.restore_attachment(first, detached.before)
	_check("bone attachment undo reinstates carrier and metadata", first.get_parent() == carrier and carrier.get_parent() == skeleton and first.bone_name == "DifferentHeadName")
	CWAssemblyOperations.restore_attachment(first, detached.after)
	_check("bone detach redo remains editable", first.get_parent() == assembly and first.attachment_mode == CWPart.AttachmentMode.FREE)
	_bound_reference_checks(assembly)
	var head_result := CWAssemblyOperations.create_part(HEAD)
	if _check("speaking head imports through unrestricted path", head_result.ok):
		var head: CWPart = head_result.part
		head.name = "SpeakingHead"
		assembly.add_child(head)
		CWAssemblyOperations.ensure_owned(head, assembly)
		var head_rig := _skeleton(head)
		var shapes := _shape_count(head)
		_check("speaking head local bones/blend shapes preserved", head_rig != null and head_rig.get_bone_count() == 2 and shapes == 3)
		var head_attach := CWAssemblyOperations.attach(head, skeleton, CWPart.AttachmentMode.BONE, "DifferentHeadName", assembly)
		_check("bone attaching speaking head does not convert its local rig", head_attach.ok and _skeleton(head) == head_rig and _shape_count(head) == shapes)
		var jaw_name := head_rig.get_bone_name(head_rig.find_bone("Jaw")) if head_rig.find_bone("Jaw") >= 0 else head_rig.get_bone_name(1)
		var second_world := second.global_transform
		var jaw_attach := CWAssemblyOperations.attach(second, head_rig, CWPart.AttachmentMode.BONE, jaw_name, assembly)
		_check("another part can target the head's own Jaw", jaw_attach.ok and second.get_node(second.target_path) == head_rig and second.global_transform.is_equal_approx(second_world))
		if jaw_attach.ok:
			var copied_head := CWAssemblyOperations.duplicate_part(head)
			_check("duplicate does not recursively copy dependent accessories", copied_head.ok and CWAssemblyOperations.collect_parts(copied_head.part).size() == 1 and _shape_count(copied_head.part) == shapes)
			if copied_head.ok:
				var local_skin_valid := true
				for reference: Dictionary in copied_head.reference_states:
					if reference.key == &"skeleton":
						local_skin_valid = local_skin_valid and reference.base.get_node_or_null(reference.value) == _skeleton(copied_head.part) and reference.target == _skeleton(copied_head.part)
				_check("duplicate local-rig meshes reference the copied skeleton", local_skin_valid)
				copied_head.part.free()
	var output_dir := "user://assembly_check_" + str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + CWAssemblyOperations.generate_id().substr(0, 8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var output := output_dir + "/saved_assembly.tscn"
	var source_hash := FileAccess.get_sha256(ProjectSettings.globalize_path(HEAD))
	var owner_before := first.owner
	_check("invalid destination fails without changing ownership", not CWAssemblyOperations.save_scene(assembly, "").ok and first.owner == owner_before)
	_check("source scene overwrite is rejected", not CWAssemblyOperations.save_scene(assembly, STATIC).ok)
	var saved := CWAssemblyOperations.save_scene(assembly, output)
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
	var graph_output := await _animation_graph_checks(output_dir)
	if not graph_output.is_empty():
		print("COLD_GRAPH_SCENE_PATH=" + graph_output)
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
	var source := CWAssembly.new()
	source.name = "TwoPartSource"
	source.assembly_id = CWAssemblyOperations.generate_id()
	root.add_child(source)
	var body: CWPart = CWAssemblyOperations.create_part(STATIC).part
	body.name = "SourceBody"
	source.add_child(body)
	body.transform = Transform3D(Basis.from_euler(Vector3(0.2, -0.1, 0.3)).scaled(Vector3(1.2, 0.9, 0.8)), Vector3(0.1, 0.3, -0.2))
	var rig := Skeleton3D.new()
	rig.name = "SourceSkeleton"
	rig.add_bone("SourceSocket")
	rig.set_bone_rest(0, Transform3D(Basis.from_euler(Vector3(0.1, 0.2, 0)), Vector3(0, 1.7, 0)))
	body.get_node("Model").add_child(rig)
	var accessory: CWPart = CWAssemblyOperations.create_part(STATIC).part
	accessory.name = "SourceAccessory"
	source.add_child(accessory)
	accessory.position = Vector3(0.2, 2.1, 0.3)
	accessory.binding_data = Resource.new()
	accessory.binding_data.set_meta("donor_path", accessory.get_path_to(rig))
	var mask := CWMeshMask.new()
	mask.source_node_path = NodePath("Model")
	accessory.geometry_masks.append(mask)
	CWAssemblyOperations.ensure_owned(source, source)
	await process_frame
	var attached := CWAssemblyOperations.attach(accessory, rig, CWPart.AttachmentMode.BONE, "SourceSocket", source)
	_check("nested source prefab has authored bone attachment", attached.ok and accessory.get_node_or_null(accessory.target_path) == rig)
	var saved_source := output_dir + "/two_part_source.tscn"
	var authored_ids := [body.part_id, accessory.part_id]
	var saved := CWAssemblyOperations.save_scene(source, saved_source)
	if not _check("nested two-part source saves explicitly", saved.ok):
		source.free()
		return ""
	source.free()
	var source_hash := FileAccess.get_sha256(ProjectSettings.globalize_path(saved_source))
	var adopted := CWPart.new()
	adopted.part_id = CWAssemblyOperations.generate_id()
	var adopted_model := (ResourceLoader.load(saved_source, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
	adopted_model.name = "Model"
	adopted.add_child(adopted_model)
	var adoption_before := CWAssemblyOperations.capture_source_composition(adopted)
	CWAssemblyOperations.initialize_source_composition(adopted)
	var adoption_after := CWAssemblyOperations.capture_source_composition(adopted)
	_check("explicit native adoption regenerates nested source identities", _ids_exclude(adopted, authored_ids) and _unique_ids(adopted))
	CWAssemblyOperations.restore_source_composition(adoption_before)
	_check("native adoption undo restores exact nested IDs and metadata presence", _source_snapshot_matches(adoption_before) and _named_part(adopted, "SourceBody").part_id == authored_ids[0] and _named_part(adopted, "SourceAccessory").part_id == authored_ids[1])
	CWAssemblyOperations.restore_source_composition(adoption_after)
	_check("native adoption redo restores the same new identities and source groups", _source_snapshot_matches(adoption_after) and _ids_exclude(adopted, authored_ids))
	adopted.free()
	var first_result := CWAssemblyOperations.create_part(saved_source)
	var second_result := CWAssemblyOperations.create_part(saved_source)
	if not _check("saved composition can be imported twice", first_result.ok and second_result.ok):
		if first_result.ok: first_result.part.free()
		if second_result.ok: second_result.part.free()
		return ""
	var assembly := CWAssembly.new()
	assembly.name = "NestedAssembly"
	assembly.assembly_id = CWAssemblyOperations.generate_id()
	root.add_child(assembly)
	var first: CWPart = first_result.part
	first.name = "FirstComposition"
	assembly.add_child(first)
	var second: CWPart = second_result.part
	second.name = "SecondComposition"
	assembly.add_child(second)
	second.position.x = 3
	_check("both imports retain two source parts and their carrier", CWAssemblyOperations.collect_parts(first).size() == 3 and CWAssemblyOperations.collect_parts(second).size() == 3 and _nested_references_valid(first) and _nested_references_valid(second))
	_check("imported nested IDs are new and disjoint", _unique_ids(assembly) and _ids_exclude(assembly, authored_ids))
	_check("separate imported compositions have independent mutable resources", first.get_node("Model/SourceBody/Model").mesh != second.get_node("Model/SourceBody/Model").mesh and _named_part(first, "SourceAccessory").binding_data != _named_part(second, "SourceAccessory").binding_data)
	var first_rig := first.get_node("Model/SourceBody/Model/SourceSkeleton") as Skeleton3D
	var external: CWPart = CWAssemblyOperations.create_part(STATIC).part
	external.name = "ExternalAccessory"
	assembly.add_child(external)
	CWAssemblyOperations.ensure_owned(assembly, assembly)
	var external_attachment := CWAssemblyOperations.attach(external, first_rig, CWPart.AttachmentMode.BONE, "SourceSocket", assembly)
	_check("external dependent added after import remains separate", external_attachment.ok and CWAssemblyOperations.collect_parts(first).size() == 4)
	var source_ids: Array = []
	for part in CWAssemblyOperations.collect_parts(assembly):
		source_ids.append(part.part_id)
	var nested_copy := CWAssemblyOperations.duplicate_part(_named_part(first, "SourceBody"))
	if _check("duplicating an inner source part retains composed accessory and excludes external one", nested_copy.ok and CWAssemblyOperations.collect_parts(nested_copy.part).size() == 2 and _nested_references_valid(nested_copy.part) and _ids_exclude(nested_copy.part, source_ids)):
		nested_copy.part.free()
	elif nested_copy.ok:
		nested_copy.part.free()
	var duplicated := CWAssemblyOperations.duplicate_part(first)
	if not _check("composition duplicate retains authored parts but excludes external accessory", duplicated.ok and CWAssemblyOperations.collect_parts(duplicated.part).size() == 3 and _named_part(duplicated.part, "ExternalAccessory") == null):
		if duplicated.ok: duplicated.part.free()
		assembly.free()
		return ""
	var copy: CWPart = duplicated.part
	copy.name = "CopiedComposition"
	assembly.add_child(copy)
	copy.global_transform = duplicated.world_transform
	copy.position.x += 6
	CWAssemblyOperations.ensure_owned(copy, assembly)
	CWAssemblyOperations.rebase_references(duplicated.reference_states)
	_check("composition duplicate regenerates every nested part ID", _unique_ids(assembly) and _ids_exclude(copy, source_ids))
	_check("copied source attachment and binding paths resolve inside its own rig", _nested_references_valid(copy))
	var copied_body := _named_part(copy, "SourceBody")
	var original_body := _named_part(first, "SourceBody")
	var copied_model := copied_body.get_node("Model") as MeshInstance3D
	var original_model := original_body.get_node("Model") as MeshInstance3D
	_check("nested duplicate mutable meshes and binding masks remain independent", copied_model.mesh != original_model.mesh and _named_part(copy, "SourceAccessory").geometry_masks[0] != _named_part(first, "SourceAccessory").geometry_masks[0])
	var output := output_dir + "/nested_assembly.tscn"
	var saved_nested := CWAssemblyOperations.save_scene(assembly, output)
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
	_check("cold nested scene retains all three compositions and one external accessory", CWAssemblyOperations.collect_parts(instance).size() == 10 and _unique_ids(instance))
	for node_name in ["FirstComposition", "SecondComposition", "CopiedComposition"]:
		var part := instance.get_node(node_name) as CWPart
		_check("cold %s retains its local authored attachment paths" % node_name, _nested_references_valid(part))
		var copied := CWAssemblyOperations.duplicate_part(part)
		if _check("cold %s duplicate preserves source boundary" % node_name, copied.ok and CWAssemblyOperations.collect_parts(copied.part).size() == 3 and _named_part(copied.part, "ExternalAccessory") == null):
			copied.part.free()
		elif copied.ok:
			copied.part.free()
	instance.free()


func _nested_references_valid(part: CWPart) -> bool:
	var body := _named_part(part, "SourceBody")
	var accessory := _named_part(part, "SourceAccessory")
	if body == null or accessory == null:
		return false
	var rig := body.get_node_or_null("Model/SourceSkeleton") as Skeleton3D
	return rig != null and accessory.get_parent() is BoneAttachment3D and accessory.get_node_or_null(accessory.target_path) == rig and accessory.get_node_or_null(accessory.binding_data.get_meta("donor_path")) == rig and accessory.get_node_or_null(accessory.geometry_masks[0].source_node_path) == accessory.get_node("Model")


func _named_part(root_node: Node, node_name: String) -> CWPart:
	for part in CWAssemblyOperations.collect_parts(root_node):
		if part.name == node_name:
			return part
	return null


func _unique_ids(root_node: Node) -> bool:
	var seen := {}
	for part in CWAssemblyOperations.collect_parts(root_node):
		if part.part_id.is_empty() or seen.has(part.part_id):
			return false
		seen[part.part_id] = true
	return true


func _ids_exclude(root_node: Node, excluded: Array) -> bool:
	for part in CWAssemblyOperations.collect_parts(root_node):
		if part.part_id in excluded:
			return false
	return true


func _source_snapshot_matches(states: Array) -> bool:
	for state: Dictionary in states:
		var node: Node = state.node
		if not is_instance_valid(node) or node.has_meta(CWAssemblyOperations.SOURCE_GROUP_META) != state.had_source_group:
			return false
		if state.had_source_group and node.get_meta(CWAssemblyOperations.SOURCE_GROUP_META) != state.source_group:
			return false
		if state.has("part_id") and (node as CWPart).part_id != state.part_id:
			return false
	return true


func _independent_snapshot_checks(source: CWPart) -> void:
	var owner_before := source.owner
	var snapshot := CWAssemblyOperations.independent_snapshot(source) as CWPart
	if not _check("independent snapshot is off-tree and preserves authored identity", snapshot != null and snapshot.get_parent() == null and snapshot.part_id == source.part_id):
		return
	var source_model := source.get_node("Model") as MeshInstance3D
	var snapshot_model := snapshot.get_node("Model") as MeshInstance3D
	var source_mesh := source_model.mesh as BoxMesh
	var snapshot_mesh := snapshot_model.mesh as BoxMesh
	var source_material := source_mesh.material as StandardMaterial3D
	var original_surface_color := source_material.albedo_color
	var original_size := source_mesh.size
	var original_offset: Vector3 = source.binding_data.offset
	var original_color: Color = source.binding_data.material.albedo_color
	_check("snapshot owns its full hierarchy without changing live owners", snapshot_model.owner == snapshot and snapshot_model.get_node("AnimationPlayer").owner == snapshot and source.owner == owner_before)
	_check("snapshot mutable resources are independent with internal aliases preserved", snapshot_mesh != source_mesh and snapshot_mesh.material != source_material and snapshot.binding_data != source.binding_data and snapshot.binding_data == snapshot.geometry_masks[0] and snapshot.binding_data.related[0] == snapshot.binding_data.material and snapshot.binding_data.material != source.binding_data.material)
	source_mesh.size = original_size * 2.0
	source_material.albedo_color = Color.RED
	source.binding_data.offset = Vector3(7, 4, 2)
	source.binding_data.material.albedo_color = Color.RED
	_check("editing the retained original cannot change source snapshot", snapshot_mesh.size == original_size and snapshot_mesh.material.albedo_color == original_surface_color and snapshot.binding_data.offset == original_offset and snapshot.binding_data.material.albedo_color == original_color)
	source_mesh.size = original_size
	source_material.albedo_color = original_surface_color
	source.binding_data.offset = original_offset
	source.binding_data.material.albedo_color = original_color
	var packed := PackedScene.new()
	if not _check("independent snapshot packs its complete owned descendants", packed.pack(snapshot) == OK):
		snapshot.free()
		return
	var first_instance := packed.instantiate() as CWPart
	var second_instance := packed.instantiate() as CWPart
	var first_mesh := first_instance.get_node("Model").mesh as BoxMesh
	first_mesh.size = original_size * 3.0
	first_mesh.material.albedo_color = Color.BLUE
	first_instance.binding_data.material.albedo_color = Color.BLUE
	_check("editing packed snapshot instance cannot affect original snapshot or another instance", snapshot_mesh.size == original_size and source_mesh.size == original_size and (second_instance.get_node("Model").mesh as BoxMesh).size == original_size and snapshot_mesh.material.albedo_color == original_surface_color and source_material.albedo_color == original_surface_color and second_instance.get_node("Model").mesh.material.albedo_color == original_surface_color and snapshot.binding_data.material.albedo_color == original_color and source.binding_data.material.albedo_color == original_color and second_instance.binding_data.material.albedo_color == original_color)
	_check("packed snapshot instances retain their own resource aliases", first_instance.binding_data == first_instance.geometry_masks[0] and second_instance.binding_data == second_instance.geometry_masks[0] and first_instance.binding_data.related[0] == first_instance.binding_data.material and first_instance.binding_data != second_instance.binding_data)
	snapshot.binding_data.offset = Vector3(9, 8, 7)
	_check("editing snapshot metadata leaves source and packed instances independent", source.binding_data.offset == original_offset and first_instance.binding_data.offset == original_offset and second_instance.binding_data.offset == original_offset)
	first_instance.free()
	second_instance.free()
	snapshot.free()


func _animation_graph_checks(output_dir: String) -> String:
	var assembly := CWAssembly.new()
	assembly.name = "GraphAssembly"
	assembly.assembly_id = CWAssemblyOperations.generate_id()
	root.add_child(assembly)
	var part: CWPart = CWAssemblyOperations.create_part(STATIC).part
	part.name = "OriginalGraphPart"
	assembly.add_child(part)
	var model := part.get_node("Model") as Node3D
	var idle := AnimationNodeAnimation.new()
	idle.animation = &"gentle"
	var nested := AnimationNodeBlendTree.new()
	nested.add_node("SharedIdle", idle, Vector2(40, 100))
	nested.connect_node("output", 0, "SharedIdle")
	var graph := AnimationNodeBlendTree.new()
	graph.resource_name = "Editable body graph"
	graph.graph_offset = Vector2(18, -24)
	graph.add_node("Idle", idle, Vector2(50, 140))
	graph.add_node("Nested", nested, Vector2(100, 240))
	var mixer := AnimationNodeBlend2.new()
	mixer.sync = true
	graph.add_node("Mixer", mixer, Vector2(250, 150))
	graph.set_node_position("output", Vector2(430, 180))
	graph.connect_node("Mixer", 0, "Idle")
	graph.connect_node("Mixer", 1, "Nested")
	graph.connect_node("output", 0, "Mixer")
	var machine := AnimationNodeStateMachine.new()
	machine.resource_name = "Editable facial state machine"
	machine.allow_transition_to_self = true
	machine.add_node("Idle", nested, Vector2(300, 100))
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = -2.0
	space.max_space = 3.0
	space.add_blend_point(idle, -2.0, -1, "IdlePoint")
	var alternate := AnimationNodeAnimation.new()
	alternate.animation = &"gentle"
	space.add_blend_point(alternate, 3.0, -1, "AlternatePoint")
	machine.add_node("Run", space, Vector2(500, 150))
	var start := AnimationNodeStateMachineTransition.new()
	start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	machine.add_transition("Start", "Idle", start)
	var transition := AnimationNodeStateMachineTransition.new()
	transition.xfade_time = 0.125
	transition.xfade_curve = Curve.new()
	transition.xfade_curve.add_point(Vector2.ZERO)
	transition.xfade_curve.add_point(Vector2.ONE)
	machine.add_transition("Idle", "Run", transition)
	machine.add_transition("Run", "Idle", transition)
	graph.set_meta("graph_aliases", {"idle": idle, "nested": nested, "transition": transition})
	var body_tree := _add_graph_tree(model, "BodyTree", graph, true)
	body_tree.set("parameters/Mixer/blend_amount", 0.37)
	_add_graph_tree(model, "BodyTreeAlias", graph, false)
	_add_graph_tree(model, "LocalFaceTree", machine, true)
	CWAssemblyOperations.ensure_owned(assembly, assembly)
	await process_frame
	_check("authored active animation graphs are structurally valid", _graph_structure_valid(part))
	var duplicate := CWAssemblyOperations.duplicate_part(part)
	if not _check("nested blend-tree/state-machine part duplicates cleanly", duplicate.ok):
		assembly.free()
		return ""
	var copy: CWPart = duplicate.part
	copy.name = "CopiedGraphPart"
	assembly.add_child(copy)
	CWAssemblyOperations.ensure_owned(copy, assembly)
	var copied_graph := copy.get_node("Model/BodyTree").tree_root as AnimationNodeBlendTree
	var copied_machine := copy.get_node("Model/LocalFaceTree").tree_root as AnimationNodeStateMachine
	_check("duplicate keeps graph structure positions node properties and resource aliases", _graph_structure_valid(copy))
	_check("duplicate graphs nested nodes transitions and curves are independent", copied_graph != graph and copied_graph.get_node("Idle") != idle and copied_graph.get_node("Nested") != nested and copied_machine != machine and copied_machine.get_transition(1) != transition and copied_machine.get_transition(1).xfade_curve != transition.xfade_curve)
	(copied_graph.get_node("Idle") as AnimationNodeAnimation).play_mode = AnimationNodeAnimation.PLAY_MODE_BACKWARD
	copied_graph.set_node_position("Idle", Vector2(80, 180))
	copied_machine.get_transition(1).xfade_time = 0.25
	copied_machine.get_transition(1).xfade_curve.set_point_value(1, 0.8)
	copy.get_node("Model/BodyTree").set("parameters/Mixer/blend_amount", 0.63)
	_check("editing duplicate graph leaves all source graph data unchanged", idle.play_mode == AnimationNodeAnimation.PLAY_MODE_FORWARD and graph.get_node_position("Idle") == Vector2(50, 140) and transition.xfade_time == 0.125 and transition.xfade_curve.get_point_position(1) == Vector2.ONE and is_equal_approx(float(body_tree.get("parameters/Mixer/blend_amount")), 0.37))
	var output := output_dir + "/animation_graph_assembly.tscn"
	var saved := CWAssemblyOperations.save_scene(assembly, output)
	_check("explicit save preserves active graphs without additive setter errors", saved.ok)
	_check("save leaves source graph references and activity untouched", body_tree.tree_root == graph and body_tree.active and graph.get_node("Idle") == idle and graph.get_meta("graph_aliases").transition == transition)
	assembly.free()
	if not saved.ok:
		return ""
	var imported := CWAssemblyOperations.create_part(output)
	if _check("saved nested animation graphs can be imported again", imported.ok):
		root.add_child(imported.part)
		await process_frame
		_check("imported animation graphs retain connections and aliases", _graph_structure_valid(_named_part(imported.part, "OriginalGraphPart")) and _graph_structure_valid(_named_part(imported.part, "CopiedGraphPart")))
		imported.part.free()
	await _cold_graphs(output)
	return output


func _add_graph_tree(model: Node3D, node_name: String, graph: AnimationRootNode, active: bool) -> AnimationTree:
	var tree := AnimationTree.new()
	tree.name = node_name
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(model.get_node("AnimationPlayer"))
	tree.tree_root = graph
	tree.active = active
	return tree


func _graph_structure_valid(part: CWPart) -> bool:
	if part == null:
		return false
	var graph := part.get_node("Model/BodyTree").tree_root as AnimationNodeBlendTree
	var machine := part.get_node("Model/LocalFaceTree").tree_root as AnimationNodeStateMachine
	if graph == null or machine == null or not graph.has_node("Idle") or not graph.has_node("Nested") or not graph.has_node("Mixer"):
		return false
	var nested := graph.get_node("Nested") as AnimationNodeBlendTree
	var space := machine.get_node("Run") as AnimationNodeBlendSpace1D
	var aliases: Dictionary = graph.get_meta("graph_aliases", {})
	return graph.resource_name == "Editable body graph" and graph.graph_offset == Vector2(18, -24) and graph.get_node_position("output") == Vector2(430, 180) and graph.get_node_position("Mixer") == Vector2(250, 150) and graph.get_node("Mixer").sync and _graph_connected(graph, "Mixer", 0, "Idle") and _graph_connected(graph, "Mixer", 1, "Nested") and _graph_connected(graph, "output", 0, "Mixer") and _graph_connected(nested, "output", 0, "SharedIdle") and nested.get_node("SharedIdle") == graph.get_node("Idle") and machine.get_node("Idle") == nested and space.get_blend_point_count() == 2 and space.get_blend_point_node(0) == graph.get_node("Idle") and space.min_space == -2.0 and space.max_space == 3.0 and machine.get_transition_count() == 3 and machine.get_transition(1) == machine.get_transition(2) and machine.allow_transition_to_self and part.get_node("Model/BodyTreeAlias").tree_root == graph and aliases.get("idle") == graph.get_node("Idle") and aliases.get("nested") == nested and aliases.get("transition") == machine.get_transition(1)


func _graph_connected(graph: AnimationNodeBlendTree, node_name: StringName, input: int, source_node: StringName) -> bool:
	var connections: Array = graph.get("node_connections")
	for index in range(0, connections.size(), 3):
		if connections[index] == node_name and connections[index + 1] == input and connections[index + 2] == source_node:
			return true
	return false


func _cold_graphs(path: String) -> void:
	var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if not _check("saved animation graph scene opens", packed != null):
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	var original := instance.get_node("OriginalGraphPart") as CWPart
	var copy := instance.get_node("CopiedGraphPart") as CWPart
	_check("cold animation graphs retain nested structures and aliases", _graph_structure_valid(original) and _graph_structure_valid(copy))
	var graph := original.get_node("Model/BodyTree").tree_root as AnimationNodeBlendTree
	var copied_graph := copy.get_node("Model/BodyTree").tree_root as AnimationNodeBlendTree
	var machine := original.get_node("Model/LocalFaceTree").tree_root as AnimationNodeStateMachine
	var copied_machine := copy.get_node("Model/LocalFaceTree").tree_root as AnimationNodeStateMachine
	_check("cold graphs keep edited copy data and independent resources", graph != copied_graph and graph.get_node("Idle") != copied_graph.get_node("Idle") and graph.get_node_position("Idle") == Vector2(50, 140) and copied_graph.get_node_position("Idle") == Vector2(80, 180) and (copied_graph.get_node("Idle") as AnimationNodeAnimation).play_mode == AnimationNodeAnimation.PLAY_MODE_BACKWARD and machine.get_transition(1).xfade_time == 0.125 and copied_machine.get_transition(1).xfade_time == 0.25 and copied_machine.get_transition(1).xfade_curve.get_point_position(1) == Vector2(1, 0.8))
	_check("cold active trees resolve local players and retain per-tree parameters", original.get_node("Model/BodyTree").active and copy.get_node("Model/LocalFaceTree").active and original.get_node("Model/BodyTree").get_node_or_null(original.get_node("Model/BodyTree").anim_player) == original.get_node("Model/AnimationPlayer") and is_equal_approx(float(original.get_node("Model/BodyTree").get("parameters/Mixer/blend_amount")), 0.37) and is_equal_approx(float(copy.get_node("Model/BodyTree").get("parameters/Mixer/blend_amount")), 0.63))
	var duplicate := CWAssemblyOperations.duplicate_part(copy)
	if _check("cold graph duplicate retains complete aliases with independent roots", duplicate.ok and _graph_structure_valid(duplicate.part) and duplicate.part.get_node("Model/BodyTree").tree_root != copied_graph):
		duplicate.part.free()
	elif duplicate.ok:
		duplicate.part.free()
	instance.free()


func _validate_loaded(instance: Node) -> void:
	var parts := CWAssemblyOperations.collect_parts(instance)
	_check("saved parts and arbitrary names retained", parts.size() == 6)
	var first: CWPart
	var second: CWPart
	var head: CWPart
	for part in parts:
		if part.name == "First": first = part
		if part.name == "Second": second = part
		if part.name == "SpeakingHead": head = part
	if not _check("all authored part identities survive reopening", first != null and second != null and head != null and first.part_id != second.part_id):
		return
	_check("saved speaking head preserves local bones and facial shapes", _skeleton(head) != null and _skeleton(head).get_bone_count() == 2 and _shape_count(head) == 3)
	_check("saved attachment to local Jaw resolves", second.attachment_mode == CWPart.AttachmentMode.BONE and second.get_node_or_null(second.target_path) == _skeleton(head))
	_check("binding provenance and nested masks survive", second.binding_data.offset == Vector3(7, 8, 9) and second.geometry_masks.size() == 1)
	_check("working resources remain independent after reopening", first.binding_data != second.binding_data and first.binding_data.material != second.binding_data.material)
	var model := second.get_node("Model") as MeshInstance3D
	var old := model.transform
	model.position += Vector3(0.5, 0.2, -0.1)
	model.rotation += Vector3(0.1, 0.2, 0.3)
	model.scale *= Vector3(1.1, 0.8, 1.2)
	_check("reopened root mesh remains transform editable", model.transform != old)
	var donor := instance.get_node("ReferenceDestination/ReferenceDonor") as CWPart
	var bound := instance.get_node("ReferenceHolder/ReferenceGarment") as CWPart
	var copied := instance.get_node("ReferenceCopy") as CWPart
	if _check("reopened external-bound parts are present", donor != null and bound != null and copied != null):
		var donor_rig := donor.get_node("Model/ReferenceSkeleton") as Skeleton3D
		_check("cold bound source and duplicate skeleton paths resolve", bound.get_node("Model").get_node_or_null(bound.get_node("Model").skeleton) == donor_rig and copied.get_node("Model").get_node_or_null(copied.get_node("Model").skeleton) == donor_rig)
		_check("cold donor attachment and provenance references resolve", bound.get_node_or_null(bound.target_path) == donor_rig and copied.get_node_or_null(copied.binding_data.get_meta("donor_path")) == donor_rig)


func _bound_reference_checks(assembly: CWAssembly) -> void:
	var holder := Node3D.new()
	holder.name = "ReferenceHolder"
	assembly.add_child(holder)
	holder.transform = Transform3D(Basis.from_euler(Vector3(0.1, 0.2, 0.4)), Vector3(0.4, 0.2, -0.3))
	var destination := Node3D.new()
	destination.name = "ReferenceDestination"
	assembly.add_child(destination)
	destination.position = Vector3(2, 0.5, -3)
	var donor: CWPart = CWAssemblyOperations.create_part(STATIC).part
	donor.name = "ReferenceDonor"
	assembly.add_child(donor)
	var skeleton := Skeleton3D.new()
	skeleton.name = "ReferenceSkeleton"
	skeleton.add_bone("ArbitraryDonorBone")
	donor.get_node("Model").add_child(skeleton)
	var part: CWPart = CWAssemblyOperations.create_part(STATIC).part
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
	part.attachment_mode = CWPart.AttachmentMode.SKINNED
	part.target_path = part.get_path_to(skeleton)
	part.binding_data = Resource.new()
	part.binding_data.set_meta("donor_path", part.get_path_to(skeleton))
	var mask := CWMeshMask.new()
	mask.source_mesh = weighted
	mask.topology_fingerprint = CWMeshOperations.fingerprint(weighted)
	mask.source_node_path = part.get_path_to(mesh)
	part.geometry_masks.append(mask)
	CWAssemblyOperations.ensure_owned(assembly, assembly)
	var duplicate := CWAssemblyOperations.duplicate_part(part)
	var copy: CWPart = duplicate.part
	copy.name = "ReferenceCopy"
	assembly.add_child(copy)
	copy.transform = assembly.global_transform.affine_inverse() * duplicate.world_transform
	CWAssemblyOperations.ensure_owned(copy, assembly)
	CWAssemblyOperations.rebase_references(duplicate.reference_states)
	var copied_mesh := copy.get_node("Model") as MeshInstance3D
	_check("bound duplicate keeps independent skin and original donor at different hierarchy depth", copy.attachment_mode == CWPart.AttachmentMode.SKINNED and copied_mesh.skin != mesh.skin and copied_mesh.get_node_or_null(copied_mesh.skeleton) == skeleton)
	_check("bound duplicate provenance and metadata target are rebased after insertion", copy.get_node_or_null(copy.target_path) == skeleton and copy.get_node_or_null(copy.binding_data.get_meta("donor_path")) == skeleton)
	_check("duplicate mask references cloned mesh through independent resource", copy.geometry_masks[0] != mask and copy.get_node_or_null(copy.geometry_masks[0].source_node_path) == copied_mesh)
	var references := CWAssemblyOperations.capture_references(assembly)
	mesh.name = "RenamedModel"
	CWAssemblyOperations.rebase_references(references)
	_check("explicit native mesh rename rebases retained mask source path", part.get_node_or_null(mask.source_node_path) == mesh and mask.source_node_path == NodePath("RenamedModel"))
	mesh.name = "Model"
	CWAssemblyOperations.restore_references(references)
	_check("native mesh rename undo restores exact mask source path", mask.source_node_path == NodePath("Model") and part.get_node_or_null(mask.source_node_path) == mesh)
	var old_mesh_path := mesh.skeleton
	var old_donor_path: NodePath = part.binding_data.get_meta("donor_path")
	var moved := CWAssemblyOperations.attach(part, assembly, CWPart.AttachmentMode.FREE, "", assembly)
	_check("bound mesh detach rebases its external skeleton and provenance", moved.ok and mesh.get_node_or_null(mesh.skeleton) == skeleton and part.get_node_or_null(part.binding_data.get_meta("donor_path")) == skeleton)
	CWAssemblyOperations.restore_attachment(part, moved.before)
	_check("bound detach undo restores exact skin paths and original mode", mesh.skeleton == old_mesh_path and part.binding_data.get_meta("donor_path") == old_donor_path and part.attachment_mode == CWPart.AttachmentMode.SKINNED)
	CWAssemblyOperations.restore_attachment(part, moved.after)
	_check("bound detach redo resolves external donor", mesh.get_node_or_null(mesh.skeleton) == skeleton)
	CWAssemblyOperations.restore_attachment(part, moved.before)
	var moved_donor := CWAssemblyOperations.attach(donor, destination, CWPart.AttachmentMode.PARENT, "", assembly)
	_check("moving donor rebases all incoming external skin paths", moved_donor.ok and mesh.get_node_or_null(mesh.skeleton) == skeleton and copied_mesh.get_node_or_null(copied_mesh.skeleton) == skeleton)
	_check("moving donor rebases incoming binding and attachment metadata", part.get_node_or_null(part.target_path) == skeleton and copy.get_node_or_null(copy.binding_data.get_meta("donor_path")) == skeleton)
	CWAssemblyOperations.restore_attachment(donor, moved_donor.before)
	_check("donor reparent undo restores incoming skin references", donor.get_parent() == assembly and mesh.skeleton == old_mesh_path and copied_mesh.get_node_or_null(copied_mesh.skeleton) == skeleton)
	CWAssemblyOperations.restore_attachment(donor, moved_donor.after)
	_check("donor reparent redo keeps both independent garments linked", donor.get_parent() == destination and mesh.get_node_or_null(mesh.skeleton) == skeleton and copied_mesh.get_node_or_null(copied_mesh.skeleton) == skeleton)


func _skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		# Dependent parts retain their own separate rig identities.
		if child is CWPart:
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
		if not child is CWPart:
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
