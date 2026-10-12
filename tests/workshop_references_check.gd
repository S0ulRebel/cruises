extends "res://tests/check.gd"

const Workspace = preload("res://addons/character_workshop/reference_workspace.gd")
const Dock = preload("res://addons/character_workshop/dock.tscn")
const Assembly = preload("res://actors/assembly/assembly.gd")

func _run() -> void:
	var store := {"value": {}}
	var panel := Dock.instantiate()
	root.add_child(panel)
	await process_frame
	var board = panel.get_node("%ReferenceBoard")
	board.workspace.read_preferences = func(): return store.value
	board.workspace.write_preferences = func(value): store.value = value
	var first := Assembly.new()
	first.name = "FirstCharacter"
	root.add_child(first)
	var second := Assembly.new()
	second.name = "SecondCharacter"
	root.add_child(second)
	panel.populate(first, [], null)
	var output := "user://reference_test_%d.png" % OS.get_process_id()
	var image := Image.create(120, 80, false, Image.FORMAT_RGBA8)
	image.fill(Color.CORAL)
	check("fixture image saved only to explicit user destination", image.save_png(output) == OK)
	board.add_images([output, output, "user://unavailable_reference.png", "res://project.godot"])
	check("deduplicate images and reject unavailable/non-image files", board.workspace.state().paths == [output])
	check("unsaved character references write no persistent preferences", store.value.is_empty())
	var view = panel.get_node("%ReferenceView")
	view.surface.size = Vector2(240, 240)
	check("reference automatically opens the second pane", view.visible and not panel.get_node("%DetailView").visible and panel.get_node("%DetailPane").visible)
	check("active image loads at original dimensions", view.texture != null and view.texture.get_size() == Vector2(120, 80))
	var rect: Rect2 = view.image_rect()
	check("Fit preserves aspect ratio and centers image", rect.size.is_equal_approx(Vector2(240, 160)) and rect.position.is_equal_approx(Vector2(0, 40)))
	var point := Vector2(170, 120)
	var anchor := (point - rect.position) / rect.size
	view.zoom_at(2.0, point)
	var zoomed: Rect2 = view.image_rect()
	check("zoom keeps the pointer over the same image coordinate", ((point - zoomed.position) / zoomed.size).is_equal_approx(anchor))
	view.pan(Vector2(13, -9))
	check("pan moves the image by the dragged distance", view.image_rect().position.is_equal_approx(zoomed.position + Vector2(13, -9)))
	panel.get_node("%Detail3D").pressed.emit()
	check("3D switch restores original second viewport", panel.get_node("%DetailView").visible and not view.visible)
	panel.get_node("%DetailReference").pressed.emit()
	check("switching modes retains reference zoom", is_equal_approx(view.zoom, 2.0))
	panel.show_references(true)
	panel.show_assets()
	check("asset drawer replaces reference board without hiding hierarchy", panel.get_node("%AssetDrawer").visible and not board.visible and panel.get_node("%Sidebar").visible)
	panel.show_references(true)
	check("reference board replaces asset drawer", board.visible and not panel.get_node("%AssetDrawer").visible)
	first.scene_file_path = "res://tests/reference_character.tscn"
	panel.populate(first, [], null)
	check("first Save records reference preferences by scene path", store.value.has(first.scene_file_path))
	first.scene_file_path = "res://tests/reference_character_copy.tscn"
	panel.populate(first, [], null)
	check("Save As carries current reference choices to its new destination", store.value[first.scene_file_path].paths == [output])
	var clean_store: Dictionary = store.value.duplicate(true)
	var reopened := Assembly.new()
	reopened.scene_file_path = first.scene_file_path
	var fresh = Workspace.new()
	fresh.read_preferences = func(): return store.value
	fresh.write_preferences = func(value): store.value = value
	fresh.set_context(reopened)
	check("cold workspace restores saved character reference choices", fresh.state().paths == [output] and fresh.state().mode == "reference")
	check("opening a saved character never writes preferences", store.value == clean_store)
	panel.populate(second, [], null)
	check("another unsaved character has independent references", board.workspace.state().paths.is_empty() and view.texture == null)
	panel.populate(first, [], null)
	check("returning to character restores its images", board.workspace.state().active == output)
	board._dialog_root = weakref(first)
	board.context_provider = func(): return second
	board._files_selected(PackedStringArray([output]))
	check("file dialog rejects changed actual editor scene", board.get_node("%ReferenceHint").text.begins_with("Character changed"))
	var actor := CharacterBody3D.new()
	actor.scene_file_path = "res://tests/reference_actor.tscn"
	root.add_child(actor)
	var body := Assembly.new()
	actor.add_child(body)
	body.owner = actor
	panel.populate(body, [], null)
	board._dialog_root = weakref(body)
	board.context_provider = func(): return actor
	board._files_selected(PackedStringArray([output]))
	check("exported actor accepts references on its owned Body", board.workspace.state().paths == [output] and store.value.has(actor.scene_file_path))
	panel.populate(first, [], null)
	board.remove_active()
	check("remove detaches reference and keeps source file", board.workspace.state().paths.is_empty() and FileAccess.file_exists(output))
	check("reference UI creates no game nodes or metadata", first.get_child_count() == 0 and first.get_meta_list().is_empty())
	var stale_store := {"value": {first.scene_file_path: {"paths": ["user://missing.png"], "active": "user://missing.png", "mode": "reference"}}}
	var missing := Assembly.new()
	missing.scene_file_path = first.scene_file_path
	board.workspace = Workspace.new()
	board.workspace.read_preferences = func(): return stale_store.value
	panel.populate(missing, [], null)
	check("missing saved reference shows recoverable empty state", view.texture == null and view.get_node("%ReferenceEmpty").text.begins_with("Reference unavailable"))
	check("missing reference remains removable", not board.get_node("%RemoveReference").disabled)
	check("native project-file drops accept packed path arrays", board._can_drop(Vector2.ZERO, {"type": "files", "files": PackedStringArray([output])}) and view._can_drop(Vector2.ZERO, {"type": "files", "files": PackedStringArray([output])}))
	board.remove_active()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(output))
	reopened.free()
	missing.free()
	panel.queue_free()
	first.queue_free()
	second.queue_free()
	actor.queue_free()
	await process_frame
	finish()
