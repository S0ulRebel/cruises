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
		var drawable := _drawable_bounds(mesh, actor)
		if not drawable.found:
			continue
		var box: AABB = drawable.bounds
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
			# This exported controller plays the chosen clips directly. A source
			# tree driving that same player would overwrite its walk every frame.
			for tree_node in body.find_children("*", "AnimationTree", true, false):
				var tree := tree_node as AnimationTree
				if tree.get_node_or_null(tree.anim_player) == player:
					tree.active = false
			break
	var result := AssemblyOperations.save_scene(actor, output_path)
	actor.free()
	return result


static func _drawable_bounds(instance: MeshInstance3D, top: Node3D) -> Dictionary:
	var skeleton := instance.get_node_or_null(instance.skeleton) as Skeleton3D if instance.skin != null else null
	var matrix := RigSpace.chain(skeleton if skeleton != null else instance, top)
	var found := false
	var bounds := AABB()
	for surface in instance.mesh.get_surface_count():
		var arrays := instance.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		else:
			for index in vertices.size():
				indices.append(index)
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		if skeleton != null and arrays[Mesh.ARRAY_BONES] != null:
			bones = arrays[Mesh.ARRAY_BONES]
			weights = arrays[Mesh.ARRAY_WEIGHTS]
		var stride := bones.size() / maxi(vertices.size(), 1)
		for index in indices:
			var position := vertices[index]
			if stride > 0:
				position = Vector3.ZERO
				for influence in stride:
					var bind := bones[index * stride + influence]
					var weight := weights[index * stride + influence]
					if weight <= 0.0:
						continue
					var bone := instance.skin.get_bind_bone(bind)
					if bone < 0:
						bone = skeleton.find_bone(instance.skin.get_bind_name(bind))
					if bone >= 0:
						position += skeleton.get_bone_global_pose(bone) * instance.skin.get_bind_pose(bind) * vertices[index] * weight
			position = matrix * position
			bounds = bounds.expand(position) if found else AABB(position, Vector3.ZERO)
			found = true
	return {"found": found, "bounds": bounds}


static func _visible_to(node: Node3D, ancestor: Node3D) -> bool:
	var current: Node = node
	while current != null:
		if current is Node3D and not (current as Node3D).visible:
			return false
		if current == ancestor:
			return true
		current = current.get_parent()
	return false
