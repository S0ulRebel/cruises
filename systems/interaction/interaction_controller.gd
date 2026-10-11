class_name InteractionController
extends Node
## One serialized walk-and-response operation. Components never find other modules.
signal action_finished(success: bool)
const HighlightScript := preload("res://ui/highlight/highlight.gd")
var busy := false
var _location: Location
var _caption: Node
var _dialogue: Node
var _inventory: Node
var _pointer: Node
var _state: GameState
var _cast: Dictionary = {}
var _hovered: Hotspot
var _hotspots: Array[Hotspot] = []

func setup(location: Location, caption: Node, dialogue: Node, inventory: Node,
		pointer: Node, state: GameState, cast: Dictionary) -> void:
	release_location()
	_location = location
	_caption = caption
	_dialogue = dialogue
	_inventory = inventory
	_pointer = pointer
	_state = state
	_cast = cast
	location.floor_clicked.connect(_walk)
	for child in location.find_children("*", "Area3D", true, false):
		if child is Hotspot:
			var spot := child as Hotspot
			_hotspots.append(spot)
			spot.input_event.connect(_click.bind(spot))
			spot.mouse_entered.connect(_hover.bind(spot))
			spot.mouse_exited.connect(_unhover.bind(spot))
	if not _state.selection_changed.is_connected(_selection_changed):
		_state.selection_changed.connect(_selection_changed)
	if not _inventory.opened.is_connected(_clear_hover):
		_inventory.opened.connect(_clear_hover)

func _selection_changed(_id: String) -> void:
	if is_instance_valid(_hovered): _hover(_hovered)

func release_location() -> void:
	_clear_hover()
	if is_instance_valid(_location) and _location.floor_clicked.is_connected(_walk):
		_location.floor_clicked.disconnect(_walk)
	for spot in _hotspots:
		if not is_instance_valid(spot): continue
		if spot.input_event.is_connected(_click.bind(spot)):
			spot.input_event.disconnect(_click.bind(spot))
		if spot.mouse_entered.is_connected(_hover.bind(spot)):
			spot.mouse_entered.disconnect(_hover.bind(spot))
		if spot.mouse_exited.is_connected(_unhover.bind(spot)):
			spot.mouse_exited.disconnect(_unhover.bind(spot))
	_hotspots.clear()
	if is_instance_valid(_state) and _state.selection_changed.is_connected(_selection_changed):
		_state.selection_changed.disconnect(_selection_changed)
	if is_instance_valid(_inventory) and _inventory.opened.is_connected(_clear_hover):
		_inventory.opened.disconnect(_clear_hover)
	_location = null

func _walk(point: Vector3) -> void:
	if not busy and not _inventory.is_open() and _location.navigation_ready:
		_location.player.walk_to(point)

func _click(_camera: Node, event: InputEvent, _point: Vector3, _normal: Vector3,
		_shape: int, spot: Hotspot) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		interact(spot)

func _hover(spot: Hotspot) -> void:
	if busy or _inventory.is_open(): return
	_clear_hover()
	_hovered = spot
	HighlightScript.set_on(spot, true)
	_pointer.point_at(spot.display_name,
		spot.phrase(spot.resolve(_state.selection), _inventory.display_name(_state.selection)))

func _unhover(spot: Hotspot) -> void:
	if _hovered == spot: _clear_hover()

func _clear_hover() -> void:
	if is_instance_valid(_hovered): HighlightScript.set_on(_hovered, false)
	_hovered = null
	if _pointer: _pointer.clear()

func interact(spot: Hotspot) -> void:
	if busy or _inventory.is_open() or not _location.navigation_ready: return
	busy = true
	_clear_hover()
	var held := _state.selection
	var verb := spot.resolve(held)
	var where := spot.resolve_approach(verb, _location.player.global_position)
	_location.player.walk_to(where["at"], where["facing"])
	var movement: Array = await _location.player.movement_finished
	if not movement[0] or not is_instance_valid(spot):
		busy = false
		action_finished.emit(false)
		return
	var result := spot.result_for(verb, held)
	match String(result["kind"]):
		"talk": await _talk(String(result["path"]))
		"take":
			var item_id := String(result["item"])
			if not item_id.is_empty():
				var added := _state.add(item_id)
				await _say("Taken: %s." % _inventory.display_name(item_id)
					if added else "He already has it.")
		"combine": await _apply_outcome(spot, held, result["outcome"])
		_: await _say(String(result["text"]))
	busy = false
	action_finished.emit(true)

func _apply_outcome(spot: Hotspot, held: String, outcome: Dictionary) -> void:
	if outcome.has("takes"): _state.remove(String(outcome["takes"]))
	elif outcome.get("solved", false) and not outcome.get("keeps", false): _state.remove(held)
	if outcome.has("gives"): _state.add(String(outcome["gives"]))
	if outcome.has("sets"): _state.flags[String(outcome["sets"])] = true
	for flag in outcome.get("clear", []): _state.flags.erase(String(flag))
	if outcome.get("solved", false):
		spot.combinations = {}
		spot.needs_item = ""
		spot.gives_item = ""
	if outcome.has("say"): await _say(String(outcome["say"]))

func _say(text: String) -> void:
	var definition = _location.player.definition
	var person: Dictionary = definition.cast_entry() if definition else _cast.get("live", {})
	_caption.say(String(person.get("name", "Captain Livé")), text,
		String(person.get("assets", "captain_live")), Color(String(person.get("colour", "#1c1a1f"))))
	await _caption.advanced
	_caption.hide_box()

func _talk(path: String) -> void:
	if not path.is_empty() and _dialogue.load_conversation(path):
		# Deferred call ensures even an empty conversation's completion is observed.
		_dialogue.play.call_deferred()
		await _dialogue.finished
