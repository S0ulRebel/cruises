extends Node2D
## Someone who can cross a room.
##
## Deliberately ignorant of what it is drawing. A walker owns a position, a path and a
## facing; whether that is shown as a placeholder block, a sprite sheet or a cel-shaded
## Tripo model is the business of whatever sits under `Body`. That separation is the
## whole point of building this before the models exist - the controller can be finished
## and tested now, and the art drops into a slot that is already the right shape.
##
## Depth is the room's job, not the walker's: it asks the room how big it should be at
## its own feet, every frame. A character who walks upstage and does not shrink is the
## single most obvious thing wrong with a cheap adventure game.

signal arrived

## Pixels per second at full size. Scaled down with the character as they go upstage, so
## the apparent speed across the floor stays even.
@export var speed := 420.0
## How close counts as there. Smaller than this and he jitters on the spot.
@export var arrive_radius := 6.0

var facing := 1  ## 1 right, -1 left. Enough for now; eight-way comes with the real art.

var _room: Node2D
var _body: Node2D
var _target := Vector2.ZERO
var _moving := false


func _ready() -> void:
	_body = get_node_or_null("Body")


## The room supplies perspective and the floor. Set once, when the walker is placed.
func enter_room(room: Node2D) -> void:
	_room = room


func walk_to(target: Vector2) -> void:
	if _room and _room.has_method("closest_floor_point"):
		target = _room.closest_floor_point(target)
	_target = target
	_moving = true


func stop() -> void:
	_moving = false


func _physics_process(delta: float) -> void:
	_apply_depth()

	if not _moving:
		return

	var step := _target - global_position
	if step.length() <= arrive_radius:
		global_position = _target
		_moving = false
		arrived.emit()
		return

	var direction := step.normalized()
	if absf(direction.x) > 0.05:
		facing = signi(int(signf(direction.x)))
		if _body:
			_body.scale.x = absf(_body.scale.x) * float(facing)

	# Upstage characters cover less screen distance per second, or they appear to sprint.
	var moved := global_position + direction * speed * _current_scale() * delta
	# Clamp every step, so he slides along a wall instead of stopping dead against it.
	if _room and _room.has_method("closest_floor_point"):
		moved = _room.closest_floor_point(moved)
	global_position = moved


func _current_scale() -> float:
	if _room and _room.has_method("scale_at"):
		return _room.scale_at(global_position)
	return 1.0


func _apply_depth() -> void:
	var s := _current_scale()
	scale = Vector2(s, s)
	# Standing further back means drawn behind. Using Y directly keeps characters and
	# any future floor props in one consistent ordering without a separate sort pass.
	z_index = int(global_position.y)
