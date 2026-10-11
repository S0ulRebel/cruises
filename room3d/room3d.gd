extends Node3D
## A room as real 3D space, with the painting hung behind it.
##
## This supersedes the 2D room for anything with 3D characters in it, and the reason is
## that the 2D version was approximating three things a camera already does properly:
##
##   perspective     a 2D walker shrinks by interpolating between two markers. A camera
##                   just has perspective.
##   depth sorting   2D needs z_index driven off foot position. 3D has a depth buffer.
##   lighting        a 2D sprite cannot be lit by the room it stands in. A 3D character
##                   can, which is the thing that stops figures looking pasted on.
##
## The architecture is Grim Fandango's: a fixed camera per room, a painted backdrop, an
## invisible floor the characters actually walk on. The backdrop is a quad behind
## everything; the floor is a real collision plane the mouse raycasts onto. Because the
## camera never moves within a room, the painting and the geometry only have to agree
## from one angle - which is the whole reason this is cheaper than modelling the room.
##
## It is also the blockout the background gets painted over. Same camera, same floor,
## so the painting and the walkable area agree by construction instead of by eye.

signal floor_clicked(position: Vector3)
signal hotspot_clicked(name: String)

## Metres across the back wall. Everything else is sized off this so a room can be
## rescaled without re-placing its contents.
@export var room_width := 12.0
@export var room_depth := 7.0
## The placeholder backdrop. 3.2 m is a real cabin's headroom and was right for the
## old elevated camera; the new low wide one sees straight over it and the grey void
## shows above. Raised until it fills the frame - it is a stand-in for the artist's
## room pieces, not a measurement of anything.
@export var wall_height := 4.6

## The fixed camera, matched to the art session's target render
## (docs/reference/room_target.png). Low, close and wide: the bowl looms in the
## foreground, you look slightly UP at the characters, and the ceiling beams are in
## frame. The old values - 2.6 m up, 9 m back, 42 degrees - were an elevated
## architectural view with no depth in it.
##
## Solved from the render rather than guessed, by measuring two things of known size
## against the frame height: the 3.2 m back wall fills 0.425 of it and the captain's
## 1.90 m fills 0.557, which puts him 2.1 m from the camera, the wall 4.6 m, and the
## vertical FOV at 79 degrees.
##
## 79 is not used. The same render puts his eyes 1.0 m above the camera and his feet
## 0.4 m below it, and both cannot be true - it is painted, not rendered, so its
## perspective does not close. These are the measurement's shape (low, close, wide)
## pulled back to a lens that does not bow the walls.
@export var camera_height := 1.15
@export var camera_distance := 4.1
@export var camera_pitch_degrees := -3.0
@export var camera_fov := 62.0

## Anything in this group is parsed when the walkable area is baked: the floor adds to
## it, a solid prop cuts a hole in it. Characters are NOT in it - they move, and a
## re-bake every step is far too expensive. They carry a NavigationObstacle3D instead,
## which carves the mesh at runtime. See actors/mover/mover.gd.
const NAV_SOURCE := "nav_source"

var camera: Camera3D
var floor_body: StaticBody3D
var nav_region: NavigationRegion3D
var backdrop: MeshInstance3D
var key_light: DirectionalLight3D


func _ready() -> void:
	_build_camera()
	_build_floor()
	_build_backdrop()
	_build_light()
	_build_navigation()


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = camera_fov
	camera.position = Vector3(0.0, camera_height, camera_distance)
	camera.rotation_degrees = Vector3(camera_pitch_degrees, 0.0, 0.0)
	camera.current = true
	add_child(camera)


func _build_floor() -> void:
	floor_body = StaticBody3D.new()
	floor_body.name = "Floor"
	add_child(floor_body)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# A thin box rather than a plane: a plane is infinite, and the player would be able
	# to click the void beyond the room and walk there.
	box.size = Vector3(room_width, 0.2, room_depth)
	shape.shape = box
	shape.position = Vector3(0.0, -0.1, 0.0)
	floor_body.add_child(shape)
	floor_body.add_to_group(NAV_SOURCE)

	var visual := MeshInstance3D.new()
	visual.name = "FloorVisual"
	var plane := PlaneMesh.new()
	plane.size = Vector2(room_width, room_depth)
	visual.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#2a1b10")
	mat.roughness = 0.95
	visual.material_override = mat
	floor_body.add_child(visual)


func _build_backdrop() -> void:
	# The painting. A quad standing at the back of the room, unshaded so the painted
	# light is the light - nothing in the engine should be relighting a painting.
	backdrop = MeshInstance3D.new()
	backdrop.name = "Backdrop"
	var quad := QuadMesh.new()
	quad.size = Vector2(room_width, wall_height)
	backdrop.mesh = quad
	backdrop.position = Vector3(0.0, wall_height * 0.5, -room_depth * 0.5)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#3a2416")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	backdrop.material_override = mat
	add_child(backdrop)


