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
	if not location.navigation_regions.is_empty() and not await location.await_navigation():
		push_error("Game location has no usable synchronized navigation. Bake its authored regions.")
		return
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
	if not candidate._get_configuration_warnings().is_empty():
		candidate.free()
		return false
	var previous := location
	var previous_index := previous.get_index()
	interactions.busy = true
	previous.player.stop()
	interactions.release_location()
	remove_child(previous)
	await get_tree().physics_frame
	location = candidate as Location
	add_child(location)
	move_child(location, previous_index)
	var ready := location.navigation_regions.is_empty() or await location.await_navigation()
	if not ready:
		remove_child(location)
		location.queue_free()
		await get_tree().physics_frame
		location = previous
		add_child(location)
		move_child(location, previous_index)
		if not location.navigation_regions.is_empty():
			await location.await_navigation()
		_wire_location()
		interactions.busy = false
		return false
	previous.queue_free()
	_wire_location()
	interactions.busy = false
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not Engine.is_editor_hint() and event.is_action_pressed("game_quit"):
		get_viewport().set_input_as_handled()
		get_tree().quit()
