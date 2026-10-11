@tool
extends Node3D
const UnlitScript := preload("res://props/parts/unlit.gd")
## Count Fingers' bowl: the generated mesh, wearing glass.
##
## Tint and roughness are editable on the prefab or an individual instance. This
## editor-visible component supplies glass without changing the imported geometry.
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
@export var glass: NodePath:
	set(value):
		glass = value
		_refresh()

## Tinted rather than clear: a perfectly clear sphere has no edge anywhere and reads as
## a hole. The tint is what says there is glass here.
@export var tint := Color(0.72, 0.86, 0.92, 0.22):
	set(value):
		tint = value
		_refresh()
@export_range(0.0, 1.0) var roughness := 0.04:
	set(value):
		roughness = value
		_refresh()

## Flat tinted glass for locations using painted lighting without engine lights.
## Roughness applies when this is disabled; painted glass uses the unshaded default.
@export var painted_glass := true:
	set(value):
		painted_glass = value
		_refresh()

var _original_materials: Dictionary = {}


func _ready() -> void:
	apply_material()


func _enter_tree() -> void:
	if is_node_ready():
		apply_material.call_deferred()


func _exit_tree() -> void:
	var retained: Array[Material] = []
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.material_override: retained.append(mesh.material_override)
		for surface in mesh.get_surface_override_material_count():
			var current := mesh.get_surface_override_material(surface)
			if current: retained.append(current)
	UnlitScript.retain_through_teardown(retained, get_tree())
	var bowl := get_node_or_null(glass) as Node3D
	if bowl != null:
		for node in bowl.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if _original_materials.has(mesh.get_instance_id()):
				mesh.material_override = _original_materials[mesh.get_instance_id()]
	_original_materials.clear()


func _refresh() -> void:
	if is_inside_tree():
		apply_material.call_deferred()


func _get_configuration_warnings() -> PackedStringArray:
	return ["Assign the glass model node."] if get_node_or_null(glass) == null else []


func apply_material() -> void:
	var bowl := get_node_or_null(glass) as Node3D
	if bowl == null:
		if not Engine.is_editor_hint():
			push_error("fishbowl: no glass mesh at '%s' under %s" % [glass, name])
		return
	if Engine.is_editor_hint():
		update_configuration_warnings()

	var material := StandardMaterial3D.new()
	# The cabin uses painted fake lighting; transparent glass must remain visible without Light3D.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if painted_glass else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.albedo_color = tint
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.metallic = 0.0
	material.roughness = 1.0 if painted_glass else roughness
	# Both faces, because the inside of the far wall is visible through the near one.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	for node in bowl.find_children("*", "MeshInstance3D", true, false):
		var vis := node as MeshInstance3D
		if not _original_materials.has(vis.get_instance_id()):
			_original_materials[vis.get_instance_id()] = vis.material_override
		vis.material_override = material
		vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
