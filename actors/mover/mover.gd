@tool
extends CharacterBody3D
## Someone crossing a room, in three dimensions.
##
## Much less work than the 2D version, because the camera is doing the parts that had
## to be faked there. No depth sorting, no perspective scaling, no marker interpolation
## - a character two metres further back is simply two metres further back.
##
## Body, Agent, Obstacle and collision are authored children of the actor prefab.

signal arrived
signal movement_finished(success: bool, reason: String)
@export var definition: CharacterDefinition
@export var movement_timeout := 30.0
@export var stuck_timeout := 2.0
var _elapsed := 0.0
var _stuck := 0.0
var _last_position := Vector3.ZERO

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
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"
## Optional explicit player for assemblies containing several independent local rigs.
@export var animation_player_path: NodePath
## Long enough to hide the switch, short enough that a step does not start late.
const BLEND := 0.18

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
	_agent = get_node_or_null("Agent") as NavigationAgent3D
	if Engine.is_editor_hint(): return
	if _agent and _agent.avoidance_enabled:
		_agent.velocity_computed.connect(_on_safe_velocity)
	if _agent == null: push_error("Mover requires its authored Agent child.")

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if get_node_or_null("Body") == null: warnings.append("Author a Body visual child.")
	if get_node_or_null("Agent") == null: warnings.append("Author a NavigationAgent3D named Agent.")
	return warnings


## Walk to a point. `facing_degrees` is an optional heading to settle into on arrival -
## leave it out and he keeps whatever direction he was walking.
func walk_to(point: Vector3, facing_degrees := NAN) -> void:
	if _moving:
		_finish_movement(false, "cancelled")
	_target = point
	_final_facing = facing_degrees
	_moving = true
	_elapsed = 0.0
	_stuck = 0.0
	_last_position = global_position
	if _agent:
		_agent.target_position = point


func stop() -> void:
	if _moving:
		_finish_movement(false, "cancelled")
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
	if not animation_player_path.is_empty():
		_clips = get_node_or_null(animation_player_path) as AnimationPlayer
	elif not players.is_empty():
		_clips = players[0] as AnimationPlayer
	if not animation_player_path.is_empty():
		# An unrelated local facial tree must not override this explicitly selected
		# locomotion player. Existing authored layered actors retain the default route.
		return
	# A character with hand poses may carry an authored layered graph.
	# Both are looked for: the cast is mixed while characters are still
	# coming through the pipeline one at a time.
	_tree = get_node_or_null("Layers") as AnimationTree
	if _tree == null:
		var trees := _body.find_children("*", "AnimationTree", true, false)
		if not trees.is_empty():
			_tree = trees[0] as AnimationTree


func _play(clip: String) -> void:
	if not _looked:
		_find_clips()
	if _tree != null:
		_gait_target = 1.0 if clip == MOVING else 0.0
		return
	var resolved := String(idle_animation) if clip == STILL else String(walk_animation) if clip == MOVING else clip
	if _clips == null or _playing == resolved or not _clips.has_animation(resolved):
		return
	_clips.play(resolved, BLEND)
	_playing = resolved


## Hold a hand pose over whatever the body is doing. The name is a clip in the
## character file - see tools/add_hand_poses.py and the authored actor animations.
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
	if Engine.is_editor_hint(): return
	_drive_gait(delta)
	if not _moving:
		_play(STILL)
		velocity = Vector3.ZERO
		if _agent and _agent.avoidance_enabled:
			_agent.velocity = Vector3.ZERO
		move_and_slide()
		return
	_play(MOVING)
	_elapsed += delta
	_stuck = _stuck + delta if global_position.distance_to(_last_position) < 0.001 else 0.0
	_last_position = global_position
	if _elapsed > movement_timeout or _stuck > stuck_timeout:
		_finish_movement(false, "stuck")
		return
	if _agent == null or NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) == 0:
		_finish_movement(false, "navigation_unavailable")
		return

	# Where to head NEXT, which is a corner of the path rather than the destination.
	# Advance the authored agent's path. No straight-line fallback through obstacles.
	var step := _agent.get_next_path_position()
	if not _agent.is_target_reachable():
		_finish_movement(false, "unreachable")
		return

	var to_target := _target - global_position
	to_target.y = 0.0
	var reached := to_target.length() <= maxf(arrive_distance, _agent.target_desired_distance)

	if reached:
		_settle_facing()
		_finish_movement(true, "arrived")
		return
	if _agent.is_navigation_finished():
		_finish_movement(false, "path_exhausted")
		return

	var to_step := step - global_position
	to_step.y = 0.0
	var direction := to_step.normalized() if to_step.length() > 0.001 else Vector3.ZERO
	velocity = direction * speed
	if _agent.avoidance_enabled:
		_agent.velocity = velocity
	else:
		move_and_slide()

	# Turn to face where he is going, rather than snapping. A character who pivots
	# instantly reads as a sprite being flipped, which is the thing 3D is here to avoid.
	if _body and direction.length_squared() > 0.001:
		var wanted := atan2(direction.x, direction.z)
		_body.rotation.y = lerp_angle(_body.rotation.y, wanted - global_rotation.y, turn_speed * delta)


## Turn to the heading the caller asked for on arrival, if it asked for one. This is
## what makes him address Santi rather than Santi's shoulder.
func _settle_facing() -> void:
	if _body == null or is_nan(_final_facing):
		return
	_body.rotation.y = deg_to_rad(_final_facing) - global_rotation.y
	_final_facing = NAN

func _on_safe_velocity(safe_velocity: Vector3) -> void:
	if _moving:
		velocity = safe_velocity
		move_and_slide()

func _finish_movement(success: bool, reason: String) -> void:
	_moving = false
	velocity = Vector3.ZERO
	if _agent and _agent.avoidance_enabled:
		_agent.velocity = Vector3.ZERO
	_play(STILL)
	if success:
		arrived.emit()
	movement_finished.emit(success, reason)
