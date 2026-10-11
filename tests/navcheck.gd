extends "res://tests/check.gd"
## Exercises the saved cabin and an outdoor fixture, never a builder table.
func _run() -> void:
	var cabin := instantiate_scene("res://locations/captains_cabin/captains_cabin.tscn") as Location
	if cabin == null:
		finish()
		return
	root.add_child(cabin)
	if not check("saved cabin navigation synchronizes", await cabin.await_navigation()):
		finish()
		return
	var solids := cabin.find_children("*", "StaticBody3D", true, false)
	var sources := 0
	for solid in solids:
		if solid.is_in_group("nav_source"):
			sources += 1
	check("authored floor and furniture participate in baking", sources >= 4)
	var map := cabin.get_world_3d().navigation_map
	var from := Vector3(3.9, 0, 0.7)
	var to := Vector3(3.9, 0, 3.0)
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	check("path across the crate exists", path.size() >= 2)
	check("path detours around the authored crate", path_length(path) > from.distance_to(to) + 0.3)
	for area in cabin.find_children("*", "Area3D", true, false):
		if not area is Hotspot:
			continue
		var spot := area as Hotspot
		var approach := spot.resolve_approach(spot.resolve(""), cabin.player.global_position)
		var destination: Vector3 = approach["at"]
		var route := NavigationServer3D.map_get_path(map, cabin.player.global_position, destination, true)
		check("authored approach is reachable: " + spot.display_name, route.size() >= 2 or cabin.player.global_position.distance_to(destination) < 0.4)
	var crate: Node3D
	for child in cabin.get_children():
		if child is Node3D and child.scene_file_path.ends_with("/supply_crate.tscn"):
			crate = child
	if check("crate is an authored reusable instance", crate != null):
		crate.position.x = 1.0
		var previous := NavigationServer3D.map_get_iteration_id(map)
		cabin.rebake_navigation()
		check("explicit rebake updates the navigation map", await wait_for(func() -> bool: return NavigationServer3D.map_get_iteration_id(map) > previous))
		var cleared := NavigationServer3D.map_get_path(map, from, to, true)
		check("moving the crate clears its previous footprint", cleared.size() >= 2 and path_length(cleared) < from.distance_to(to) + 0.3)
		var relocated_from := Vector3(1.0, 0, 0.7)
		var relocated_to := Vector3(1.0, 0, 3.0)
		var relocated := NavigationServer3D.map_get_path(map, relocated_from, relocated_to, true)
		check("rebake blocks the crate's new footprint", relocated.size() >= 2 and path_length(relocated) > relocated_from.distance_to(relocated_to) + 0.3)
	cabin.queue_free()
	await process_frame
	await physics_frame
	var outdoor := instantiate_scene("res://tests/fixtures/outdoor_location.tscn") as Location
	if outdoor != null:
		root.add_child(outdoor)
		check("outdoor authored navigation synchronizes", await outdoor.await_navigation())
		var outdoor_map := outdoor.get_world_3d().navigation_map
		var previous := NavigationServer3D.map_get_iteration_id(outdoor_map)
		outdoor.rebake_navigation()
		check("outdoor geometry can be explicitly baked", await wait_for(func() -> bool: return NavigationServer3D.map_get_iteration_id(outdoor_map) > previous))
		var route := NavigationServer3D.map_get_path(outdoor_map, Vector3(0, 0, -2), Vector3(0, 0, 2), true)
		check("outdoor route detours around a rotated reused prop", route.size() >= 2 and path_length(route) > 4.3)
	finish()

func path_length(path: PackedVector3Array) -> float:
	var length := 0.0
	for index in range(1, path.size()):
		length += path[index - 1].distance_to(path[index])
	return length
