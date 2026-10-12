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
	var transform_before := accessory.global_transform
	var transform_after := transform_before
	transform_after.origin += Vector3(0.2, -0.1, 0.35)
	transform_after.basis = Basis(Vector3.UP, 0.15) * transform_after.basis.scaled(Vector3.ONE * 1.1)
	expect(commands.transform_selected(accessory, transform_before, transform_after).ok, "viewport transform on a bone-attached part")
	expect(accessory.global_transform.is_equal_approx(transform_after), "move rotate scale preserve the requested world transform")
	history.undo()
	expect(accessory.global_transform.is_equal_approx(transform_before), "viewport transform uses native undo")
	history.redo()
	expect(accessory.global_transform.is_equal_approx(transform_after), "viewport transform uses native redo")
	history.undo()
	var singular := transform_before
	singular.basis = Basis.IDENTITY.scaled(Vector3(0, 1, 1))
	expect(not commands.transform_selected(accessory, transform_before, singular).ok and accessory.global_transform.is_equal_approx(transform_before), "invalid scale rejected without changing the part")
	expect(not commands.transform_selected(accessory, Transform3D.IDENTITY, transform_after).ok, "stale drag rejected without overwriting another edit")
	var assembly_before := assembly.global_transform
	assembly.position += Vector3(3, -1, 2)
	var body_before := body.global_transform
	body.top_level = true
	body.global_transform = body_before
	var independent_before := body.global_transform
	var independent_after := independent_before.translated(Vector3(0.1, 0.2, -0.3))
	expect(commands.transform_selected(body, independent_before, independent_after).ok and body.global_transform.is_equal_approx(independent_after), "top-level part transform stays independent of its parent")
	history.undo()
	expect(body.global_transform.is_equal_approx(independent_before), "top-level transform undo restores exact placement")
	body.top_level = false
	body.global_transform = body_before
	assembly.global_transform = assembly_before
	var ownership_dock: Control = load("res://addons/character_workshop/dock.tscn").instantiate()
	get_tree().root.add_child(ownership_dock)
	ownership_dock.populate(assembly, Ops.collect_parts(assembly), body)
	expect(ownership_dock.get_node("%Meshes").item_count == 1, "body mesh selector excludes attached accessory meshes")
	expect(ownership_dock.get_node("%Statistics").text.contains("2 bones"), "part statistics exclude dependent local rigs")
	var parts_tree := ownership_dock.get_node("%Parts") as Tree
	var root_row := parts_tree.get_root()
	expect(root_row.get_metadata(0) == assembly and not parts_tree.hide_root, "hierarchy shows the real assembly root")
	var body_row := _tree_item_for(root_row, body)
	var accessory_row := _tree_item_for(root_row, accessory)
	expect(body_row != null and accessory_row != null and accessory_row.get_parent() == body_row, "bone-attached accessories nest under their owning body part")
	if body_row != null:
		body_row.collapsed = true
		ownership_dock.populate(assembly, Ops.collect_parts(assembly), body)
		expect(_tree_item_for(parts_tree.get_root(), body).collapsed, "hierarchy refresh retains collapsed branches")
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
	var native_composition := Assembly.new()
	native_composition.name = "NativeManagedComposition"
	assembly.add_child(native_composition)
	native_composition.position = Vector3(-2, 0.3, 1)
	var nested_body: Node3D = Ops.create_part(SOURCE).part
	var nested_head: Node3D = Ops.create_part(SOURCE).part
	native_composition.add_child(nested_body)
	native_composition.add_child(nested_head)
	nested_body.name = "ExistingBody"
	nested_head.name = "ExistingHead"
	Ops.ensure_owned(native_composition, assembly)
	var nested_skeleton: Skeleton3D = nested_body.get_node("Model/Skeleton")
	expect(Ops.attach(nested_head, nested_skeleton, 2, "Jaw", assembly).ok, "native composition includes managed local-rig attachment")
	var original_nested_ids: Array = [nested_body.get("part_id"), nested_head.get("part_id")]
	var original_body_group: Variant = nested_body.get_node("Model").get_meta(Ops.SOURCE_GROUP_META)
	var original_head_group: Variant = nested_head.get_node("Model").get_meta(Ops.SOURCE_GROUP_META)
	var original_nested_world := nested_head.global_transform
	var adopted_composition: Dictionary = commands.adopt_selected(native_composition)
	expect(adopted_composition.ok, "native managed assembly adoption")
	var composition_part: Node3D = adopted_composition.part
	var initialized_nested_ids: Array = [nested_body.get("part_id"), nested_head.get("part_id")]
	expect(initialized_nested_ids[0] != original_nested_ids[0] and initialized_nested_ids[1] != original_nested_ids[1], "adoption regenerates nested managed identities")
	expect(native_composition.get_meta(Ops.SOURCE_GROUP_META) == composition_part.get("part_id") and nested_body.get_meta(Ops.SOURCE_GROUP_META) == composition_part.get("part_id"), "adoption records the imported composition boundary")
	expect(nested_head.global_transform.is_equal_approx(original_nested_world), "nested adoption preserves world placement and carrier")
	var copied_composition: Dictionary = commands.duplicate_selected(composition_part)
	expect(copied_composition.ok and Ops.collect_parts(copied_composition.part).size() == 3, "duplicate retains imported nested parts")
	var copied_head: Node3D = copied_composition.part.find_child("ExistingHead", true, false) as Node3D
	var copied_nested_ids: Array = [copied_composition.part.get_node("Model/ExistingBody").get("part_id"), copied_head.get("part_id")]
	expect(copied_head.get_parent() is BoneAttachment3D and copied_head.get_node_or_null(copied_head.get("target_path")) == copied_composition.part.get_node("Model/ExistingBody/Model/Skeleton"), "duplicate retains source bone carrier and target")
	expect(copied_nested_ids[0] != initialized_nested_ids[0] and copied_nested_ids[1] != initialized_nested_ids[1], "duplicated nested identities remain independent")
	history.undo()
	history.undo()
	expect(native_composition.get_parent() == assembly and native_composition.name == "NativeManagedComposition", "nested adoption undo restores native hierarchy")
	expect([nested_body.get("part_id"), nested_head.get("part_id")] == original_nested_ids, "nested adoption undo restores exact original identities")
	expect(not native_composition.has_meta(Ops.SOURCE_GROUP_META) and not nested_body.has_meta(Ops.SOURCE_GROUP_META) and nested_body.get_node("Model").get_meta(Ops.SOURCE_GROUP_META) == original_body_group and nested_head.get_node("Model").get_meta(Ops.SOURCE_GROUP_META) == original_head_group, "nested adoption undo restores original composition metadata")
	history.redo()
	expect([nested_body.get("part_id"), nested_head.get("part_id")] == initialized_nested_ids and native_composition.get_meta(Ops.SOURCE_GROUP_META) == composition_part.get("part_id"), "nested adoption redo reuses initialized identities and group")
	history.redo()
	expect(Ops.collect_parts(copied_composition.part).size() == 3 and [copied_composition.part.get_node("Model/ExistingBody").get("part_id"), copied_head.get("part_id")] == copied_nested_ids, "composition duplicate redo reuses copied identities")
	history.undo()
	history.undo()
	assembly.remove_child(native_composition)
	var body_player: AnimationPlayer = body.get_node("Model/AnimationPlayer")
	var borrowed := {"ok": true, "error": "", "player": body_player, "created": false, "library": body_player.get_animation_library("").duplicate(true), "model": body.get_node("Model")}
	expect(commands.install_animation_library(borrowed).ok, "prepared borrowed library installation")
	native_composition.free()
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
	expect(_tree_part_count(dock.get_node("%Parts").get_root()) == 3, "authored hierarchy displays each scene-derived part once")
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
		await _check_pane_editing(plugin, ui_part)
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
		await _check_unsaved_starters(plugin)
		# Backend command fixtures share the editor world. Keep their synthetic
		# green geometry out of the graphical user-workspace acceptance capture.
		assembly.hide()
		await _check_workspace(plugin)
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


