extends "res://tests/check.gd"

func _run() -> void:
	var location := instantiate_scene("res://tests/fixtures/outdoor_location.tscn") as Location
	if location == null:
		finish()
		return
	root.add_child(location)
	if not check("outdoor navigation synchronizes", await location.await_navigation()):
		finish()
		return
	var actor: Node = location.player
	_check_animation_loops(actor)
	_check_animation_loops(location.get_node("Santi"))
	var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var skeleton := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var leg := skeleton.find_bone("mixamorig_LeftUpLeg")
	if not check("Captain has an animated leg", leg >= 0):
		finish()
		return
	var results: Array = []
	var arrivals := [0]
	actor.movement_finished.connect(func(success: bool, reason: String) -> void:
		results.append({"success": success, "reason": reason}))
	actor.arrived.connect(func() -> void: arrivals[0] += 1)
	var target := Vector3(-2, 0, 2)
	var route := NavigationServer3D.map_get_path(location.get_world_3d().navigation_map, actor.global_position, target, true)
	check("saved outdoor navigation connects the movement target", route.size() >= 2, str(route))
	# Keep this route long enough to observe the real skeleton after two walk cycles.
	var original_speed: float = actor.speed
	actor.speed = 0.5
	actor.walk_to(target, 90.0)
	var elapsed := 0.0
	var late_poses: Array[Quaternion] = []
	var late_positions: Array[Vector3] = []
	while results.is_empty() and elapsed < 5.0:
		await physics_frame
		elapsed += actor.get_physics_process_delta_time()
		if elapsed > player.get_animation("walk").length * 2.0 and results.is_empty():
			late_poses.append(skeleton.get_bone_pose_rotation(leg))
			late_positions.append(actor.global_position)
	var leg_motion := 0.0
	for pose in late_poses:
		leg_motion = maxf(leg_motion, late_poses[0].angle_to(pose))
	check("walk keeps cycling while moving beyond two clip durations", late_poses.size() > 10 and leg_motion > 0.05 and late_positions[0].distance_to(late_positions[-1]) > 0.2, "late samples=%d, leg motion=%.3f radians" % [late_poses.size(), leg_motion])
	check("reachable movement completes", not results.is_empty())
	check("reachable movement reports success", not results.is_empty() and results[0]["success"], str(results))
	check("success means actual arrival", (actor.global_position - target).length() < 0.5 and arrivals[0] == 1, str(actor.global_position))
	actor.speed = original_speed
	var tree := actor.get_node("Layers") as AnimationTree
	check("arrival blends back to idle", await wait_for(func() -> bool: return is_zero_approx(float(tree.get("parameters/locomotion/blend_position"))), 1.0))
	results.clear()
	actor.walk_to(Vector3(1000, 0, 1000))
	check("unreachable movement completes within deadline", await wait_for(func() -> bool: return not results.is_empty()))
	check("unreachable movement cannot emit arrived", not results.is_empty() and not results[0]["success"] and arrivals[0] == 1, str(results))
	results.clear()
	actor.walk_to(Vector3(-4, 0, 2))
	actor.stop()
	check("stop reports cancellation once", results.size() == 1 and results[0]["reason"] == "cancelled" and not results[0]["success"])
	await physics_frame
	await physics_frame
	check("cancelled movement stays stopped", results.size() == 1 and actor.velocity.is_zero_approx())
	results.clear()
	actor.speed = 0.0
	actor.stuck_timeout = 0.15
	actor.movement_timeout = 0.5
	actor.walk_to(Vector3(-4, 0, 2))
	check("stuck movement has bounded completion", await wait_for(func() -> bool: return not results.is_empty(), 2.0))
	check("stuck movement reports failure", not results.is_empty() and not results[0]["success"], str(results))
	finish()

func _check_animation_loops(actor: Node) -> void:
	var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip in ["idle", "walk"]:
		check("%s %s repeats" % [actor.name, clip], player.get_animation(clip).loop_mode == Animation.LOOP_LINEAR)
	for clip in ["bow", "point"]:
		check("%s %s remains a one-shot gesture" % [actor.name, clip], player.get_animation(clip).loop_mode == Animation.LOOP_NONE)
