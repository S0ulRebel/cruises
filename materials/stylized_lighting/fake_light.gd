@tool
class_name StylizedFakeLight
extends Marker3D
## Scene parameter source. Position is a fake point light; direction points TOWARD light.
## Explicit targets only. No engine light, scene construction or resource saving.

@export_enum("Directional", "Point") var light_mode := 0
@export var direction := Vector3(-0.4, 0.8, 0.5)
## Aim the spotlight beam opposite Direction, from source toward the target.
@export var aim_spotlight := true
@export_range(0.0, 3.0, 0.01) var strength := 1.0
@export var light_color := Color(1.0, 0.91, 0.74)
@export var shadow_color := Color(0.30, 0.36, 0.52)
@export_range(0.0, 1.0, 0.01) var effect_strength := 1.0
@export var targets: Array[NodePath] = []
## Optional explicit blocker marker, used by 16_fake_occlusion only.
@export var occluder: NodePath

var _last_parameters: Dictionary = {}
var _last_targets: Array[NodePath] = []
var _bindings: Array[StylizedMaterialBinding] = []

func _ready() -> void:
	apply(true)

func _process(_delta: float) -> void:
	apply()

func apply(force := false) -> void:
	if not is_inside_tree(): return
	var parameters := {
		"light_position": global_position,
		"light_direction": direction.normalized() if direction.length_squared() > 0.000001 else Vector3.UP,
		"point_weight": float(light_mode), "light_strength": strength,
		"light_color": light_color, "shadow_color": shadow_color,
		"effect_strength": effect_strength,
	}
	var blocker := get_node_or_null(occluder) as Node3D
	if blocker != null: parameters["occluder_position"] = blocker.global_position
	if aim_spotlight: parameters["spot_direction"] = -parameters["light_direction"]
	if not force and parameters == _last_parameters and targets == _last_targets: return
	_last_parameters = parameters
	_last_targets = targets.duplicate()
	var current: Array[StylizedMaterialBinding] = []
	for path in targets:
		var binding := get_node_or_null(path) as StylizedMaterialBinding
		if binding != null:
			current.append(binding)
			binding.set_light_parameters(parameters)
	for binding in _bindings:
		if is_instance_valid(binding) and not binding in current:
			binding.clear_light_parameters()
	_bindings = current
	if Engine.is_editor_hint(): update_configuration_warnings()

func _exit_tree() -> void:
	for binding in _bindings:
		if is_instance_valid(binding) and binding.is_inside_tree():
			binding.clear_light_parameters()
	_bindings.clear()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if targets.is_empty(): warnings.append("Assign the material components this fake light controls.")
	for path in targets:
		if not get_node_or_null(path) is StylizedMaterialBinding:
			warnings.append("Target %s must be a StylizedMaterialBinding node." % path)
	return warnings
