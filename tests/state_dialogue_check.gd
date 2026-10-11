extends "res://tests/check.gd"

class CaptionDouble:
	extends Node
	signal advanced
	var lines: Array[String] = []
	func say(_speaker: String, text: String, _id := "", _colour := Color()) -> void:
		lines.append(text)
		_emit_advance.call_deferred()
	func _emit_advance() -> void:
		advanced.emit()
	func hide_box() -> void:
		pass

class ChoicesDouble:
	extends Node
	func ask(_options: Array) -> int:
		return 0
	func dismiss() -> void:
		pass
	func set_portrait(_id: String) -> void:
		pass

func _run() -> void:
	var state := GameState.new()
	root.add_child(state)
	var key := ItemDefinition.new()
	key.content_id = "key"
	state.items = [key]
	check("unknown items cannot enter inventory", not state.add("unknown"))
	check("a defined item enters inventory", state.add("key"))
	check("items are unique", not state.add("key") and state.held.size() == 1)
	state.select("unknown")
	check("unknown items cannot be selected", state.selection.is_empty())
	state.select("key")
	check("held items can be selected", state.selection == "key")
	state.select("key")
	check("selection toggles off", state.selection.is_empty())
	state.select("key")
	state.remove("key")
	check("removal clears selection", state.held.is_empty() and state.selection.is_empty())
	var path := "res://dialogue/dialogue.gd"
	if not check("dialogue module exists", ResourceLoader.exists(path)):
		finish()
		return
	var dialogue: Node = load(path).new()
	var caption := CaptionDouble.new()
	var choices := ChoicesDouble.new()
	root.add_child(caption)
	root.add_child(choices)
	root.add_child(dialogue)
	dialogue.setup(caption, choices)
	dialogue.use_flags(state.flags)
	state.flags["old_flag"] = true
	check("dialogue loads the flag-clear fixture", dialogue.load_conversation("res://tests/fixtures/choice_clear.json"))
	var completed := [false]
	dialogue.finished.connect(func() -> void: completed[0] = true)
	dialogue.play.call_deferred()
	check("conversation completes within its deadline", await wait_for(func() -> bool: return completed[0]))
	check("choice clear reaches shared session state", not state.flags.has("old_flag"))
	check("choice set reaches shared session state", state.flags.has("new_flag"))
	check("conditions observe the changed flags", caption.lines == ["The cleared flag is gone"])
	state.flags["from_session"] = true
	check("dialogue reads the same flag dictionary", dialogue.flags.has("from_session"))
	finish()