func _check_unsaved_starters(plugin: EditorPlugin) -> void:
	# The runner must remain in the editor tree when New Scene changes scene tabs.
	var tree := get_tree()
	var previous_root := EditorInterface.get_edited_scene_root()
	reparent(tree.root)
	owner = null
	var native_dock: Control = plugin.dock
	var dialog := native_dock.get_node("%FileDialog") as FileDialog
	var template_path := "res://actors/assembly/templates/captain_portrait.tscn"
	var template_hash := FileAccess.get_sha256(template_path)
	var empty_hash := FileAccess.get_sha256("res://actors/assembly/templates/empty.tscn")
	native_dock.get_node("%New").pressed.emit()
	for frame: int in 3:
		await tree.process_frame
	var empty := EditorInterface.get_edited_scene_root()
	expect(empty is Assembly and empty != previous_root and empty.scene_file_path.is_empty() and Ops.collect_parts(empty).is_empty(), "New immediately creates an empty unsaved assembly")
	expect(not dialog.visible, "New does not open a destination dialog")
	expect(EditorInterface.get_open_scene_roots().has(previous_root), "New preserves the previous edited scene tab")
	expect(plugin.commands.scene_root == empty, "new unsaved assembly is immediately editable in the dock")
	var templates := native_dock.get_node("%Templates") as OptionButton
	var index := -1
	for item in templates.item_count:
		if templates.get_item_metadata(item) == template_path:
			index = item
	expect(index > 0 and templates.get_item_text(0) == "New from template…", "template selector describes creating a character")
	if index < 0:
		return
	templates.select(index)
	templates.item_selected.emit(index)
	for frame: int in 3:
		await tree.process_frame
	var first := EditorInterface.get_edited_scene_root()
	expect(first is Assembly and first != empty and first.scene_file_path.is_empty() and Ops.collect_parts(first).size() == 5, "template selection immediately opens its unsaved character copy")
	expect(not dialog.visible and templates.selected == 0, "template creation skips browsing and resets its chooser for reuse")
	expect(EditorInterface.get_open_scene_roots().has(empty) and EditorInterface.get_open_scene_roots().has(previous_root), "template creation preserves existing scenes")
	expect(plugin.commands.scene_root == first, "template copy is immediately editable")
	if not first is Assembly or not first.has_node("SpeakingHead"):
		return
	var original_position := (first.get_node("SpeakingHead") as Node3D).position
	(first.get_node("SpeakingHead") as Node3D).position += Vector3(0.25, 0, 0)
	templates.select(index)
	templates.item_selected.emit(index)
	for frame: int in 3:
		await tree.process_frame
	var second := EditorInterface.get_edited_scene_root()
	expect(second != first and second.scene_file_path.is_empty(), "selecting the same template again creates another unsaved character")
	if second.has_node("SpeakingHead"):
		expect((second.get_node("SpeakingHead") as Node3D).position.is_equal_approx(original_position), "editing one template copy does not change the next copy")
	var source := (load(template_path) as PackedScene).instantiate()
	if second.has_node("SpeakingHead"):
		var source_mesh: MeshInstance3D = source.get_node("SpeakingHead/Model").find_children("*", "MeshInstance3D", true, false)[0]
		var working_mesh: MeshInstance3D = second.get_node("SpeakingHead/Model").find_children("*", "MeshInstance3D", true, false)[0]
		expect(source_mesh.mesh != working_mesh.mesh and source_mesh.get_active_material(0) != working_mesh.get_active_material(0), "template working copy has private editable mesh and materials")
	source.free()
	expect(FileAccess.get_sha256(template_path) == template_hash and FileAccess.get_sha256("res://actors/assembly/templates/empty.tscn") == empty_hash, "creating characters never saves over templates")
	plugin._request("template", "res://actors/assembly/templates/missing_template.tscn")
	expect(EditorInterface.get_edited_scene_root() == second and not dialog.visible, "missing template reports failure without changing the working scene")
	native_dock.get_node("%Save").pressed.emit()
	expect(dialog.visible and dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE and plugin._file_action == "save", "Save As retains the explicit destination dialog")
	dialog.hide()
	native_dock.get_node("%Open").pressed.emit()
	expect(dialog.visible and dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE and plugin._file_action == "open", "Open existing retains the scene browser")
	dialog.hide()
	native_dock.get_node("%SaveAs").pressed.emit()
	dialog.hide()
	plugin._create_from_template(template_path)
	for frame: int in 3:
		await tree.process_frame
	var stale_output := "user://workshop_stale_save_%d.tscn" % OS.get_process_id()
	plugin._file_selected(stale_output)
	expect(not FileAccess.file_exists(stale_output) and EditorInterface.get_edited_scene_root().scene_file_path.is_empty(), "changing characters while choosing Save As cannot save the wrong scene")
	plugin._clear_file_request()

