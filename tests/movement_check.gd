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
	var results: Array = []
	var arrivals := [0]
	actor.movement_finished.connect(func(success: bool, reason: String) -> void:
		results.append({"success": success, "reason": reason}))
	actor.arrived.connect(func() -> void: arrivals[0] += 1)
	var target := Vector3(-2, 0, 2)
	var route := NavigationServer3D.map_get_path(location.get_world_3d().navigation_map, actor.global_position, target, true)
	check("saved outdoor navigation connects the movement target", route.size() >= 2, str(route))
	actor.walk_to(target, 90.0)
	check("reachable movement completes", await wait_for(func() -> bool: return results.size() > 0))
	check("reachable movement reports success", not results.is_empty() and results[0]["success"], str(results))
	check("success means actual arrival", (actor.global_position - target).length() < 0.5 and arrivals[0] == 1, str(actor.global_position))
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
