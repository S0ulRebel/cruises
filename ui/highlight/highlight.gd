class_name Highlight
extends RefCounted
## Lighting up the thing under the cursor.
##
## Static, with no state of its own: it is told which node to light and whether to
## light it. Separate from main.gd because "what the mouse is over" and "how a thing
## shows that it is clickable" are two subjects, and the second one is the kind that
## grows - an outline shader, a different colour per verb, a pulse.

## Warm, not white, so it reads as lamplight catching the thing rather than as a
## selection box. Faint, because 0.9 turned the crate into a lantern: the player needs
## to know it is clickable, not to be dazzled by it.
const COLOUR := Color("#c79a52")
const STRENGTH := 0.18

## A hotspot is an invisible Area3D, so it names the mesh that should light up instead.
const VISUAL := "visual"


## Light `what`, or the mesh it names, searching under `room` for that name.
static func set_on(what: Node, on: bool, room: Node) -> void:
	var target: Node = what
	if what.has_meta(VISUAL):
		var named := room.find_child(String(what.get_meta(VISUAL)), true, false)
		if named:
			target = named
	for node in meshes_of(target):
		var mesh := node as MeshInstance3D
		# material_override beats any surface override, so a mesh that has one has to
		# be lit through it - setting a surface override on a mesh that already has an
		# override changes nothing at all, silently.
		if mesh.material_override is BaseMaterial3D:
			_glow(mesh.material_override as BaseMaterial3D, on)
			continue
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material is BaseMaterial3D:
				var lit := mesh.get_surface_override_material(surface) as BaseMaterial3D
				if lit == null:
					lit = (material as BaseMaterial3D).duplicate()
					mesh.set_surface_override_material(surface, lit)
				_glow(lit, on)


static func _glow(material: BaseMaterial3D, on: bool) -> void:
	material.emission_enabled = on
	material.emission = COLOUR
	material.emission_energy_multiplier = STRENGTH if on else 0.0


## Every mesh in or under a node, including the node itself. A generated prop is a
## mesh inside a scene; a placeholder box IS the mesh.
static func meshes_of(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		out.append(child)
	return out
