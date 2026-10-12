@tool
extends RefCounted
## Shared project configuration. Loading never writes defaults or changes content.

const PATH := "res://character_workshop.cfg"
var asset_folders := PackedStringArray(["res://"])
var template_folders := PackedStringArray()
var save_folder := "res://"
var adapter_path := ""
var animation_library := "workshop"

func read() -> String:
	var file := ConfigFile.new()
	if not FileAccess.file_exists(PATH):
		return ""
	var error := file.load(PATH)
	if error != OK:
		return "Cannot read %s: %s" % [PATH, error_string(error)]
	asset_folders = _folders(file.get_value("folders", "assets", PackedStringArray(["res://"])))
	template_folders = _folders(file.get_value("folders", "templates", PackedStringArray()))
	save_folder = str(file.get_value("folders", "save", "res://"))
	adapter_path = str(file.get_value("integration", "adapter", ""))
	animation_library = str(file.get_value("animation", "library", "workshop"))
	return validate()

func validate() -> String:
	for folder: String in asset_folders + template_folders + PackedStringArray([save_folder]):
		if not folder.begins_with("res://") or not DirAccess.dir_exists_absolute(folder):
			return "Choose an existing project folder: " + folder
	if animation_library.is_empty() or animation_library.contains("/") or animation_library.contains(":"):
		return "Animation library needs a nonempty name without / or :."
	if not adapter_path.is_empty():
		if not adapter_path.begins_with("res://") or not ResourceLoader.exists(adapter_path, "Script"):
			return "Choose an existing project adapter script, or leave it empty."
		var script: Script = load(adapter_path)
		if script == null or not script.can_instantiate() or script.get_instance_base_type() != "RefCounted":
			return "The project adapter must be a constructible RefCounted script."
	return ""

func write() -> String:
	var error := validate()
	if not error.is_empty():
		return error
	var file := ConfigFile.new()
	file.set_value("folders", "assets", asset_folders)
	file.set_value("folders", "templates", template_folders)
	file.set_value("folders", "save", save_folder)
	file.set_value("integration", "adapter", adapter_path)
	file.set_value("animation", "library", animation_library)
	var result := file.save(PATH)
	return "" if result == OK else "Could not save %s: %s" % [PATH, error_string(result)]

func create_adapter() -> RefCounted:
	if adapter_path.is_empty() or not validate().is_empty():
		return null
	return (load(adapter_path) as Script).new() as RefCounted

static func _folders(value: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if value is Array or value is PackedStringArray:
		for item: Variant in value:
			var folder := str(item).strip_edges().replace("\\", "/")
			if folder != "res://":
				folder = folder.trim_suffix("/")
			if not folder.is_empty() and not result.has(folder):
				result.append(folder)
	return result
