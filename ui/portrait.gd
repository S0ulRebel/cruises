class_name Portrait
extends Control
## Portrait presentation; fixed controls and the viewport are saved scenes.
@export var panel_size := Vector2(224, 224)
@export var framed := false
@onready var _head: TalkingHead = $TalkingHead
@onready var _blank: Control = $Placeholder
@onready var _blank_name: Label = $Placeholder/Name
var _characters: Dictionary = {}
var _plan: Array = []
var _who := ""
var _speech_id := ""
var _talking := false

func set_characters(characters: Array[CharacterDefinition]) -> void:
	_characters.clear()
	for definition in characters:
		_characters[definition.asset_id] = definition
		_characters[definition.content_id] = definition
	_head.set_characters(characters)

func speak(character_id: String, display := "", colour := Color(), line := "") -> void:
	_who = character_id
	var definition := _characters.get(character_id) as CharacterDefinition
	_speech_id = definition.asset_id if definition else character_id
	_blank_name.text = display if not display.is_empty() else character_id.capitalize()
	if colour.a > 0.0:
		_blank_name.modulate = colour
	_head.visible = _head.show_character(character_id)
	_blank.visible = not _head.visible
	show()
	_talking = true
	_plan = Speech.plan(line, _speech_id) if _head.visible else []
	if _head.visible:
		_head.apply(Speech.sample(_plan, 0.0), _speech_id)

func set_progress(fraction: float) -> void:
	if _talking and not _plan.is_empty() and _head.visible:
		_head.apply(Speech.sample(_plan, clampf(fraction, 0.0, 1.0) * Speech.duration(_plan)), _speech_id)

func settle() -> void:
	_talking = false
	_plan = []
	if _head.visible:
		_head.settle(_speech_id)

func dismiss() -> void:
	settle()
	hide()

func has_live_head() -> bool:
	return visible and _head.visible
