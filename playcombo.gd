extends SceneTree
## Walks the real puzzle data, not a made-up hotspot: does Livé's crate actually have
## written answers for the things he can be carrying, and do the intended ones hand
## over what they promise?
##
## Catches the thing a unit test cannot - a combination keyed on an item id that no
## hotspot ever gives out, which is a puzzle nobody can reach.

func _init() -> void:
	var failures := 0
	# The room's contents live with the builder that places them, not in main.gd -
	# see CONVENTIONS.md. Checking against a hand-copied layout stops testing the game
	# the moment either drifts, so this reads the real table.
	var main: GDScript = load("res://tools/build_cabin.gd")
	var items: Dictionary = load("res://ui/inventory.gd").ITEMS

	var gives: Array = []
	var hotspots: Array = main.HOTSPOTS
	for entry in hotspots:
		var props: Dictionary = entry["props"]
		if props.has("gives_item"):
			gives.append(String(props["gives_item"]))

	var combos := 0
	for entry in hotspots:
		var props: Dictionary = entry["props"]
		var table: Dictionary = props.get("combinations", {})
		for item_id in table:
			combos += 1
			var outcome: Dictionary = table[item_id]
			failures += _check("%s x %s: the item exists in the inventory" % [entry["label"], item_id],
				items.has(item_id))
			failures += _check("%s x %s: it says something" % [entry["label"], item_id],
				not String(outcome.get("say", "")).is_empty())
			if outcome.has("gives"):
				failures += _check("%s x %s: what it gives exists" % [entry["label"], item_id],
					items.has(String(outcome["gives"])))
			# A combination for an item the player can never hold is a puzzle with no
			# way in. Allowed only if some hotspot hands that item out.
			failures += _check("%s x %s: the player can actually get that item" % [entry["label"], item_id],
				item_id in gives, "nothing gives '%s'" % item_id)

	print("  %d combinations across %d hotspots" % [combos, hotspots.size()])
	failures += _check("there are combinations at all", combos > 0)

	print("\n%s" % ("ALL CHECKS PASSED" if failures == 0 else "%d CHECK(S) FAILED" % failures))
	quit(1 if failures > 0 else 0)


func _check(what: String, ok: bool, got := "") -> int:
	if not ok:
		print("FAIL  %s%s" % [what, "" if got.is_empty() else "  -> %s" % got])
	return 0 if ok else 1
