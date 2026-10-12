@tool
extends VBoxContainer
## Viewport-first authoring workspace. Hierarchy reflects actual parts and parents.

signal request(action: String, value: Variant)

const Ops = preload("res://actors/assembly/operations.gd")
const Part = preload("res://actors/assembly/part.gd")

var current_part: Node3D
var current_mesh: MeshInstance3D
var current_target: Node3D
var _syncing := false
var _root: Node3D
var _selection: Node3D
var _tool := "move"
var _hierarchy_signature := ""
var _tree_items: Dictionary = {}
var _collapsed: Dictionary = {}
var _editor: EditorInterface
var _attach_source: Node3D
var _attach_candidate: Node3D
var _context_part: Node3D
const PART_ACTIONS := ["rename", "visibility", "replace", "duplicate", "detach", "remove"]

func _ready() -> void:
	for pair: Array in [["New", "new"], ["Open", "open"], ["Save", "save"], ["SaveAs", "save_as"], ["SaveActor", "save_actor"], ["RepairReferences", "repair_references"], ["ImportLegacy", "legacy"], ["BorrowClips", "borrow"], ["Adopt", "adopt"], ["Duplicate", "duplicate"], ["Visibility", "visibility"], ["Remove", "remove"], ["Replace", "replace"], ["Attach", "attach"], ["Detach", "detach"], ["Bind", "bind"], ["CancelBinding", "cancel_binding"], ["SelectBox", "select_box"], ["SelectSurface", "select_surface"], ["ClearFaces", "clear_faces"], ["Exclude", "exclude"], ["Restore", "restore"], ["ResetMesh", "reset_mesh"], ["Play", "play"], ["Stop", "stop"], ["Rest", "rest"], ["Inspector", "inspector"]]:
		var action: String = pair[1]
		get_node("%" + pair[0]).pressed.connect(func(): request.emit(action, null))
	%Parts.item_selected.connect(_part_selected)
	%Parts.item_edited.connect(_part_renamed)
	%Parts.button_clicked.connect(_part_button)
	%Parts.gui_input.connect(_hierarchy_input)
	%Parts.set_drag_forwarding(_hierarchy_drag, _hierarchy_can_drop, _hierarchy_drop)
	%Parts.drop_mode_flags = Tree.DROP_MODE_ON_ITEM
	%Parts.allow_rmb_select = false
	for index: int in PART_ACTIONS.size():
		%PartMenu.add_item(["Rename", "Hide / Show", "Replace…", "Duplicate", "Detach", "Remove"][index], index)
	%PartMenu.id_pressed.connect(_context_action)
	%Targets.item_selected.connect(_target_selected)
	%Meshes.item_selected.connect(_mesh_selected)
	%Mode.add_item("Free placement", 0)
	%Mode.add_item("Parent to a node / part", 1)
	%Mode.add_item("Follow a skeleton bone", 2)
	%FaceMode.toggled.connect(func(value: bool): request.emit("face_mode", value))
	%PreviewShade.toggled.connect(func(value: bool): request.emit("preview_shade", value))
	%Clip.item_selected.connect(func(_index: int): request.emit("clip_changed", null))
	%Loop.toggled.connect(func(value: bool): request.emit("loop", value))
	%Templates.item_selected.connect(func(index: int): request.emit("template", %Templates.get_item_metadata(index)))
	%Players.item_selected.connect(func(_index: int): request.emit("player_changed", null))
	%Mode.item_selected.connect(func(_index: int): _populate_bones())
	%Add.pressed.connect(show_assets)
	%AddHierarchyPart.pressed.connect(show_assets)
	%More.pressed.connect(show_advanced)
	%FocusMode.toggled.connect(func(value: bool): request.emit("focus_mode", value))
	%CancelAttach.pressed.connect(func(): request.emit("tool", "move"))
	%Coordinates.add_item("World axes", 0)
	%Coordinates.add_item("Local axes", 1)
	%Coordinates.item_selected.connect(func(_index: int): _update_view_options())
	%SnapEnabled.toggled.connect(func(_value: bool): _update_view_options())
	for field: String in ["MoveStep", "RotateStep", "ScaleStep"]:
		get_node("%" + field).value_changed.connect(func(_value: float): _update_view_options())
	%GridOverlay.toggled.connect(func(_value: bool): _update_view_options())
	%BoundsOverlay.toggled.connect(func(_value: bool): _update_view_options())
	%AdvancedTools.close_requested.connect(%AdvancedTools.hide)
	%TwoViews.toggled.connect(func(value: bool): %DetailView.visible = value)
	for pair: Array in [["Move", "move"], ["Rotate", "rotate"], ["Scale", "scale"], ["PickAttach", "attach"]]:
		var mode: String = pair[1]
		get_node("%" + pair[0]).pressed.connect(func(): request.emit("tool", mode))
	%MainView.request.connect(_forward_request)
	%DetailView.request.connect(_forward_request)
	%Assets.request.connect(_forward_request)
	_update_view_options()
	set_status("Choose New or a template, then Add part. Select in the hierarchy or either view; W/E/R change tools, F frames selection.")
	set_tool(_tool)

