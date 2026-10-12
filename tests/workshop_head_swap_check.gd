extends SceneTree
## Actual authored head swap. Checks load/save only; they never regenerate the
## template or modify source assets. Explicit saves use unique user:// outputs.

const TEMPLATE := "res://actors/assembly/templates/head_swap_demo.tscn"
const BODY_SOURCE := "res://art/models/characters/body_zombie.glb"
const HEAD_SOURCE := "res://art/characters/captain_live/pieces/head/head_face.glb"

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[1] if args.size() == 2 and args[0] == "cold" else TEMPLATE
	var hashes := {}
	for source in [TEMPLATE, BODY_SOURCE, HEAD_SOURCE]:
		hashes[source] = FileAccess.get_sha256(ProjectSettings.globalize_path(source))
	var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if not _check("head-swap scene loads", packed != null):
		_finish()
		return
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	await process_frame
	await process_frame
	await _validate(scene)
	if path == TEMPLATE:
		var directory := "user://workshop_head_swap_check_" + CWAssemblyOperations.generate_id()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		var output := directory + "/head_swap.tscn"
		var result := CWAssemblyOperations.save_scene(scene, output)
		_check("explicit head-swap scene save succeeds", result.ok and FileAccess.file_exists(output))
		if result.ok:
			var reopened := (ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate() as Node3D
			root.add_child(reopened)
			await process_frame
			await process_frame
			await _validate(reopened)
			reopened.free()
			print("COLD_SCENE_PATH=" + output)
	for source in hashes:
		_check("checking preserves " + source.get_file(), hashes[source] == FileAccess.get_sha256(ProjectSettings.globalize_path(source)))
	scene.free()
	_finish()


func _validate(scene: Node3D) -> void:
	var parts := CWAssemblyOperations.collect_parts(scene)
	_check("body and five freely named Captain parts remain authored", parts.size() == 6)
	var body := _part(parts, "Body")
	var head := _part(parts, "SpeakingHead")
	var hair := _part(parts, "Hair")
	var hat := _part(parts, "Hat")
	var moustache := _part(parts, "Moustache")
	var tuft := _part(parts, "ChinTuft")
	if not _check("all intended parts have stable identities", body != null and head != null and hair != null and hat != null and moustache != null and tuft != null):
		return
	var ids := {}
	for part in parts:
		ids[part.part_id] = true
	_check("six parts have independent nonempty identities", ids.size() == 6 and not ids.has(""))
	var body_rig := body.get_node("Model/RootNode/Armature/Skeleton3D") as Skeleton3D
	var head_rig := head.get_node("Model/head_rig/Skeleton3D") as Skeleton3D
	var body_mesh := _primary_mesh(body)
	var head_mesh := _primary_mesh(head)
	_check("complete body and head rigs retained", body_rig.get_bone_count() == 52 and head_rig.get_bone_count() == 2 and head_rig.find_bone("Head") >= 0 and head_rig.find_bone("Jaw") >= 0)
	_check("speaking head retains all three facial shapes and skin", head_mesh.mesh.get_blend_shape_count() == 3 and head_mesh.skin != null and head_mesh.get_node_or_null(head_mesh.skeleton) == head_rig)
	_check("body skin remains on original donor rig", body_mesh.skin != null and body_mesh.skin.get_bind_count() == 52 and body_mesh.get_node_or_null(body_mesh.skeleton) == body_rig)
	_check("head attaches to body Head and retains local rig", head.attachment_mode == CWPart.AttachmentMode.BONE and head.bone_name == "mixamorig_Head" and head.get_node_or_null(head.target_path) == body_rig and head.get_parent() is BoneAttachment3D)
	_check("hair, hat and moustache follow local Head", _targets(hair, head_rig, "Head") and _targets(hat, head_rig, "Head") and _targets(moustache, head_rig, "Head"))
	_check("chin tuft follows the speaking head's local Jaw", _targets(tuft, head_rig, "Jaw"))
	_check("body holds explicit reversible mask metadata", body.geometry_masks.size() == 1 and body.geometry_masks[0] is CWMeshMask)
	var mask := body.geometry_masks[0] as CWMeshMask
	_check("mask source path resolves current editable body mesh", body.get_node_or_null(mask.source_node_path) == body_mesh)
	_check("retained source matches original source fingerprint", CWMeshOperations.validate(mask.source_mesh, mask).is_empty())
	_check("mask records spatial authoring and source identity", mask.has_meta("selection_bounds") and mask.has_meta("selection_jaw_bounds") and mask.get_meta("source_path") == BODY_SOURCE)
	_check("source remains recoverable with all original faces", _triangles(mask.source_mesh) == 4630)
	_check("derived mesh excludes all selected head/jaw faces", _triangles(body_mesh.mesh) == 3361 and int(mask.get_meta("excluded_face_count")) == 1269)
	var upper: AABB = mask.get_meta("selection_bounds")
	var lower: AABB = mask.get_meta("selection_jaw_bounds")
	_check("old skull and elongated jaw have no drawable/pickable triangles", CWMeshOperations.faces_in_box(body_mesh.mesh, upper).is_empty() and CWMeshOperations.faces_in_box(body_mesh.mesh, lower).is_empty())
	_check("original source still contains the removed skull and jaw", not CWMeshOperations.faces_in_box(mask.source_mesh, upper).is_empty() and not CWMeshOperations.faces_in_box(mask.source_mesh, lower).is_empty())
	_check("upper rear neck remains and stale shadows are absent", _neck_vertices(body_mesh.mesh) > 0 and (body_mesh.mesh as ArrayMesh).shadow_mesh == null)
	var source_arrays := mask.source_mesh.surface_get_arrays(0)
	var derived_arrays := body_mesh.mesh.surface_get_arrays(0)
	_check("UV and skin/bone channels survive face exclusion", source_arrays[Mesh.ARRAY_TEX_UV] == derived_arrays[Mesh.ARRAY_TEX_UV] and source_arrays[Mesh.ARRAY_BONES] == derived_arrays[Mesh.ARRAY_BONES] and source_arrays[Mesh.ARRAY_WEIGHTS] == derived_arrays[Mesh.ARRAY_WEIGHTS])
	_check("derived material retains donor texture", body_mesh.mesh.surface_get_material(0).albedo_texture != null)
	var head_at := body_rig.global_transform * body_rig.get_bone_global_pose(body_rig.find_bone("mixamorig_Head"))
	_check("starter head scale and measured neck overlap retained", head.global_transform.origin.distance_to(head_at.origin + Vector3(0, -0.015, 0)) < 0.0001 and head.global_transform.basis.get_scale().is_equal_approx(Vector3.ONE * 0.3))
	var derived := body_mesh.mesh
	var undo := UndoRedo.new()
	undo.create_action("Restore original fused head")
	undo.add_do_property(body_mesh, "mesh", mask.source_mesh)
	undo.add_undo_property(body_mesh, "mesh", derived)
	undo.commit_action()
	_check("explicit restore recovers original fused head", _triangles(body_mesh.mesh) == 4630)
	undo.undo()
	_check("undo restores derived head exclusion", body_mesh.mesh == derived and _triangles(body_mesh.mesh) == 3361)
	undo.redo()
	_check("redo restores original head without touching source", body_mesh.mesh == mask.source_mesh)
	undo.undo()
	undo.clear_history()
	undo.free()
	await _pose_checks(body_rig, head_rig, head, moustache, tuft, body_mesh)


func _pose_checks(body: Skeleton3D, local: Skeleton3D, head: CWPart, moustache: CWPart, tuft: CWPart, body_mesh: MeshInstance3D) -> void:
	var index := body.find_bone("mixamorig_Head")
	var rotation := body.get_bone_pose_rotation(index)
	var initial_head := head.global_transform
	body.set_bone_pose_rotation(index, rotation * Quaternion(Vector3.UP, deg_to_rad(18)))
	body.force_update_all_bone_transforms()
	await process_frame
	await process_frame
	_check("body head pose drives replacement head without reconstruction", not head.global_transform.is_equal_approx(initial_head) and head.global_transform.is_equal_approx((head.get_parent() as Node3D).global_transform * head.transform) and _triangles(body_mesh.mesh) == 3361)
	var jaw := local.find_bone("Jaw")
	var jaw_rotation := local.get_bone_pose_rotation(jaw)
	var tuft_before := tuft.global_transform
	var moustache_before := moustache.global_transform
	# Same rest-orientation composition used by ui/talking_head.gd. Replacing the
	# local orientation with an identity-axis quaternion would flip this source rig.
	local.set_bone_pose_rotation(jaw, local.get_bone_rest(jaw).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, deg_to_rad(12)))
	local.force_update_all_bone_transforms()
	await process_frame
	await process_frame
	_check("jaw pose moves chin tuft while moustache stays on Head", not tuft.global_transform.is_equal_approx(tuft_before) and moustache.global_transform.is_equal_approx(moustache_before))
	local.set_bone_pose_rotation(jaw, jaw_rotation)
	body.set_bone_pose_rotation(index, rotation)
	local.force_update_all_bone_transforms()
	body.force_update_all_bone_transforms()
	await process_frame
	await process_frame
	_check("pose reset restores authored head placement", head.global_transform.is_equal_approx(initial_head))


func _part(parts: Array[CWPart], name: String) -> CWPart:
	for part in parts:
		if part.name == name:
			return part
	return null


func _primary_mesh(part: CWPart) -> MeshInstance3D:
	var model := part.get_node("Model")
	if model is MeshInstance3D:
		return model
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if CWAssemblyOperations.nearest_part(node) == part:
			return node
	return null


func _targets(part: CWPart, rig: Skeleton3D, bone: String) -> bool:
	return part.attachment_mode == CWPart.AttachmentMode.BONE and part.get_node_or_null(part.target_path) == rig and part.bone_name == bone


func _triangles(mesh: Mesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		count += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	return count


func _neck_vertices(mesh: Mesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		for index in arrays[Mesh.ARRAY_INDEX]:
			var vertex: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
			if vertex.y > 1.45 and vertex.y < 1.521 and vertex.z < 0.06 and absf(vertex.x) < 0.08:
				count += 1
	return count


func _check(label: String, condition: bool) -> bool:
	_checks += 1
	if not condition:
		_failures += 1
	print(("PASS " if condition else "FAIL ") + label)
	return condition


func _finish() -> void:
	print(("CHECKS PASSED: " if _failures == 0 else "CHECKS FAILED: ") + "%d head-swap checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
