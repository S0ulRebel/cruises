extends "res://tests/check.gd"

const BASELINE := "res://docs/migration/baseline_layout.json"
const PREFABS := {
	"Desk": "captain_desk", "Chair": "captain_chair", "Crate": "supply_crate",
	"Chest": "pirate_chest", "Porthole": "porthole", "Compass": "compass",
	"BrassInkwell": "brass_inkwell", "Rapier": "rapier", "BowlStand": "bowl_stand",
	"Fishbowl": "fishbowl", "live": "captain_live", "santi": "santi_wong"
}
const SHELL := ["Floor", "Backdrop", "WallLeft", "WallRight", "Ceiling"]
const HighlightScript := preload("res://ui/highlight/highlight.gd")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var game := instantiate_scene("res://game/game.tscn")
	if game == null:
		finish()
		return
	var location := game.get("location") as Location
	if not check("Game references its saved location", location != null and game.is_ancestor_of(location)):
		game.free()
		finish()
		return
	check("default location is authored before Play", location.scene_file_path == "res://locations/captains_cabin/captains_cabin.tscn")
	check("camera is an authored local reference", location.camera != null and location.is_ancestor_of(location.camera))
	check("player is an authored local reference", location.player != null and location.is_ancestor_of(location.player))
	check("cabin has one authored navigation region", location.navigation_regions.size() == 1)
	var before := counts(location)
	check("saved cabin has one camera", before.get("Camera3D", 0) == 1)
	check("saved cabin has two humanoid actors", before.get("CharacterBody3D", 0) == 2)
	check_layout(location)
	check_hotspots(location, 8)
	for actor in location.find_children("*", "CharacterBody3D", true, false):
		var actor_counts := counts(actor)
		check("one saved Agent on " + actor.name, actor_counts.get("NavigationAgent3D", 0) == 1)
		check("one saved Obstacle on " + actor.name, actor_counts.get("NavigationObstacle3D", 0) == 1)
		check("actor root is a reusable prefab", not actor.scene_file_path.is_empty())
	var baseline_positions := positions(location)
	game.set("skip_cold_open", true)
	root.add_child(game)
	check("Game startup completes within deadline", await wait_for(func() -> bool: return game.get("initialized") == true, 8.0))
	check("startup creates no duplicate location components", counts(location) == before)
	check("startup preserves authored visible root placement", positions(location) == baseline_positions)
	check("startup navigation is ready", location.navigation_ready)
	check("Game wires one shared session state", game.get("state") is GameState)
	check("startup releases interaction busy state", game.get("interactions") != null and not game.get("interactions").busy)
	check_camera_framing(location)
	await check_location_transition(game)
	game.queue_free()
	await process_frame
	await physics_frame
	await check_outdoor_reuse()
	await check_fishbowl_highlight_teardown()
	finish()