func initialize(editor: EditorInterface) -> void:
	_editor = editor
	%Assets.initialize(editor)

func refresh_catalog() -> void:
	%Assets.refresh_catalog()

func show_assets() -> void:
	%AssetDrawer.visible = not %AssetDrawer.visible
	if %AssetDrawer.visible:
		%Assets.focus_search()

func show_advanced() -> void:
	if %AdvancedTools.visible:
		%AdvancedTools.hide()
	else:
		%AdvancedTools.popup_centered(Vector2i(490, 640))

func _forward_request(action: String, value: Variant) -> void:
	if action == "close_assets":
		%AssetDrawer.hide()
	elif action == "drop_placement":
		%MainView.drop_at_cursor = bool(value)
		%DetailView.drop_at_cursor = bool(value)
	else:
		request.emit(action, value)

func _update_view_options() -> void:
	for view: Control in [%MainView, %DetailView]:
		view.set_fitting_options(%Coordinates.selected == 1, %SnapEnabled.button_pressed, %MoveStep.value, %RotateStep.value, %ScaleStep.value)
		view.show_grid = %GridOverlay.button_pressed
		view.show_bounds = %BoundsOverlay.button_pressed
		view.overlay.queue_redraw()

func set_tool(mode: String) -> void:
	_tool = mode
	for pair: Array in [["Move", "move"], ["Rotate", "rotate"], ["Scale", "scale"], ["PickAttach", "attach"]]:
		get_node("%" + pair[0]).set_pressed_no_signal(mode == pair[1])
	%MainView.set_tool(mode)
	%DetailView.set_tool(mode)
	%AttachmentBanner.visible = mode == "attach"
	set_attachment_candidate(null)

func set_attachment_source(source: Node3D) -> void:
	_attach_source = source
	set_attachment_candidate(_attach_candidate)

func set_attachment_candidate(candidate: Node3D) -> void:
	_attach_candidate = candidate if is_instance_valid(candidate) else null
	var source_name := str(_attach_source.name) if is_instance_valid(_attach_source) else "part"
	var target_name := str(candidate.name) if is_instance_valid(candidate) else "choose a parent"
	%AttachmentPrompt.text = "Attach %s → %s" % [source_name, target_name]
	%AttachmentPrompt.tooltip_text = "Placement is preserved. Click a valid parent or Cancel attach."
	for view: Control in [%MainView, %DetailView]:
		view.attachment_candidate = _attach_candidate
	for identity: int in _tree_items:
		var item: TreeItem = _tree_items[identity]
		if item.get_metadata(0) == _attach_candidate and _tool == "attach":
			item.set_custom_bg_color(0, Color(0.15, 0.35, 0.28, 0.45))
		else:
			item.clear_custom_bg_color(0)