func _tree_item_for(item: TreeItem, node: Node) -> TreeItem:
	if item == null:
		return null
	if item.get_metadata(0) == node:
		return item
	for child: TreeItem in item.get_children():
		var found := _tree_item_for(child, node)
		if found != null:
			return found
	return null

func _tree_part_count(item: TreeItem) -> int:
	if item == null:
		return 0
	var total := 1 if item.get_metadata(0) is AssemblyPart else 0
	for child: TreeItem in item.get_children():
		total += _tree_part_count(child)
	return total

func _check_workspace(plugin: EditorPlugin) -> void:
	EditorInterface.set_main_screen_editor("Character Workshop")
	for frame: int in 4:
		await get_tree().process_frame
	var panel: Control = plugin.dock
	expect(panel.get_parent() == EditorInterface.get_editor_main_screen() and panel.is_visible_in_tree(), "Workshop owns a visible main-screen workspace")
	var panes: Array[Node] = panel.find_children("*", "SubViewport", true, false)
	expect(panes.size() == 2, "two real viewport panes are present")
	var edited := EditorInterface.get_edited_scene_root() as Node3D
	plugin._select(edited)
	plugin._refresh()
	expect(panel.get_node("%Parts").get_selected().get_metadata(0) == edited, "hierarchy root stays selected after native synchronization")
	var root_before := edited.global_transform
	var root_after := root_before.translated(Vector3(0.1, 0, 0))
	expect(plugin.commands.transform_selected(edited, root_before, root_after).ok and edited.global_transform.is_equal_approx(root_after), "assembly root can be fitted as a whole")
	var root_history := plugin.get_undo_redo().get_history_undo_redo(plugin.get_undo_redo().get_object_history_id(edited))
	root_history.undo()
	expect(edited.global_transform.is_equal_approx(root_before), "whole-assembly transform uses native undo")
	plugin._request("inspector", null)
	expect(plugin._transform_dialog.visible, "Fine adjust also works for the selected assembly root")
	plugin._transform_dialog.cancel()
	for pane: SubViewport in panes:
		expect(pane.world_3d == edited.get_world_3d(), "viewport renders the actual edited character world")
		expect(not edited.is_ancestor_of(pane) and pane.get_camera_3d() != null, "tool cameras stay outside the authored character")
	expect(not panel.get_node("%AdvancedTools").visible, "advanced selectors are closed by default")
	var browser: Control = panel.get_node("%Assets")
	expect(browser != null, "visual project asset browser is embedded")
	if browser != null:
		browser.refresh_catalog()
		var asset_list := browser.get_node("%AssetList") as ItemList
		expect(asset_list.item_count > 0, "asset browser discovers real project prefabs and imported models")
		browser.get_node("%AssetSearch").text = "head face"
		browser.get_node("%AssetSearch").text_changed.emit("head face")
		expect(asset_list.item_count > 0 and asset_list.item_count < browser._catalog.size(), "asset search filters filename words across snake-case names")
		if asset_list.item_count > 0:
			asset_list.select(0)
			var source_path: String = browser.selected_path()
			expect(source_path.begins_with("res://") and ResourceLoader.exists(source_path, "PackedScene"), "thumbnail selection retains an actual project source path")
		browser.get_node("%AssetSearch").text = ""
		browser.get_node("%AssetSearch").text_changed.emit("")
	await _check_import_validation(plugin)
	await _check_usability(plugin)
	var capture := OS.get_environment("CRUISES_WORKSHOP_CAPTURE")
	if not capture.is_empty() and DisplayServer.get_name() != "headless":
		plugin.hide_bottom_panel()
		var window := get_window()
		window.mode = Window.MODE_WINDOWED
		window.size = Vector2i(1600, 1000)
		for frame: int in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var screenshot := panel.get_viewport().get_texture().get_image()
		if screenshot != null:
			screenshot.save_png(capture)
			print("WORKSHOP_CAPTURE=", capture)
		panel.show_assets()
		browser.get_node("%AssetSearch").text = "hair"
		browser.get_node("%AssetSearch").text_changed.emit("hair")
		for frame: int in 35:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		screenshot = panel.get_viewport().get_texture().get_image()
		if screenshot != null:
			screenshot.save_png(capture.get_base_dir().path_join("assets.png"))
		panel.get_node("%AssetDrawer").hide()
		browser.get_node("%AssetSearch").text = ""
		browser.get_node("%AssetSearch").text_changed.emit("")
		plugin._request("inspector", null)
		for frame: int in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		screenshot = panel.get_viewport().get_texture().get_image()
		if screenshot != null:
			screenshot.save_png(capture.get_base_dir().path_join("fine_adjust.png"))
		plugin._transform_dialog.cancel()

