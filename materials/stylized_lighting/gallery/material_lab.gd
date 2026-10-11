extends Node3D
## Authored two-panel comparison; controls change appearance only, never save assets.
@export var catalog: Resource
@onready var shader_sample := $ShaderPanel/Sample
@onready var graph_sample := $GraphPanel/Sample
@onready var shader_light: StylizedFakeLight = $ShaderPanel/FakeLight
@onready var graph_light: StylizedFakeLight = $GraphPanel/FakeLight
@onready var variant_picker: OptionButton = $Controls/Top/Rows/Selection/Variant
@onready var description: Label = $Controls/Top/Rows/Description
@onready var mode: OptionButton = $Controls/Bottom/Rows/First/Mode
@onready var azimuth: HSlider = $Controls/Bottom/Rows/First/Azimuth
@onready var elevation: HSlider = $Controls/Bottom/Rows/First/Elevation
@onready var strength: HSlider = $Controls/Bottom/Rows/Second/Strength
@onready var effect: HSlider = $Controls/Bottom/Rows/Second/Effect
@onready var sweep: CheckButton = $Controls/Bottom/Rows/Second/Sweep
var _selected := 0

func _ready() -> void:
	# Read authored controls; opening/running the lab preserves marker placement.
	var direction := shader_light.direction.normalized()
	azimuth.set_value_no_signal(fposmod(rad_to_deg(atan2(direction.x, direction.z)), 360.0))
	elevation.set_value_no_signal(rad_to_deg(asin(clampf(direction.y, -1, 1))))
	strength.set_value_no_signal(shader_light.strength)
	effect.set_value_no_signal(shader_light.effect_strength)
	mode.select(shader_light.light_mode)
	$Controls/Bottom/Rows/Second/LightColor.color = shader_light.light_color
	$Controls/Bottom/Rows/Second/ShadowColor.color = shader_light.shadow_color
	description.text = catalog.descriptions[0]
	_update_labels()

func select_variant(index: int) -> void:
	_selected = index
	(shader_sample.get_node("Material") as StylizedMaterialBinding).material = catalog.shader_materials[index]
	(graph_sample.get_node("Material") as StylizedMaterialBinding).material = catalog.graph_materials[index]
	description.text = catalog.descriptions[index]
	variant_picker.select(index)
	# Point/spot falloff defaults demonstrate their distance/cone response.
	mode.select(1 if index in [10, 11] else 0)
	_update_light()

func _on_variant_selected(index: int) -> void:
	select_variant(index)

func _on_sample_selected(index: int) -> void:
	for sample in [shader_sample, graph_sample]:
		sample.get_node("Primitives").visible = index != 1
		sample.get_node("Chair").visible = index != 0

func _on_mode_selected(_index: int) -> void:
	_update_light()

func _on_light_changed(_value: float) -> void:
	_update_light()

func _on_angle_changed(_value: float) -> void:
	_update_light(true)

func _on_color_changed(_color: Color) -> void:
	_update_light()

func _update_light(reposition := false) -> void:
	if not is_node_ready(): return
	var angle := deg_to_rad(azimuth.value)
	var height := deg_to_rad(elevation.value)
	var direction := Vector3(sin(angle) * cos(height), sin(height), cos(angle) * cos(height))
	for fake in [shader_light, graph_light]:
		fake.direction = direction
		if reposition:
			var distance := maxf((fake.position - Vector3(0, 0.6, 0)).length(), 0.1)
			fake.position = Vector3(0, 0.6, 0) + direction * distance
		fake.strength = strength.value
		fake.effect_strength = effect.value
		fake.light_mode = mode.selected
		fake.light_color = $Controls/Bottom/Rows/Second/LightColor.color
		fake.shadow_color = $Controls/Bottom/Rows/Second/ShadowColor.color
		fake.apply(true)
	_update_labels()

func _update_labels() -> void:
	$Controls/Bottom/Rows/First/AzimuthLabel.text = "Light angle %d°" % azimuth.value
	$Controls/Bottom/Rows/First/ElevationLabel.text = "Elevation %d°" % elevation.value
	$Controls/Bottom/Rows/Second/StrengthLabel.text = "Strength %.2f" % strength.value
	$Controls/Bottom/Rows/Second/EffectLabel.text = "Effect %.2f" % effect.value

func _on_rotation_changed(value: float) -> void:
	for sample in [shader_sample, graph_sample]:
		sample.get_node("Primitives").rotation.y = deg_to_rad(value)
		sample.get_node("Chair").rotation.y = deg_to_rad(value)

func _process(delta: float) -> void:
	if sweep.button_pressed:
		azimuth.value = fposmod(azimuth.value + delta * 18.0, 360.0)
