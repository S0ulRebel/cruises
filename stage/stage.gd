extends Node2D
## Authored cold-open locations and figures; scripts change visibility and effects.
@onready var _locations: Node2D = $Locations
var _current: Node2D
var _shake_offset := Vector2.ZERO
var _rest_modulate := Color.WHITE
var shake_power := 0.0
var light_level := 1.0
var _cast: Dictionary = {}

func _ready() -> void:
	_rest_modulate = modulate

func set_cast(cast: Dictionary) -> void:
	_cast = cast

func set_location(location: Dictionary, location_id := "") -> void:
	_current = null
	for child in _locations.get_children():
		child.hide()
		if String(child.get("location_id")) == location_id or String(child.get("display_name")) == String(location.get("name", "")):
			_current = child
	if _current == null:
		push_error("Cold-open location has no authored scene: %s" % location_id)
		return
	_current.show()
	for actor in _current.get_node("Actors").get_children():
		actor.hide()
		actor.set_speaking(false)
	var layouts := _current.get_node_or_null("Layouts") as AnimationPlayer
	if layouts:
		layouts.play("two")
		layouts.advance(0.0)

func enter(ids: Array) -> void:
	if _current == null:
		return
	var visible_count := 0
	for actor in _current.get_node("Actors").get_children():
		if actor.actor_id in ids:
			actor.show()
		if actor.visible:
			visible_count += 1
	var layouts := _current.get_node_or_null("Layouts") as AnimationPlayer
	if layouts and visible_count >= 3:
		layouts.play("three")
		layouts.advance(0.0)

func set_speaker(who: String) -> void:
	if _current:
		for actor in _current.get_node("Actors").get_children():
			actor.set_speaking(actor.actor_id == who)

func set_light(level: float) -> void:
	light_level = level
	modulate = _rest_modulate * Color(level, level, level, 1.0)

func _process(_delta: float) -> void:
	position -= _shake_offset
	_shake_offset = Vector2.ZERO
	if shake_power > 0.0:
		_shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_power
		position += _shake_offset