func _check_pane_editing(plugin: EditorPlugin, part: Node3D) -> void:
	EditorInterface.set_main_screen_editor("Character Workshop")
	var pane: Control = plugin.dock.get_node("%MainView")
	pane.frame_selected()
	for frame: int in 3:
		await get_tree().process_frame
	var original := part.global_transform
	var native_history := plugin.get_undo_redo().get_history_undo_redo(plugin.get_undo_redo().get_object_history_id(part))
	for mode: String in ["move", "rotate", "scale"]:
		plugin._request("tool", mode)
		var center: Vector2 = pane.camera.unproject_position(part.global_position)
		pane._left_press(center)
		pane._drag_to(center + Vector2(25, -12), false)
		expect(not part.global_transform.is_equal_approx(original), "actual viewport %s handle previews on the authored part" % mode)
		pane._finish_drag()
		expect(not part.global_transform.is_equal_approx(original), "actual viewport %s commit routes through native commands" % mode)
		native_history.undo()
		expect(part.global_transform.is_equal_approx(original), "actual viewport %s commit undoes exactly" % mode)
	pane._left_press(pane.camera.unproject_position(part.global_position))
	pane._drag_to(pane.camera.unproject_position(part.global_position) + Vector2(15, 0), false)
	pane.cancel_drag()
	expect(part.global_transform.is_equal_approx(original), "viewport cancel restores the authored transform")
	plugin._request("tool", "move")
	plugin._request("inspector", null)
	var dialog: Control = plugin._transform_dialog
	expect(dialog.visible, "Fine adjust opens exact transform fields")
	dialog.get_node("%PositionX").get_line_edit().text = str(part.position.x + 0.125)
	dialog.get_node("%PositionX").apply()
	dialog.get_node("%TransformApply").pressed.emit()
	var adjusted := not part.global_transform.is_equal_approx(original)
	expect(not dialog.visible and adjusted, "Fine adjust applies one deliberate authored transform")
	if adjusted:
		native_history.undo()
	expect(part.global_transform.is_equal_approx(original), "Fine adjust uses native undo")
	plugin._request("inspector", null)
	dialog.get_node("%PositionX").value += 1.0
	dialog.cancel()
	expect(part.global_transform.is_equal_approx(original), "Fine adjust Cancel changes no placement")
	plugin._request("inspector", null)
	dialog.get_node("%ScaleX").get_line_edit().text = "0"
	dialog.get_node("%ScaleX").apply()
	dialog.get_node("%TransformApply").pressed.emit()
	expect(dialog.visible and part.global_transform.is_equal_approx(original), "Fine adjust rejects zero scale without changing the part")
	dialog.cancel()
	var target: Node3D = plugin.commands.duplicate_selected(part).part
	plugin._select(part)
	plugin._refresh()
	plugin._request("tool", "attach")
	plugin._request("select", target)
	expect(part.get_parent() == target and part.global_transform.is_equal_approx(original), "hierarchy Attach pick reparents without a world-position jump")
	native_history.undo()
	plugin._refresh()
	expect(part.get_parent() == plugin.commands.scene_root and part.global_transform.is_equal_approx(original), "picked attachment undo restores placement and hierarchy")
	native_history.undo()
	plugin._select(part)
	plugin._refresh()
	plugin._request("tool", "attach")
	expect(plugin.commands.remove_selected(part, "keep_free").ok, "attachment source can be removed through native history")
	plugin._refresh()
	expect(plugin._tool == "move", "deleting attachment source restores normal selection")
	native_history.undo()
	plugin._select(part)
	plugin._refresh()