func cancel_drag() -> void:
	%MainView.cancel_drag()
	%DetailView.cancel_drag()

func set_face_selection(mesh: MeshInstance3D, source: Mesh, faces: Dictionary) -> void:
	%MainView.set_face_selection(mesh, source, faces)
	%DetailView.set_face_selection(mesh, source, faces)

func frame_all() -> void:
	%MainView.frame_all()
	%DetailView.frame_all()

func frame_selected() -> void:
	%MainView.frame_selected()
	%DetailView.frame_selected()

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type", "") == "files" and data.get("files", []).size() > 0

func _drop_data(_position: Vector2, data: Variant) -> void:
	request.emit("add_paths", data.files)

func set_status(message: String, is_error: bool = false) -> void:
	%Status.text = message
	%Status.modulate = Color(1.0, 0.55, 0.4) if is_error else Color.WHITE

func populate(root: Node3D, parts: Array, selected: Node3D) -> void:
	_syncing = true
	var scene_changed := root != _root
	var selection_changed := selected != _selection
	_root = root
	_selection = selected
	current_part = selected if selected is Part and parts.has(selected) else null
	_populate_hierarchy(root, parts, selected, selection_changed)
	%AssemblyTitle.text = str(root.name) + (" · unsaved" if root.scene_file_path.is_empty() else "") if root != null else "Character Workshop"
	%AssemblyTitle.tooltip_text = root.scene_file_path if root != null else "Open or create an assembly."
	%PartInfo.text = str(selected.name) if selected != null else "Select a part"
	%PartInfo.tooltip_text = str(current_part.get("source_path")) if current_part != null else "Select a part in the hierarchy or viewport."
	%AttachmentInfo.text = _attachment_description(current_part)
	%MainView.set_context(root, selected)
	%DetailView.set_context(root, selected)
	if scene_changed:
		%MainView.frame_all()
		%DetailView.frame_selected() if selected != null else %DetailView.frame_all()
	elif selection_changed and selected != null:
		%DetailView.frame_selected()
	for name: String in ["Duplicate", "Visibility", "Remove", "Replace", "Attach", "Detach", "Bind", "Exclude", "Restore", "ResetMesh"]:
		get_node("%" + name).disabled = current_part == null
	%PickAttach.disabled = current_part == null
	%Inspector.disabled = selected == null
	%Save.disabled = root == null
	%SaveAs.disabled = root == null
	%AdvancedHint.text = "Selected: " + str(selected.name) if selected != null else "Select a part for attachment and geometry tools."
	%Targets.clear()
	if root != null:
		for node: Node in _nodes(root):
			if node is Node3D and (selected == null or (node != selected and not selected.is_ancestor_of(node))):
				var index: int = %Targets.item_count
				var label := str(root.get_path_to(node))
				if node is Skeleton3D:
					label += " · Skeleton (%d bones)" % node.get_bone_count()
				%Targets.add_item(label)
				%Targets.set_item_metadata(index, node)
				%Targets.set_item_tooltip(index, label)
				if node == current_target:
					%Targets.select(index)
	current_target = %Targets.get_item_metadata(%Targets.selected) if %Targets.item_count > 0 else null
	_populate_bones()
	var old_mesh: MeshInstance3D = current_mesh if is_instance_valid(current_mesh) else null
	%Meshes.clear()
	if current_part != null:
		for node: Node in _nodes(current_part):
			if node is MeshInstance3D and node.mesh != null and Ops.nearest_part(node) == current_part:
				var index: int = %Meshes.item_count
				%Meshes.add_item(str(current_part.get_path_to(node)))
				%Meshes.set_item_metadata(index, node)
				if node == old_mesh:
					%Meshes.select(index)
	current_mesh = %Meshes.get_item_metadata(%Meshes.selected) if %Meshes.item_count > 0 else null
	%Meshes.disabled = %Meshes.item_count == 0
	%FaceMode.disabled = current_mesh == null
	%Mode.disabled = current_part == null
	%Targets.disabled = current_part == null or %Targets.item_count == 0
	%Bones.disabled = current_part == null or not current_target is Skeleton3D
	for action: String in ["SelectBox", "SelectSurface", "ClearFaces"]:
		get_node("%" + action).disabled = current_mesh == null
	var old_player: AnimationPlayer = selected_player()
	%Players.clear()
	if root != null:
		for node: Node in _nodes(root):
			if node is AnimationPlayer:
				var index: int = %Players.item_count
				%Players.add_item(str(root.get_path_to(node)))
				%Players.set_item_metadata(index, node)
				if node == old_player:
					%Players.select(index)
	_populate_clips()
	%Statistics.text = _statistics(current_part)
	_syncing = false