func check_location_transition(game: Node) -> void:
	var state := game.get("state") as GameState
	if state == null:
		return
	var state_id := state.get_instance_id()
	state.flags["fixture_session_flag"] = true
	check("defined key is available for transition coverage", state.add("key"))
	state.select("key")
	for path in ["res://props/supply_crate/supply_crate.tscn",
			"res://tests/fixtures/missing_camera_location.tscn",
			"res://tests/fixtures/missing_player_location.tscn",
			"res://tests/fixtures/broken_navigation_location.tscn",
			"res://tests/fixtures/broken_navigation_location.tscn"]:
		await check_rejected_transition(game, path)
	var scene := load("res://tests/fixtures/outdoor_location.tscn") as PackedScene
	game.get("interactions").busy = true
	check("busy interaction prevents a location transition", not await game.change_location(scene))
	game.get("interactions").busy = false
	check("Game transitions into a reused outdoor location", await game.change_location(scene))
	var next := game.get("location") as Location
	check("transition keeps the same GameState instance", game.get("state").get_instance_id() == state_id)
	check("transition preserves flags, inventory and selection", state.flags.has("fixture_session_flag") and state.held == ["key"] and state.selection == "key")
	check("transition wires the new camera, player and navigation", next != null and next.camera != null and next.player != null and next.navigation_ready)
	check("transition frees the previous location and actors", game.get_node_or_null("CaptainsCabin") == null and counts(next).get("Camera3D", 0) == 1 and counts(game).get("CharacterBody3D", 0) == 2)
	check("transition releases busy state", not game.get("interactions").busy)
	var nonwalkable := load("res://tests/fixtures/nonwalkable_location.tscn") as PackedScene
	check("an intentionally nonwalkable location is allowed", await game.change_location(nonwalkable))
	var still := game.get("location") as Location
	check("nonwalkable location needs no navigation region", still != null and still.navigation_regions.is_empty() and not still.navigation_ready)
	check("nonwalkable transition preserves session state", game.get("state").get_instance_id() == state_id and state.flags.has("fixture_session_flag") and state.held == ["key"] and state.selection == "key")
	check("nonwalkable transition releases busy state", not game.get("interactions").busy)

func check_rejected_transition(game: Node, path: String) -> void:
	var previous := game.get("location") as Location
	var state := game.get("state") as GameState
	var state_id := state.get_instance_id()
	var index := previous.get_index()
	var placement := positions(previous)
	var before := counts(previous)
	var connections := previous.floor_clicked.get_connections().size()
	var hotspot_connections := hotspot_bindings(previous)
	var hovered: Hotspot
	var hover_rest := {}
	if path.ends_with("broken_navigation_location.tscn"):
		hovered = previous.get_node("Fishbowl/Hotspot") as Hotspot
		hover_rest = material_values(hovered.visual)
		# Exercise the controller's real public input signal so release_location clears hover.
		hovered.mouse_entered.emit()
		check("prop is highlighted before failed navigation", all_glowing(material_values(hovered.visual)))
	var started := Time.get_ticks_msec()
	var accepted: bool = await game.change_location(load(path) as PackedScene)
	var label := path.get_file()
	check("invalid transition rejects " + label, not accepted)
	check("invalid transition returns within its deadline", Time.get_ticks_msec() - started < 5000)
	if not check("failed transition keeps the same live location", is_instance_valid(previous) and game.get("location") == previous and game.is_ancestor_of(previous)):
		return
	check("failed transition preserves placement and components", previous.get_index() == index and positions(previous) == placement and counts(previous) == before)
	check("failed transition restores the original gameplay camera", game.get_viewport().get_camera_3d() == previous.camera)
	check("failed transition preserves flags, held items and selection", game.get("state").get_instance_id() == state_id and state.flags.has("fixture_session_flag") and state.held == ["key"] and state.selection == "key")
	check("failed transition restores synchronized navigation", previous.navigation_ready)
	check("failed transition reconnects interactions exactly once", previous.floor_clicked.get_connections().size() == connections)
	check("failed transition preserves each hotspot's bindings", hotspot_bindings(previous) == hotspot_connections)
	check("failed transition leaves the session usable", game.get("initialized") == true and not game.get("interactions").busy)
	if hovered != null:
		check("failed hovered transition restores exact material values", material_values(hovered.visual) == hover_rest)

func hotspot_bindings(location: Location) -> Dictionary:
	var bindings := {}
	for area in location.find_children("*", "Area3D", true, false):
		if area is Hotspot:
			bindings[String(location.get_path_to(area))] = [area.input_event.get_connections().size(),
				area.mouse_entered.get_connections().size(), area.mouse_exited.get_connections().size()]
	return bindings

