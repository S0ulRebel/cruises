class_name Highlight
extends RefCounted
## Lighting up the thing under the cursor.
##
## Static, with no state of its own: it is told which node to light and whether to
## light it. Separate from interaction orchestration because "what the mouse is over" and "how a thing
## shows that it is clickable" are two subjects, and the second one is the kind that
## grows - an outline shader, a different colour per verb, a pulse.

## Warm, not white, so it reads as lamplight catching the thing rather than as a
## selection box. Faint, because 0.9 turned the crate into a lantern: the player needs
## to know it is clickable, not to be dazzled by it.
const COLOUR := Color("#c79a52")
const STRENGTH := 0.18

## A hotspot is an invisible Area3D, so it names the mesh that should light up instead.
const VISUAL := "visual"


## Light `what`, or its explicitly assigned local visual.
static func set_on(what: Node, on: bool, _room: Node = null) -> void:
	var target: Node = what
	if what is Hotspot and what.visual:
		target = what.visual
	for node in meshes_of(target):
		var mesh := node as MeshInstance3D
		# material_override beats any surface override, so a mesh that has one has to
		# be lit through it - setting a surface override on a mesh that already has an
		# override changes nothing at all, silently.
		if mesh.material_override is BaseMaterial3D:
			if not mesh.has_meta("highlight_unique_override"):
				mesh.material_override = mesh.material_override.duplicate()
				mesh.set_meta("highlight_unique_override", true)
			_glow(mesh.material_override as BaseMaterial3D, on)
			continue
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material is BaseMaterial3D:
				var lit := mesh.get_surface_override_material(surface) as BaseMaterial3D
				if lit == null or not mesh.has_meta("highlight_unique_%d" % surface):
					lit = (material as BaseMaterial3D).duplicate()
					mesh.set_surface_override_material(surface, lit)
					mesh.set_meta("highlight_unique_%d" % surface, true)
				_glow(lit, on)


static func _glow(material: BaseMaterial3D, on: bool) -> void:
	if not material.has_meta("highlight_rest"):
		material.set_meta("highlight_rest", [material.emission_enabled, material.emission,
			material.emission_energy_multiplier])
	var rest: Array = material.get_meta("highlight_rest")
	material.emission_enabled = true if on else rest[0]
	material.emission = COLOUR if on else rest[1]
	material.emission_energy_multiplier = STRENGTH if on else rest[2]


## Every mesh in or under a node, including the node itself. A generated prop is a
## mesh inside a scene; a placeholder box IS the mesh.
static func meshes_of(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		out.append(child)
	return out
