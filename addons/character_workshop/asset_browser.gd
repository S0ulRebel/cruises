@tool
extends VBoxContainer
## Read-only project catalogue. Adding/importing is explicitly delegated to the
## workshop; opening this browser never creates or saves authoring resources.

signal request(action: String, value: Variant)

var _editor: EditorInterface
var _filesystem: EditorFileSystem
var _previewer: EditorResourcePreview
var _catalog: Array[String] = []
var _rows: Dictionary = {}
var _previews: Dictionary = {}
var _queued_previews: Dictionary = {}
var _mesh_jobs: Dictionary = {}
var _mesh_preview_busy := false
var _scene_types: Dictionary = {}
var _refresh_pending := false
var _fallback: Texture2D
var _word_pattern := RegEx.new()


func _ready() -> void:
	_word_pattern.compile("[^\\p{L}\\p{N}]+")
	for label: String in ["All assets", "Imported models", "Scene prefabs"]:
		%AssetType.add_item(label)
	%AssetType.item_selected.connect(func(_index: int): _filter_catalog(%AssetSearch.text))
	%AssetFolder.item_selected.connect(func(_index: int): _filter_catalog(%AssetSearch.text))
	%CloseAssets.pressed.connect(func(): request.emit("close_assets", null))
	%DropPlacement.add_item("Drop: authored position", 0)
	%DropPlacement.add_item("Drop: cursor position", 1)
	%DropPlacement.item_selected.connect(func(index: int): request.emit("drop_placement", index == 1))
	%AssetSearch.text_changed.connect(_filter_catalog)
	%AssetList.item_selected.connect(_select_asset)
	%AssetList.item_activated.connect(func(index: int): _select_asset(index); _add_selected())
	%AssetAdd.pressed.connect(_add_selected)
	%AssetImport.pressed.connect(func(): request.emit("import_asset", null))
	%AssetRefresh.pressed.connect(refresh_catalog)
	%AssetList.set_drag_forwarding(_asset_drag_data, Callable(), Callable())
	%AssetList.get_v_scroll_bar().value_changed.connect(func(_value: float): _queue_visible_previews.call_deferred())
	%AssetList.resized.connect(func(): _queue_visible_previews.call_deferred())
	visibility_changed.connect(func(): _queue_visible_previews.call_deferred())
	if _editor != null:
		refresh_catalog.call_deferred()


func initialize(editor: EditorInterface) -> void:
	_disconnect_sources()
	_editor = editor
	if _editor == null:
		return
	_filesystem = _editor.get_resource_filesystem()
	_previewer = _editor.get_resource_previewer()
	_filesystem.filesystem_changed.connect(_schedule_refresh)
	_previewer.preview_invalidated.connect(_preview_invalidated)
	_fallback = _editor.get_base_control().get_theme_icon("PackedScene", "EditorIcons")
	if is_node_ready():
		refresh_catalog.call_deferred()


func _exit_tree() -> void:
	_disconnect_sources()


func _disconnect_sources() -> void:
	if is_instance_valid(_filesystem) and _filesystem.filesystem_changed.is_connected(_schedule_refresh):
		_filesystem.filesystem_changed.disconnect(_schedule_refresh)
	if is_instance_valid(_previewer) and _previewer.preview_invalidated.is_connected(_preview_invalidated):
		_previewer.preview_invalidated.disconnect(_preview_invalidated)


func _schedule_refresh() -> void:
	if not _refresh_pending:
		_refresh_pending = true
		refresh_catalog.call_deferred()


func refresh_catalog() -> void:
	_refresh_pending = false
	if not is_node_ready() or not is_instance_valid(_filesystem):
		return
	_catalog.clear()
	_scene_types.clear()
	_collect_directory(_filesystem.get_filesystem())
	_catalog.sort()
	_populate_folders()
	_filter_catalog(%AssetSearch.text)

