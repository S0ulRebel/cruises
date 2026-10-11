@tool
class_name StylizedMaterialBinding
extends Node3D
## Apply an editable fake-light material to existing meshes, retaining their textures.
## Owns per-surface copies, never changes geometry, transforms or source resources.

@export var target: NodePath = NodePath(".."):
	set(value):
		target = value
		_schedule_apply()
@export var material: ShaderMaterial:
	set(value):
		if material != null and material.changed.is_connected(_schedule_apply):
			material.changed.disconnect(_schedule_apply)
		material = value
		if material != null and not material.changed.is_connected(_schedule_apply):
			material.changed.connect(_schedule_apply)
		_schedule_apply()
@export var texture_override: Texture2D:
	set(value):
		texture_override = value
		_schedule_apply()
@export var preserve_source_tint := true:
	set(value):
		preserve_source_tint = value
		_schedule_apply()

var _originals: Dictionary = {}
var _materials: Array[ShaderMaterial] = []
var _light_parameters: Dictionary = {}
var _scheduled := false
var _template_state: Dictionary = {}

func _ready() -> void:
	if material != null and not material.changed.is_connected(_schedule_apply):
		material.changed.connect(_schedule_apply)
	apply()

func _process(_delta: float) -> void:
	# ShaderMaterial uniform edits do not emit Resource.changed in Godot.
	# Detect Inspector/code edits so per-instance copies remain editable live.
	if _capture_template_state() != _template_state:
		_schedule_apply()

func _capture_template_state() -> Dictionary:
	var state: Dictionary = {"material": material}
	if material == null or material.shader == null: return state
	state["shader"] = material.shader
	for uniform in material.shader.get_shader_uniform_list():
		state[uniform.name] = material.get_shader_parameter(uniform.name)
	return state

func _schedule_apply() -> void:
	if is_inside_tree() and not _scheduled:
		_scheduled = true
		apply.call_deferred()

func apply() -> void:
	_scheduled = false
	if not is_inside_tree(): return
	var root := get_node_or_null(target)
	_template_state = _capture_template_state()
	_restore()
	if root == null or material == null:
		update_configuration_warnings()
		return
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D: meshes.push_front(root)
	for node in meshes:
		var mesh := node as MeshInstance3D
		if mesh.mesh == null: continue
		var surfaces: Array = []
		for index in mesh.mesh.get_surface_count():
			surfaces.append(mesh.get_surface_override_material(index))
		_originals[mesh] = {"override": mesh.material_override, "surfaces": surfaces}
		# Read each original active material before removing a whole-mesh override.
		var sources: Array[Material] = []
		for index in mesh.mesh.get_surface_count():
			sources.append(mesh.get_active_material(index))
		mesh.material_override = null
		for index in sources.size():
			var copy := material.duplicate() as ShaderMaterial
			var source := sources[index] as BaseMaterial3D
			var texture := texture_override
			if texture == null and source != null: texture = source.albedo_texture
			if texture != null: copy.set_shader_parameter("albedo_texture", texture)
			if preserve_source_tint and source != null:
				var tint: Variant = material.get_shader_parameter("base_tint")
				copy.set_shader_parameter("base_tint", source.albedo_color * (tint if tint is Color else Color.WHITE))
			for key in _light_parameters: copy.set_shader_parameter(key, _light_parameters[key])
			mesh.set_surface_override_material(index, copy)
			_materials.append(copy)
	update_configuration_warnings()

func set_light_parameters(parameters: Dictionary) -> void:
	var removed := false
	for key in _light_parameters:
		if not parameters.has(key): removed = true
	_light_parameters = parameters.duplicate()
	if removed:
		apply()
		return
	for copy in _materials:
		for key in parameters: copy.set_shader_parameter(key, parameters[key])

func clear_light_parameters() -> void:
	_light_parameters.clear()
	apply()

func get_applied_materials() -> Array[ShaderMaterial]:
	return _materials.duplicate()

func _restore() -> void:
	var retained: Array[Material] = []
	for copy in _materials: retained.append(copy)
	for mesh in _originals:
		if not is_instance_valid(mesh): continue
		var record: Dictionary = _originals[mesh]
		mesh.material_override = record.override
		for index in mini(record.surfaces.size(), mesh.get_surface_override_material_count()):
			mesh.set_surface_override_material(index, record.surfaces[index])
	_originals.clear()
	_materials.clear()
	if not retained.is_empty() and is_inside_tree():
		Unlit.retain_through_teardown(retained, get_tree())

func _exit_tree() -> void:
	_restore()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if get_node_or_null(target) == null: warnings.append("Assign the existing model or mesh this component affects.")
	if material == null: warnings.append("Assign a _shader or _graph ShaderMaterial from the library.")
	return warnings