func _populate_hierarchy(root: Node3D, parts: Array, selected: Node3D, reveal_selection: bool = false) -> void:
	var signature := "%s:%s" % [root.get_instance_id(), root.name] if root != null else "empty"
	for part: Node3D in parts:
		var parent: Node3D = _hierarchy_parent(part, root, parts)
		signature += "|%s:%s:%s:%s:%s" % [part.get_instance_id(), part.name, parent.get_instance_id() if parent != null else 0, part.visible, part.get("bone_name")]
	if signature != _hierarchy_signature:
		_remember_collapsed(%Parts.get_root())
		%Parts.clear()
		_tree_items.clear()
		_hierarchy_signature = signature
		var tree_root: TreeItem = %Parts.create_item()
		tree_root.set_text(0, str(root.name) if root != null else "No character open")
		tree_root.set_metadata(0, root)
		tree_root.set_editable(0, true)
		tree_root.set_selectable(0, root != null)
		if root != null:
			_tree_items[root.get_instance_id()] = tree_root
			tree_root.collapsed = _collapsed.get(root.get_instance_id(), false)
			for part: Node3D in parts:
				_hierarchy_item(part, root, parts, tree_root)
	%Parts.deselect_all()
	if selected != null and _tree_items.has(selected.get_instance_id()):
		var item: TreeItem = _tree_items[selected.get_instance_id()]
		if reveal_selection:
			var ancestor := item.get_parent()
			while ancestor != null:
				ancestor.collapsed = false
				ancestor = ancestor.get_parent()
		item.select(0)
		if reveal_selection:
			%Parts.scroll_to_item(item)

func _hierarchy_parent(part: Node3D, root: Node3D, parts: Array) -> Node3D:
	var parent: Node = part.get_parent()
	while parent != null and parent != root:
		if parent is Part and parts.has(parent):
			return parent as Node3D
		parent = parent.get_parent()
	return root

func _hierarchy_item(part: Node3D, root: Node3D, parts: Array, tree_root: TreeItem) -> TreeItem:
	var identity := part.get_instance_id()
	if _tree_items.has(identity):
		return _tree_items[identity]
	var parent := _hierarchy_parent(part, root, parts)
	var parent_item := tree_root
	if parent != null and parent != root:
		parent_item = _hierarchy_item(parent, root, parts, tree_root)
	var item: TreeItem = %Parts.create_item(parent_item)
	_tree_items[identity] = item
	var bone: String = str(part.get("bone_name"))
	item.set_text(0, str(part.name))
	item.set_metadata(0, part)
	item.set_editable(0, true)
	item.add_button(0, get_theme_icon("GuiVisibilityVisible" if part.visible else "GuiVisibilityHidden", "EditorIcons"), 0, false, "Hide part" if part.visible else "Show part")
	item.collapsed = _collapsed.get(identity, false)
	var attachment := "\nBone: " + bone if not bone.is_empty() else ""
	item.set_tooltip_text(0, "%s\n%s%s\nID: %s" % [root.get_path_to(part), part.get("source_path"), attachment, part.get("part_id")])
	if has_theme_icon("Node3D", "EditorIcons"):
		item.set_icon(0, get_theme_icon("Node3D", "EditorIcons"))
	return item

