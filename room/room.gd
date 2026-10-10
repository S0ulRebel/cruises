extends Node2D
## A place the player can walk around in.
##
## The classic adventure-game room, and still the cheapest thing to author: a painted
## picture, a polygon saying where the floor is, two markers saying how big a person is
## at the front and at the back, and some shapes you can click on. Everything else -
## perspective, depth sorting, where he is allowed to stand - falls out of those four.
##
## Expected children, by name:
##   Background    Sprite2D      the painted room
##   Walkable      Polygon2D     the floor. The only place he can stand
##   ScaleNear     Marker2D      where a character is full size
##   ScaleFar      Marker2D      where a character is smallest
##   Hotspots      Node2D of Area2D    things worth clicking
##   Foreground    Node2D of Sprite2D  strips he walks behind
##
## Any of them may be missing; a room with no hotspots is still a room, and during
## blocking that is usually what you have.
##
## There is deliberately no navigation server here. Clamping a click to a floor polygon
## is pure geometry, and doing it with Geometry2D makes it deterministic and testable
## with no map to synchronise - the server returns the origin for every query made
## before its first iteration, silently, which presents as a character who walks into
## the corner of the world. Pathfinding comes back the day a room has furniture to walk
## around, and then it is one method, not the whole floor.

signal hotspot_clicked(name: String)
signal floor_clicked(position: Vector2)

## How small a character gets at the back of the room. Perspective, approximated by a
## straight line between two markers, because a room this size never needs the real curve.
@export_range(0.05, 1.0) var far_scale := 0.55

var _floor: PackedVector2Array = PackedVector2Array()
var _near: Marker2D
var _far: Marker2D


func _ready() -> void:
	var walkable := get_node_or_null("Walkable") as Polygon2D
	if walkable:
		_floor = walkable.polygon
	_near = get_node_or_null("ScaleNear") as Marker2D
	_far = get_node_or_null("ScaleFar") as Marker2D

	var hotspots := get_node_or_null("Hotspots")
	if hotspots:
		for child in hotspots.get_children():
			var area := child as Area2D
			if area:
				area.input_event.connect(_on_hotspot_input.bind(area.name))

	# Foreground strips sit above everybody. Y-sorting would do this too, but a strip is
	# not a thing standing on the floor - it has no depth of its own to sort by.
	var foreground := get_node_or_null("Foreground")
	if foreground:
		foreground.z_index = 100


## How big a character standing here should be drawn.
func scale_at(point: Vector2) -> float:
	if _near == null or _far == null:
		return 1.0
	var span := _near.position.y - _far.position.y
	if is_zero_approx(span):
		return 1.0
	var t := clampf((_near.position.y - point.y) / span, 0.0, 1.0)
	return lerpf(1.0, far_scale, t)


func is_on_floor(point: Vector2) -> bool:
	if _floor.is_empty():
		return true
	return Geometry2D.is_point_in_polygon(point, _floor)


## The nearest spot on the floor to where they clicked. Clicking a wall should walk you
## as close to it as the floor allows, not do nothing - doing nothing reads as a bug.
func closest_floor_point(point: Vector2) -> Vector2:
	if _floor.is_empty() or Geometry2D.is_point_in_polygon(point, _floor):
		return point

	var best := _floor[0]
	var best_distance := INF
	for i in _floor.size():
		var a := _floor[i]
		var b := _floor[(i + 1) % _floor.size()]
		var on_edge := Geometry2D.get_closest_point_to_segment(point, a, b)
		var distance := on_edge.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best = on_edge
	return best


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	floor_clicked.emit(closest_floor_point(get_global_mouse_position()))


func _on_hotspot_input(_viewport: Node, event: InputEvent, _shape: int, hotspot_name: String) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		hotspot_clicked.emit(hotspot_name)
		get_viewport().set_input_as_handled()
