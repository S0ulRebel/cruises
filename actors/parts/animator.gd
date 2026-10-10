class_name Animator
extends RefCounted
## Layered animation for a Mixamo-rigged character.
##
## Two axes, built the way the owner described them:
##
##   REGIONS    the body, the hands and the face are separate layers over one skeleton,
##              so each can be driven by a different source. Body motion comes from a
##              text-to-motion model, hands from a poser, the face from blend shapes -
##              three different pipelines that must not overwrite each other.
##
##   SIMULTANEOUS MOTIONS   a walk drives the whole body while a wave plays on one arm
##              and overrides the walk's arm swing there. Not a separate "walk while
##              waving" clip.
##
## The second axis is why this is layered at runtime rather than baked. Baking needs a
## clip per combination - walk+wave, walk+point, idle+wave, idle+think - which is the
## product of the two lists. Layering needs their sum. With ten locomotions and ten
## gestures that is 20 clips instead of 100, and adding an eleventh gesture costs one
## clip rather than ten.
##
## The graph:
##
##   locomotion (BlendSpace1D, by speed)  ->  Add2 [filter: right arm]   <- gesture
##                                        ->  Add2 [filter: both hands]  <- hand pose
##                                        ->  output
##
## Filtering is the whole mechanism and it has one notorious trap: ticking bones does
## nothing unless filtering is also ENABLED on that node. Missing it silently applies
## the layer to the entire skeleton, which looks like the filter is being ignored.

## Mixamo bone chains, by region. A filter must list every bone it means to drive:
## a child inherits its parent's rotation, so filtering the upper arm alone still lets
## the forearm and hand swing with the body underneath.
const RIGHT_ARM := [
	"mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightForeArm",
	"mixamorig_RightHand",
]
const LEFT_ARM := [
	"mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm",
	"mixamorig_LeftHand",
]
## Fingers only - the arm is deliberately absent, so a hand pose can play over whatever
## the arm is doing.
const RIGHT_FINGERS := [
	"mixamorig_RightHandThumb1", "mixamorig_RightHandThumb2", "mixamorig_RightHandThumb3",
	"mixamorig_RightHandIndex1", "mixamorig_RightHandIndex2", "mixamorig_RightHandIndex3",
	"mixamorig_RightHandMiddle1", "mixamorig_RightHandMiddle2", "mixamorig_RightHandMiddle3",
	"mixamorig_RightHandRing1", "mixamorig_RightHandRing2", "mixamorig_RightHandRing3",
	"mixamorig_RightHandPinky1", "mixamorig_RightHandPinky2", "mixamorig_RightHandPinky3",
]
const LEFT_FINGERS := [
	"mixamorig_LeftHandThumb1", "mixamorig_LeftHandThumb2", "mixamorig_LeftHandThumb3",
	"mixamorig_LeftHandIndex1", "mixamorig_LeftHandIndex2", "mixamorig_LeftHandIndex3",
	"mixamorig_LeftHandMiddle1", "mixamorig_LeftHandMiddle2", "mixamorig_LeftHandMiddle3",
	"mixamorig_LeftHandRing1", "mixamorig_LeftHandRing2", "mixamorig_LeftHandRing3",
	"mixamorig_LeftHandPinky1", "mixamorig_LeftHandPinky2", "mixamorig_LeftHandPinky3",
]
const HEAD := ["mixamorig_Neck", "mixamorig_Head"]
## Everything from the chest up. For a gesture that leans the torso, not just the arm.
const UPPER_BODY := [
	"mixamorig_Spine1", "mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head",
] + RIGHT_ARM + LEFT_ARM

## The layers, in the order they stack. Each is an Add2 filtered to its own bones, so a
## layer at zero contributes nothing and the one beneath shows through untouched.
const LAYERS := [
	{ "name": "gesture_right", "bones": RIGHT_ARM },
	{ "name": "gesture_left", "bones": LEFT_ARM },
	{ "name": "hands", "bones": RIGHT_FINGERS + LEFT_FINGERS },
	{ "name": "head", "bones": HEAD },
]


## Build the tree. `player` must already hold the clips; `skeleton_path` is the path the
## AnimationPlayer resolves bones from, which is what filter paths are written against.
static func build(tree: AnimationTree, player: AnimationPlayer, skeleton_path: String,
		locomotion: Array[String]) -> AnimationNodeBlendTree:
	var graph := AnimationNodeBlendTree.new()

	var base := _locomotion(player, locomotion)
	graph.add_node("locomotion", base, Vector2(0, 0))

	var previous := "locomotion"
	var y := 0.0
	for layer in LAYERS:
		var name := String(layer["name"])
		var clip := AnimationNodeAnimation.new()
		graph.add_node(name + "_clip", clip, Vector2(0, y + 180))

		var add := AnimationNodeAdd2.new()
		# Both halves of the trap, together: enable filtering, THEN list the bones.
		# Enabling without listing drives nothing; listing without enabling drives
		# the whole skeleton.
		add.filter_enabled = true
		for bone in layer["bones"]:
			add.set_filter_path(NodePath("%s:%s" % [skeleton_path, bone]), true)
		graph.add_node(name, add, Vector2(300, y))

		graph.connect_node(name, 0, previous)
		graph.connect_node(name, 1, name + "_clip")
		previous = name
		y += 220.0

	graph.connect_node("output", 0, previous)
	tree.tree_root = graph
	tree.anim_player = tree.get_path_to(player)
	tree.active = true
	return graph


## Locomotion as a 1D blend space over speed, so idle and walk are one dial rather than
## two clips with a transition to manage.
static func _locomotion(player: AnimationPlayer, clips: Array[String]) -> AnimationNodeBlendSpace1D:
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = 1.0
	for i in clips.size():
		if not player.has_animation(clips[i]):
			continue
		var node := AnimationNodeAnimation.new()
		node.animation = clips[i]
		space.add_blend_point(node, float(i) / maxf(1.0, float(clips.size() - 1)), -1, clips[i])
	return space


## Which bones a layer actually drives. The filter is invisible once set, and a filter
## that silently covers the whole skeleton looks exactly like one that works.
static func describe(graph: AnimationNodeBlendTree, skeleton: Skeleton3D,
		skeleton_path: String) -> void:
	for layer in LAYERS:
		var name := String(layer["name"])
		var node := graph.get_node(name) as AnimationNodeAdd2
		if node == null:
			continue
		var driven := 0
		for i in skeleton.get_bone_count():
			if node.is_path_filtered(NodePath("%s:%s" % [skeleton_path, skeleton.get_bone_name(i)])):
				driven += 1
		print("  %-14s filtering=%s  drives %d of %d bones" % [
			name, node.filter_enabled, driven, skeleton.get_bone_count()])
