extends Node3D
## Verifies the layer filters cover the bones they claim and nothing else. A filter is
## invisible once set, and one that silently covers the whole skeleton looks identical
## to one that works - so it is checked by counting, not by eye.

const Animator := preload("res://actors/parts/animator.gd")
const BorrowClips := preload("res://actors/parts/borrow_clips.gd")

func _ready() -> void:
	var model := (load("res://art/characters/captain_live/captain_live_animated.glb") as PackedScene).instantiate()
	add_child(model)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D

	var player := AnimationPlayer.new()
	player.name = "Clips"
	model.add_child(player)
	var lib := BorrowClips.library("res://art/animations/clip_source.glb", skeleton, model)
	player.add_animation_library("", lib)

	var tree := AnimationTree.new()
	model.add_child(tree)
	var path := String(model.get_path_to(skeleton))
	var graph := Animator.build(tree, player, path, ["idle", "walk", "run"] as Array[String])

	print("skeleton: %d bones at '%s'" % [skeleton.get_bone_count(), path])
	print("clips: %d" % lib.get_animation_list().size())
	print("layers:")
	Animator.describe(graph, skeleton, path)

	# The point of the whole thing: the gesture layer must leave the legs alone.
	var right := graph.get_node("gesture_right") as AnimationNodeAdd2
	var leg := NodePath("%s:mixamorig_RightUpLeg" % path)
	var arm := NodePath("%s:mixamorig_RightArm" % path)
	print("\ngesture_right drives RightArm:   %s  (must be true)" % right.is_path_filtered(arm))
	print("gesture_right drives RightUpLeg: %s  (must be false)" % right.is_path_filtered(leg))
	get_tree().quit()
