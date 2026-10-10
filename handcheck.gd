extends Node3D
## Looks at the hand layer in the engine, not in Blender.
##
## Blender renders the clip; this renders what the AnimationTree actually produces,
## which is the thing the game shows. They can differ: the pose is ADDED onto whatever
## finger rotation the locomotion clip already carries, and Mixamo's idle is not a flat
## hand. A pose that reads in isolation can over-curl once that sum is taken.
##
## One PNG per pose, framed on the right hand, plus the measured tip spread so a
## collapse is caught by number rather than by eye.

const Animator := preload("res://actors/parts/animator.gd")
const MODEL := "res://art/characters/captain_live/captain_live_hands.glb"
const POSES := ["hand_relaxed", "hand_open_palm", "hand_point", "hand_grip", "hand_fist"]

var _skeleton: Skeleton3D
var _tree: AnimationTree
var _graph: AnimationNodeBlendTree
var _camera: Camera3D
var _lamp: OmniLight3D
var _index := 0
var _settle := 0


func _ready() -> void:
	var model := (load(MODEL) as PackedScene).instantiate()
	add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for name in POSES:
		if player.has_animation(name):
			player.get_animation(name).loop_mode = Animation.LOOP_LINEAR

	_tree = AnimationTree.new()
	model.add_child(_tree)
	var path := String(model.get_path_to(_skeleton))
	_graph = Animator.build(_tree, player, path, ["idle", "walk"] as Array[String])
	_tree.set("parameters/locomotion/blend_position", 0.0)
	_tree.set("parameters/hands/add_amount", 1.0)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, 35, 0)
	key.light_energy = 2.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -130, 0)
	fill.light_energy = 0.8
	add_child(fill)

	_lamp = OmniLight3D.new()
	_lamp.light_energy = 1.1
	_lamp.omni_range = 2.5
	add_child(_lamp)

	_camera = Camera3D.new()
	_camera.fov = 22.0
	add_child(_camera)
	_camera.make_current()

	# tree.set() on a wrong parameter path fails silently, so the gait dial the mover
	# drives is written and read back here rather than assumed to exist.
	_tree.set("parameters/locomotion/blend_position", 1.0)
	print("gait dial reads back %s (must be 1)" % _tree.get("parameters/locomotion/blend_position"))
	_tree.set("parameters/locomotion/blend_position", 0.0)

	_apply()


func _apply() -> void:
	var node := _graph.get_node("hands_clip") as AnimationNodeAnimation
	node.animation = POSES[_index]
	_settle = 0


## The tree needs a frame or two after a clip swap before the skeleton shows it, and a
## screenshot taken on the same frame catches the previous pose. Waited out rather than
## assumed.
## Mean of every finger bone, which tracks the pose - a fist's centre is closer to the
## wrist than a flat hand's, and framing on it keeps the fingers in shot either way.
func _hand_centre(fallback: Vector3) -> Vector3:
	var total := Vector3.ZERO
	var count := 0
	for i in _skeleton.get_bone_count():
		var name := _skeleton.get_bone_name(i)
		if not name.begins_with("mixamorig_RightHand") or name == "mixamorig_RightHand":
			continue
		total += _skeleton.global_transform * _skeleton.get_bone_global_pose(i).origin
		count += 1
	return total / float(count) if count > 0 else fallback


func _process(_delta: float) -> void:
	# _process keeps firing across the await, so the frame after the last pose comes
	# back with the index already past the end. Guarded, not caught.
	if _index >= POSES.size():
		return
	_settle += 1
	if _settle < 6:
		return

	var hand := _skeleton.find_bone("mixamorig_RightHand")
	var hips := _skeleton.find_bone("mixamorig_Hips")
	var wrist := _skeleton.global_transform * _skeleton.get_bone_global_pose(hand).origin
	var pelvis := _skeleton.global_transform * _skeleton.get_bone_global_pose(hips).origin
	# Aim at the middle of the fingers, not the wrist. The wrist is the top of the
	# hand, so framing on it put the cuff across the middle of every shot.
	var centre := _hand_centre(wrist)
	# Outward along the line from the body to the hand, so the coat is behind the hand
	# rather than in front of it. Shooting from a fixed offset put the lapel in the way.
	var out := (centre - pelvis)
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3.RIGHT
	_camera.global_position = centre + out * 0.52 + Vector3(0.0, 0.06, 0.40)
	# The hand hangs against a near-black coat, so the scene key leaves it in its
	# own shadow. A lamp riding the camera is the only way to read the silhouette.
	_lamp.global_position = _camera.global_position + out * 0.1 + Vector3(0.0, 0.25, 0.0)
	_camera.look_at(centre)

	# Tip-to-WRIST, not tip-to-tip. Tip-to-tip measures how splayed the fingers are,
	# which barely moves between a flat hand and a fist - the number that separates
	# them is how far each tip has travelled back toward the palm.
	var reach := PackedStringArray()
	for finger in ["Index", "Middle", "Ring", "Pinky"]:
		var b := _skeleton.find_bone("mixamorig_RightHand%s3" % finger)
		if b < 0:
			continue
		var tip := _skeleton.global_transform * _skeleton.get_bone_global_pose(b).origin
		reach.append("%.1f" % (tip.distance_to(centre) * 100.0))
	print("%-16s tip reach from hand centre  %s cm" % [POSES[_index], ", ".join(reach)])

	var image_size := get_viewport().get_texture().get_size()
	var at := _camera.unproject_position(centre)
	if _index == 0:
		print("  viewport %s, hand at %s" % [image_size, at])

	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	shot.save_png("res://handshot_%s.png" % POSES[_index])

	_index += 1
	if _index >= POSES.size():
		get_tree().quit()
		return
	_apply()