func _check_import_validation(plugin: EditorPlugin) -> void:
	var directory := "user://workshop_import_validation_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("candidate.glb")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("invalid")
	file.close()
	expect(not plugin._validate_import_source(path).is_empty(), "invalid GLB is rejected before copying")
	var payload := JSON.stringify({"asset": {"version": "2.0"}, "images": [{"uri": "missing_texture.png"}]}).to_utf8_buffer()
	while payload.size() % 4 != 0:
		payload.append(32)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_32(0x46546C67)
	file.store_32(2)
	file.store_32(payload.size() + 20)
	file.store_32(payload.size())
	file.store_32(0x4E4F534A)
	file.store_buffer(payload)
	file.close()
	expect(plugin._validate_import_source(path).contains("external textures"), "GLB external dependencies require the normal full-folder import")
	var source := "res://ui/portraits/captain_live/head_face_normals.glb"
	expect(plugin._validate_import_source(source).is_empty(), "a real embedded production GLB passes import validation")
	var original_hash := FileAccess.get_sha256(source)
	plugin._import_source = source
	plugin._import_destination_selected(source.get_base_dir())
	expect(FileAccess.get_sha256(source) == original_hash and plugin._import_pending.is_empty(), "import collision preserves the existing asset and does not start an overwrite")
	plugin.dock.set_status("Character Workshop ready. Select a part in either view or the hierarchy.")

