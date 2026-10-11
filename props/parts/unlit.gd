@tool
class_name Unlit
extends Node3D
## Draw this thing's texture as painted, with no engine lighting on it.
##
## This material component leaves imported models intact and applies the same
## treatment to every mesh, including meshes added by a later model reimport.
## Materials are copied per instance so editing one prop does not affect another.
##
## Why unlit at all: a StandardMaterial3D is PHYSICALLY based. It computes its own
## response to every light in the room, and that response is what makes a cartoon read
## as plastic. Tripo delights during texturing, so these textures already carry colour
## and no shading - lighting them a second time is the whole problem.
##
## This component also runs in the editor, so the authored preview has the same
## materials as the game. It does not construct nodes or change placement.

## What to flatten. Defaults to this node and everything under it, which is how a
## prop prefab uses it - the script sits on the prefab root. A character already has
## a script on its root (mover.gd), so there it is added as a CHILD pointing at "..".
@export var target: NodePath = NodePath("."):
	set(value):
		target = value
		if is_inside_tree():
			apply.call_deferred()


func _ready() -> void:
	apply()


func apply() -> void:
	var what := get_node_or_null(target)
	if what == null:
		if not Engine.is_editor_hint():
			push_error("unlit: nothing at '%s' under %s" % [target, name])
		return
	flatten(what)
	if Engine.is_editor_hint():
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	return ["Assign the model this material component affects."] if get_node_or_null(target) == null else []


## Every mesh under `root`, drawn as painted. Static so the room shell and anything
## else can use it without being one of these.
static func flatten(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		# material_override beats every surface override, so a mesh that has one has
		# to be flattened through it or nothing happens, silently.
		if mesh.material_override is BaseMaterial3D:
			var over: BaseMaterial3D = (mesh.material_override as BaseMaterial3D).duplicate()
			over.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.material_override = over
			continue
		for surface in mesh.get_surface_override_material_count():
			var base := mesh.get_active_material(surface) as BaseMaterial3D
			if base == null:
				continue
			var flat: BaseMaterial3D = base.duplicate()
			flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.set_surface_override_material(surface, flat)
