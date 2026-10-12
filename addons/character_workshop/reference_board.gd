@tool
extends VBoxContainer

signal changed(state: Dictionary)
signal close_requested
const Workspace = preload("res://addons/character_workshop/reference_workspace.gd")
var workspace = Workspace.new()
var context_provider: Callable
var _root: Node
var _dialog_root: WeakRef
var _paths: Array = []
var _active := ""
var _mode := "3d"
var _thumbnails: Dictionary = {}

func _ready() -> void:
	%AddReferences.pressed.connect(browse)
	%RemoveReference.pressed.connect(remove_active)
	%CloseReferences.pressed.connect(func(): close_requested.emit())
	%ReferenceFiles.files_selected.connect(_files_selected)
	%ReferenceImages.item_selected.connect(select_image)
	%ReferenceImages.set_drag_forwarding(Callable(), _can_drop, _drop)
	visibility_changed.connect(func():
		if visible: _rebuild())

func set_context(root: Node) -> void:
	_root = root
	%AddReferences.disabled = not is_instance_valid(root)
	if not workspace.set_context(root):
		return
	var value: Dictionary = workspace.state()
	_paths = value.paths
	_active = value.active
	_mode = value.mode
	_thumbnails.clear()
	_rebuild()
	changed.emit(value)

func set_mode(mode: String) -> void:
	_mode = mode
	_publish()

func browse() -> void:
	if not is_instance_valid(_root):
		return
	_dialog_root = weakref(_root)
	%ReferenceFiles.popup_centered_ratio(0.7)

func _files_selected(paths: PackedStringArray) -> void:
	var actual: Node = context_provider.call() if context_provider.is_valid() else _root
	var current := is_instance_valid(actual) and is_instance_valid(_root) and (actual == _root or actual.is_ancestor_of(_root))
	if _dialog_root == null or _dialog_root.get_ref() != _root or not current:
		%ReferenceHint.text = "Character changed. Open Add images again for this character."
		return
	add_images(Array(paths))

func add_images(paths: Array) -> void:
	if not is_instance_valid(_root):
		return
	var rejected := 0
	for raw: Variant in paths:
		var path := str(raw).replace("\\", "/").simplify_path()
		if not path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"] or not FileAccess.file_exists(path):
			rejected += 1
			continue
		var canonical := ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path().to_lower()
		if _paths.any(func(existing): return ProjectSettings.globalize_path(existing).replace("\\", "/").simplify_path().to_lower() == canonical):
			continue
		var image := Image.new()
		if image.load(ProjectSettings.globalize_path(path)) != OK:
			rejected += 1
			continue
		_paths.append(path)
		_active = path
		var ratio := minf(96.0 / image.get_width(), 96.0 / image.get_height())
		image.resize(maxi(1, roundi(image.get_width() * ratio)), maxi(1, roundi(image.get_height() * ratio)))
		_thumbnails[path] = ImageTexture.create_from_image(image)
	_mode = "reference" if not _active.is_empty() else _mode
	_rebuild()
	_publish()
	if rejected > 0:
		%ReferenceHint.text = "%d unavailable/unsupported image(s) skipped. Use PNG, JPEG or WebP." % rejected

func select_image(index: int) -> void:
	if index < 0 or index >= _paths.size():
		return
	_active = _paths[index]
	_mode = "reference"
	_publish()

func remove_active() -> void:
	var index := _paths.find(_active)
	if index < 0:
		return
	_thumbnails.erase(_active)
	_paths.remove_at(index)
	_active = _paths[mini(index, _paths.size() - 1)] if not _paths.is_empty() else ""
	_rebuild()
	_publish()

func _publish() -> void:
	workspace.update(_paths, _active, _mode)
	%RemoveReference.disabled = _active.is_empty()
	changed.emit(workspace.state())

func _rebuild() -> void:
	%ReferenceImages.clear()
	for path: String in _paths:
		if visible and not _thumbnails.has(path) and FileAccess.file_exists(path):
			var image := Image.new()
			if image.load(ProjectSettings.globalize_path(path)) == OK:
				var ratio := minf(96.0 / image.get_width(), 96.0 / image.get_height())
				image.resize(maxi(1, roundi(image.get_width() * ratio)), maxi(1, roundi(image.get_height() * ratio)))
				_thumbnails[path] = ImageTexture.create_from_image(image)
		var index: int = %ReferenceImages.add_item(path.get_file(), _thumbnails.get(path))
		%ReferenceImages.set_item_tooltip(index, path)
		if path == _active:
			%ReferenceImages.select(index)
	%RemoveReference.disabled = _active.is_empty()
	%ReferenceHint.text = "Choose an image to show beside the character. Project images can be dropped here."

func _can_drop(_position: Vector2, data: Variant) -> bool:
	if not is_instance_valid(_root) or not data is Dictionary or data.get("type") != "files":
		return false
	var files: Variant = data.get("files")
	return (files is Array or files is PackedStringArray) and not files.is_empty() and Array(files).all(func(path): return str(path).get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"])

func _drop(_position: Vector2, data: Variant) -> void:
	add_images(Array(data.files))
