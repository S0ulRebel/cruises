extends "res://tests/check.gd"
## Render the actual dialogue panel; all images go to an isolated diagnostic folder.
const ArtOutput := preload("res://tests/art_output.gd")

func _run() -> void:
	if not check("portrait capture needs a graphical renderer", DisplayServer.get_name() != "headless"):
		finish()
		return
	root.size = Vector2i(1920, 1080)
	var game := instantiate_scene("res://game/game.tscn")
	game.set("skip_cold_open", true)
	root.add_child(game)
	if not check("authored Game initializes", await wait_for(func() -> bool: return game.initialized, 8.0)):
		finish()
		return
	var output := ArtOutput.new_run("portrait-fit")
	print("Portrait evidence: " + output)
	var caption := game.get("caption") as Node
	caption.set_process(false)
	caption.say("Captain Livé", "We will find our compass and sail onward.", "live", Color.WHITE)
	caption.get_node("Root/DialoguePanel/Speech").text = "We will find our compass and sail onward."
	var portrait := caption.get_node("Root/DialoguePanel/Portrait") as Portrait
	var talking_head := portrait.get_node("TalkingHead") as TalkingHead
	var viewport := talking_head.get_node("Viewport") as SubViewport
	var rest: Image
	for entry in [["rest", 0.0], ["speaking", 0.42], ["speaking_wide", 0.73], ["settled", 1.0]]:
		portrait.set_progress(entry[1])
		if entry[0] == "settled": portrait.settle()
		await drawn_frames(3)
		var panel_image := viewport.get_texture().get_image()
		check("portrait frame saves: " + entry[0], panel_image.save_png(output.path_join(entry[0] + ".png")) == OK)
		if entry[0] == "rest":
			rest = panel_image
			check("actual dialogue screenshot saves", root.get_texture().get_image().save_png(output.path_join("dialogue.png")) == OK)
		elif entry[0] == "speaking":
			check("speech changes visible portrait pixels", changed_pixels(rest, panel_image) > 20)
	caption.hide_box()
	var choices := game.get("choices") as Node
	choices.set_player(game.location.player.definition.cast_entry())
	choices.ask.call_deferred(["Sail onward.", "Inspect the compass."])
	await drawn_frames(4)
	check("response screenshot saves", root.get_texture().get_image().save_png(output.path_join("responses.png")) == OK)
	choices.call("_choose", 0)
	await drawn_frames(3)
	game.queue_free()
	await drawn_frames(3)
	finish()

func drawn_frames(count: int) -> void:
	for i in count:
		await physics_frame
		await RenderingServer.frame_post_draw

func changed_pixels(a: Image, b: Image) -> int:
	var changed := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y): changed += 1
	print("Visible speech pixel changes: ", changed)
	return changed
