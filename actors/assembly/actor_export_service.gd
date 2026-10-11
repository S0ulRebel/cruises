@tool
class_name CharacterActorExportService
extends RefCounted
## Optional, explicit gameplay prefab output. The regular assembly remains a
## static reusable scene; navigation and collision are added only by this action.

static func export_actor(assembly: Node3D, output_path: String) -> Dictionary:
	if assembly == null or output_path.is_empty() or output_path.get_extension() != "tscn":
		return {"ok": false, "error": "Choose an assembly and an explicit .tscn output path."}
	var actor := CharacterBody3D.new()
	actor.name = "CharacterActor"
	actor.set_script(load("res://actors/mover/mover.gd"))
	var body := assembly.duplicate() as Node3D
	body.name = "Body"
	actor.add_child(body)
	var bounds := AABB()
	var found := false
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or mesh.mesh.get_surface_count() == 0 or not _visible_to(mesh, body):
			continue
		var box := RigSpace.chain(mesh, actor) * mesh.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	if not found:
		actor.free()
		return {"ok": false, "error": "The assembly contains no visible mesh geometry."}
	var height := maxf(bounds.size.y, 0.2)
	actor.set("character_height", height)
	var capsule := CapsuleShape3D.new()
	capsule.radius = minf(0.26, height * 0.25)
	capsule.height = height
	var shape := CollisionShape3D.new()
	shape.name = "BodyShape"
	shape.shape = capsule
	shape.position = Vector3(bounds.get_center().x, bounds.position.y + height * 0.5, bounds.get_center().z)
	actor.add_child(shape)
	var agent := NavigationAgent3D.new()
	agent.name = "Agent"
	agent.height = height
	agent.radius = capsule.radius
	agent.path_desired_distance = 0.35
	agent.target_desired_distance = 0.35
	agent.avoidance_enabled = true
	actor.add_child(agent)
	var obstacle := NavigationObstacle3D.new()
	obstacle.name = "Obstacle"
	obstacle.height = height
	obstacle.radius = capsule.radius
	obstacle.avoidance_enabled = false
	obstacle.affect_navigation_mesh = false
	obstacle.carve_navigation_mesh = false
	actor.add_child(obstacle)
	var players := body.find_children("*", "AnimationPlayer", true, false)
	for node in players:
		var player := node as AnimationPlayer
		var idle: String = "idle" if player.has_animation("idle") else "captain/idle"
		var walk: String = "walk" if player.has_animation("walk") else "captain/walk"
		if player.has_animation(idle) and player.has_animation(walk):
			actor.set("idle_animation", StringName(idle))
			actor.set("walk_animation", StringName(walk))
			actor.set("animation_player_path", actor.get_path_to(player))
			break
	var result := AssemblyOperations.save_scene(actor, output_path)
	actor.free()
	return result


static func _visible_to(node: Node3D, ancestor: Node3D) -> bool:
	var current: Node = node
	while current != null:
		if current is Node3D and not (current as Node3D).visible:
			return false
		if current == ancestor:
			return true
		current = current.get_parent()
	return false