func _populate_folders() -> void:
	var previous: String = str(%AssetFolder.get_item_metadata(%AssetFolder.selected)) if %AssetFolder.item_count > 0 else ""
	var folders: Array[String] = []
	for path: String in _catalog:
		var folder := path.get_base_dir()
		if folder not in folders:
			folders.append(folder)
	folders.sort()
	%AssetFolder.clear()
	%AssetFolder.add_item("All folders")
	%AssetFolder.set_item_metadata(0, "")
	for folder: String in folders:
		var index: int = %AssetFolder.item_count
		%AssetFolder.add_item(folder.trim_prefix("res://"))
		%AssetFolder.set_item_metadata(index, folder)
		%AssetFolder.set_item_tooltip(index, folder)
		if folder == previous:
			%AssetFolder.select(index)

func _matches_asset(path: String, query: String) -> bool:
	var extension := path.get_extension().to_lower()
	if %AssetType.selected == 1 and extension in ["tscn", "scn"]:
		return false
	if %AssetType.selected == 2 and extension not in ["tscn", "scn"]:
		return false
	var folder: String = str(%AssetFolder.get_item_metadata(%AssetFolder.selected)) if %AssetFolder.item_count > 0 else ""
	if not folder.is_empty() and not path.begins_with(folder + "/"):
		return false
	var words := _word_pattern.sub(path.to_lower(), " ", true).split(" ", false)
	var search := _word_pattern.sub(query.strip_edges().to_lower(), " ", true).split(" ", false)
	for term: String in search:
		var found := false
		for word: String in words:
			if word.begins_with(term):
				found = true
				break
		if not found:
			return false
	return true


func _collect_directory(directory: EditorFileSystemDirectory) -> void:
	if directory == null:
		return
	for index: int in directory.get_subdir_count():
		var child: EditorFileSystemDirectory = directory.get_subdir(index)
		# Tool UI and fixtures are not character assets. Models and prefabs may
		# otherwise live anywhere in the project, with no required registry.
		if child.get_path() in ["res://addons/character_workshop", "res://tests", "res://tools"]:
			continue
		_collect_directory(child)
	for index: int in directory.get_file_count():
		if directory.get_file_type(index) != &"PackedScene":
			continue
		var path: String = directory.get_file_path(index)
		if path.get_extension().to_lower() not in ["tscn", "scn"] and not directory.get_file_import_is_valid(index):
			continue
		if path.get_extension().to_lower() == "tscn" and not _text_scene_is_3d(path, []):
			continue
		if path.get_extension().to_lower() == "scn" and not _binary_scene_is_3d(path):
			continue
		_catalog.append(path)


func _text_scene_is_3d(path: String, ancestors: Array) -> bool:
	if _scene_types.has(path):
		return bool(_scene_types[path])
	if path in ancestors or ancestors.size() >= 16:
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var resources: Dictionary = {}
	var is_3d := false
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.begins_with("[ext_resource "):
			resources[_header_value(line, "id")] = _header_resource_path(line, path)
		elif line.begins_with("[node "):
			var root_type: String = _header_value(line, "type")
			if not root_type.is_empty():
				is_3d = root_type == "Node3D" or ClassDB.is_parent_class(root_type, "Node3D")
			else:
				var instance: RegEx = RegEx.new()
				instance.compile('instance=ExtResource\\("([^"]+)"\\)')
				var matched: RegExMatch = instance.search(line)
				if matched != null:
					var source: String = str(resources.get(matched.get_string(1), ""))
					if source.begins_with("res://"):
						if source.get_extension().to_lower() == "tscn":
							is_3d = _text_scene_is_3d(source, ancestors + [path])
						elif source.get_extension().to_lower() == "scn":
							is_3d = _binary_scene_is_3d(source)
						else:
							is_3d = _filesystem.get_file_type(source) == &"PackedScene"
			break
	file.close()
	_scene_types[path] = is_3d
	return is_3d


func _binary_scene_is_3d(path: String) -> bool:
	# Binary scenes have no cheap text header. Inspect their saved state without
	# instantiating nodes or running their tool scripts. Ordinary text scenes and
	# imported models never take this resource-loading branch.
	var packed: PackedScene = ResourceLoader.load(path, "PackedScene") as PackedScene
	if packed == null:
		return false
	var state: SceneState = packed.get_state()
	while state != null:
		if state.get_node_count() > 0:
			var root_type: StringName = state.get_node_type(0)
			if root_type != &"":
				return root_type == &"Node3D" or ClassDB.is_parent_class(root_type, &"Node3D")
		state = state.get_base_scene_state()
	return false


