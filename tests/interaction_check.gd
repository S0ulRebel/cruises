extends "res://tests/check.gd"

class MoverDouble:
	extends "res://actors/mover/mover.gd"
	var walks := 0
	func _ready() -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass
	func walk_to(_point: Vector3, _facing := NAN) -> void:
		walks += 1
	func stop() -> void:
		movement_finished.emit(false, "cancelled")

class CaptionDouble:
	extends Node
	signal advanced
	var calls := 0
	func say(_name: String, _text: String, _id := "", _colour := Color()) -> void:
		calls += 1
	func hide_box() -> void:
		pass

class DialogueDouble:
	extends Node
	signal finished
	var started := false
	func load_conversation(_path: String) -> bool:
		return true
	func play() -> void:
		started = true

class InventoryDouble:
	extends Node
	signal opened
	func is_open() -> bool:
		return false
	func display_name(item_id: String) -> String:
		return item_id.capitalize()

class PointerDouble:
	extends Node
	func clear() -> void:
		pass
	func point_at(_label: String, _phrase: String) -> void:
		pass

func _run() -> void:
	var path := "res://systems/interaction/interaction_controller.gd"
	if not check("interaction controller exists", ResourceLoader.exists(path)):
		finish()
		return
	var location := Location.new()
	var mover := MoverDouble.new()
	location.add_child(mover)
	location.player = mover
	root.add_child(location)
	location.navigation_ready = true
	var state := GameState.new()
	var key := ItemDefinition.new()
	key.content_id = "key"
	state.items = [key]
	var caption := CaptionDouble.new()
	var dialogue := DialogueDouble.new()
	var inventory := InventoryDouble.new()
	var pointer := PointerDouble.new()
	var controller: Node = load(path).new()
	for node in [state, caption, dialogue, inventory, pointer, controller]:
		root.add_child(node)
	controller.setup(location, caption, dialogue, inventory, pointer, state, {})
	var spot := Hotspot.new()
	spot.gives_item = "key"
	location.add_child(spot)
	var outcomes: Array[bool] = []
	controller.action_finished.connect(func(success: bool) -> void: outcomes.append(success))
	controller.interact(spot)
	check("movement acquires busy state", controller.busy)
	controller.interact(spot)
	check("a concurrent click starts no second movement", mover.walks == 1)
	mover.movement_finished.emit(false, "unreachable")
	check("failed movement releases busy state", not controller.busy and outcomes == [false])
	check("failed movement never executes the remote action", caption.calls == 0 and state.held.is_empty())
	controller.interact(spot)
	mover.stop()
	check("cancelled movement releases busy state", not controller.busy and outcomes == [false, false])
	controller.interact(spot)
	mover.movement_finished.emit(true, "arrived")
	check("take applies after successful arrival", state.held == ["key"])
	check("speech keeps interaction busy", controller.busy and caption.calls == 1)
	var walks_before: int = mover.walks
	controller.interact(spot)
	check("speech prevents overlapping actions", mover.walks == walks_before)
	caption.advanced.emit()
	check("speech completion releases busy state", not controller.busy and outcomes.back())
	spot.gives_item = ""
	spot.conversation = "res://tests/fixtures/choice_clear.json"
	controller.interact(spot)
	mover.movement_finished.emit(true, "arrived")
	check("dialogue starts within deadline", await wait_for(func() -> bool: return dialogue.started))
	check("dialogue owns busy until completion", controller.busy)
	dialogue.finished.emit()
	check("dialogue completion releases busy state", not controller.busy and outcomes.back())
	finish()
