extends "res://tests/check.gd"
## Manual graphical evidence; reads authored Game and saves only to a unique cache directory.
const ArtOutput := preload("res://tests/art_output.gd")
var clicks: Array[String] = []

func _run() -> void:
	if not check("framing capture requires a rendering window", DisplayServer.get_name() != "headless"):
		finish()
		return
	root.size = Vector2i(1920, 1080)
	var game := instantiate_scene("res://game/game.tscn")
	if game == null:
		finish()
		return
	game.set("skip_cold_open", true)
	root.add_child(game)
	if not check("authored Game starts", await wait_for(func() -> bool: return game.get("initialized") == true, 8.0)):
		game.queue_free()
		finish()
		return
	var output := ArtOutput.new_run("cabin-framing")
	print("Framing evidence: " + output)
	await frames(12)
	check("default framing image saves", await capture(output.path_join("default.png")))
	var location := game.get("location") as Location
	var camera := location.camera
	var reports := {}
	for child in location.find_children("*", "Area3D", true, false):
		var spot := child as Hotspot
		if spot == null: continue
		spot.input_event.connect(func(_camera: Node, event: InputEvent, _point: Vector3, _normal: Vector3, _shape: int) -> void:
			if event is InputEventMouseButton and event.pressed:
				clicks.append(spot.display_name))
		var point := visual_centre(spot.visual)
		var screen := camera.unproject_position(point)
		clicks.clear()
		game.get("interactions").busy = false
		var motion := InputEventMouseMotion.new()
		motion.position = screen
		Input.parse_input_event(motion)
		await frames(3)
		game.get("interactions").busy = true
		var press := InputEventMouseButton.new()
		press.position = screen
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		Input.parse_input_event(press)
		await frames(3)
		var released := press.duplicate() as InputEventMouseButton
		released.pressed = false
		Input.parse_input_event(released)
		await frames(3)
		check("actual click reaches its own hotspot: " + spot.display_name, clicks == [spot.display_name], str(clicks))
		reports[spot.display_name] = {"screen": [screen.x, screen.y], "clicked": clicks.duplicate()}
		if spot.display_name == "Inkwell":
			game.get("interactions").busy = false
			spot.mouse_entered.emit()
			game.get("interactions").busy = true
			check("inkwell hover image saves", await capture(output.path_join("inkwell_hover.png")))
	game.get("interactions").busy = true
	for child in location.find_children("*", "Area3D", true, false):
		if child is Hotspot:
			child.mouse_exited.emit()
	game.get("pointer").clear()
	var person := location.player.definition.cast_entry()
	var caption: Node = game.get("caption")
	caption.reveal_cps = 10000.0
	caption.say(person["name"], "The whole cabin is finally in view. The compass, the inkwell, the rapier... and that suspicious crate.", person["assets"], Color(person["colour"]))
	await frames(12)
	check("speech and portrait framing image saves", await capture(output.path_join("speech.png")))
	caption.hide_box()
	var choices: Node = game.get("choices")
	choices.set_player(person)
	show_choices.call_deferred(choices)
	await frames(12)
	check("response and portrait framing image saves", await capture(output.path_join("responses.png")))
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	Input.parse_input_event(key)
	await frames(3)
	var evidence := {"camera_position": str(camera.position),
		"camera_rotation_degrees": str(camera.rotation_degrees), "fov": camera.fov,
		"framing_profile": camera.get_meta("framing_profile", ""), "picking": reports}
	FileAccess.open(output.path_join("picking.json"), FileAccess.WRITE).store_string(JSON.stringify(evidence, "\t"))
	game.queue_free()
	await frames(3)
	finish()

func show_choices(choices: Node) -> void:
	await choices.ask(["Ask Santi about the suspicious crate.", "Inspect the compass and inkwell.", "Speak to Count Fingers."])

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await RenderingServer.frame_post_draw

func capture(path: String) -> bool:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png(path) == OK

func visual_centre(node: Node3D) -> Vector3:
	var initialized := false
	var bounds := AABB()
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if not initialized else bounds.merge(box)
		initialized = true
	return bounds.get_center()