func _header_value(header: String, field: String) -> String:
	var expression: RegEx = RegEx.new()
	expression.compile('(?:^| )%s="([^"]*)"' % field)
	var matched: RegExMatch = expression.search(header)
	return matched.get_string(1) if matched != null else ""


func _header_resource_path(header: String, scene_path: String) -> String:
	var uid_text: String = _header_value(header, "uid")
	if uid_text.begins_with("uid://"):
		var uid: int = ResourceUID.text_to_id(uid_text)
		if uid != ResourceUID.INVALID_ID and ResourceUID.has_id(uid):
			return ResourceUID.get_id_path(uid)
	var path: String = _header_value(header, "path")
	if not path.is_empty() and path.is_relative_path():
		path = scene_path.get_base_dir().path_join(path).simplify_path()
	return path


func _filter_catalog(query: String) -> void:
	if not is_node_ready():
		return
	var previous: String = selected_path()
	_rows.clear()
	%AssetList.clear()
	for path: String in _catalog:
		if not _matches_asset(path, query):
			continue
		var extension := path.get_extension().to_upper()
		var source := path.get_base_dir().trim_prefix("res://")
		var caption := "%s\n%s · %s" % [path.get_file().get_basename().replace("_", " "), extension, source]
		var index: int = %AssetList.add_item(caption, _previews.get(path, _fallback))
		%AssetList.set_item_metadata(index, path)
		%AssetList.set_item_tooltip(index, path + "\nDouble-click to add; drag into the fitting view.")
		_rows[path] = index
		if path == previous:
			%AssetList.select(index)
	%AssetCount.text = "%d of %d models / prefabs" % [%AssetList.item_count, _catalog.size()]
	%AssetEmpty.visible = %AssetList.item_count == 0
	%AssetEmpty.text = "No matching assets. Try a different search." if not query.is_empty() else "No 3D models or prefabs imported yet."
	_select_asset(-1)
	_queue_visible_previews.call_deferred()


func selected_path() -> String:
	if not is_node_ready():
		return ""
	var selected: PackedInt32Array = %AssetList.get_selected_items()
	return str(%AssetList.get_item_metadata(selected[0])) if not selected.is_empty() else ""


func focus_search() -> void:
	if is_node_ready():
		%AssetSearch.grab_focus()
		%AssetSearch.select_all()


func _select_asset(_index: int) -> void:
	var path: String = selected_path()
	%AssetAdd.disabled = path.is_empty()
	%AssetPath.text = path if not path.is_empty() else "Select a model or prefab to add."
	%AssetPath.tooltip_text = path


func _add_selected() -> void:
	var path: String = selected_path()
	if not path.is_empty():
		request.emit("add_paths", PackedStringArray([path]))


func _asset_drag_data(position: Vector2) -> Variant:
	var index: int = %AssetList.get_item_at_position(position, true)
	if index < 0:
		return null
	%AssetList.select(index)
	_select_asset(index)
	var path: String = selected_path()
	var preview: VBoxContainer = VBoxContainer.new()
	var image: TextureRect = TextureRect.new()
	image.custom_minimum_size = Vector2(80, 80)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = %AssetList.get_item_icon(index)
	preview.add_child(image)
	var caption: Label = Label.new()
	caption.text = path.get_file()
	preview.add_child(caption)
	%AssetList.set_drag_preview(preview)
	return {"type": "files", "files": PackedStringArray([path])}


func _queue_visible_previews() -> void:
	if not is_node_ready() or not is_visible_in_tree() or not is_instance_valid(_previewer):
		return
	if %AssetList.size.x <= 0.0 or %AssetList.size.y <= 0.0:
		return
	%AssetList.force_update_list_size()
	var scrollbar: VScrollBar = %AssetList.get_v_scroll_bar()
	var visible_rect := Rect2(Vector2(0, scrollbar.value), %AssetList.size)
	for index: int in %AssetList.item_count:
		var item_rect: Rect2 = %AssetList.get_item_rect(index)
		# Hidden/unlaid-out columns can temporarily return negative sentinel
		# sizes. The resize signal schedules another pass after valid layout.
		if item_rect.size.x <= 0.0 or item_rect.size.y <= 0.0:
			continue
		if not item_rect.intersects(visible_rect):
			continue
		var path: String = str(%AssetList.get_item_metadata(index))
		if _previews.has(path) or _queued_previews.has(path) or _mesh_jobs.has(path):
			continue
		_queued_previews[path] = true
		_previewer.queue_resource_preview(path, self, "_preview_ready", null)


