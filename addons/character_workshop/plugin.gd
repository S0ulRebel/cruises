@tool
extends EditorPlugin

const Assembly = preload("res://actors/assembly/assembly.gd")
const Ops = preload("res://actors/assembly/operations.gd")
const MeshOps = preload("res://actors/assembly/mesh_exclusion/operations.gd")
const Commands = preload("commands.gd")
const Preview = preload("preview.gd")
const DockScene = preload("dock.tscn")
const ImportDialogs = preload("import_dialogs.tscn")
const PortraitRig = preload("res://ui/portraits/portrait_rig.gd")
const MeshStorage = preload("res://addons/character_workshop/mesh_storage.gd")

var dock: Control
var commands: RefCounted
var preview: RefCounted
var face_selection: Dictionary = {}
var face_mode := false
var _reference_poses: Array = []
var _camera: Camera3D
var _file_action := ""
var _pending_action := ""
var _pending_part: Node3D
var _policy := "cancel"
var _refresh_time := 0.0
var _reference_root: Node
var _references: Array = []
var _binding_busy := false
var _binding_cancel := false
var _workspace_visible := false
var _tool := "move"
var _attach_part: Node3D
var _import_dialogs: Node
var _import_source := ""
var _import_pending := ""
var _import_root: Node3D
var _import_scan_needed := false
var _transform_dialog: Control
var _save_root: Node3D
var _save_root_id := 0
var _focus_before := false
var _focus_active := false

func _enter_tree() -> void:
	dock = DockScene.instantiate()
	commands = Commands.new()
	commands.undo = get_undo_redo()
	preview = Preview.new()
	get_editor_interface().get_editor_main_screen().add_child(dock)
	dock.initialize(get_editor_interface())
	_transform_dialog = dock.get_node("%FineAdjust")
	_transform_dialog.request.connect(_request)
	_make_visible(false)
	_import_dialogs = ImportDialogs.instantiate()
	dock.add_child(_import_dialogs)
	_import_dialogs.get_node("Source").file_selected.connect(_import_source_selected)
	_import_dialogs.get_node("Destination").dir_selected.connect(_import_destination_selected)
	get_editor_interface().get_resource_filesystem().filesystem_changed.connect(_finish_import)
	dock.request.connect(_request)
	dock.get_node("%FileDialog").file_selected.connect(_file_selected)
	dock.get_node("%FileDialog").files_selected.connect(_files_selected)
	dock.get_node("%FileDialog").canceled.connect(_clear_file_request)
	dock.get_node("%Dependents").confirmed.connect(_dependents_confirmed)
	dock.get_node("%DependencyPolicy").add_item("Keep attachments as free parts", 0)
	dock.get_node("%DependencyPolicy").add_item("Remove this part and all attachments", 1)
	commands.changed.connect(_command_changed)
	scene_changed.connect(_scene_changed)
	get_editor_interface().get_selection().selection_changed.connect(_selection_changed)
	add_tool_menu_item("Character Workshop: New empty character", _new_assembly)
	set_input_event_forwarding_always_enabled()
	set_force_draw_over_forwarding_enabled()
	set_process(true)
	_load_templates()
	call_deferred("_refresh")

func _exit_tree() -> void:
	_restore_focus_mode()
	_binding_cancel = true
	if _binding_busy and ResourceLoader.exists("res://actors/assembly/binding_service.gd"):
		var service: Script = load("res://actors/assembly/binding_service.gd")
		service.cancel_pending_jobs()
	_restore_preview()
	if get_editor_interface().get_selection().selection_changed.is_connected(_selection_changed):
		get_editor_interface().get_selection().selection_changed.disconnect(_selection_changed)
	remove_tool_menu_item("Character Workshop: New empty character")
	if get_editor_interface().get_resource_filesystem().filesystem_changed.is_connected(_finish_import):
		get_editor_interface().get_resource_filesystem().filesystem_changed.disconnect(_finish_import)
	dock.cancel_drag()
	dock.get_parent().remove_child(dock)
	dock.queue_free()

func _handles(object: Object) -> bool:
	# Retain character selection inside an explicitly opened Workshop, but never
	# claim nodes from another main screen and reopen the Workshop implicitly.
	return _workspace_visible and (object is Assembly or object is AssemblyPart or object is PortraitRig)

func _has_main_screen() -> bool:
	return true

func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_editor_theme().get_icon("Skeleton3D", "EditorIcons")

func _make_visible(visible: bool) -> void:
	_workspace_visible = visible
	if is_instance_valid(dock):
		if not visible:
			_restore_focus_mode()
			dock.cancel_drag()
			_restore_preview()
			face_selection.clear()
			_attach_part = null
			_tool = "move"
			dock.set_tool(_tool)
			dock.get_node("%AdvancedTools").hide()
			if is_instance_valid(_transform_dialog):
				_transform_dialog.cancel()
		dock.visible = visible

func _apply_changes() -> void:
	dock.cancel_drag()
	_restore_preview()

