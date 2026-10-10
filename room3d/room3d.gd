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
@export var wall_height := 3.2

## The fixed camera. Slightly above eye level and angled down is the adventure-game
## default: it shows the floor, which is what the player is navigating.
@export var camera_height := 2.6
@export var camera_distance := 9.0
@export var camera_pitch_degrees := -14.0
@export var camera_fov := 42.0

var camera: Camera3D
var floor_body: StaticBody3D
var backdrop: MeshInstance3D
var key_light: DirectionalLight3D


func _ready() -> void:
	_build_camera()
	_build_floor()
	_build_backdrop()
	_build_light()


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
