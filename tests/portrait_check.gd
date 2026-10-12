extends "res://tests/check.gd"
## Exercise the fitted prefab through the real speech and response panels.
const PARTS := ["Hair", "Moustache", "ChinTuft"]

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var definitions: Array[CharacterDefinition] = [load("res://actors/captain_live/character.tres")]
	var caption := instantiate_scene("res://ui/caption.tscn")
	var choices := instantiate_scene("res://ui/choices.tscn")
	root.add_child(caption)
	root.add_child(choices)
	caption.set_characters(definitions)
	choices.set_characters(definitions)
	choices.set_player(definitions[0].cast_entry())
	caption.set_process(false)
	caption.say("Captain Livé", "We will find our compass and sail onward.", "live", Color.WHITE)
	var portrait := caption.get_node("Root/DialoguePanel/Portrait") as Portrait
	check("actual caption displays the fitted portrait", caption.speaking_with_portrait())
	var content := portrait.get_node("TalkingHead/Viewport/Content")
	var rig := content.get_child(0) as Node3D
	var skeleton := rig.get_node(rig.skeleton_path) as Skeleton3D
	var jaw := skeleton.find_bone("Jaw")
	var camera := rig.get_node("Camera") as Camera3D
	var assembly := rig.get_node("Assembly") as Node3D
	var head := rig.get_node("Assembly/SpeakingHead") as Node3D
	var forward := head.global_basis.z.normalized()
	var horizontal_forward := Vector3(forward.x, 0, forward.z).normalized()
	check("head stays frontal with a subtle chin tilt", horizontal_forward.dot(camera.global_basis.z.normalized()) > 0.999 and absf(forward.y) < sin(deg_to_rad(5.0)))
	check("portrait has no world actor or body", rig.find_children("*", "CharacterBody3D", true, false).is_empty())
	var parts := {}
	var authored := {"Camera": camera.transform, "Assembly": assembly.transform, "Head": head.transform}
	var editable_parts := AssemblyOperations.collect_parts(assembly)
	check("all six owner-fitted parts are present", editable_parts.size() == 6)
	for part in editable_parts:
		var path := str(assembly.get_path_to(part))
		parts[path] = part
		authored[path] = part.transform
	for name in PARTS:
		var matches := rig.find_children(name, "Node3D", true, false)
		if not check("one authored portrait part: " + name, matches.size() == 1):
			finish()
			return
		parts[name] = matches[0]
		authored[name] = matches[0].transform
	await frames(3)
	var tuft_rest: Vector3 = parts["ChinTuft"].global_position
	var moustache_rest: Transform3D = parts["Moustache"].global_transform
	var jaw_rest := skeleton.get_bone_pose_rotation(jaw)
	var jaw_motion := 0.0
	var tuft_motion := 0.0
	for i in 24:
		portrait.set_progress(float(i) / 23.0)
		await frames(1)
		jaw_motion = maxf(jaw_motion, jaw_rest.angle_to(skeleton.get_bone_pose_rotation(jaw)))
		tuft_motion = maxf(tuft_motion, tuft_rest.distance_to(parts["ChinTuft"].global_position))
		check("moustache stays on the upper face while speaking", parts["Moustache"].global_transform.is_equal_approx(moustache_rest))
	check("dialogue drives jaw motion", jaw_motion > 0.05, "%.3f radians" % jaw_motion)
	check("chin tuft follows the talking jaw", tuft_motion > 0.01, "%.3f units" % tuft_motion)
	check("speaking preserves the authored assembly, head and camera", camera.transform == authored["Camera"] and assembly.transform == authored["Assembly"] and head.transform == authored["Head"])
	for name in parts:
		check("speaking preserves the editable local fit: " + name, parts[name].transform == authored[name])
	portrait.settle()
	await frames(2)
	check("settling restores the jaw and chin tuft", jaw_rest.is_equal_approx(skeleton.get_bone_pose_rotation(jaw)) and tuft_rest.is_equal_approx(parts["ChinTuft"].global_position))
	check_framing(rig, camera)
	var instance_id := rig.get_instance_id()
	caption.say("Captain Livé", "All aboard.", "live", Color.WHITE)
	check("the same speaker reuses one fitted rig", content.get_child_count() == 1 and content.get_child(0).get_instance_id() == instance_id)
	caption.hide_box()
	check("hide dismisses the portrait", not portrait.visible)
	choices.ask.call_deferred(["Sail onward", "Stay here"])
	await frames(3)
	var choice_portrait := choices.get_node("Root/DialoguePanel/Portrait") as Portrait
	check("responses display the same player portrait", choice_portrait.has_live_head())
	var choice_rig := choice_portrait.get_node("TalkingHead/Viewport/Content").get_child(0)
	check("speech and response portraits have independent rigs", choice_rig.get_instance_id() != instance_id)
	choices.call("_choose", 0)
	await frames(2)
	check("response completion dismisses its portrait", not choice_portrait.visible)
	portrait.speak("missing", "Unknown", Color.WHITE, "None.")
	check("unknown character uses the name placeholder", content.get_child_count() == 0 and not portrait.has_live_head())
	portrait.speak("live", "Captain Livé", Color.WHITE, "Our course is set.")
	check("a portrait can be restored after a missing speaker", content.get_child_count() == 1 and portrait.has_live_head())
	caption.queue_free()
	choices.queue_free()
	await frames(3)
	check("dialogue portraits free cleanly", not is_instance_valid(caption) and not is_instance_valid(choices))
	finish()

func frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame

func check_framing(rig: Node3D, camera: Camera3D) -> void:
	var viewport := camera.get_viewport()
	var safe := Rect2(Vector2.ONE * 4.0, Vector2(viewport.size) - Vector2.ONE * 8.0)
	var fits := true
	for mesh in rig.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		var box: AABB = mesh.get_aabb()
		for i in 8:
			var point: Vector3 = mesh.global_transform * box.get_endpoint(i)
			fits = fits and not camera.is_position_behind(point) and safe.has_point(camera.unproject_position(point))
	check("head, hat and feather fit inside the actual portrait viewport", fits)