func _save_external_data() -> void:
	dock.cancel_drag()
	_restore_preview()

func _get_plugin_name() -> String:
	return "Character Workshop"

func _process(delta: float) -> void:
	preview.advance(delta)
	_refresh_time += delta
	if _refresh_time > 0.75:
		_refresh_time = 0.0
		_refresh()
		if _import_scan_needed:
			var filesystem := get_editor_interface().get_resource_filesystem()
			if not filesystem.is_scanning() and not filesystem.is_importing():
				_import_scan_needed = false
				filesystem.scan()
		elif not _import_pending.is_empty():
			_finish_import()
	if face_mode or not face_selection.is_empty():
		update_overlays()

func _scene_root() -> Node3D:
	var root: Node = get_editor_interface().get_edited_scene_root()
	return root as Node3D if _supports_scene(root) else null

func _supports_scene(root: Node) -> bool:
	return root is Assembly or root is PortraitRig or (root is CharacterBody3D and root.get_node_or_null("Body") is Assembly)

func _close_workspace(root: Node = null) -> void:
	if root == null:
		root = get_editor_interface().get_edited_scene_root()
	get_editor_interface().set_main_screen_editor("2D" if root is CanvasItem else "3D")

func _close_after_scene_switch(root_id: int) -> void:
	var root: Node = get_editor_interface().get_edited_scene_root()
	if (root.get_instance_id() if root != null else 0) == root_id and _workspace_visible:
		_close_workspace(root)

func _open_workspace(root_id: int) -> void:
	var root := _scene_root()
	if root != null and root.get_instance_id() == root_id:
		get_editor_interface().set_main_screen_editor(_get_plugin_name())

func _native_selected() -> Node3D:
	var nodes: Array = get_editor_interface().get_selection().get_selected_nodes()
	return nodes[0] as Node3D if nodes.size() == 1 and is_instance_valid(nodes[0]) else null

func _refresh() -> void:
	if not is_instance_valid(dock):
		return
	var root := _scene_root()
	commands.scene_root = root
	if _tool == "attach" and (not is_instance_valid(_attach_part) or root == null or not root.is_ancestor_of(_attach_part)):
		_attach_part = null
		_tool = "move"
		dock.set_tool(_tool)
	_track_references(root)
	var native := _native_selected()
	var selected := root if root != null and native == root else Ops.nearest_part(native)
	if selected != null and (root == null or (selected != root and not root.is_ancestor_of(selected))):
		selected = null
	if _transform_dialog.visible and selected != _transform_dialog._part:
		if selected == null:
			_transform_dialog.cancel()
		else:
			_transform_dialog.open_for(selected)
	var old_mesh: MeshInstance3D = dock.current_mesh if is_instance_valid(dock.current_mesh) else null
	dock.populate(root, Ops.collect_parts(root), selected)
	dock.set_attachment_source(_attach_part)
	var native_mesh := _native_selected() as MeshInstance3D
	if native_mesh != null and selected != null:
		dock.current_mesh = native_mesh
	if old_mesh != dock.current_mesh:
		face_selection.clear()
		_set_face_mode(false)
		dock.get_node("%FaceMode").set_pressed_no_signal(false)
	_update_geometry_info()

func _scene_changed(_root: Node) -> void:
	dock.cancel_drag()
	_attach_part = null
	_tool = "move"
	dock.set_tool(_tool)
	_transform_dialog.cancel()
	dock.get_node("%AdvancedTools").hide()
	_restore_preview()
	face_selection.clear()
	_reference_root = null
	_references.clear()
	# Godot restores each scene tab's previous main screen after this signal.
	# Close after that restoration; only an explicit New/Open queues reopening.
	call_deferred("_close_after_scene_switch", _root.get_instance_id() if _root != null else 0)
	call_deferred("_refresh")

func _selection_changed() -> void:
	call_deferred("_refresh")

func _command_changed() -> void:
	get_editor_interface().mark_scene_as_unsaved()
	call_deferred("_refresh")

func _select(node: Node) -> void:
	var keep_workspace := _workspace_visible
	var selection := get_editor_interface().get_selection()
	selection.clear()
	if is_instance_valid(node) and node.is_inside_tree():
		selection.add_node(node)
		get_editor_interface().edit_node(node)
	if keep_workspace:
		get_editor_interface().set_main_screen_editor(_get_plugin_name())

func _report(result: Dictionary, success: String) -> void:
	if not result.get("ok", false):
		dock.set_status(result.get("error", "Operation failed."), true)
		return
	dock.set_status(success)
	if result.has("part"):
		_select(result.part)
	_refresh()

