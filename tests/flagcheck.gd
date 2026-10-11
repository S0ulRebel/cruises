extends "res://tests/check.gd"
## Cross-checks dialogue conditions against the authored game/puzzle data.
func _run() -> void:
	var game := instantiate_scene("res://game/game.tscn")
	if game == null:
		finish()
		return
	var state := game.get("state") as GameState
	var location := game.get("location") as Location
	if not check("game exposes state and location", state != null and location != null):
		game.free()
		finish()
		return
	var conversation: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://screenplay/santi_galley.json"))
	if not check("conversation data parses", conversation is Dictionary):
		game.free()
		finish()
		return
	var required := {}
	var set_by := {}
	for node in conversation.get("nodes", {}).values():
		for flag in node.get("set", []):
			set_by[String(flag)] = "conversation"
		for group in ["lines", "choices", "branch"]:
			for entry in node.get(group, []):
				for flag in entry.get("if", []) + entry.get("unless", []):
					required[String(flag)] = true
				for flag in entry.get("set", []):
					set_by[String(flag)] = "choice"
	for area in location.find_children("*", "Area3D", true, false):
		if area is Hotspot:
			for outcome in area.combinations.values():
				if outcome.has("sets"):
					set_by[String(outcome["sets"])] = "puzzle"
	var crosses := false
	for flag in required:
		check("something sets required flag: " + flag, set_by.has(flag))
		crosses = crosses or set_by.get(flag) == "puzzle"
	check("an authored puzzle changes dialogue", crosses)
	game.free()
	finish()