## The walkable area, baked from the floor minus whatever solid stands on it.
##
## A point-and-click needs pathfinding rather than collision. With collision alone the
## player clicks past a crate and the character grinds along its edge, which reads as
## the game fighting them. With a navigation mesh he walks AROUND it to the spot that
## was clicked, which reads as him knowing the room. Props keep their collision bodies
## anyway - that is what makes them clickable, and the backstop if anyone ends up off
## the mesh.
func _build_navigation() -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Navigation"
	add_child(nav_region)

	var mesh := NavigationMesh.new()
	# Parse collision shapes, not visuals: a prop is solid because it has a body, and
	# a purely decorative mesh should not block anyone.
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = NAV_SOURCE
	# Half the shoulder width of a character, so he does not clip a crate he squeezes
	# past. Characters are 0.26 radius; 0.30 leaves a little daylight.
	mesh.agent_radius = 0.30
	mesh.agent_height = 2.0
	mesh.agent_max_climb = 0.2
	# The default 0.25 m cell is coarse for a room this size - gaps between furniture
	# vanish and the character refuses to walk between the desk and the wall.
	mesh.cell_size = 0.10
	mesh.cell_height = 0.10
	nav_region.navigation_mesh = mesh


## Re-bake the walkable area. Called once everything solid is in the room, and again
## whenever something solid is added or removed. Not called per frame and not called
## when a character moves - see NAV_SOURCE.
func rebake_navigation() -> void:
	if nav_region == null:
		return
	nav_region.bake_navigation_mesh(false)
	# Push the filled mesh to the server by hand. Baking writes into the NavigationMesh
	# RESOURCE, and the region only uploads on assignment - but assigning the same
	# resource back is a no-op, because the setter returns early when the value has not
	# changed. Without this the server keeps the empty copy it was handed at build time
	# and every path comes back with zero points, which looks like a broken click
	# rather than a stale upload.
	NavigationServer3D.region_set_navigation_mesh(
		nav_region.get_rid(), nav_region.navigation_mesh)
	# Baking fills the MESH; the navigation SERVER only picks it up on its own sync,
	# which happens at the end of a physics step. Without forcing it, a path requested
	# in the same frame as the bake comes back empty and the character stands still -
	# which looks like a broken click, not a timing problem.
	var map := get_world_3d().navigation_map
	if map.is_valid():
		NavigationServer3D.map_force_update(map)
	navigation_ready = false


## True once the navigation server can actually answer. See await_navigation().
var navigation_ready := false


## Wait until the walkable area is queryable.
##
## The server answers NOTHING until its SECOND synchronisation iteration: the first
## registers the region, the mesh arrives on the next one. Query before that and
## map_get_path returns zero points and map_get_closest_point returns the origin -
## silently, with no error unless you happen to be printing them. A character told to
## walk in that window simply never moves, which reads as a broken click.
##
## Counting physics frames is a guess; the iteration id is the signal.
func await_navigation() -> void:
	var map := get_world_3d().navigation_map
	if not map.is_valid():
		return
	# Ask the map a question we know the answer to, and wait until it gets it right.
	#
	# Counting sync iterations was the first attempt and it is not reliable: how many
	# iterations a bake takes to land depends on what else changed that frame, and
	# freeing a previous room shifts it. A behavioural check cannot be fooled by any
	# of that - either the server can place a point on the floor or it cannot.
	var probe := global_position + Vector3(0.0, 0.1, 0.0)
	var waited := 0
	navigation_ready = false
	while waited < 240:
		var landed := NavigationServer3D.map_get_closest_point(map, probe)
		# The origin is what an unsynced map returns for everything, so a result near
		# the probe means the mesh is really there - unless the probe IS the origin,
		# which is why it is lifted off the floor.
		if landed.distance_to(probe) < 1.0 and landed != Vector3.ZERO:
			navigation_ready = true
			break
		await get_tree().physics_frame
		waited += 1
	if not navigation_ready:
		push_warning("Room3D: navigation never synchronised; nobody will be able to walk.")


func _build_light() -> void:
	# One key light per room, matching the direction recorded in the room's palette.
	# Characters are lit by this; the backdrop is not, because it is already painted.
	key_light = DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	key_light.light_energy = 1.1
	key_light.light_color = Color("#ffd9a8")
	key_light.shadow_enabled = true
	add_child(key_light)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-18.0, -130.0, 0.0)
	fill.light_energy = 0.35
	fill.light_color = Color("#8fb3d9")
	add_child(fill)


## Set the key light to match what the room's painting shows. Called with the values
## recorded in the room's palette.json, so the figures agree with the picture.
func set_key_light(direction_degrees: Vector3, colour: Color, energy := 1.1) -> void:
	key_light.rotation_degrees = direction_degrees
	key_light.light_color = colour
	key_light.light_energy = energy


## Where on the floor the mouse is pointing, if anywhere.
func floor_point_under(screen_position: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("position") if hit else null


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var point: Variant = floor_point_under(click.position)
	if point != null:
		floor_clicked.emit(point as Vector3)
