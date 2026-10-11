@tool
class_name Location
extends Node3D
## Authored environment. Never creates or relocates scene contents.
signal floor_clicked(point: Vector3)
const Mover := preload("res://actors/mover/mover.gd")
@export var camera: Camera3D
@export var player: Mover
@export var navigation_regions: Array[NavigationRegion3D] = []
@export_flags_3d_physics var walkable_collision_mask := 2
var navigation_ready := false

func _ready() -> void:
	if not Engine.is_editor_hint():
		get_viewport().physics_object_picking = true

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if camera == null:
		warnings.append("Assign the authored gameplay camera.")
	if player == null:
		warnings.append("Assign the authored player actor.")
	return warnings

func await_navigation() -> bool:
	navigation_ready = false
	if navigation_regions.is_empty():
		return false
	var map := get_world_3d().navigation_map
	var region_rids: Array[RID] = []
	for region in navigation_regions:
		if region.enabled and region.navigation_mesh and region.navigation_mesh.get_polygon_count() > 0:
			region_rids.append(region.get_rid())
	if region_rids.is_empty(): return false
	for frame in 240:
		await get_tree().physics_frame
		if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
			navigation_ready = true
			for region in navigation_regions:
				if region.get_rid() not in region_rids: continue
				if NavigationServer3D.region_get_iteration_id(region.get_rid()) == 0:
					navigation_ready = false
					break
				var vertices := region.navigation_mesh.get_vertices()
				var polygon := region.navigation_mesh.get_polygon(0)
				var probe := Vector3.ZERO
				for vertex in polygon: probe += vertices[vertex]
				probe = region.to_global(probe / polygon.size())
				# A registered region can precede its polygons in the map's iteration.
				if NavigationServer3D.map_get_closest_point_owner(map, probe) not in region_rids:
					navigation_ready = false
					break
			if navigation_ready:
				return true
	push_warning("Location: navigation did not synchronize.")
	return false

## Explicit authoring refresh only. Save the region through the editor after baking.
func rebake_navigation() -> void:
	for region in navigation_regions:
		region.bake_navigation_mesh(false)

func floor_point_under(screen_position: Vector2) -> Variant:
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin,
		origin + camera.project_ray_normal(screen_position) * 1000.0)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	# Leave area/prop clicks unhandled so Godot physics picking can deliver them.
	if hit and hit["collider"] is PhysicsBody3D:
		if (hit["collider"].collision_layer & walkable_collision_mask) != 0:
			return hit["position"]
	return null

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var point: Variant = floor_point_under(click.position)
		if point != null:
			get_viewport().set_input_as_handled()
			floor_clicked.emit(point)
