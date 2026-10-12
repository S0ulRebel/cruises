extends Node
## Copied into the external portability fixture and saved with its character.
## This runtime check deliberately has no editor or authoring-service dependency.
var failures := 0
var count := 0

func _ready() -> void:
	if not Engine.is_editor_hint() and OS.get_environment("WORKSHOP_PORTABLE_CHECK") == "1":
		_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		failures += 1
		printerr("PORTABLE_FAIL: ", message)
	else:
		print("ok ", message)

func _run() -> void:
	await get_tree().process_frame
	var root := get_parent() as CWAssembly
	expect(root != null and not Engine.is_editor_hint(), "saved character runs without the editor plugin")
	if root == null:
		_finish()
		return
	var parts := _parts(root)
	expect(parts.size() == 3, "cold saved scene retains arbitrary parts")
	expect(root._get_configuration_warnings().is_empty(), "assembly validation needs only runtime metadata")
	var body := root.get_node("BodyPart") as CWPart
	expect(body.position.is_equal_approx(Vector3(1, 2, 3)) and body.scale.is_equal_approx(Vector3(1.2, 0.9, 1.1)), "cold fitting survives")
	var skeleton := body.get_node("Model/Skeleton") as Skeleton3D
	expect(skeleton.get_bone_count() == 3 and skeleton.get_bone_name(1) == "Jaw", "cold local rig survives")
	var player := body.get_node("Model/AnimationPlayer") as AnimationPlayer
	expect(player.has_animation("workshop/talk"), "generic borrowed animation survives")
	player.play("workshop/talk")
	player.seek(0.5, true)
	expect(skeleton.get_bone_pose_position(skeleton.find_bone("Hips")).y < -0.05, "borrowed skeletal animation plays without authoring services")
	player.stop()
	var accessories: Array[CWPart] = []
	for part in parts:
		if part.name == "Accessory":
			accessories.append(part)
	expect(accessories.size() == 1, "saved accessory is independently identifiable")
	if accessories.size() == 1:
		var accessory := accessories[0]
		expect(accessory.attachment_mode == CWPart.AttachmentMode.BONE and accessory.bone_name == "Head" and accessory.get_parent() is BoneAttachment3D, "cold bone attachment survives")
		expect(accessory.get_node_or_null(accessory.target_path) == skeleton, "bone target resolves in the saved scene")
	expect(body.geometry_masks.size() == 1 and body.geometry_masks[0] is CWMeshMask, "reversible mesh metadata survives without authoring services")
	if body.geometry_masks.size() == 1:
		var mask := body.geometry_masks[0] as CWMeshMask
		expect(mask.excluded_faces.has(0) and mask.excluded_faces[0] == PackedInt32Array([0]), "saved mesh exclusion keeps its source face selection")
	if OS.get_cmdline_user_args().has("exported"):
		for path: String in ["core/assembly_operations.gd", "core/binding_service.gd", "core/animation_service.gd", "plugin.gd", "commands.gd", "project_config.gd"]:
			expect(not ResourceLoader.exists("res://addons/character_workshop/" + path), "export excludes authoring code: " + path)
		expect(not ResourceLoader.exists("res://verification/runner.gd"), "export excludes the authoring test harness")
	_finish()

func _parts(node: Node) -> Array[CWPart]:
	var result: Array[CWPart] = []
	if node is CWPart:
		result.append(node)
	for child in node.get_children():
		result.append_array(_parts(child))
	return result

func _finish() -> void:
	print("PORTABLE_RUNTIME_CHECK: %d/%d passed" % [count - failures, count])
	if failures == 0:
		print("CHECKS PASSED: independent runtime")
	get_tree().quit(0 if failures == 0 else 1)
