class_name Unlit
extends Node3D
## Draw this thing's texture as painted, with no engine lighting on it.
##
## Why a script and not a saved material: the material sits on a MeshInstance3D INSIDE
## an imported .glb, and Godot cannot write a property on a node inside an instanced
## scene without saving that node in full - which inlines the whole mesh into the
## .tscn. The room went from 22 KB to 8.7 MB the one time that happened, and setting
## it in the prefab generator instead was simply not saved at all: the prefabs kept
## their PBR materials, the lights had been removed, and every prop rendered as a
## black silhouette.
##
## Why unlit at all: a StandardMaterial3D is PHYSICALLY based. It computes its own
## response to every light in the room, and that response is what makes a cartoon read
## as plastic. Tripo delights during texturing, so these textures already carry colour
## and no shading - lighting them a second time is the whole problem.
##
## This runs at _ready in the real game, not behind a flag. The room the owner opens
## is the room he gets.

## What to flatten. Defaults to this node and everything under it, which is how a
## prop prefab uses it - the script sits on the prefab root. A character already has
## a script on its root (mover.gd), so there it is added as a CHILD pointing at "..".
@export var target: NodePath = NodePath(".")


func _ready() -> void:
	var what := get_node_or_null(target)
	if what == null:
		push_error("unlit: nothing at '%s' under %s" % [target, name])
		return
	flatten(what)


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
