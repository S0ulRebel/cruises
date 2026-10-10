extends CharacterBody3D
## Someone crossing a room, in three dimensions.
##
## Much less work than the 2D version, because the camera is doing the parts that had
## to be faked there. No depth sorting, no perspective scaling, no marker interpolation
## - a character two metres further back is simply two metres further back.
##
## Knows nothing about what it is drawing. Whatever sits under `Body` is the art, and
## today that is a capsule. A rigged Tripo model drops into the same slot.

signal arrived

## Metres per second. A walk, not a jog - adventure characters amble, and the player is
## reading dialogue most of the time anyway.
@export var speed := 2.2
@export var turn_speed := 10.0
@export var arrive_distance := 0.12
## Height in metres, from the character sheet. Used to size the placeholder, and worth
## keeping on the real model so a mis-scaled import is obvious instead of subtle.
@export var character_height := 1.9

## Which clip plays when standing still, and which when crossing the room. Driven from
## the movement state here rather than set once at spawn: a character who walks on the
## spot while standing still reads as broken before anything else about him registers.
const STILL := "idle"
const MOVING := "walk"
## Long enough to hide the switch, short enough that a step does not start late.
const BLEND := 0.18

var _target: Vector3
var _moving := false
var _body: Node3D
var _clips: AnimationPlayer
var _playing := ""
var _looked := false


func _ready() -> void:
	_body = get_node_or_null("Body")


func walk_to(point: Vector3) -> void:
	_target = point
	_moving = true


func stop() -> void:
	_moving = false
	_play(STILL)
	velocity = Vector3.ZERO


## The AnimationPlayer arrives with the model, which is attached after _ready, so it is
## found on first use rather than at startup. Looked for once: a character with no clips
## is a placeholder capsule, and searching the tree every frame for something that is
## never going to be there is a cost for nothing.
func _find_clips() -> void:
	_looked = true
	if _body == null:
		return
	var players := _body.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_clips = players[0] as AnimationPlayer


func _play(clip: String) -> void:
	if not _looked:
		_find_clips()
	if _clips == null or _playing == clip or not _clips.has_animation(clip):
		return
	_clips.play(clip, BLEND)
	_playing = clip


func _physics_process(delta: float) -> void:
	if not _moving:
		_play(STILL)
		velocity = Vector3.ZERO
		move_and_slide()
		return
	_play(MOVING)

	var to_target := _target - global_position
	to_target.y = 0.0

	if to_target.length() <= arrive_distance:
		_moving = false
		_play(STILL)
		velocity = Vector3.ZERO
		move_and_slide()
		arrived.emit()
		return

	var direction := to_target.normalized()
	velocity = direction * speed
	move_and_slide()

	# Turn to face where he is going, rather than snapping. A character who pivots
	# instantly reads as a sprite being flipped, which is the thing 3D is here to avoid.
	if _body and direction.length_squared() > 0.001:
		var wanted := atan2(direction.x, direction.z)
		_body.rotation.y = lerp_angle(_body.rotation.y, wanted, turn_speed * delta)
