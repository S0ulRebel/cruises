extends Node3D
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

	var scene: PackedScene = load("res://art/characters/captain_live/captain_live_static.glb")
	var model := scene.instantiate() as Node3D
	add_child(model)

	# What did we actually get?
	_describe(model, 0)

	for i in 8:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://glbtest_static.png")
	print("saved glbtest_static.png")
	get_tree().quit()


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
