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
var _tree: AnimationTree
var _playing := ""
var _looked := false
## Where the locomotion blend space is now, and where it is heading. 0 is standing, 1
## is walking. Eased rather than set, because the blend space has no crossfade of its
## own the way AnimationPlayer.play(clip, blend) does.
var _gait := 0.0
var _gait_target := 0.0


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
	# A character with hand poses is driven by the layered graph instead - main.gd
	# builds it. Both are looked for: the cast is mixed while characters are still
	# coming through the pipeline one at a time.
	var trees := _body.find_children("*", "AnimationTree", true, false)
	if not trees.is_empty():
		_tree = trees[0] as AnimationTree


func _play(clip: String) -> void:
	if not _looked:
		_find_clips()
	if _tree != null:
		_gait_target = 1.0 if clip == MOVING else 0.0
		return
	if _clips == null or _playing == clip or not _clips.has_animation(clip):
		return
	_clips.play(clip, BLEND)
	_playing = clip


## Hold a hand pose over whatever the body is doing. The name is a clip in the
## character file - see tools/add_hand_poses.py and main.gd HAND_POSES.
func set_hand_pose(pose: String) -> void:
	if not _looked:
		_find_clips()
	if _tree == null or _clips == null or not _clips.has_animation(pose):
		return
	var graph := _tree.tree_root as AnimationNodeBlendTree
	if graph == null:
		return
	var node := graph.get_node("hands_clip") as AnimationNodeAnimation
	if node == null:
		return
	node.animation = pose
	_tree.set("parameters/hands/add_amount", 1.0)


## Ease the blend space toward the gait that was asked for. BLEND is the time a full
## stand-to-walk change takes, so the rate is its reciprocal.
func _drive_gait(delta: float) -> void:
	if _tree == null:
		return
	_gait = move_toward(_gait, _gait_target, delta / BLEND)
	_tree.set("parameters/locomotion/blend_position", _gait)


func _physics_process(delta: float) -> void:
	_drive_gait(delta)
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