func _remember_collapsed(item: TreeItem) -> void:
	if item == null:
		return
	var node: Variant = item.get_metadata(0)
	if is_instance_valid(node):
		_collapsed[node.get_instance_id()] = item.collapsed
	for child: TreeItem in item.get_children():
		_remember_collapsed(child)

func _nodes(node: Node) -> Array:
	var values: Array = [node]
	for child: Node in node.get_children():
		values.append_array(_nodes(child))
	return values

func _part_selected() -> void:
	if not _syncing:
		var item: TreeItem = %Parts.get_selected()
		request.emit("select", item.get_metadata(0) if item != null else null)

func _attachment_description(part: Node3D) -> String:
	if not is_instance_valid(part):
		return "Select a part to see its attachment."
	if int(part.get("attachment_mode")) == 0:
		return "Free placement"
	var target: Node = part.get_node_or_null(part.get("target_path"))
	if target == null:
		return "Attachment target is missing. Choose a parent again."
	var bone := str(part.get("bone_name"))
	return "Attached to %s%s" % [target.name, " · " + bone if not bone.is_empty() else ""]

func _part_renamed() -> void:
	var item: TreeItem = %Parts.get_edited()
	if item != null:
		var node: Node3D = item.get_metadata(0)
		var requested := item.get_text(0)
		item.set_text(0, str(node.name))
		request.emit("rename_part", {"part": node, "name": requested})

func _part_button(item: TreeItem, _column: int, _id: int, mouse_button: int) -> void:
	if mouse_button == MOUSE_BUTTON_LEFT:
		request.emit("part_action", {"part": item.get_metadata(0), "action": "visibility"})

func _context_action(index: int) -> void:
	if not is_instance_valid(_context_part):
		return
	request.emit("tool", "move")
	if PART_ACTIONS[index] == "rename":
		var item: TreeItem = _tree_items.get(_context_part.get_instance_id())
		if item != null:
			item.select(0)
			%Parts.edit_selected()
	else:
		request.emit("part_action", {"part": _context_part, "action": PART_ACTIONS[index]})

func _hierarchy_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _tool == "attach":
		var item: TreeItem = %Parts.get_item_at_position(event.position)
		request.emit("hover_attach", item.get_metadata(0) if item != null else null)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var item: TreeItem = %Parts.get_item_at_position(event.position)
		if item == null:
			return
		_context_part = item.get_metadata(0)
		for index: int in PART_ACTIONS.size():
			%PartMenu.set_item_disabled(index, _context_part == _root and index != 0)
		%PartMenu.position = Vector2i(%Parts.get_screen_position() + event.position)
		%PartMenu.popup()
		%Parts.accept_event()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		%Parts.edit_selected()
		%Parts.accept_event()

func _hierarchy_drag(position: Vector2) -> Variant:
	var item: TreeItem = %Parts.get_item_at_position(position)
	var node: Variant = item.get_metadata(0) if item != null else null
	if not node is Part:
		return null
	var caption := Label.new()
	caption.text = "Attach " + str(node.name) + " to a parent"
	%Parts.set_drag_preview(caption)
	return {"workshop_part": node, "root": _root}