func _request(action: String, value: Variant) -> void:
	if _has_moved_references() and action in ["add", "add_paths", "drop_assets", "rename_part", "reparent_part", "part_action", "adopt", "duplicate", "remove", "replace", "attach", "detach", "bind", "legacy", "borrow", "face_mode", "select_box", "select_surface", "exclude", "restore", "reset_mesh"]:
		dock.set_status("Repair moved / renamed references before changing this assembly.", true)
		return
	var part: Node3D = dock.current_part if is_instance_valid(dock.current_part) else null
	match action:
		"close_workshop":
			_close_workspace()
		"tool":
			_restore_preview()
			dock.cancel_drag()
			_tool = str(value)
			_attach_part = part if _tool == "attach" else null
			if _tool == "attach" and part == null:
				dock.set_status("Select the part you want to attach first.", true)
				_tool = "move"
			dock.set_tool(_tool)
			if _tool == "attach":
				dock.set_attachment_source(_attach_part)
				dock.set_status("Pick the destination part in either view or the hierarchy. Placement will stay the same.")
		"begin_transform":
			_restore_preview()
		"transform":
			_report(commands.transform_selected(value.part, value.before, value.after), "Transform applied. Undo restores the previous placement.")
		"view_input":
			value.handled = _forward_3d_gui_input(value.camera, value.event) == EditorPlugin.AFTER_GUI_INPUT_STOP
		"focus_mode":
			if bool(value) and not _focus_active:
				_focus_before = get_editor_interface().is_distraction_free_mode_enabled()
				_focus_active = true
				get_editor_interface().set_distraction_free_mode(true)
			elif not bool(value):
				_restore_focus_mode()
		"hover_attach":
			var candidate: Node3D = value if is_instance_valid(value) else null
			if candidate != null and is_instance_valid(_attach_part) and (candidate == _attach_part or _attach_part.is_ancestor_of(candidate)):
				candidate = null
			dock.set_attachment_candidate(candidate)
		"rename_part":
			dock.cancel_drag()
			_restore_preview()
			_report(commands.rename_selected(value.part, value.name), "Renamed; attachment references updated. Undo restores the old name.")
		"reparent_part":
			dock.cancel_drag()
			_restore_preview()
			_report(commands.attach_selected(value.part, value.target, 1), "Attached to %s without changing placement." % value.target.name)
		"part_action":
			_request("tool", "move")
			_select(value.part)
			_refresh()
			_request(value.action, null)
		"drop_assets":
			if value.root != _scene_root():
				dock.set_status("The character changed during the drop. Add the part again.", true)
			else:
				_files_selected(value.paths, value.get("world_position"))
		"attach_target":
			_pick_attachment(value)
		"inspector":
			dock.cancel_drag()
			_restore_preview()
			var selected := part if part != null else _native_selected()
			if is_instance_valid(selected):
				_transform_dialog.open_for(selected)
		"import_asset":
			if not _import_pending.is_empty():
				dock.set_status("Wait for the current model import to finish.", true)
			else:
				_import_dialogs.get_node("Source").popup_centered_ratio(0.65)
		"new":
			_new_assembly()
		"template":
			if not str(value).is_empty():
				_create_from_template(str(value))
		"open":
			_show_file("open", FileDialog.FILE_MODE_OPEN_FILE, ["*.tscn, *.scn ; Character scenes"])
		"save":
			var root := _scene_root()
			if root != null and not root.scene_file_path.is_empty():
				_clear_file_request()
				_save_current_scene(root.scene_file_path)
			else:
				_request("save_as", null)
		"save_as":
			if _scene_root() == null:
				dock.set_status("Open an assembly scene first.", true)
			else:
				_show_file("save", FileDialog.FILE_MODE_SAVE_FILE, ["*.tscn ; Character scene"])
		"save_actor":
			if _scene_root() == null:
				dock.set_status("Open an assembly scene first.", true)
			else:
				_show_file("save_actor", FileDialog.FILE_MODE_SAVE_FILE, ["*.tscn ; Gameplay actor scene"])
		"add":
			_show_file("add", FileDialog.FILE_MODE_OPEN_FILES, ["*.tscn, *.scn, *.glb, *.gltf, *.obj, *.fbx, *.blend, *.dae ; 3D models and prefabs"])
		"legacy":
			_show_file("legacy", FileDialog.FILE_MODE_OPEN_FILE, ["*.tres, *.res ; Legacy fit or outfit"])
		"borrow":
			_show_file("borrow", FileDialog.FILE_MODE_OPEN_FILE, ["*.glb, *.gltf, *.fbx, *.tscn, *.scn ; Animation source"])
		"add_paths":
			_files_selected(value)
		"adopt":
			_report(commands.adopt_selected(_native_selected()), "Model adopted. Move, rotate and scale its part using native controls.")
		"select":
			if _tool == "attach":
				dock.set_attachment_source(_attach_part)
				_pick_attachment(value)
			else:
				_select(value)
		"duplicate":
			_report(commands.duplicate_selected(part), "Independent part duplicated.")
		"visibility":
			_report(commands.toggle_hidden(part), "Visibility changed; Undo restores it.")
		"remove", "replace":
			_prepare_remove_or_replace(action, part)
		"attach":
			_report(commands.attach_selected(part, dock.current_target, dock.selected_mode(), dock.selected_bone()), "Attached without changing world placement. Local rig and facial features retained.")
		"detach":
			_report(commands.attach_selected(part, _scene_root(), 0), "Detached to free placement.")
		"repair_references":
			_report(commands.repair_references(_references), "Retained targets repaired after the scene-tree edit. Undo restores the prior paths.")
		"bind":
			_bind(part, dock.current_target)
		"cancel_binding":
			_binding_cancel = true
			dock.set_status("Cancelling binding; the original Model is retained.")
		"mesh_changed":
			face_selection.clear()
			_set_face_mode(false)
			_update_geometry_info()
		"face_mode":
			_set_face_mode(bool(value))
		"clear_faces":
			face_selection.clear()
			_update_geometry_info()
		"select_box":
			_select_box()
		"select_surface":
			_select_surface()
		"exclude", "restore", "reset_mesh":
			if action != "reset_mesh" and face_selection.is_empty():
				dock.set_status("Select faces first using the viewport, region or surface selector.", true)
			else:
				var result: Dictionary = commands.change_geometry(part, dock.current_mesh, face_selection, "reset" if action == "reset_mesh" else action)
				_report(result, "Mesh %s applied. Source preserved; save explicitly to persist. Existing collision must be reviewed." % action)
		"preview_shade":
			preview.neutral_shading(_scene_root(), bool(value))
		"play":
			_set_face_mode(false)
			dock.get_node("%FaceMode").set_pressed_no_signal(false)
			var error: String = preview.play(dock.selected_player(), dock.selected_clip(), dock.loop_requested())
			dock.set_status("Playing independent preview; authored part transforms remain editable." if error.is_empty() else error, not error.is_empty())
		"stop":
			_restore_preview()
		"rest":
			_set_face_mode(true)
			dock.get_node("%FaceMode").set_pressed_no_signal(face_mode)
		"player_changed":
			preview.stop()
			dock.refresh_clips()
		"loop":
			preview.set_loop(dock.selected_clip(), bool(value))
		"clip_changed":
			preview.stop()

