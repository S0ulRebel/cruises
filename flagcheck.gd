extends SceneTree
## Does a puzzle actually change a conversation?
##
## The flag plumbing is easy to get right in pieces and wrong as a whole: two stores
## instead of one, a line gated on a flag nothing ever sets, or a choice that appears
## before the thing it refers to has happened. All three read as writing problems
## rather than as bugs.

func _init() -> void:
	var failures := 0
	var Dialogue: GDScript = load("res://dialogue/dialogue.gd")
	# The room's contents live with the builder that places them, not in main.gd -
	# see CONVENTIONS.md. Checking against a hand-copied layout stops testing the game
	# the moment either drifts, so this reads the real table.
	var main: GDScript = load("res://tools/build_cabin.gd")

	# Every flag a conversation waits on should be set by something somewhere.
	var waited_on := {}
	var convo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://screenplay/santi_galley.json"))
	for node_id in convo.get("nodes", {}):
		var node: Dictionary = convo["nodes"][node_id]
		for group in ["lines", "choices"]:
			for entry in node.get(group, []):
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				for flag in entry.get("if", []):
					waited_on[String(flag)] = true
				for flag in entry.get("unless", []):
					waited_on[String(flag)] = true

	var set_by := {}
	for node_id in convo.get("nodes", {}):
		var node: Dictionary = convo["nodes"][node_id]
		for flag in node.get("set", []):
			set_by[String(flag)] = "conversation"
		for entry in node.get("choices", []):
			if typeof(entry) == TYPE_DICTIONARY:
				for flag in entry.get("set", []):
					set_by[String(flag)] = "choice"
	var hotspots: Array = main.HOTSPOTS
	for entry in hotspots:
		var props: Dictionary = entry["props"]
		for item_id in props.get("combinations", {}):
			var outcome: Dictionary = props["combinations"][item_id]
			if outcome.has("sets"):
				set_by[String(outcome["sets"])] = "puzzle"

	print("  conversation waits on %s" % [waited_on.keys()])
	print("  something sets %s" % [set_by.keys()])
	for flag in waited_on:
		failures += _check("'%s' is set by something" % flag, set_by.has(flag),
			"nothing ever sets it, so that line can never appear")

	# And at least one of them crosses the boundary: a puzzle changing dialogue is the
	# whole reason the two stores were merged.
	var crossed: bool = false
	for flag in waited_on:
		if set_by.get(flag, "") == "puzzle":
			crossed = true
	failures += _check("a puzzle flag reaches the dialogue", crossed)

	# The stores really are one object, not two that happen to agree.
	var d: Node = Dialogue.new()
	var store := {}
	d.use_flags(store)
	store["from_the_room"] = true
	failures += _check("the dialogue sees a flag the room set",
		d.flags.has("from_the_room"))
	d.flags["from_the_dialogue"] = true
	failures += _check("the room sees a flag the dialogue set",
		store.has("from_the_dialogue"))
	d.free()

	print("\n%s" % ("ALL CHECKS PASSED" if failures == 0 else "%d CHECK(S) FAILED" % failures))
	quit(1 if failures > 0 else 0)


func _check(what: String, ok: bool, got := "") -> int:
	print("%s  %s%s" % ["ok  " if ok else "FAIL", what, "" if ok else "  -> %s" % got])
	return 0 if ok else 1
