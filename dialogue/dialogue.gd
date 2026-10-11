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

## Survives between conversations, and SHARED with the room: prising the crate open
## and asking Santi about the captive write to the same place, so a puzzle can change
## what a person says and a conversation can unlock a door. Two separate stores was
## the state of this until flags were wired up, and it meant neither could see the
## other. Save/load will own this later.
var flags := {}
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


## Hand the dialogue the room's flag store so the two share one. Passed by reference -
## a Dictionary in GDScript is shared, not copied - which is the whole point.
func use_flags(store: Dictionary) -> void:
	flags = store


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
			# Lines take `if` and `unless` as well as choices do. A conversation that
			# can only branch at a menu has to send the player through a menu to
			# acknowledge anything, which is the difference between a character who
			# notices you are carrying their compass and one who waits to be asked.
			if not _conditions_met(line):
				continue
			var who := String(line.get("who", ""))
			var person: Dictionary = _cast.get(who, {})
			if verbose:
				print("%s: %s" % [person.get("name", who), line.get("text", "")])
			# The ASSET id, not the screenplay id: it is what names the head piece and
			# the entry in speech data. CharacterDefinition keeps these IDs separate.
			_caption.say(String(person.get("name", who)), String(line.get("text", "")),
				String(person.get("assets", who)),
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
			at = _next_node(node)
			continue

		_caption.hide_box()
		if _choices.has_method("set_player"):
			_choices.set_player(_cast.get(String(_conversation.get("player", "live")), {}))
		var picked: int = await _choices.ask(offered.map(func(c: Dictionary) -> String:
			return String(c.get("text", "..."))))

		var choice: Dictionary = offered[picked]
		if verbose:
			print("  >> %s" % choice.get("text", "..."))
		if bool(choice.get("once", false)):
			_mark_used(convo_id, at, int(choice.get("_index", -1)))
		for flag in choice.get("set", []):
			flags[String(flag)] = true
		for flag in choice.get("clear", []):
			flags.erase(String(flag))

		# A choice may speak before it jumps - usually the player's own line.
		if choice.has("say"):
			var speaker := String(choice.get("who", _conversation.get("player", "live")))
			var person: Dictionary = _cast.get(speaker, {})
			_caption.say(String(person.get("name", speaker)), String(choice.get("say", "")),
				String(person.get("assets", speaker)),
				Color(String(person.get("colour", "#4a4f5a"))))
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
## Where a node goes when it has nothing to ask. `goto` is the plain answer; `branch`
## is a list tried in order, first one whose conditions are met wins, so a node can
## send the player somewhere different once they have opened the crate without
## needing a choice menu to do it.
##
##     "branch": [ { "if": ["crate_open"], "goto": "after" }, { "goto": "before" } ]
func _next_node(node: Dictionary) -> String:
	for option_variant in node.get("branch", []):
		if typeof(option_variant) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = option_variant
		if _conditions_met(option):
			return String(option.get("goto", ""))
	return String(node.get("goto", ""))


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


## Whether a line, choice or branch may be used, given what has happened so far.
## `if` needs every flag present; `unless` needs every flag absent.
func _conditions_met(entry: Dictionary) -> bool:
	for flag in entry.get("if", []):
		if not flags.has(String(flag)):
			return false
	for flag in entry.get("unless", []):
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