func _preview_ready(path: String, preview: Texture2D, _small_preview: Texture2D, _userdata: Variant) -> void:
	_queued_previews.erase(path)
	# PackedScene previews only exist after a native saved-scene screenshot.
	# Imported GLBs need a read-only mesh preview, requested lazily for these
	# visible entries. Do not instantiate scenes or execute their tool scripts.
	if preview == null and is_node_ready() and _rows.has(path) and _editor != null and DisplayServer.get_name() != "headless":
		var error: Error = ResourceLoader.load_threaded_request(path, "PackedScene")
		if error == OK or error == ERR_BUSY:
			_mesh_jobs[path] = true
			return
	_store_preview(path, preview)


func _store_preview(path: String, preview: Texture2D) -> void:
	_previews[path] = preview if preview != null else _fallback
	if is_node_ready() and _rows.has(path):
		%AssetList.set_item_icon(int(_rows[path]), _previews[path])


func _process(_delta: float) -> void:
	if _mesh_preview_busy or _mesh_jobs.is_empty() or not is_visible_in_tree() or _editor == null:
		return
	# Load source resources in the background, then render at most one thumbnail
	# per frame. Mesh/resources remain source data; previews stay in memory.
	for path: String in _mesh_jobs.keys():
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_mesh_jobs.erase(path)
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			_store_preview(path, null)
			continue
		var source: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
		if not _rows.has(path):
			continue
		var mesh: Mesh = representative_mesh(source)
		if mesh == null or mesh.get_surface_count() == 0:
			_store_preview(path, null)
			continue
		_mesh_preview_busy = true
		var meshes: Array[Mesh] = [mesh]
		var previews: Array[Texture2D] = _editor.make_mesh_previews(meshes, 96)
		_mesh_preview_busy = false
		_store_preview(path, previews[0] if not previews.is_empty() else null)
		return


func representative_mesh(source: PackedScene, visited: Array = []) -> Mesh:
	if source == null or source.get_instance_id() in visited:
		return null
	var next: Array = visited + [source.get_instance_id()]
	var state: SceneState = source.get_state()
	var selected: Mesh
	var selected_size := -1.0
	while state != null:
		for index: int in state.get_node_count():
			var mesh: Mesh
			var override_material: Material
			var surface_materials: Dictionary = {}
			var visible := true
			for property: int in state.get_node_property_count(index):
				var name: String = str(state.get_node_property_name(index, property))
				var value: Variant = state.get_node_property_value(index, property)
				if name == "mesh" and value is Mesh:
					mesh = value
				elif name == "material_override" and value is Material:
					override_material = value
				elif name == "visible":
					visible = bool(value)
				elif name.begins_with("surface_material_override/") and value is Material:
					surface_materials[int(name.get_slice("/", 1))] = value
			if not visible:
				continue
			var nested: PackedScene = state.get_node_instance(index)
			var nested_mesh: Mesh = representative_mesh(nested, next) if nested != null else null
			if nested_mesh != null and nested_mesh.get_aabb().size.length_squared() > selected_size:
				selected = nested_mesh
				selected_size = nested_mesh.get_aabb().size.length_squared()
			if mesh == null or mesh.get_aabb().size.length_squared() <= selected_size:
				continue
			selected = mesh
			selected_size = mesh.get_aabb().size.length_squared()
			if override_material != null or not surface_materials.is_empty():
				selected = mesh.duplicate(false) as Mesh
				for surface: int in selected.get_surface_count():
					if override_material != null:
						selected.surface_set_material(surface, override_material)
					elif surface_materials.has(surface):
						selected.surface_set_material(surface, surface_materials[surface])
		state = state.get_base_scene_state()
	return selected


func _preview_invalidated(path: String) -> void:
	_previews.erase(path)
	_queue_visible_previews.call_deferred()
