@tool
extends ConfirmationDialog
signal saved
const Config = preload("project_config.gd")
var _editing: RefCounted
var _folder_target := ""

func _ready() -> void:
	confirmed.connect(_save)
	%AddAssetFolder.pressed.connect(func(): _pick_folder("assets"))
	%AddTemplateFolder.pressed.connect(func(): _pick_folder("templates"))
	%ChooseSaveFolder.pressed.connect(func(): _pick_folder("save"))
	%FolderDialog.dir_selected.connect(_folder_selected)
	%SettingsReset.pressed.connect(func(): _populate(Config.new()))

func open() -> void:
	var config = Config.new()
	var error: String = config.read()
	_populate(config)
	%SettingsError.text = error
	popup_centered(Vector2i(620, 560))

func _populate(config: RefCounted) -> void:
	_editing = config
	%AssetFolders.text = "\n".join(config.asset_folders)
	%TemplateFolders.text = "\n".join(config.template_folders)
	%SaveFolder.text = config.save_folder
	%AdapterPath.text = config.adapter_path
	%LibraryName.text = config.animation_library
	%SettingsError.text = ""

func _pick_folder(target: String) -> void:
	_folder_target = target
	%FolderDialog.current_dir = "res://"
	%FolderDialog.popup_centered_ratio(0.7)

func _folder_selected(path: String) -> void:
	match _folder_target:
		"assets": %AssetFolders.text = _append_folder(%AssetFolders.text, path)
		"templates": %TemplateFolders.text = _append_folder(%TemplateFolders.text, path)
		"save": %SaveFolder.text = path

func _append_folder(text: String, path: String) -> String:
	var paths: PackedStringArray = Config._folders(text.split("\n"))
	if not paths.has(path):
		paths.append(path)
	return "\n".join(paths)

func _save() -> void:
	_editing.asset_folders = Config._folders(%AssetFolders.text.split("\n"))
	_editing.template_folders = Config._folders(%TemplateFolders.text.split("\n"))
	_editing.save_folder = %SaveFolder.text.strip_edges()
	_editing.adapter_path = %AdapterPath.text.strip_edges()
	_editing.animation_library = %LibraryName.text.strip_edges()
	var error: String = _editing.write()
	%SettingsError.text = error
	if not error.is_empty():
		return
	hide()
	saved.emit()