func _hierarchy_can_drop(position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or data.get("root") != _root:
		return false
	var source: Variant = data.get("workshop_part")
	var item: TreeItem = %Parts.get_item_at_position(position)
	var target: Node3D = item.get_metadata(0) if item != null else null
	return source is Part and is_instance_valid(source) and is_instance_valid(target) and source != target and not source.is_ancestor_of(target) and _root.is_ancestor_of(source)

func _hierarchy_drop(position: Vector2, data: Variant) -> void:
	if _hierarchy_can_drop(position, data):
		var item: TreeItem = %Parts.get_item_at_position(position)
		request.emit("reparent_part", {"part": data.workshop_part, "target": item.get_metadata(0)})

func _target_selected(index: int) -> void:
	current_target = %Targets.get_item_metadata(index)
	_populate_bones()

func _mesh_selected(index: int) -> void:
	current_mesh = %Meshes.get_item_metadata(index)
	request.emit("mesh_changed", null)

func _populate_bones() -> void:
	var selected := selected_bone()
	%Bones.clear()
	if is_instance_valid(current_target) and current_target is Skeleton3D:
		for index: int in current_target.get_bone_count():
			%Bones.add_item(current_target.get_bone_name(index), index)
			if selected == current_target.get_bone_name(index):
				%Bones.select(index)
	%Bones.disabled = not is_instance_valid(current_target) or not current_target is Skeleton3D or %Mode.get_selected_id() != 2

func selected_bone() -> String:
	return %Bones.get_item_text(%Bones.selected) if %Bones.item_count > 0 else ""

func selected_mode() -> int:
	return %Mode.get_selected_id()

func selected_player() -> AnimationPlayer:
	if %Players.item_count > 0:
		var value: Variant = %Players.get_item_metadata(%Players.selected)
		if is_instance_valid(value):
			return value as AnimationPlayer
	return null

func _populate_clips() -> void:
	var name := selected_clip()
	%Clip.clear()
	var player := selected_player()
	if player != null:
		for clip: String in player.get_animation_list():
			var index: int = %Clip.item_count
			%Clip.add_item(clip)
			if name == clip:
				%Clip.select(index)
	%Play.disabled = player == null or %Clip.item_count == 0
	%Stop.disabled = player == null

func selected_clip() -> String:
	return %Clip.get_item_text(%Clip.selected) if %Clip.item_count > 0 else ""

func refresh_clips() -> void:
	_populate_clips()

func loop_requested() -> bool:
	return %Loop.button_pressed

func subtract_requested() -> bool:
	return %Subtract.button_pressed

func box_bounds() -> AABB:
	var centre := Vector3(%CentreX.value, %CentreY.value, %CentreZ.value)
	var size := Vector3(%SizeX.value, %SizeY.value, %SizeZ.value)
	return AABB(centre - size * 0.5, size)

func set_surface_choices(count: int) -> void:
	var selected: int = %Surface.get_selected_id() if %Surface.item_count > 0 else -1
	%Surface.clear()
	%Surface.add_item("Whole mesh", -1)
	for index: int in count:
		%Surface.add_item("Surface %d" % index, index)
		if selected == index:
			%Surface.select(index + 1)

func selected_surface() -> int:
	return %Surface.get_selected_id()

func set_face_count(count: int, excluded: int = 0) -> void:
	%Faces.text = "%d selected · %d excluded\nSelection uses the source reference pose." % [count, excluded]

func set_templates(paths: PackedStringArray) -> void:
	%Templates.clear()
	%Templates.add_item("New from template…")
	%Templates.set_item_metadata(0, "")
	for path: String in paths:
		var index: int = %Templates.item_count
		%Templates.add_item(path.get_file().get_basename().capitalize())
		%Templates.set_item_metadata(index, path)

func _statistics(part: Node3D) -> String:
	if part == null:
		return ""
	var vertices := 0
	var triangles := 0
	var bones := 0
	var shapes := 0
	for node: Node in _nodes(part):
		if Ops.nearest_part(node) != part:
			continue
		if node is MeshInstance3D and node.mesh != null:
			if node.mesh.has_method("get_blend_shape_count"):
				shapes += node.mesh.get_blend_shape_count()
			for surface: int in node.mesh.get_surface_count():
				var arrays: Array = node.mesh.surface_get_arrays(surface)
				vertices += arrays[Mesh.ARRAY_VERTEX].size()
				var indices: Variant = arrays[Mesh.ARRAY_INDEX]
				triangles += int(indices.size() / 3) if indices != null and not indices.is_empty() else int(arrays[Mesh.ARRAY_VERTEX].size() / 3)
		if node is Skeleton3D:
			bones += node.get_bone_count()
	return "%s vertices · %s triangles\n%d bones · %d blend shapes" % [vertices, triangles, bones, shapes]
