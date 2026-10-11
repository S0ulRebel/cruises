extends Node3D
const ArtOutput := preload("res://tests/art_output.gd")
## Loads one glTF on its own with nothing else in the scene. If a character looks
## wrong in the room, this says whether the room is at fault or the file is.

func _ready() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 2.6)
	cam.rotation_degrees.x = -8.0
	cam.current = true
	add_child(cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -140, 0)
	fill.light_energy = 0.4
	add_child(fill)

	var scene: PackedScene = load("res://art/characters/captain_live/captain_live_hands.glb")
	var model := scene.instantiate() as Node3D
	add_child(model)

	# What did we actually get?
	_describe(model, 0)

	for i in 8:
		await RenderingServer.frame_post_draw
	var output := ArtOutput.new_run("glbtest").path_join("captain_live.png")
	var saved := get_viewport().get_texture().get_image().save_png(output) == OK
	var rigged := not model.find_children("*", "Skeleton3D", true, false).is_empty()
	var visible_model := not model.find_children("*", "MeshInstance3D", true, false).is_empty()
	print("saved " + output)
	var ok := saved and rigged and visible_model
	print("ALL CHECKS PASSED" if ok else "FAIL model has no rig, mesh or saved frame")
	get_tree().quit(0 if ok else 1)


func _describe(node: Node, depth: int) -> void:
	var line := "  ".repeat(depth) + node.name + "  [" + node.get_class() + "]"
	var skel := node as Skeleton3D
	if skel:
		line += "  bones=%d" % skel.get_bone_count()
	var mi := node as MeshInstance3D
	if mi:
		line += "  skeleton_path=%s  surfaces=%d" % [mi.skeleton, mi.mesh.get_surface_count() if mi.mesh else 0]
		line += "  aabb=%s" % [mi.get_aabb().size.snapped(Vector3.ONE * 0.01)]
	print(line)
	for child in node.get_children():
		_describe(child, depth + 1)