func _check_usability(plugin: EditorPlugin) -> void:
	var panel: Control = plugin.dock
	var root := EditorInterface.get_edited_scene_root() as Node3D
	var head: Node3D = root.get_node("SpeakingHead")
	var hair: Node3D = head.find_child("Hair", true, false)
	var history := plugin.get_undo_redo().get_history_undo_redo(plugin.get_undo_redo().get_object_history_id(root))
	plugin._select(head)
	plugin._refresh()
	panel.show_assets()
	expect(panel.get_node("%AssetDrawer").visible and panel.get_node("%Parts").is_visible_in_tree(), "asset drawer leaves the hierarchy available")
	panel._forward_request("close_assets", null)
	expect(not panel.get_node("%AssetDrawer").visible, "asset drawer closes without changing hierarchy selection")
	var browser: Control = panel.get_node("%Assets")
	expect(browser._matches_asset("res://art/hair.glb", "hair") and not browser._matches_asset("res://art/chair.glb", "hair"), "word-aware search distinguishes hair from chair")
	expect(browser._matches_asset("res://art/head_face.glb", "head fa"), "search accepts filename-word prefixes")
	browser.get_node("%AssetType").select(1)
	expect(not browser._matches_asset("res://actors/head.tscn", "head") and browser._matches_asset("res://art/head.glb", "head"), "asset type filter separates models and prefabs")
	browser.get_node("%AssetType").select(0)
	var folders := browser.get_node("%AssetFolder") as OptionButton
	if folders.item_count > 1:
		folders.select(1)
		var folder: String = str(folders.get_item_metadata(1))
		expect(browser._matches_asset(folder.path_join("head.glb"), "head") and not browser._matches_asset("res://outside/head.glb", "head"), "folder filter retains source boundaries")
		folders.select(0)
	browser._filter_catalog("")
	expect(panel.get_node("%AdvancedTabs").get_tab_count() == 4, "advanced tools have four task-specific categories")
	expect(plugin._transform_dialog is PanelContainer and panel.is_ancestor_of(plugin._transform_dialog), "precise fields are an inline panel rather than a floating window")
	var item := _tree_item_for(panel.get_node("%Parts").get_root(), head)
	expect(item.is_editable(0) and item.get_button_count(0) == 1, "hierarchy exposes inline rename and visibility")
	panel._context_part = head
	panel._context_action(1)
	expect(not head.visible, "context visibility action uses the clicked part")
	history.undo()
	plugin._refresh()
	expect(head.visible, "context visibility undo restores the part")
	var animation_player := AnimationPlayer.new()
	root.add_child(animation_player)
	var animation := Animation.new()
	animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(0, NodePath("SpeakingHead:position"))
	animation.track_insert_key(0, 0.0, Vector3.ZERO)
	var library := AnimationLibrary.new()
	library.add_animation("fit", animation)
	animation_player.add_animation_library("", library)
	var hair_target: Node = hair.get_node_or_null(hair.get("target_path"))
	var original_name := str(head.name)
	plugin._request("rename_part", {"part": head, "name": "SpeakingHeadRenamed"})
	expect(str(head.name) == "SpeakingHeadRenamed" and hair.get_node_or_null(hair.get("target_path")) == hair_target, "inline rename preserves attachment targets")
	var changed := animation_player.get_animation("fit")
	expect(changed != animation and changed.track_get_path(0) == NodePath("SpeakingHeadRenamed:position") and animation.track_get_path(0) == NodePath("SpeakingHead:position"), "rename rebases animation tracks in a private copy")
	history.undo()
	expect(str(head.name) == original_name and animation_player.get_animation("fit") == animation, "rename undo restores names and original animation resources")
	history.redo()
	expect(animation_player.get_animation("fit").track_get_path(0) == NodePath("SpeakingHeadRenamed:position"), "rename redo retains animation targets")
	history.undo()
	animation_player.free()
	expect(not plugin.commands.rename_selected(head, "bad/name").ok, "invalid hierarchy names fail without mutation")
	var before := hair.global_transform
	var tree: Tree = panel.get_node("%Parts")
	var hair_row := _tree_item_for(tree.get_root(), hair)
	var root_row := tree.get_root()
	var head_row := _tree_item_for(root_row, head)
	var drag_data := {"workshop_part": hair, "root": root}
	expect(panel._hierarchy_can_drop(tree.get_item_area_rect(root_row).get_center(), drag_data), "hierarchy accepts dropping a part onto the character root")
	expect(not panel._hierarchy_can_drop(tree.get_item_area_rect(hair_row).get_center(), drag_data), "hierarchy rejects parenting a part to itself")
	expect(not panel._hierarchy_can_drop(tree.get_item_area_rect(hair_row).get_center(), {"workshop_part": head, "root": root}), "hierarchy rejects attachment cycles before dropping")
	plugin._request("reparent_part", {"part": hair, "target": root})
	expect(hair.get_parent() == root and hair.global_transform.is_equal_approx(before), "hierarchy reparent preserves world placement")
	history.undo()
	expect(hair.global_transform.is_equal_approx(before) and Ops.nearest_part(hair.get_parent()) == head, "hierarchy reparent undo restores its original parent")
	plugin._select(hair)
	plugin._refresh()
	plugin._request("tool", "attach")
	plugin._request("hover_attach", head)
	expect(panel.get_node("%AttachmentBanner").visible and panel.get_node("%AttachmentPrompt").text.contains("Hair") and panel.get_node("%AttachmentPrompt").text.contains("SpeakingHead"), "attachment banner names source and candidate parent")
	panel.get_node("%CancelAttach").pressed.emit()
	expect(plugin._tool == "move" and not panel.get_node("%AttachmentBanner").visible, "visible attachment cancel restores fitting")
	var pane: Control = panel.get_node("%MainView")
	panel.get_node("%Coordinates").select(1)
	panel.get_node("%Coordinates").item_selected.emit(1)
	panel.get_node("%MoveStep").value = 0.125
	panel.get_node("%SnapEnabled").button_pressed = true
	expect(pane.local_axes and pane.snap_enabled and is_equal_approx(pane.move_step, 0.125), "fitting controls reach both camera panes")
	expect(pane._transform_axis(hair.global_basis, 0).is_equal_approx(hair.global_basis.x.normalized()), "local translation axes follow the authored orientation")
	panel.get_node("%Coordinates").select(0)
	panel.get_node("%Coordinates").item_selected.emit(0)
	panel.get_node("%SnapEnabled").button_pressed = false
	panel.get_node("%MoveStep").value = 0.05
	expect(pane._transform_axis(hair.global_basis, 0) == Vector3.RIGHT, "world axes remain independent of part orientation")
	var cursor: Vector2 = pane.overlay.size * 0.5
	pane.set_preset("Front")
	var point: Variant = pane.placement_point(cursor)
	expect(point is Vector3 and point.is_finite(), "front view supports cursor placement with a screen-plane fallback")
	var payload := {"type": "files", "files": PackedStringArray([SOURCE])}
	pane.drop_at_cursor = true
	expect(pane._can_drop_data(cursor, payload) and pane._drop_preview.point is Vector3, "cursor drop provides a placement marker without instantiating an asset")
	pane._drop_data(cursor, payload)
	var added: Node3D = panel.current_part
	expect(added != hair and added.global_position.is_equal_approx(point), "cursor drop authors the wrapper at the previewed point")
	history.undo()
	expect(added.get_parent() == null, "cursor placement and insertion share one undo action")
	pane.drop_at_cursor = false
	expect(not pane._can_drop_data(cursor, {"type": "files", "files": PackedStringArray(["res://project.godot"])}), "viewport refuses non-model drops")
	plugin._select(head)
	plugin._refresh()
	var prior_focus := EditorInterface.is_distraction_free_mode_enabled()
	plugin._request("focus_mode", true)
	expect(EditorInterface.is_distraction_free_mode_enabled(), "workshop focus hides surrounding editor docks")
	plugin._request("focus_mode", false)
	expect(EditorInterface.is_distraction_free_mode_enabled() == prior_focus, "leaving focus restores the previous editor layout")
	var output := "user://workshop_usability_%d.tscn" % OS.get_process_id()
	var test_source_root := Assembly.new()
	var test_source_part: Node3D = Ops.create_part(SOURCE).part
	test_source_root.add_child(test_source_part)
	expect(not Ops.validate_scene_save(test_source_root, ProjectSettings.globalize_path(SOURCE)).ok, "save validation rejects absolute aliases of a source prefab")
	test_source_root.free()
	var source_hash := FileAccess.get_sha256("res://actors/assembly/templates/captain_portrait.tscn")
	panel.get_node("%SaveAs").pressed.emit()
	panel.get_node("%FileDialog").hide()
	plugin._file_selected(output)
	expect(EditorInterface.get_edited_scene_root() == root and root.scene_file_path == output and FileAccess.file_exists(output), "Save As associates the current editing tab without reopening")
	var renamed: Dictionary = plugin.commands.rename_selected(head, "SavedHead")
	panel.get_node("%Save").pressed.emit()
	var saved: PackedScene = ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	var reopened: Node = saved.instantiate() if saved != null else null
	expect(renamed.ok and reopened != null and reopened.has_node("SavedHead") and not panel.get_node("%FileDialog").visible, "ordinary Save writes subsequent edits to the chosen path")
	if reopened != null:
		var valid_references := true
		for reference: Dictionary in Ops.capture_references(reopened):
			valid_references = valid_references and is_instance_valid(reference.target)
		expect(Ops.collect_parts(reopened).size() == 5 and valid_references, "native saved assembly reload retains all parts and rig/attachment references")
		reopened.free()
	history.undo()
	panel.get_node("%Save").pressed.emit()
	expect(FileAccess.get_sha256("res://actors/assembly/templates/captain_portrait.tscn") == source_hash, "native saves preserve the template source")
	print("WORKSHOP_USABILITY_OUTPUT: ", output)
