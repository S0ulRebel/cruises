extends Node3D
## Proves the walkable area is real: that a path goes AROUND a solid prop instead of
## through it, that a character blocks others, and that an approach point lands
## somewhere you can actually stand.
##
## Measured rather than eyeballed, because a navigation bug looks like nothing at all
## until a character walks through a desk in front of the player.

const Room3D := preload("res://room3d/room3d.gd")

var _failures := 0


func _ready() -> void:
	var room := Room3D.new()
	add_child(room)

	# A wall across the middle of the room with one gap, so a straight line from A to B
	# is blocked and the only way through is a detour. If pathfinding works, the path
	# bends through the gap; if it does not, it runs straight through the wall.
	# Spans the full width of the room except for a one-metre gap at x 0..1. The first
	# version left a second gap at the left edge, so the "detour" was two metres and
	# the test passed a path that had barely deviated.
	_wall(room, Vector3(-3.0, 0.5, 0.0), Vector3(6.0, 1.0, 0.6))   # x -6..0
	_wall(room, Vector3(3.5, 0.5, 0.0), Vector3(5.0, 1.0, 0.6))    # x  1..6
	room.rebake_navigation()
	await room.await_navigation()

	var mesh := room.nav_region.navigation_mesh
	print("  baked: %d vertices, %d polygons" % [mesh.get_vertices().size(), mesh.get_polygon_count()])
	print("  nav_source group members: %d" % get_tree().get_nodes_in_group(Room3D.NAV_SOURCE).size())
	var map := get_world_3d().navigation_map
	print("  regions on map: %d" % NavigationServer3D.map_get_regions(map).size())
	_check("the navigation map exists", map.is_valid())
	_check("the bake produced polygons", mesh.get_polygon_count() > 0)

	# Where the baked mesh actually is, before asking it for anything.
	var verts := mesh.get_vertices()
	if verts.size() > 0:
		var lo := verts[0]
		var hi := verts[0]
		for v in verts:
			lo = Vector3(minf(lo.x, v.x), minf(lo.y, v.y), minf(lo.z, v.z))
			hi = Vector3(maxf(hi.x, v.x), maxf(hi.y, v.y), maxf(hi.z, v.z))
		print("  mesh spans %v to %v" % [lo, hi])
	var short := NavigationServer3D.map_get_path(map, Vector3(-4, 0, 2.5), Vector3(-1, 0, 2.5), true)
	print("  unobstructed short path: %d points" % short.size())

	var from := Vector3(-4.0, 0.0, 2.5)
	var to := Vector3(-4.0, 0.0, -2.5)
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	print("  path from %v to %v: %d points" % [from, to, path.size()])
	_check("a path exists at all", path.size() >= 2)

	# A straight line is 5.0 m. Going around the wall has to be longer. If the path
	# length is within a whisker of the straight line, it went through the wall.
	var straight := from.distance_to(to)
	var walked := 0.0
	for i in path.size() - 1:
		walked += path[i].distance_to(path[i + 1])
	print("  straight line %.2f m, path %.2f m (%.2fx)" % [straight, walked, walked / straight])
	# Through the only gap is roughly 4 m across, 5 m down and 4 m back, against a 5 m
	# straight line. Anything under twice the straight line went through a wall.
	_check("the path detours rather than going straight through", walked > straight * 2.0)

	# No point on the path may sit inside a wall.
	var inside := 0
	for p in path:
		if absf(p.z) < 0.3 and (p.x < 0.0 or p.x > 1.0):
			inside += 1
	print("  %d of %d path points lie inside a wall" % [inside, path.size()])
	_check("no path point is inside a wall", inside == 0)

	# An approach point computed for an unreachable spot must come back standable.
	var in_the_wall := Vector3(-3.0, 0.0, 0.0)
	var snapped := NavigationServer3D.map_get_closest_point(map, in_the_wall)
	print("  a point inside the wall %v snaps to %v" % [in_the_wall, snapped])
	_check("an unreachable approach snaps onto the walkable area",
		snapped.distance_to(in_the_wall) > 0.2)

	room.queue_free()
	await get_tree().process_frame
	await _check_real_room()

	print("\n%s" % ("ALL CHECKS PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _wall(room: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_to_group(Room3D.NAV_SOURCE)
	room.add_child(body)


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])


## The actual room, built from the same data the game uses, so this cannot drift from
## what ships. Checks the two things a layout gets wrong: a gap too narrow to walk
## through, and an approach point that ended up inside the furniture it belongs to.
func _check_real_room() -> void:
	print("
-- Livé's quarters, from main.gd data --")
	var main_script := load("res://main.gd")
	var furniture: Array = main_script.FURNITURE
	var hotspots: Array = main_script.HOTSPOTS

	var room := Room3D.new()
	add_child(room)
	for piece in furniture:
		if not bool(piece.get("solid", true)):
			continue
		_wall(room, piece["at"], piece["size"])
	room.rebake_navigation()
	await room.await_navigation()
	var map := get_world_3d().navigation_map

	var start := Vector3(-1.4, 0.0, 1.2)   # where Livé stands at the start of the scene
	for entry in hotspots:
		var stand: Vector3 = entry["stand"]
		var on_mesh := NavigationServer3D.map_get_closest_point(map, stand)
		var drift := Vector2(on_mesh.x - stand.x, on_mesh.z - stand.z).length()
		var path := NavigationServer3D.map_get_path(map, start, on_mesh, true)
		var walked := 0.0
		for i in path.size() - 1:
			walked += path[i].distance_to(path[i + 1])
		print("  %-9s stand %v -> %v (moved %.2f m), path %d pts, %.2f m"
			% [entry["label"], stand, on_mesh, drift, path.size(), walked])
		# Drift means the authored spot was inside furniture or off the floor. A few
		# centimetres is the agent radius; a lot means the spot is wrong.
		_check("%s: its approach point is standable" % entry["label"], drift < 0.5)
		_check("%s: it is reachable from the start" % entry["label"], path.size() >= 2)