func material_values(visual: Node) -> Dictionary:
	var values := {}
	for mesh_node in HighlightScript.meshes_of(visual):
		var mesh := mesh_node as MeshInstance3D
		if mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as BaseMaterial3D
			if material == null: continue
			# Store values only, so the assertion itself cannot keep a material RID alive.
			values["%s:%d" % [visual.get_path_to(mesh), surface]] = {
				"albedo": material.albedo_color, "roughness": material.roughness,
				"transparency": material.transparency, "shading": material.shading_mode,
				"emission_enabled": material.emission_enabled, "emission": material.emission,
				"emission_energy": material.emission_energy_multiplier}
	return values

func all_glowing(values: Dictionary) -> bool:
	if values.is_empty(): return false
	for value in values.values():
		if not value["emission_enabled"] or value["emission"] != HighlightScript.COLOUR or not is_equal_approx(value["emission_energy"], HighlightScript.STRENGTH):
			return false
	return true

func check_fishbowl_highlight_teardown() -> void:
	var one := instantiate_scene("res://props/fishbowl/fishbowl.tscn") as Node3D
	var two := instantiate_scene("res://props/fishbowl/fishbowl.tscn") as Node3D
	if one == null or two == null:
		if one != null: one.free()
		if two != null: two.free()
		return
	one.name = "FishbowlOne"
	two.name = "FishbowlTwo"
	one.position.x = -1.0
	two.position.x = 1.0
	root.add_child(one)
	root.add_child(two)
	await process_frame
	await process_frame
	var first := one.get_node("Hotspot") as Hotspot
	var second := two.get_node("Hotspot") as Hotspot
	var first_rest := material_values(first.visual)
	var second_rest := material_values(second.visual)
	check("both fishbowls expose highlightable materials", not first_rest.is_empty() and not second_rest.is_empty())
	HighlightScript.set_on(first, true)
	check("first fishbowl highlights locally", all_glowing(material_values(first.visual)))
	check("first fishbowl leaves the second instance's emission unchanged", material_values(second.visual) == second_rest)
	HighlightScript.set_on(first, false)
	check("first fishbowl restores all material values", material_values(first.visual) == first_rest)
	HighlightScript.set_on(second, true)
	check("second fishbowl highlights locally", all_glowing(material_values(second.visual)))
	check("second fishbowl leaves the first instance's emission unchanged", material_values(first.visual) == first_rest)
	HighlightScript.set_on(second, false)
	check("second fishbowl restores all material values", material_values(second.visual) == second_rest)
	# Free one while highlighted and one after hover-off; keep no Material references.
	HighlightScript.set_on(first, true)
	one.queue_free()
	two.queue_free()
	await process_frame
	await process_frame
	await process_frame
	check("highlighted and formerly highlighted fishbowls free cleanly", not is_instance_valid(one) and not is_instance_valid(two))

func counts(node: Node) -> Dictionary:
	var out := {}
	for child in all_nodes(node):
		var kind := child.get_class()
		out[kind] = int(out.get(kind, 0)) + 1
	return out

