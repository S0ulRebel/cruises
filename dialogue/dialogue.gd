extends Node
## Branching conversation, played from a data file.
##
## This is where most of a comedy adventure actually lives. A room has one painting and
## three hotspots; a conversation has forty lines, half of which only exist so the
## player can pick the rude one. So the format has to be writable by the person writing
## the jokes, without the engine in the way, and it has to be forgiving - a conversation
## with a typo in it should misbehave in one branch, not refuse to load.
##
## A conversation is a bag of nodes. A node says some lines, then either offers choices,
## jumps somewhere, or ends. Flags remember what has already been said, which is the
## only state a conversation needs and the thing that stops characters re-introducing
## themselves every time you click them.
##
##   {
##     "id": "santi_galley",
##     "start": "root",
##     "nodes": {
##       "root": { "choices": [
##           { "text": "About that captive.", "goto": "captive", "once": true },
##           { "text": "Never mind.", "exit": true } ] },
##       "captive": {
##           "lines": [ { "who": "santi", "text": "..." } ],
##           "set": [ "asked_captive" ],
##           "goto": "root" }
##     }
##   }
##
## A choice may carry `if` and `unless` lists of flags; `once` hides it after use.

signal finished

const MAX_STEPS := 500  ## A cycle of gotos with no lines would otherwise hang the game.

var flags := {}  ## Survives between conversations. Save/load will own this later.
## Print a transcript as it plays. A branching conversation is hard to check by walking
## it by hand - most of the work is confirming that a branch you cannot currently see is
## still reachable from somewhere.
var verbose := false

var _caption: Node
var _choices: Node
var _cast: Dictionary = {}
var _conversation: Dictionary = {}
var _used: Dictionary = {}  ## conversation id -> { node id -> [used choice indices] }


func setup(caption: Node, choices: Node) -> void:
	_caption = caption
	_choices = choices


func set_cast(cast: Dictionary) -> void:
	_cast = cast


func load_conversation(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("No conversation at %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Conversation at %s is not a JSON object" % path)
		return false
	_conversation = parsed
	return true


func play() -> void:
	var convo_id := String(_conversation.get("id", "unnamed"))
	var nodes: Dictionary = _conversation.get("nodes", {})
	var at := String(_conversation.get("start", "root"))
	var steps := 0

	while at != "" and steps < MAX_STEPS:
		steps += 1
		if not nodes.has(at):
			push_warning("Conversation '%s' jumps to missing node '%s'" % [convo_id, at])
			break

		var node: Dictionary = nodes[at]

		for line_variant in node.get("lines", []):
			if typeof(line_variant) != TYPE_DICTIONARY:
				continue
			var line: Dictionary = line_variant
			var who := String(line.get("who", ""))
			var person: Dictionary = _cast.get(who, {})
			if verbose:
				print("%s: %s" % [person.get("name", who), line.get("text", "")])
			_caption.say(String(person.get("name", who)), String(line.get("text", "")), who,
				Color(String(person.get("colour", "#4a4f5a"))))
			await _caption.advanced

		for flag in node.get("set", []):
			flags[String(flag)] = true
		for flag in node.get("clear", []):
			flags.erase(String(flag))

		if node.get("exit", false):
			break

		var offered := _visible_choices(convo_id, at, node)
		if verbose and not offered.is_empty():
			print("  -- choices at '%s' --" % at)
			for i in offered.size():
				print("     %d. %s" % [i + 1, offered[i].get("text", "...")])
		if offered.is_empty():
			at = String(node.get("goto", ""))
			continue

		_caption.hide_box()
		var picked: int = await _choices.ask(offered.map(func(c: Dictionary) -> String:
			return String(c.get("text", "..."))))

		var choice: Dictionary = offered[picked]
		if verbose:
			print("  >> %s" % choice.get("text", "..."))
		if bool(choice.get("once", false)):
			_mark_used(convo_id, at, int(choice.get("_index", -1)))
		for flag in choice.get("set", []):
			flags[String(flag)] = true

		# A choice may speak before it jumps - usually the player's own line.
		if choice.has("say"):
			var speaker := String(choice.get("who", _conversation.get("player", "live")))
			var person: Dictionary = _cast.get(speaker, {})
			_caption.say(String(person.get("name", speaker)), String(choice.get("say", "")))
			await _caption.advanced

		if bool(choice.get("exit", false)):
			break
		at = String(choice.get("goto", ""))

	if steps >= MAX_STEPS:
		push_warning("Conversation '%s' ran %d steps - probably a goto loop" % [convo_id, MAX_STEPS])

	_caption.hide_box()
	_choices.dismiss()
	finished.emit()


## Choices the player can see right now: not used up, and their flag conditions met.
func _visible_choices(convo_id: String, node_id: String, node: Dictionary) -> Array:
	var out: Array = []
	var raw: Array = node.get("choices", [])
	for i in raw.size():
		if typeof(raw[i]) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = (raw[i] as Dictionary).duplicate()
		choice["_index"] = i
		if bool(choice.get("once", false)) and _is_used(convo_id, node_id, i):
			continue
		if not _conditions_met(choice):
			continue
		out.append(choice)
	return out


func _conditions_met(choice: Dictionary) -> bool:
	for flag in choice.get("if", []):
		if not flags.has(String(flag)):
			return false
	for flag in choice.get("unless", []):
		if flags.has(String(flag)):
			return false
	return true


func _is_used(convo_id: String, node_id: String, index: int) -> bool:
	var per_node: Dictionary = _used.get(convo_id, {})
	return index in per_node.get(node_id, [])


func _mark_used(convo_id: String, node_id: String, index: int) -> void:
	if index < 0:
		return
	var per_node: Dictionary = _used.get_or_add(convo_id, {})
	var list: Array = per_node.get_or_add(node_id, [])
	if not index in list:
		list.append(index)