func _show_file(action: String, mode: int, filters: PackedStringArray) -> void:
	_save_root = _scene_root() if action == "save" else null
	_save_root_id = _save_root.get_instance_id() if is_instance_valid(_save_root) else 0
	dock.cancel_drag()
	_file_action = action
	var dialog: FileDialog = dock.get_node("%FileDialog")
	dialog.file_mode = mode
	dialog.filters = filters
	dialog.title = {"add": "Add any model or prefab", "replace": "Choose replacement model", "open": "Open character scene", "new": "Save new character scene", "save": "Save character scene as"}.get(action, "Choose a file")
	if mode == FileDialog.FILE_MODE_SAVE_FILE:
		dialog.current_file = "character.tscn"
	dialog.popup_centered_ratio(0.7)

func _clear_file_request() -> void:
	_save_root = null
	_save_root_id = 0
	_file_action = ""

func _new_assembly() -> void:
	_create_from_template("res://actors/assembly/templates/empty.tscn")
	get_editor_interface().set_main_screen_editor(_get_plugin_name())

func _save_current_scene(path: String) -> void:
	dock.cancel_drag()
	_restore_preview()
	var root := _scene_root()
	if root == null or (_file_action == "save" and _save_root_id != 0 and root.get_instance_id() != _save_root_id):
		dock.set_status("The character changed while choosing a save path. Save the current character again.", true)
		return
	if _has_moved_references():
		dock.set_status("Repair moved / renamed references before saving this character.", true)
		return
	if not path.begins_with("res://") and not path.begins_with("user://") and not path.is_absolute_path():
		dock.set_status("Choose an explicit scene path.", true)
		return
	if not root is PortraitRig and _is_portrait_destination(path):
		dock.set_status("This destination contains a portrait camera and speaking rig. Open that portrait scene to save the complete portrait, or choose a separate assembly path.", true)
		return
	var validated := Ops.validate_scene_save(root, path)
	if not validated.ok:
		_report(validated, "")
		return
	var stored: Dictionary = MeshStorage.new().store(root, path)
	if not stored.ok:
		_report(stored, "")
		return
	get_editor_interface().save_scene_as(path, false)
	if root.scene_file_path != path or not FileAccess.file_exists(path):
		dock.set_status("The character could not be saved to the chosen path.", true)
		return
	_clear_file_request()
	dock.set_status("Saved %s. Mesh resources: %s" % [path.get_file(), stored.directory] if stored.count > 0 else "Saved %s. Continue editing this character." % path.get_file())
	_refresh()

