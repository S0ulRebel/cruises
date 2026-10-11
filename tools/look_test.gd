extends RefCounted
## Render the same room under each stylised-lighting option, so the choice is made by
## looking rather than by reading.
##
##     godot --path . -- --shot --look off
##     ... rig | builtin | toon | toon_hard | poster
##
## A tool. Nothing here runs in the game; main.gd calls apply() only when --look is on
## the command line.

const TOON := "res://systems/look/toon.gdshader"
const POSTER := "res://systems/look/posterise.gdshader"

## Every option, in the order they are worth comparing.
const LOOKS := ["unlit", "off", "rig", "builtin", "toon", "toon_hard", "poster"]


static func apply(room: Node3D, look: String, host: Node) -> void:
	match look:
		"unlit":
			_unlit(room)
		"off":
			_strip_environment(room)
			_second_light(room)
		"rig":
			pass  # what the room already is
		"builtin":
			_builtin_toon(room)
		"toon":
			_cel(room, 3, 0.06)
		"toon_hard":
			_cel(room, 2, 0.0)
		"poster":
			_posterise(host)
		_:
			push_error("look_test: no look called '%s'" % look)


## No lighting at all. Every surface is its own texture, drawn as painted.
##
## This is the baseline the look gets built on, not a variant of it. A
## StandardMaterial3D is PHYSICALLY based: it computes its own response to every light
## in the room, and that response is the thing that makes a cartoon read as plastic.
## Turning it off is not a style choice yet, it is removing the thing in the way.
##
## Tripo delights during texturing, so these textures carry colour and no shading -
## which is exactly what an unlit material wants and why this is worth looking at
## before anything is added back.
##
## Every light in the room is switched off too, not just ignored: an unlit surface
## does not read them, but anything still on a PBR material would, and the point is
## that nothing in the picture is lit by the engine.
static func _unlit(room: Node3D) -> void:
	var env := room.get_node_or_null("Lighting")
	if env:
		env.queue_free()
	for node in room.find_children("*", "Light3D", true, false):
		(node as Light3D).visible = false

	var flattened := 0
	for mesh in _meshes(room):
		for surface in mesh.get_surface_override_material_count():
			var base := mesh.get_active_material(surface) as BaseMaterial3D
			if base == null:
				continue
			var flat: BaseMaterial3D = base.duplicate()
			flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.set_surface_override_material(surface, flat)
			flattened += 1
	print("unlit: %d surfaces flattened, %d lights off" % [flattened,
		room.find_children("*", "Light3D", true, false).size()])


## What the room looked like before any of this: two shadow-casting directionals and
## no WorldEnvironment at all.
static func _strip_environment(room: Node3D) -> void:
	var env := room.get_node_or_null("Lighting")
	if env:
		env.queue_free()


static func _second_light(room: Node3D) -> void:
	var fill := DirectionalLight3D.new()
	fill.name = "OldFill"
	fill.rotation_degrees = Vector3(-18.0, -130.0, 0.0)
	fill.light_energy = 0.35
	fill.light_color = Color("#8fb3d9")
	fill.shadow_enabled = true
	room.add_child(fill)


## Godot's own toon diffuse. Needs a LOW roughness - at the 1.0 a Tripo export arrives
## with, it is indistinguishable from normal shading, which is why it gets reported as
## not working.
static func _builtin_toon(room: Node3D) -> void:
	for mesh in _meshes(room):
		for surface in mesh.get_surface_override_material_count():
			var base := mesh.get_active_material(surface) as BaseMaterial3D
			if base == null:
				continue
			var toon: BaseMaterial3D = base.duplicate()
			toon.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			toon.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			toon.roughness = 0.15
			mesh.set_surface_override_material(surface, toon)


## The ported cel shader, carrying each prop's own texture across.
static func _cel(room: Node3D, bands: int, softness: float) -> void:
	var shader := load(TOON) as Shader
	var swapped := 0
	var skipped := 0
	for mesh in _meshes(room):
		for surface in mesh.get_surface_override_material_count():
			var base := mesh.get_active_material(surface) as BaseMaterial3D
			if base == null:
				skipped += 1
				continue
			swapped += 1
			var cel := ShaderMaterial.new()
			cel.shader = shader
			# The one thing that must survive: the prop's own albedo. Without this
			# every object in the room comes out the same flat colour.
			cel.set_shader_parameter("albedo", base.albedo_texture)
			cel.set_shader_parameter("tint", Vector3(
				base.albedo_color.r, base.albedo_color.g, base.albedo_color.b))
			cel.set_shader_parameter("bands", bands)
			cel.set_shader_parameter("band_softness", softness)
			mesh.set_surface_override_material(surface, cel)
	print("cel: %d surfaces swapped, %d skipped, %d meshes" % [swapped, skipped, _meshes(room).size()])


static func _posterise(host: Node) -> void:
	var layer := CanvasLayer.new()
	layer.name = "Posterise"
	# Below the UI's layer, or the dialogue bar gets posterised with the room.
	layer.layer = 5
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load(POSTER) as Shader
	rect.material = material
	layer.add_child(rect)
	host.add_child(layer)


static func _meshes(root: Node) -> Array:
	var out: Array = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		out.append(node as MeshInstance3D)
	return out