func all_nodes(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(all_nodes(child))
	return out

func by_prefab(location: Node, id: String) -> Node3D:
	for child in location.get_children():
		if child is Node3D and child.scene_file_path.get_file().get_basename() == id:
			return child
	return null

func positions(location: Node) -> Dictionary:
	var out := {}
	for child in location.get_children():
		if child is Node3D:
			out[String(child.name)] = child.transform
	return out

func check_layout(location: Location) -> void:
	var baseline: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	if not check("recorded layout parses", baseline is Dictionary):
		return
	var pattern := RegEx.new()
	pattern.compile("[-+]?[0-9]+(?:\\.[0-9]+)?(?:e[-+]?[0-9]+)?")
	var tested := 0
	for entry in baseline["saved"]:
		var parts := String(entry["path"]).split("/", false)
		if parts.size() != 2:
			continue
		var label: String = parts[1]
		# The original camera stays recorded as migration evidence. Its explicitly
		# authored replacement is tested by visibility/picking, without moving props.
		if label not in PREFABS and label not in SHELL:
			continue
		var node: Node3D
		if label in SHELL: node = location.get_node_or_null(label) as Node3D
		else: node = by_prefab(location, PREFABS[label])
		if not check("baseline object exists: " + label, node != null):
			continue
		if label in SHELL:
			check("fixed environment object is a reusable prefab: " + label, not node.scene_file_path.is_empty())
		var matches := pattern.search_all(String(entry["transform"]))
		if not check("baseline transform parses: " + label, matches.size() == 12):
			continue
		var values: Array[float] = []
		for result in matches:
			values.append(float(result.get_string()))
		# Snapshot strings name the same X/Y/Z axes accepted by Basis' vector constructor.
		var expected := Transform3D(Basis(Vector3(values[0], values[1], values[2]),
			Vector3(values[3], values[4], values[5]), Vector3(values[6], values[7], values[8])),
			Vector3(values[9], values[10], values[11]))
		check("baseline composition preserved: " + label, node.transform.is_equal_approx(expected), str(node.transform))
		tested += 1
	check("all baseline prop/actor/environment transforms were checked", tested == PREFABS.size() + SHELL.size())

func check_camera_framing(location: Location) -> void:
	var camera := location.camera
	check("camera has the explicitly authored all-props framing profile",
		camera.get_meta("framing_profile", "") == "cabin_all_props_v1")
	var frame := Rect2(Vector2(24, 24), Vector2(1872, 1032))
	for label in PREFABS:
		var object := by_prefab(location, PREFABS[label])
		if object == null: continue
		var projected := projected_bounds(object, camera)
		check("complete object bounds remain in frame: " + String(label),
			projected.size.x > 0.0 and projected.size.y > 0.0 and frame.encloses(projected), str(projected))
	for actor in [location.player, location.get_node("Santi")]:
		var height := projected_bounds(actor, camera).size.y
		check("actor remains readable at gameplay scale: " + String(actor.name),
			height >= 250.0 and height <= 390.0, "%.1f px" % height)
	for child in location.find_children("*", "Area3D", true, false):
		var spot := child as Hotspot
		if spot == null: continue
		# Cast through the visual centre, including actors and solid bodies, so the
		# Captain cannot accidentally make a tabletop item impossible to click.
		var visual_bounds := world_bounds(spot.visual)
		var screen := camera.unproject_position(visual_bounds.get_center())
		var origin := camera.project_ray_origin(screen)
		var query := PhysicsRayQueryParameters3D.create(origin,
			origin + camera.project_ray_normal(screen) * 1000.0)
		query.collide_with_areas = true
		var hit := location.get_world_3d().direct_space_state.intersect_ray(query)
		check("visual-centre ray selects its own hotspot: " + spot.display_name,
			hit.get("collider") == spot, str(screen))
	for screen in [Vector2(24, 1056), Vector2(960, 1056), Vector2(1896, 1056)]:
		check("authored floor fills the bottom of the view", location.floor_point_under(screen) != null, str(screen))

func projected_bounds(node: Node3D, camera: Camera3D) -> Rect2:
	var initialized := false
	var bounds := Rect2()
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		var box: AABB = mesh.get_aabb()
		for i in 8:
			var point := camera.unproject_position(mesh.global_transform * box.get_endpoint(i))
			bounds = Rect2(point, Vector2.ZERO) if not initialized else bounds.expand(point)
			initialized = true
	return bounds

func world_bounds(node: Node3D) -> AABB:
	var initialized := false
	var bounds := AABB()
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if not initialized else bounds.merge(box)
		initialized = true
	return bounds

func check_hotspots(location: Node, minimum: int) -> void:
	var checked := 0
	for child in location.find_children("*", "Area3D", true, false):
		if not child is Hotspot:
			continue
		var spot := child as Hotspot
		var owner_node: Node = spot.get_parent()
		while owner_node != null and owner_node != location and owner_node.scene_file_path.is_empty():
			owner_node = owner_node.get_parent()
		var owned := owner_node != null and owner_node != location
		check("hotspot belongs to an object prefab: " + spot.display_name, owned)
		check("hotspot visual is local: " + spot.display_name,
			owned and spot.visual != null and (spot.visual == owner_node or owner_node.is_ancestor_of(spot.visual)))
		if spot.target_actor == null:
			check("approach marker is local: " + spot.display_name,
				owned and spot.approach_marker != null and owner_node.is_ancestor_of(spot.approach_marker))
		check("hotspot has an authored collision shape: " + spot.display_name,
			spot.find_children("*", "CollisionShape3D", true, false).size() > 0)
		if spot.target_actor != null:
			check("talk target is its own actor", owned and (spot.target_actor == owner_node or owner_node.is_ancestor_of(spot.target_actor)))
		checked += 1
	check("location has its expected interactive prefab objects", checked >= minimum)

func check_outdoor_reuse() -> void:
	var outdoor := instantiate_scene("res://tests/fixtures/outdoor_location.tscn") as Location
	if outdoor == null:
		return
	var before := counts(outdoor)
	var one := outdoor.get_node("CrateOne") as Node3D
	var two := outdoor.get_node("CrateTwo") as Node3D
	var one_transform := one.transform
	var two_transform := two.transform
	root.add_child(outdoor)
	await physics_frame
	await physics_frame
	check("outdoor Location adds no indoor shell or other fixed nodes", counts(outdoor) == before)
	check("rotated/moved prefab transforms survive startup", one.transform.is_equal_approx(one_transform) and two.transform.is_equal_approx(two_transform))
	check("outdoor fixture has no mandatory walls or ceiling", outdoor.get_node_or_null("WallLeft") == null and outdoor.get_node_or_null("Ceiling") == null)
	check("outdoor navigation is optional authored content", await outdoor.await_navigation())
	check_hotspots(outdoor, 3)
	var one_spots := one.find_children("*", "Area3D", true, false)
	var two_spots := two.find_children("*", "Area3D", true, false)
	if not check("both reused crates carry hotspots", one_spots.size() == 1 and two_spots.size() == 1):
		outdoor.queue_free()
		await process_frame
		return
	var first := one_spots[0] as Hotspot
	var second := two_spots[0] as Hotspot
	if first != null and second != null and first.approach_marker != null and second.approach_marker != null:
		check("duplicate prefab references point to different local nodes", first.visual != second.visual and first.approach_marker != second.approach_marker)
		var local_marker := one.global_transform.affine_inverse() * first.approach_marker.global_transform
		one.position += Vector3(-1.5, 0, 0.75)
		one.rotate_y(0.7)
		check("approach marker follows placement and rotation", first.approach_marker.global_transform.is_equal_approx(one.global_transform * local_marker))
		var resolved: Dictionary = first.resolve_approach(Hotspot.Verb.USE, outdoor.player.global_position)
		var expected := first.approach_marker.global_position
		var actual: Vector3 = resolved["at"]
		check("interaction resolves the moved world-space marker", Vector2(actual.x - expected.x, actual.z - expected.z).length() < 0.3)
	var meshes_one := one.find_children("*", "MeshInstance3D", true, false)
	var meshes_two := two.find_children("*", "MeshInstance3D", true, false)
	if check("reused crates contain visible meshes", not meshes_one.is_empty() and not meshes_two.is_empty()):
		var mat_one: Material = meshes_one[0].get_active_material(0)
		var mat_two: Material = meshes_two[0].get_active_material(0)
		if check("duplicate material resources are independent", mat_one is BaseMaterial3D and mat_two is BaseMaterial3D and mat_one != mat_two):
			var original: Color = mat_two.albedo_color
			mat_one.albedo_color = Color.MAGENTA
			check("editing one instance does not tint another", mat_two.albedo_color == original)
	outdoor.queue_free()
	await process_frame
