extends Node3D
## Count Fingers' bowl: the generated mesh, wearing glass.
##
## The glass is applied here rather than saved into the room scene because a
## `material_override` sits on the MeshInstance3D INSIDE the imported .glb, and Godot
## cannot write a property on a node inside an instanced scene without saving that node
## in full - which writes the whole mesh into the .tscn. The room file went from 22 KB
## to 8.7 MB the one time that happened.
##
## A generator cannot make glass: Tripo delights its textures and has no concept of
## transparency, so the shape is the art's and the material is ours. The bowl's own
## baked texture is thrown away entirely by the override.
##
## This is not placement. Where the bowl stands is in the room scene and the owner moves
## it by dragging it; this script only decides what it is made of.

## The bowl mesh, and nothing else under this node. Named explicitly rather than found
## by group, because a group added to a node inside an instanced .glb is not saved with
## the room - the first attempt glazed the water and Count Fingers along with it, and he
## vanished.
@export var glass: NodePath

## Tinted rather than clear: a perfectly clear sphere has no edge anywhere and reads as
## a hole. The tint is what says there is glass here.
@export var tint := Color(0.72, 0.86, 0.92, 0.22)
@export_range(0.0, 1.0) var roughness := 0.04


func _ready() -> void:
	var bowl := get_node_or_null(glass) as Node3D
	if bowl == null:
		push_error("fishbowl: no glass mesh at '%s' under %s" % [glass, name])
		return

	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.metallic = 0.0
	material.roughness = roughness
	# Both faces, because the inside of the far wall is visible through the near one.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	for node in bowl.find_children("*", "MeshInstance3D", true, false):
		var vis := node as MeshInstance3D
		vis.material_override = material
		vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
