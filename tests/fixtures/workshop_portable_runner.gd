@tool
extends Node
## Only copied into the explicit, unique external portability fixture project.
const Ops = preload("res://addons/character_workshop/core/assembly_operations.gd")
const Config = preload("res://addons/character_workshop/project_config.gd")
var failures := 0
var count := 0

func _ready() -> void:
	if OS.get_environment("WORKSHOP_PORTABLE_CHECK") == "1":
		_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		failures += 1
		printerr("PORTABLE_FAIL: ", message)
	else:
		print("ok ", message)

func _run() -> void:
	for frame: int in 5:
		await get_tree().process_frame
	var root := get_parent() as Node3D
	if OS.get_cmdline_user_args().has("cold"):
		var parts := Ops.collect_parts(root)
		expect(not Engine.is_editor_hint(), "saved character opens with editor plugin disabled")
		expect(parts.size() == 3, "cold saved scene retains arbitrary parts")
		var body: Node3D = root.get_node("BodyPart")
		expect(body.position.is_equal_approx(Vector3(1, 2, 3)) and body.scale.is_equal_approx(Vector3(1.2, 0.9, 1.1)), "cold fitting survives")
		expect(body.get_node("Model/Skeleton") is Skeleton3D, "cold local rig survives")
		expect((body.get_node("Model/AnimationPlayer") as AnimationPlayer).has_animation("workshop/talk"), "generic borrowed animation namespace survives")
		var accessory: Node3D = parts.filter(func(part: Node3D): return part.name == "Accessory")[0]
		expect(accessory is CWPart and accessory.attachment_mode == CWPart.AttachmentMode.BONE and accessory.bone_name == "Head", "cold bone attachment survives")
		_finish()
		return
	expect(not FileAccess.file_exists(Config.PATH), "installation does not write project configuration")
	var panel: Control = EditorInterface.get_base_control().find_child("CharacterWorkshop", true, false)
	if panel == null:
		expect(false, "copied addon enables without Cruises dependencies")
		_finish()
		return
	var plugin: EditorPlugin = panel.get_signal_connection_list("request")[0].callable.get_object()
	EditorInterface.set_main_screen_editor("Character Workshop")
	plugin._refresh()
	expect(plugin.adapter == null and plugin.config.save_folder == "res://", "standalone defaults need no adapter or setup")
	expect(not panel.get_node("%SaveActor").visible and not panel.get_node("%ImportLegacy").visible, "project-specific actions are optional")
	var browser: Control = panel.get_node("%Assets")
	browser.refresh_catalog()
	expect(browser._catalog.has("res://assets/source.tscn") and browser._catalog.has("res://assets/source.glb"), "fresh project discovers prefabs and imported GLB")
	expect(not browser._catalog.has("res://addons/character_workshop/dock.tscn"), "catalogue excludes plugin UI")
	panel.get_node("%ProjectSettingsButton").pressed.emit()
	var settings: ConfirmationDialog = plugin._settings
	expect(settings.visible, "Settings button opens project setup")
	settings.get_node("%SaveFolder").text = "res://missing_folder"
	settings.confirmed.emit()
	expect(settings.visible and not FileAccess.file_exists(Config.PATH), "invalid folder does not save configuration")
	settings.get_node("%AssetFolders").text = "res://assets\nres://assets/"
	settings.get_node("%TemplateFolders").text = "res://templates"
	settings.get_node("%SaveFolder").text = "res://characters"
	settings.confirmed.emit()
	expect(not settings.visible and FileAccess.file_exists(Config.PATH), "explicit Settings save writes only the project descriptor")
	var reloaded = Config.new()
	expect(reloaded.read().is_empty() and reloaded.asset_folders == PackedStringArray(["res://assets"]) and reloaded.save_folder == "res://characters", "folder settings persist and deduplicate")
	plugin._reload_project_config()
	browser.refresh_catalog()
	expect(browser._catalog.has("res://assets/source.glb") and not browser._catalog.has("res://other/hidden.tscn"), "asset roots actually restrict browsing")
	var templates: OptionButton = panel.get_node("%Templates")
	expect(templates.item_count == 3, "built-in empty and project template are discovered")
	plugin._files_selected(PackedStringArray(["res://assets/source.tscn"]))
	for frame: int in 3:
		await get_tree().process_frame
	var body: Node3D = panel.current_part
	body.name = "BodyPart"
	body.position = Vector3(1, 2, 3)
	body.scale = Vector3(1.2, 0.9, 1.1)
	var source_hash := FileAccess.get_sha256("res://assets/source.tscn")
	var borrowed := CWAnimationService.borrow(body.get_node("Model"), "res://assets/source.tscn")
	var installed: Dictionary = plugin.commands.install_animation_library(borrowed)
	expect(installed.ok, "animation borrowing works in independent project: " + str(installed.get("error", "")))
	plugin._files_selected(PackedStringArray(["res://assets/source.glb"]))
	for frame: int in 3:
		await get_tree().process_frame
	var accessory: Node3D = panel.current_part
	accessory.name = "Accessory"
	var before := accessory.global_transform
	expect(plugin.commands.attach_selected(accessory, body.get_node("Model/Skeleton"), 2, "Head").ok and accessory.global_transform.is_equal_approx(before), "arbitrary imported part attaches with preserved placement")
	var duplicate: Dictionary = plugin.commands.duplicate_selected(accessory)
	expect(duplicate.ok and duplicate.part.part_id != accessory.part_id, "independent duplicate remains editable")
	plugin._refresh()
	panel.get_node("%SaveAs").pressed.emit()
	var dialog: FileDialog = panel.get_node("%FileDialog")
	expect(dialog.current_dir == "res://characters", "Save As starts at configured destination")
	dialog.hide()
	plugin._file_selected("res://characters/assembled.tscn")
	for frame: int in 3:
		await get_tree().process_frame
	expect(root.scene_file_path == "res://characters/assembled.tscn" and FileAccess.file_exists(root.scene_file_path), "native explicit Save As persists assembled character")
	expect(FileAccess.get_file_as_string(root.scene_file_path).length() < 65536, "binary mesh storage keeps scene compact")
	expect(FileAccess.get_sha256("res://assets/source.tscn") == source_hash, "project source prefab remains untouched")
	panel.get_node("%CloseWorkshop").pressed.emit()
	expect(not panel.visible, "portable Workshop closes")
	var history := plugin.get_undo_redo().get_history_undo_redo(plugin.get_undo_redo().get_object_history_id(root))
	history.clear_history()
	_finish()

func _finish() -> void:
	print("PORTABLE_CHECK: %d/%d passed" % [count - failures, count])
	if failures == 0:
		print("CHECKS PASSED: independent project")
	get_tree().quit(0 if failures == 0 else 1)