func _is_portrait_destination(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var existing: PackedScene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	if existing == null:
		return false
	var state := existing.get_state()
	if state.get_node_count() == 0:
		return false
	for index in state.get_node_property_count(0):
		if state.get_node_property_name(0, index) != &"script":
			continue
		var script: Script = state.get_node_property_value(0, index)
		while script != null:
			if script.resource_path == "res://ui/portraits/portrait_rig.gd":
				return true
			script = script.get_base_script()
	return false

func _pick_attachment(target: Node3D) -> void:
	if _has_moved_references():
		dock.set_status("Repair moved / renamed references before changing this assembly.", true)
		return
	if not is_instance_valid(_attach_part):
		dock.set_status("Select a part and start Attach again.", true)
		return
	if not is_instance_valid(target) or target == _attach_part or _attach_part.is_ancestor_of(target):
		dock.set_status("Choose another part outside the selected part's hierarchy.", true)
		return
	var result: Dictionary = commands.attach_selected(_attach_part, target, 1)
	if result.get("ok", false):
		_tool = "move"
		_attach_part = null
		dock.set_tool(_tool)
	_report(result, "Attached to %s without moving. Bone attachment is available under More." % target.name)

func _import_source_selected(path: String) -> void:
	var error := _validate_import_source(path)
	if not error.is_empty():
		dock.set_status(error, true)
		return
	_import_source = path
	_import_root = _scene_root()
	_import_dialogs.get_node("Destination").popup_centered_ratio(0.65)

func _import_destination_selected(folder: String) -> void:
	if not _import_pending.is_empty():
		dock.set_status("Wait for the current model import to finish.", true)
		return
	if not folder.begins_with("res://") or not DirAccess.dir_exists_absolute(folder):
		dock.set_status("Choose an existing project folder.", true)
		return
	var validation := _validate_import_source(_import_source)
	if not validation.is_empty():
		dock.set_status(validation, true)
		return
	var path := folder.path_join(_import_source.get_file()).simplify_path()
	if not path.begins_with("res://") or FileAccess.file_exists(path):
		dock.set_status("That filename already exists. Choose another folder; existing assets are preserved.", true)
		return
	var error := DirAccess.copy_absolute(_import_source, ProjectSettings.globalize_path(path))
	if error != OK:
		dock.set_status("Import copy failed: %s." % error_string(error), true)
		return
	_import_pending = path
	_import_scan_needed = true
	dock.set_status("Importing %s into %s…" % [_import_source.get_file(), folder])
	var filesystem := get_editor_interface().get_resource_filesystem()
	if not filesystem.is_scanning() and not filesystem.is_importing():
		_import_scan_needed = false
		filesystem.scan()

func _finish_import() -> void:
	if _import_pending.is_empty() or _import_scan_needed:
		return
	var filesystem := get_editor_interface().get_resource_filesystem()
	if filesystem.is_scanning() or filesystem.is_importing():
		return
	var path := _import_pending
	if filesystem.get_file_type(path).is_empty():
		return
	_import_pending = ""
	var directory := filesystem.get_filesystem_path(path.get_base_dir())
	var import_valid := false
	if directory != null:
		for index: int in directory.get_file_count():
			if directory.get_file_path(index) == path:
				import_valid = directory.get_file_import_is_valid(index)
				break
	if not import_valid or not ResourceLoader.exists(path, "PackedScene"):
		dock.set_status("Copied %s, but Godot could not import it. Review the import errors." % path, true)
		return
	if is_instance_valid(_import_root) and _scene_root() == _import_root:
		_files_selected(PackedStringArray([path]))
	else:
		dock.set_status("Imported %s. Add it from Assets when your character is open." % path)

func _validate_import_source(path: String) -> String:
	if path.get_extension().to_lower() != "glb" or not FileAccess.file_exists(path):
		return "Choose a self-contained GLB. Import other formats through Godot's FileSystem first."
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 20:
		return "This file is not a valid GLB model."
	if file.get_32() != 0x46546C67 or file.get_32() != 2 or file.get_32() != file.get_length():
		return "This file is not a valid GLB 2 model."
	var json_length := file.get_32()
	if file.get_32() != 0x4E4F534A or json_length > 32 * 1024 * 1024 or json_length + 20 > file.get_length():
		return "The GLB model has an invalid JSON header."
	var parser := JSON.new()
	if parser.parse(file.get_buffer(json_length).get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return "The GLB model has an invalid JSON header."
	for key: String in ["images", "buffers"]:
		var resources: Variant = parser.data.get(key, [])
		if not resources is Array:
			return "The GLB model has an invalid resource list."
		for resource: Variant in resources:
			if not resource is Dictionary:
				return "The GLB model has an invalid resource entry."
			var uri := str(resource.get("uri", ""))
			if not uri.is_empty() and not uri.begins_with("data:"):
				return "This GLB uses external textures or buffers. Import its complete folder through Godot first."
	return ""

func _file_selected(path: String) -> void:
	match _file_action:
		"open":
			if not ResourceLoader.exists(path, "PackedScene"):
				dock.set_status("Choose an existing character scene.", true)
				return
			get_editor_interface().open_scene_from_path(path)
			if _scene_root() != null:
				call_deferred("_open_workspace", _scene_root().get_instance_id())
		"save", "save_as":
			_save_current_scene(path)
		"save_actor":
			dock.cancel_drag()
			_restore_preview()
			if _scene_root() is PortraitRig or _is_portrait_destination(path):
				dock.set_status("Portrait scenes keep their camera and speaking rig. Use Save for the portrait; gameplay actors need a separate assembly and output path.", true)
				return
			if _has_moved_references():
				dock.set_status("Repair moved / renamed references before exporting this character.", true)
				return
			if _scene_root() is CharacterBody3D:
				_report(Ops.save_scene(_scene_root(), path), "Edited gameplay actor saved to %s." % path)
				return
			var service_path := "res://actors/assembly/actor_export_service.gd"
			if not ResourceLoader.exists(service_path):
				dock.set_status("Gameplay export service is unavailable.", true)
				return
			var service: Script = load(service_path)
			_report(service.export_actor(_scene_root(), path), "Editable gameplay actor saved to %s." % path)
			get_editor_interface().get_resource_filesystem().scan()
		"replace":
			if not is_instance_valid(_pending_part):
				dock.set_status("The part was removed while the dialog was open. Select another part.", true)
				return
			_report(commands.replace_selected(_pending_part, path, _policy), "Replacement retained placement and the chosen attachment policy.")
		"add":
			_files_selected(PackedStringArray([path]))
		"legacy":
			var service_path := "res://actors/assembly/legacy_outfit_service.gd"
			if not ResourceLoader.exists(service_path):
				dock.set_status("Legacy conversion service is unavailable.", true)
				return
			var service: Script = load(service_path)
			var result: Dictionary = commands.add_prepared_parts(service.prepare(_scene_root(), path))
			_report(result, "Legacy data imported into independent editable parts. %s" % " ".join(result.get("warnings", [])))
		"borrow":
			var service_path := "res://actors/assembly/animation_service.gd"
			if not ResourceLoader.exists(service_path) or dock.current_part == null:
				dock.set_status("Select a rigged part and ensure the animation service is available.", true)
				return
			preview.stop()
			var service: Script = load(service_path)
			_report(commands.install_animation_library(service.borrow(dock.current_part.get_node("Model"), path)), "Compatible independent clips installed. Pick a clip to preview; native/borrrowed gameplay mappings are retained.")

func _files_selected(paths: PackedStringArray, world_position: Variant = null) -> void:
	for path: String in paths:
		_report(commands.add_source(path, world_position), "Added %s. Rename in the hierarchy and fit with its handles." % path.get_file())

func _restore_focus_mode() -> void:
	if _focus_active:
		get_editor_interface().set_distraction_free_mode(_focus_before)
		_focus_active = false
		if is_instance_valid(dock):
			dock.get_node("%FocusMode").set_pressed_no_signal(false)

func _create_from_template(path: String) -> void:
	dock.cancel_drag()
	if not ResourceLoader.exists(path, "PackedScene"):
		dock.set_status("Template unavailable: %s" % path, true)
		return
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		dock.set_status("Template unavailable: %s" % path, true)
		return
	var source := scene.instantiate()
	if not source is Assembly:
		source.free()
		dock.set_status("Choose a CharacterAssembly template.", true)
		return
	var copy := Ops.independent_snapshot(source)
	source.free()
	if copy == null:
		dock.set_status("The template could not be copied.", true)
		return
	_restore_preview()
	var editor := get_editor_interface()
	# Clear the scene dock's selected-node pointer before its old root is
	# detached. Clearing EditorSelection alone leaves that native pointer stale.
	editor.edit_node(null)
	if editor.get_edited_scene_root() != null:
		var shortcut := editor.get_editor_settings().get_shortcut("editor/new_scene")
		if shortcut == null:
			copy.free()
			dock.set_status("Godot's New Scene command is unavailable.", true)
			return
		var event := InputEventShortcut.new()
		event.shortcut = shortcut
		editor.get_base_control().get_viewport().push_input(event, false)
		if editor.get_edited_scene_root() != null:
			copy.free()
			dock.set_status("Godot could not open a new scene tab. Your current scene is unchanged.", true)
			return
	# An empty path makes this an independent, unsaved scene, not an inherited
	# template. Only the user's later Save/Save As chooses a disk destination.
	copy.scene_file_path = ""
	editor.add_root_node(copy)
	editor.mark_scene_as_unsaved()
	dock.get_node("%Templates").select(0)
	_select(copy)
	editor.set_main_screen_editor(_get_plugin_name())
	call_deferred("_open_workspace", copy.get_instance_id())
	_refresh()
	dock.set_status("New unsaved character from %s. Edit it, then choose Save As when ready." % path.get_file().get_basename().capitalize())

func _load_templates() -> void:
	var paths := PackedStringArray()
	var directory := DirAccess.open("res://actors/assembly/templates")
	if directory != null:
		for file: String in directory.get_files():
			if file.ends_with(".tscn"):
				paths.append("res://actors/assembly/templates/" + file)
	paths.sort()
	dock.set_templates(paths)

func _prepare_remove_or_replace(action: String, part: Node3D) -> void:
	if part == null:
		dock.set_status("Select a part first.", true)
		return
	_pending_action = action
	_pending_part = part
	_policy = "cancel"
	if commands.dependents(part).is_empty():
		_finish_remove_or_replace()
	else:
		var options: OptionButton = dock.get_node("%DependencyPolicy")
		options.clear()
		options.add_item("Keep attachments as free parts", 0)
		options.add_item("Remove this part and all attachments", 1)
		if action == "replace":
			options.add_item("Reconnect matching target paths / bones", 2)
		dock.get_node("%Dependents").popup_centered(Vector2i(470, 180))

func _dependents_confirmed() -> void:
	_policy = ["keep_free", "remove_all", "reconnect"][dock.get_node("%DependencyPolicy").get_selected_id()]
	_finish_remove_or_replace()

func _finish_remove_or_replace() -> void:
	if _pending_action == "remove":
		_report(commands.remove_selected(_pending_part, _policy), "Part removed with the chosen dependent policy. Undo restores it.")
	else:
		_show_file("replace", FileDialog.FILE_MODE_OPEN_FILE, ["*.tscn, *.scn, *.glb, *.gltf, *.obj, *.fbx, *.blend, *.dae ; 3D models and prefabs"])

func _bind(part: Node3D, donor: Node3D) -> void:
	if _binding_busy:
		dock.set_status("Binding is already running. Cancel it or wait for completion.", true)
		return
	if part == null or donor == null:
		dock.set_status("Select a garment and choose its donor target.", true)
		return
	if not commands.dependents(part).is_empty():
		dock.set_status("Detach this part's dependent attachments before converting its Model.", true)
		return
	if not part.get("geometry_masks").is_empty():
		dock.set_status("Reset this part's mesh exclusions before binding, then reapply them to the bound result.", true)
		return
	var path := "res://actors/assembly/binding_service.gd"
	if not ResourceLoader.exists(path):
		dock.set_status("Binding service is unavailable; attachment retains the original model.", true)
		return
	dock.set_status("Binding clothing… This explicit conversion may take a moment.")
	var service: Script = load(path)
	_binding_busy = true
	_binding_cancel = false
	dock.get_node("%CancelBinding").show()
	preview.stop()
	var progress := func(value: float):
		if is_instance_valid(dock):
			dock.set_status("Binding clothing: %d%%. You may cancel; stale results cannot replace edited models." % int(value * 100.0))
	var cancelled := func() -> bool: return _binding_cancel or not is_instance_valid(dock)
	var result: Dictionary = await service.bind_part_async(part, donor, progress, cancelled)
	_binding_busy = false
	if not is_instance_valid(dock):
		if result.get("model") is Node and is_instance_valid(result.model):
			result.model.free()
		return
	dock.get_node("%CancelBinding").hide()
	if _binding_cancel:
		if result.get("model") is Node and is_instance_valid(result.model):
			result.model.free()
		dock.set_status("Binding cancelled; the original Model is retained.")
		return
	if not is_instance_valid(part) or not is_instance_valid(donor):
		if result.get("model") is Node and is_instance_valid(result.model):
			result.model.free()
		dock.set_status("Binding cancelled because its part or donor was removed.", true)
		return
	var applied: Dictionary = commands.apply_binding(part, result, donor)
	if not applied.get("ok", false) and result.get("model") is Node and is_instance_valid(result.model):
		result.model.free()
	_report(applied, "Clothing bound. Undo restores the whole original Model; fit provenance is retained.")

func _geometry_source() -> Mesh:
	if not is_instance_valid(dock.current_part) or not is_instance_valid(dock.current_mesh):
		return null
	return commands.reference_mesh(dock.current_part, dock.current_mesh)

func _update_geometry_info() -> void:
	var mesh := _geometry_source()
	dock.set_surface_choices(mesh.get_surface_count() if mesh != null else 0)
	var count := 0
	for surface: Variant in face_selection:
		count += face_selection[surface].size()
	var excluded := 0
	var mask: Resource = commands.mask_for(dock.current_part, dock.current_mesh)
	if mask != null:
		for surface: Variant in mask.excluded_faces:
			excluded += mask.excluded_faces[surface].size()
	dock.set_face_count(count, excluded)
	dock.set_face_selection(dock.current_mesh, mesh, face_selection)
	update_overlays()

func _combine_selection(faces: Dictionary) -> void:
	for surface: Variant in faces:
		var values: PackedInt32Array = face_selection.get(surface, PackedInt32Array())
		for face: int in faces[surface]:
			var index := values.find(face)
			if dock.subtract_requested() and index >= 0:
				values.remove_at(index)
			elif not dock.subtract_requested() and index < 0:
				values.append(face)
		if values.is_empty():
			face_selection.erase(surface)
		else:
			face_selection[surface] = values
	_update_geometry_info()

func _select_box() -> void:
	var source := _geometry_source()
	if source == null:
		dock.set_status("Choose a mesh first.", true)
		return
	_set_face_mode(true)
	dock.get_node("%FaceMode").set_pressed_no_signal(face_mode)
	_combine_selection(MeshOps.faces_in_box(source, dock.box_bounds()))

func _select_surface() -> void:
	var source := _geometry_source()
	if source == null:
		dock.set_status("Choose a mesh first.", true)
		return
	_set_face_mode(true)
	dock.get_node("%FaceMode").set_pressed_no_signal(face_mode)
	var faces: Dictionary = {}
	for surface: int in source.get_surface_count():
		if dock.selected_surface() >= 0 and surface != dock.selected_surface():
			continue
		var arrays: Array = source.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		var count: int = int(indices.size() / 3) if indices != null and not indices.is_empty() else int(arrays[Mesh.ARRAY_VERTEX].size() / 3)
		var ordinals := PackedInt32Array()
		for index: int in count:
			ordinals.append(index)
		faces[surface] = ordinals
	_combine_selection(faces)

func _set_face_mode(enabled: bool) -> void:
	if enabled == face_mode:
		return
	if enabled and _geometry_source() == null:
		dock.set_status("Select a mesh first.", true)
		dock.get_node("%FaceMode").set_pressed_no_signal(false)
		return
	if enabled:
		preview.stop()
		var root := _scene_root()
		for node: Node in _nodes(root):
			if node is Skeleton3D:
				var poses: Array[Transform3D] = []
				for index: int in node.get_bone_count():
					poses.append(node.get_bone_pose(index))
				_reference_poses.append({"node": node, "poses": poses})
				node.reset_bone_poses()
		dock.set_status("Reference-pose selection: click faces or select a mesh-space region. Disable this mode to use native transforms.")
	else:
		for entry: Dictionary in _reference_poses:
			if is_instance_valid(entry.node):
				for index: int in mini(entry.poses.size(), entry.node.get_bone_count()):
					entry.node.set_bone_pose(index, entry.poses[index])
		_reference_poses.clear()
	face_mode = enabled
	update_overlays()

func _nodes(root: Node) -> Array:
	if root == null:
		return []
	var result: Array = [root]
	for child: Node in root.get_children():
		result.append_array(_nodes(child))
	return result

func _track_references(root: Node3D) -> void:
	if root != _reference_root:
		_reference_root = root
		_references = Ops.capture_references(root)
	var moved := _has_moved_references()
	dock.get_node("%RepairReferences").disabled = not moved
	if moved:
		dock.set_status("A scene-tree edit moved or renamed a retained target. Click Repair moved / renamed references before saving.", true)
	else:
		_references = Ops.capture_references(root)

func _has_moved_references() -> bool:
	for state: Dictionary in _references:
		var base: Node = state.get("base")
		var target: Node = state.get("target")
		var object: Object = state.get("object")
		if not is_instance_valid(base) or not is_instance_valid(target) or not is_instance_valid(object):
			continue
		if _reference_root == null or not _reference_root.is_ancestor_of(base) or not _reference_root.is_ancestor_of(target):
			continue
		var path: NodePath = object.get_meta(state.key) if state.get("metadata", false) else object.get(state.key)
		if base.get_node_or_null(path) != target:
			return true
	return false

func _restore_preview() -> void:
	if preview != null:
		preview.stop()
		preview.restore_materials()
	_set_face_mode(false)
	if is_instance_valid(dock):
		dock.get_node("%FaceMode").set_pressed_no_signal(false)
		dock.get_node("%PreviewShade").set_pressed_no_signal(false)

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not _workspace_visible:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	_camera = camera
	if not face_mode or not is_instance_valid(dock.current_mesh):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var source := _geometry_source()
		var inverse: Transform3D = dock.current_mesh.global_transform.affine_inverse()
		var origin := inverse * camera.project_ray_origin(event.position)
		var direction := inverse.basis * camera.project_ray_normal(event.position)
		var hit: Dictionary = MeshOps.ray_face(source, origin, direction)
		if not hit.is_empty():
			_combine_selection({hit.surface: PackedInt32Array([hit.face])})
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS

func _forward_3d_force_draw_over_viewport(control: Control) -> void:
	if not _workspace_visible or not face_mode or face_selection.is_empty() or not is_instance_valid(_camera) or not is_instance_valid(dock.current_mesh):
		return
	var source := _geometry_source()
	if source == null:
		return
	var drawn := 0
	for surface: Variant in face_selection:
		if int(surface) >= source.get_surface_count():
			continue
		var arrays: Array = source.surface_get_arrays(int(surface))
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		for face: int in face_selection[surface]:
			if drawn > 6000:
				return
			var polygon := PackedVector2Array()
			for corner: int in 3:
				var index := face * 3 + corner
				if indices != null and not indices.is_empty():
					if index >= indices.size():
						break
					index = indices[index]
				if index >= vertices.size():
					break
				var world: Vector3 = dock.current_mesh.global_transform * vertices[index]
				if _camera.is_position_behind(world):
					break
				polygon.append(_camera.unproject_position(world))
			if polygon.size() == 3:
				control.draw_colored_polygon(polygon, Color(1.0, 0.5, 0.1, 0.3))
				polygon.append(polygon[0])
				control.draw_polyline(polygon, Color(1.0, 0.6, 0.1, 0.9), 1.0, true)
				drawn += 1
