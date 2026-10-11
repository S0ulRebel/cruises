@tool
extends Node
## Run the native editor with CRUISES_WORKSHOP_EDITOR_CHECK=1 and the authored
## tests/fixtures/workshop_editor_check.tscn. Never use --editor --script SceneTree:
## that creates a second editor main loop and leaks native editor resources.

const Commands = preload("res://addons/character_workshop/commands.gd")
const Ops = preload("res://actors/assembly/operations.gd")
const Assembly = preload("res://actors/assembly/assembly.gd")
const Preview = preload("res://addons/character_workshop/preview.gd")
const SOURCE := "res://tests/fixtures/workshop_editor_model.tscn"
var failures := 0
var count := 0

func _ready() -> void:
	if OS.get_environment("CRUISES_WORKSHOP_EDITOR_CHECK") != "1":
		return
	call_deferred("_run")

func expect(value: bool, message: String) -> void:
	count += 1
	if not value:
		failures += 1
		printerr("WORKSHOP_EDITOR_FAIL: ", message)

func _run() -> void:
	# Let the real editor finish installing its UI and filesystem first.
	for frame: int in 8:
		await get_tree().process_frame
	if not Engine.is_editor_hint():
		printerr("This check requires --editor; runtime does not expose editor undo history.")
		get_tree().quit(1)
		return
	var assembly := Assembly.new()
	assembly.name = "EditorCheck"
	get_tree().root.add_child(assembly)
	var editor_host := EditorPlugin.new()
	var manager: EditorUndoRedoManager = editor_host.get_undo_redo()
	if manager == null:
		printerr("Native editor history is unavailable; run this check in a real editor session.")
		editor_host.free()
		get_tree().quit(1)
		return
	var commands := Commands.new()
	commands.scene_root = assembly
	commands.undo = manager
	var added: Dictionary = commands.add_source(SOURCE)
	expect(added.ok, "arbitrary model add")
	if not added.ok:
		get_tree().quit(1)
		return
	var body: Node3D = added.part
	body.name = "MyBody"
	body.position = Vector3(1, 2, 3)
	body.rotation = Vector3(0.1, 0.2, -0.1)
	body.scale = Vector3(1.1, 0.8, 1.2)
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(assembly))
	expect(history != null, "native EditorUndoRedoManager resolves current history")
	history.undo()
	expect(body.get_parent() == null, "add undo")
	history.redo()
	expect(body.get_parent() == assembly, "add redo")
	var duplicate: Dictionary = commands.duplicate_selected(body)
	expect(duplicate.ok, "duplicate")
	var accessory: Node3D = duplicate.part
	accessory.name = "AnyAccessory"
	expect(accessory.get("part_id") != body.get("part_id"), "stable independent identities")
	expect(accessory.global_transform.is_equal_approx(body.global_transform), "duplicate preserves world placement")
	expect(accessory.get_parent() == assembly, "duplicate has independent free parent")
	var skeleton: Skeleton3D = body.get_node("Model/Skeleton")
	var world := accessory.global_transform
	var attached: Dictionary = commands.attach_selected(accessory, skeleton, 2, "Jaw")
	expect(attached.ok, "arbitrary local Jaw attachment")
	expect(accessory.global_transform.is_equal_approx(world), "bone attach preserves placement")
	expect(accessory.get_parent() is BoneAttachment3D, "real native bone carrier")
	history.undo()
	expect(accessory.get_parent() == assembly, "attachment undo")
	history.redo()
	expect(accessory.get_parent() is BoneAttachment3D, "attachment redo")
	expect(not commands.attach_selected(body, accessory, 1).ok, "cycle rejection")
	var own: Skeleton3D = accessory.get_node("Model/Skeleton")
	expect(own.get_bone_count() == 2, "attachment retains complete local rig")
	var ownership_dock: Control = load("res://addons/character_workshop/dock.tscn").instantiate()
	get_tree().root.add_child(ownership_dock)
	ownership_dock.populate(assembly, Ops.collect_parts(assembly), body)
	expect(ownership_dock.get_node("%Meshes").item_count == 1, "body mesh selector excludes attached accessory meshes")
	expect(ownership_dock.get_node("%Statistics").text.contains("2 bones"), "part statistics exclude dependent local rigs")
	ownership_dock.free()
	var child_mesh: MeshInstance3D = accessory.get_node("Model/Geometry")
	expect(not commands.change_geometry(body, child_mesh, {0: PackedInt32Array([0])}, "exclude").ok, "geometry command enforces nearest part ownership")
	var owner_mesh: MeshInstance3D = body.get_node("Model/Geometry")
	var child_collision: CollisionShape3D = accessory.get_node("Model/CollisionBody/Shape")
	expect(commands.change_geometry(body, owner_mesh, {0: PackedInt32Array([0])}, "exclude").ok and not child_collision.disabled, "body exclusions preserve dependent collision")
	expect(commands.change_geometry(body, owner_mesh, {}, "reset").ok, "nested-part ownership exclusion reset")
	expect(not commands.apply_binding(body, {"ok": true}, skeleton).ok, "binding command rejects attached dependents")
	var hidden: Dictionary = commands.toggle_hidden(accessory)
	expect(hidden.ok and not accessory.visible, "hide")
	history.undo()
	expect(accessory.visible, "hide undo")
	expect(not commands.remove_selected(body).ok, "dependent removal needs explicit policy")
	world = accessory.global_transform
	var removed: Dictionary = commands.remove_selected(body, "keep_free")
	expect(removed.ok and body.get_parent() == null, "remove body with keep-free policy")
	expect(accessory.get_parent() == assembly and accessory.global_transform.is_equal_approx(world), "dependent remains placed")
	history.undo()
	expect(body.get_parent() == assembly and accessory.get_parent() is BoneAttachment3D, "remove undo restores hierarchy")
	var replaced: Dictionary = commands.replace_selected(body, SOURCE, "reconnect")
	expect(replaced.ok, "replacement validates matching local rig")
	var replacement: Node3D = replaced.part
	expect(replacement.get("part_id") == body.get("part_id"), "replacement stable identity")
	expect(replacement.is_ancestor_of(accessory), "replacement reconnects dependent")
	expect(accessory.global_transform.is_equal_approx(world), "replacement child world placement")
	history.undo()
	expect(body.is_ancestor_of(accessory) and replacement.get_parent() == null, "replacement undo")
	history.redo()
	expect(replacement.is_ancestor_of(accessory), "replacement redo")
	history.undo()
	var native := MeshInstance3D.new()
	native.name = "NativeDraggedModel"
	native.mesh = SphereMesh.new()
	assembly.add_child(native)
	native.owner = assembly
	native.position = Vector3(3, 1, -2)
	native.rotation.y = 0.4
	world = native.global_transform
	var adopted: Dictionary = commands.adopt_selected(native)
	expect(adopted.ok, "native dragged node adoption")
	expect(native.global_transform.is_equal_approx(world), "adoption placement")
	expect(native.name == "Model" and native.get_parent() == adopted.part, "adoption wrapper")
	history.undo()
	expect(native.get_parent() == assembly and native.name == "NativeDraggedModel" and native.global_transform.is_equal_approx(world), "adoption undo")
	history.redo()
	expect(native.get_parent() == adopted.part, "adoption redo")
	var body_player: AnimationPlayer = body.get_node("Model/AnimationPlayer")
	var borrowed := {"ok": true, "error": "", "player": body_player, "created": false, "library": body_player.get_animation_library("").duplicate(true), "model": body.get_node("Model")}
	expect(commands.install_animation_library(borrowed).ok, "prepared borrowed library installation")
	expect(body_player.has_animation("captain/talk"), "borrowed clip has explicit library name")
	history.undo()
	expect(not body_player.has_animation_library("captain"), "borrowed library undo")
	history.redo()
	expect(body_player.has_animation("captain/talk"), "borrowed library redo")
	history.undo()
	commands.attach_selected(accessory, assembly, 0)
	accessory.set("attachment_mode", 3)
	accessory.set("target_path", accessory.get_path_to(skeleton))
	var donor_refs: Resource = Resource.new()
	donor_refs.set_meta("donor_path", accessory.get_path_to(skeleton))
	accessory.set("binding_data", donor_refs)
	var bound_mesh: MeshInstance3D = accessory.get_node("Model/Geometry")
	bound_mesh.skin = Skin.new()
	bound_mesh.skin.add_named_bind("Head", Transform3D.IDENTITY)
	bound_mesh.skeleton = bound_mesh.get_path_to(skeleton)
	var references: Array = Ops.capture_references(assembly)
	# Deliberate native-style hierarchy/name action, followed by explicit repair.
	manager.create_action("Rename native scene node", UndoRedo.MERGE_DISABLE, assembly)
	manager.add_do_property(body, "name", "RenamedBody")
	manager.add_undo_property(body, "name", "MyBody")
	manager.commit_action()
	expect(bound_mesh.get_node_or_null(bound_mesh.skeleton) == null, "native rename makes untracked mesh path stale")
	expect(commands.repair_references(references).ok, "explicit native reference repair")
	expect(bound_mesh.get_node_or_null(bound_mesh.skeleton) == skeleton and accessory.get_node_or_null(accessory.get("target_path")) == skeleton, "repair skin and bone target")
	expect(accessory.get_node_or_null(donor_refs.get_meta("donor_path")) == skeleton, "repair binding provenance")
	history.undo()
	expect(bound_mesh.get_node_or_null(bound_mesh.skeleton) == null, "repair undo")
	history.undo()
	expect(bound_mesh.get_node_or_null(bound_mesh.skeleton) == skeleton, "native rename undo restores old paths")
	expect(commands.dependents(body).has(accessory), "external skinned dependency is discovered")
	expect(not commands.remove_selected(body, "keep_free").ok, "donor removal cannot orphan external skin")
	var reconnected: Dictionary = commands.replace_selected(body, SOURCE, "reconnect")
	expect(reconnected.ok, "compatible replacement reconnects external skin")
	var new_skeleton: Skeleton3D = reconnected.part.get_node("Model/Skeleton")
	expect(bound_mesh.get_node_or_null(bound_mesh.skeleton) == new_skeleton and accessory.get_node_or_null(donor_refs.get_meta("donor_path")) == new_skeleton, "replacement remaps skin and donor provenance")
	history.undo()
	expect(bound_mesh.get_node_or_null(bound_mesh.skeleton) == skeleton, "external donor replacement undo")
	var all_removed: Dictionary = commands.remove_selected(body, "remove_all")
	expect(all_removed.ok and body.get_parent() == null and accessory.get_parent() == null, "remove all includes external bound dependents")
	history.undo()
	expect(body.get_parent() == assembly and accessory.get_parent() == assembly and bound_mesh.get_node_or_null(bound_mesh.skeleton) == skeleton, "remove all restores external dependencies")
	var mesh: MeshInstance3D = body.get_node("Model/Geometry")
	var original: Mesh = mesh.mesh
	var material: Material = mesh.get_surface_override_material(0)
	var collision: CollisionShape3D = body.get_node("Model/CollisionBody/Shape")
	var second_mesh: MeshInstance3D = mesh.duplicate() as MeshInstance3D
	second_mesh.name = "SecondGeometry"
	body.get_node("Model").add_child(second_mesh)
	Ops.ensure_owned(second_mesh, assembly)
	expect(commands.change_geometry(body, mesh, {0: PackedInt32Array([0])}, "exclude").ok, "first mesh shares collision baseline")
	expect(commands.change_geometry(body, second_mesh, {0: PackedInt32Array([0])}, "exclude").ok, "second mesh shares collision baseline")
	expect(commands.change_geometry(body, mesh, {}, "reset").ok and collision.disabled, "collision stays disabled while another mesh remains excluded")
	expect(commands.change_geometry(body, second_mesh, {}, "reset").ok and not collision.disabled, "last mesh reset restores original collision baseline")
	for step: int in 4:
		history.undo()
	second_mesh.free()
	var masked: Dictionary = commands.change_geometry(body, mesh, {0: PackedInt32Array([0, 1])}, "exclude")
	expect(masked.ok, "explicit geometry exclusion")
	expect(mesh.mesh != original and body.get("geometry_masks").size() == 1, "derived geometry and persistent mask")
	expect(collision.disabled, "stale collision disabled")
	expect(mesh.get_surface_override_material(0) == material, "material override retained")
	expect(not commands.apply_binding(body, {"ok": true}, skeleton).ok, "binding command rejects active mesh exclusions")
	history.undo()
	expect(mesh.mesh == original and not collision.disabled and body.get("geometry_masks").is_empty(), "geometry undo restores source and collision")
	history.redo()
	expect(collision.disabled and body.get("geometry_masks").size() == 1, "geometry redo")
	var reset: Dictionary = commands.change_geometry(body, mesh, {}, "reset")
	expect(reset.ok and mesh.mesh == original and not collision.disabled, "reset restores source and collision")
	history.undo()
	expect(body.get("geometry_masks").size() == 1, "reset undo")
	var geometry_refs: Array = Ops.capture_references(assembly)
	mesh.name = "RenamedGeometry"
	expect(commands.mask_for(body, mesh) == null, "native mesh rename exposes stale mask path")
	expect(commands.repair_references(geometry_refs).ok and commands.mask_for(body, mesh) != null, "repair exclusion mesh correspondence")
	history.undo()
	mesh.name = "Geometry"
	expect(commands.mask_for(body, mesh) != null, "mask repair undo and native rename reversal")
	var player: AnimationPlayer = body.get_node("Model/AnimationPlayer")
	var original_library := player.get_animation_library("")
	var original_animation := player.get_animation("talk")
	var preview := Preview.new()
	expect(preview.play(player, "talk", true).is_empty(), "animation preview")
	expect(player.get_animation_library("") != original_library, "independent preview library")
	preview.advance(0.5)
	expect(skeleton.get_bone_pose_position(1).y < -0.08, "local Jaw actually animates")
	expect(original_animation.loop_mode == Animation.LOOP_NONE, "original one-shot clip unchanged")
	preview.stop()
	expect(player.get_animation_library("") == original_library and skeleton.get_bone_pose_position(1).is_equal_approx(Vector3.ZERO), "preview restores original library and pose")
	preview.neutral_shading(assembly, true)
	expect(mesh.material_override != null, "temporary preview shading")
	preview.restore_materials()
	expect(mesh.material_override == null, "original material preview restored")
	var output := "user://workshop_editor_check_%d.tscn" % OS.get_process_id()
	var saved: Dictionary = Ops.save_scene(assembly, output)
	expect(saved.ok, "explicit reusable scene save")
	var packed: PackedScene = ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var loaded: Node = packed.instantiate() if packed != null else null
	expect(loaded != null, "same-session reload")
	if loaded != null:
		var loaded_body: Node3D = loaded.get_node("MyBody")
		expect(loaded_body.get("part_id") == body.get("part_id"), "reload stable identity")
		expect(loaded_body.get("geometry_masks").size() == 1, "reload mask metadata")
		loaded.free()
	var child_output: Array = []
	var child_exit := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/fixtures/workshop_editor_cold.gd", "--", output]), child_output, true)
	var child_log := "\n".join(child_output)
	expect(child_exit == 0 and child_log.contains("WORKSHOP_EDITOR_COLD: passed") and not child_log.contains("ERROR:"), "separate process cold reopen without editor/plugin")
	if child_exit != 0 or child_log.contains("ERROR:"):
		printerr(child_log)
	var dock: Control = load("res://addons/character_workshop/dock.tscn").instantiate()
	get_tree().root.add_child(dock)
	dock.populate(assembly, Ops.collect_parts(assembly), body)
	expect(dock.get_node("%Parts").get_root().get_child_count() == 3, "authored dock displays scene-derived parts")
	expect(dock.current_target != null and dock.current_mesh == mesh, "dock target and mesh lists")
	var clicks: Array = []
	dock.request.connect(func(action: String, _value: Variant): clicks.append(action))
	dock.get_node("%Duplicate").pressed.emit()
	expect(clicks == ["duplicate"], "authored button invokes command route")
	dock.free()
	var native_dock: Control = EditorInterface.get_base_control().find_child("CharacterWorkshop", true, false)
	if native_dock != null:
		var connections: Array = native_dock.get_signal_connection_list("request")
		var plugin: EditorPlugin = connections[0].callable.get_object()
		expect(plugin.commands.scene_root == get_parent(), "enabled plugin uses the actual edited assembly")
		plugin._files_selected(PackedStringArray([SOURCE]))
		for frame: int in 3:
			await get_tree().process_frame
		var ui_part: Node3D = native_dock.current_part
		expect(ui_part != null and ui_part.get_parent() == get_parent(), "native Add command selects new part")
		var camera := Camera3D.new()
		get_tree().root.add_child(camera)
		camera.position = Vector3(0, 0, 3)
		camera.look_at(Vector3.ZERO)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = camera.unproject_position(Vector3(0, 0, 0.15))
		expect(plugin._forward_3d_gui_input(camera, event) == EditorPlugin.AFTER_GUI_INPUT_PASS, "native transform input is not hijacked")
		plugin._set_face_mode(true)
		expect(plugin._forward_3d_gui_input(camera, event) == EditorPlugin.AFTER_GUI_INPUT_STOP and not plugin.face_selection.is_empty(), "deliberate viewport face click selects actual source triangle")
		native_dock.get_node("%Exclude").pressed.emit()
		for frame: int in 3:
			await get_tree().process_frame
		expect(ui_part.get("geometry_masks").size() == 1, "native dock applies face exclusion")
		plugin._set_face_mode(false)
		camera.free()
		var edited_history: UndoRedo = plugin.get_undo_redo().get_history_undo_redo(plugin.get_undo_redo().get_object_history_id(get_parent()))
		edited_history.undo()
		expect(ui_part.get("geometry_masks").is_empty(), "native exclusion undo")
		plugin._refresh()
		native_dock.get_node("%Duplicate").pressed.emit()
		for frame: int in 3:
			await get_tree().process_frame
		expect(Ops.collect_parts(get_parent()).size() == 2, "native dock Duplicate routes through history")
		edited_history.undo()
		expect(Ops.collect_parts(get_parent()).size() == 1, "native dock command undo")
		edited_history.undo()
		expect(Ops.collect_parts(get_parent()).is_empty(), "native dock add undo")
		edited_history.clear_history()
	else:
		print("WORKSHOP_EDITOR_NOTE: plugin enable test omitted; dock and native commands still verified.")
	# Discard both directions of native history: references must not destroy parents.
	history.clear_history()
	expect(is_instance_valid(assembly) and is_instance_valid(body), "history cleanup preserves authored parents")
	print("WORKSHOP_EDITOR_OUTPUT: ", output)
	print("WORKSHOP_EDITOR_CHECK: ", count - failures, "/", count, " passed")
	print("CHECKS PASSED: character workshop editor" if failures == 0 else "CHECKS FAILED: character workshop editor")
	assembly.free()
	editor_host.free()
	for frame: int in 4:
		await get_tree().process_frame
	get_tree().quit(1 if failures > 0 else 0)
