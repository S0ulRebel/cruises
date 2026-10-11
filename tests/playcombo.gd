extends "res://tests/check.gd"
## Puzzle combinations refer to content resources and real authored hotspots.
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
	var gives: Array[String] = []
	var spots: Array[Hotspot] = []
	for area in location.find_children("*", "Area3D", true, false):
		if area is Hotspot:
			spots.append(area)
			if not area.gives_item.is_empty():
				gives.append(area.gives_item)
			for outcome in area.combinations.values():
				if outcome.has("gives"):
					gives.append(String(outcome["gives"]))
	var combinations := 0
	for spot in spots:
		for item_id in spot.combinations:
			combinations += 1
			var outcome: Dictionary = spot.combinations[item_id]
			check("combination item has a definition: " + item_id, state.item(item_id) != null)
			check("combination item is obtainable: " + item_id, item_id in gives)
			check("combination has its written response", not String(outcome.get("say", "")).is_empty())
			if outcome.has("gives"):
				check("combination reward has a definition", state.item(String(outcome["gives"])) != null)
	check("authored game contains puzzle combinations", combinations > 0)
	game.free()
	finish()
