@tool
extends Node3D
## Startup/session composition. Location and service instances are saved in Game.
signal startup_ready
@export var skip_cold_open := true
@export var location: Location
@export var state: GameState
@export var interactions: InteractionController
@export var caption: Node
@export var choices: Node
@export var dialogue: Node
@export var inventory: Node
@export var pointer: Node
@export var cold_open_stage: Node2D
@export var cutscene: Node
@export var audio: Node
var initialized := false
var _cast: Dictionary = {}

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for dependency in [location, state, interactions, caption, choices, dialogue,
			inventory, pointer, cold_open_stage, cutscene, audio]:
		if dependency == null:
			warnings.append("Assign every Game service reference in the Inspector.")
			break
	return warnings

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if not _get_configuration_warnings().is_empty():
		push_error("Game is missing an authored service reference.")
		return
	inventory.setup(state)
	dialogue.setup(caption, choices)
	dialogue.use_flags(state.flags)
	_wire_location()
	interactions.busy = true
	if not skip_cold_open:
		location.hide()
		cold_open_stage.show()
		caption.show_actions = true
		cutscene.setup(cold_open_stage, caption)
		if cutscene.load_screenplay("res://screenplay/cold_open.json"):
			cutscene.play.call_deferred()
			await cutscene.finished
		location.show()
	cold_open_stage.hide()
	caption.show_actions = false
	await location.await_navigation()
	interactions.busy = false
	initialized = true
	startup_ready.emit()

func _wire_location() -> void:
	var screenplay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://screenplay/cold_open.json"))
	_cast = screenplay.get("cast", {}).duplicate(true)
	var characters: Array[CharacterDefinition] = []
	for actor in location.find_children("*", "Node3D", true, false):
		if actor.get("definition") is CharacterDefinition:
			var definition := actor.definition as CharacterDefinition
			characters.append(definition)
			_cast[definition.content_id] = definition.cast_entry()
	caption.set_characters(characters)
	choices.set_characters(characters)
	dialogue.set_cast(_cast)
	interactions.setup(location, caption, dialogue, inventory, pointer, state, _cast)

## Deliberate transition: load a whole authored place, keeping session state alive.
func change_location(scene: PackedScene) -> bool:
	if not initialized or interactions.busy or scene == null: return false
	var candidate := scene.instantiate()
	if not candidate is Location:
		candidate.free()
		return false
	interactions.busy = true
	location.player.stop()
	interactions.release_location()
	remove_child(location)
	location.queue_free()
	await get_tree().physics_frame
	location = candidate as Location
	add_child(location)
	_wire_location()
	await location.await_navigation()
	interactions.busy = false
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not Engine.is_editor_hint() and event.is_action_pressed("game_quit"):
		get_viewport().set_input_as_handled()
		get_tree().quit()
