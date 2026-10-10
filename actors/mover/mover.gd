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

## How close to the destination counts as there, for the pathfinder. Separate from
## arrive_distance, which is about the final step.
@export var path_desired_distance := 0.35
@export var path_target_distance := 0.35
## Radius other characters path around. A character is an obstacle to everyone else,
## which is how "you cannot walk through Santi" works without re-baking anything.
@export var obstacle_radius := 0.45
## Set false for anything that should not block others - a ghost, a fish in a bowl.
@export var blocks_others := true

var _target: Vector3
var _moving := false
var _agent: NavigationAgent3D
## Where to look once he gets there. NAN means keep whatever facing the walk gave him.
var _final_facing := NAN
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
	_build_agent()
	if blocks_others:
		_build_obstacle()


## Pathfinding, rather than walking straight at the target and grinding along whatever
## is in the way. See Room3D._build_navigation for why a point-and-click wants this.
func _build_agent() -> void:
	_agent = NavigationAgent3D.new()
	_agent.name = "Agent"
	_agent.path_desired_distance = path_desired_distance
	_agent.target_desired_distance = path_target_distance
	_agent.radius = 0.26
	_agent.height = character_height
	# Avoidance off on purpose: it makes characters drift and jitter around each other
	# even when nobody is moving. Standing in the way is handled by the obstacle below,
	# which is a hole in the map rather than a steering force.
	_agent.avoidance_enabled = false
	add_child(_agent)


## This character, as something others have to walk around. Carved at runtime, so it
## follows him rather than needing the room re-baked every step.
func _build_obstacle() -> void:
	var obstacle := NavigationObstacle3D.new()
	obstacle.name = "Obstacle"
	obstacle.radius = obstacle_radius
	obstacle.height = character_height
	obstacle.affect_navigation_mesh = true
	obstacle.carve_navigation_mesh = true
	add_child(obstacle)


## Walk to a point. `facing_degrees` is an optional heading to settle into on arrival -
## leave it out and he keeps whatever direction he was walking.
func walk_to(point: Vector3, facing_degrees := NAN) -> void:
	_target = point
	_final_facing = facing_degrees
	_moving = true
	if _agent:
		_agent.target_position = point


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

	# Where to head NEXT, which is a corner of the path rather than the destination.
	# Falling back to the straight line keeps this working in scenes with no navigation
	# baked - the check harnesses, and any room not yet built.
	var step := _target
	if _agent and not _agent.is_navigation_finished():
		step = _agent.get_next_path_position()

	var to_target := _target - global_position
	to_target.y = 0.0
	var reached := to_target.length() <= arrive_distance
	if _agent:
		reached = _agent.is_navigation_finished()

	if reached:
		_moving = false
		_play(STILL)
		velocity = Vector3.ZERO
		move_and_slide()
		_settle_facing()
		arrived.emit()
		return

	var to_step := step - global_position
	to_step.y = 0.0
	var direction := to_step.normalized() if to_step.length() > 0.001 else Vector3.ZERO
	velocity = direction * speed
	move_and_slide()

	# Turn to face where he is going, rather than snapping. A character who pivots
	# instantly reads as a sprite being flipped, which is the thing 3D is here to avoid.
	if _body and direction.length_squared() > 0.001:
		var wanted := atan2(direction.x, direction.z)
		_body.rotation.y = lerp_angle(_body.rotation.y, wanted, turn_speed * delta)


## Turn to the heading the caller asked for on arrival, if it asked for one. This is
## what makes him address Santi rather than Santi's shoulder.
func _settle_facing() -> void:
	if _body == null or is_nan(_final_facing):
		return
	_body.rotation.y = deg_to_rad(_final_facing)
	_final_facing = NAN
