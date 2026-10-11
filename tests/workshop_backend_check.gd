extends "res://tests/check.gd"

func _run() -> void:
	_check_nearest()
	await _check_workshop()
	finish()


func _check_nearest() -> void:
	var rig := Skeleton3D.new()
	rig.add_bone("Root")
	var copier := SkinCopy.new(rig, [], Transform3D.IDENTITY)
	# Four candidates appear in the first occupied shell, but a point outside
	# the next shell is closer. A fixed extra shell cannot certify nearest points.
	for point in [Vector3(0.085, 0.085, 0.085), Vector3(0.084, 0.084, 0.084),
		Vector3(0.083, 0.083, 0.083), Vector3(0.082, 0.082, 0.082), Vector3(0.12, 0, 0)]:
		copier._add(point, {0: 1.0})
	var best: Array = copier._nearest(Vector3.ZERO)
	check("nearest search finds closer candidate outside first occupied shells", best.size() == 4 and best[0][0] == 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1957
	for i in 120:
		copier._add(Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)), {0: 1.0})
	var exact := true
	for i in 40:
		var query := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		var expected: Array = []
		for j in copier._points.size():
			copier._consider(j, query.distance_to(copier._points[j]), expected)
		var actual: Array = copier._nearest(query)
		for j in actual.size():
			exact = exact and actual[j][0] == expected[j][0]
	check("grid lookup matches exhaustive nearest-four search", exact)
	var weights: Array = copier.weights_at(Vector3.ZERO)
	check("transferred influences normalize", is_equal_approx((weights[1] as PackedFloat32Array)[0], 1.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3(10, 10, 10)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
	var drawable := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	drawable.mesh = mesh
	drawable.skin = Skin.new()
	drawable.skin.add_bind(0, Transform3D.IDENTITY)
	var remaining := SkinCopy.new(rig, [drawable], Transform3D.IDENTITY)
	check("weight transfer ignores unused vertices retained by exclusion", remaining.size() == 3 and not remaining._points.has(Vector3(10, 10, 10)))
	drawable.free()
	rig.free()


func _check_workshop() -> void:
	var source_outfit := Outfit.new()
	var external_piece := OutfitPiece.new()
	external_piece.model = "res://actors/outfit/placeholders/hat_placeholder.tscn"
	external_piece.slot = "hat"
	source_outfit.pieces.append(external_piece)
	var working := source_outfit.working_copy()
	working.pieces[0].position.x = 0.3
	check("working outfit explicitly isolates external fit resources", external_piece.position.x == 0 and working.pieces[0] != external_piece)
	var workshop := Node3D.new()
	workshop.set_script(load("res://actors/outfit/workshop.gd"))
	root.add_child(workshop)
	await process_frame
	check("legacy preview opens without random dressing or invalid donor", workshop.get("_model") == null and workshop.get("_chosen").is_empty())
	workshop.call("load_body", "res://art/models/characters/body_zombie.glb")
	var dresser: Dresser = workshop.get("dresser")
	check("explicit valid donor loads", dresser.skeleton() != null)
	var previous_model: Node = workshop.get("_model")
	workshop.call("load_body", "res://actors/outfit/placeholders/hat_placeholder.tscn")
	check("invalid donor leaves previous model intact", workshop.get("_model") == previous_model)
	for slot in ["coat", "trousers"]:
		var piece := OutfitPiece.for_model("res://actors/outfit/placeholders/%s_placeholder.tscn" % slot)
		workshop.call("choose", slot, piece)
	workshop.call("_edit", "coat")
	var before := dresser.node_for("coat") as MeshInstance3D
	var previous_mesh := before.mesh
	var fields: Array = workshop.get("_position_boxes")
	(fields[0] as SpinBox).value += 0.15
	workshop.call("_edit", "trousers")
	workshop.call("_flush_refits")
	check("flushing after selection change refits the edited garment", (dresser.node_for("coat") as MeshInstance3D).mesh != previous_mesh)
	var old_node := dresser.node_for("coat")
	var missing := OutfitPiece.new()
	missing.slot = "coat"
	missing.model = "res://not_a_model.glb"
	check("rejected replacement is transactional", not dresser.wear(missing) and dresser.node_for("coat") == old_node)
	var source_model := (load("res://art/characters/captain_live/captain_live_animated.glb") as PackedScene).instantiate()
	var source_player := source_model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var untouched := true
	for clip in source_player.get_animation_list():
		if String(clip).get_file() not in ["idle", "walk", "run"]:
			var preview_player: AnimationPlayer = workshop.get("_player")
			if preview_player.has_animation("captain/" + String(clip)):
				untouched = untouched and preview_player.get_animation("captain/" + String(clip)).loop_mode == source_player.get_animation(clip).loop_mode
	check("preview preserves one-shot borrowed gestures", untouched)
	var actor := CharacterBody3D.new()
	actor.set_script(load("res://actors/mover/mover.gd"))
	actor.set("walk_animation", &"captain/walk")
	actor.set("idle_animation", &"captain/idle")
	actor.set("_clips", workshop.get("_player"))
	actor.set("_looked", true)
	actor.call("_play", "walk")
	check("movement dispatches mapped borrowed walk", (workshop.get("_player") as AnimationPlayer).current_animation == "captain/walk")
	actor.call("_play", "idle")
	check("movement dispatches mapped borrowed idle", (workshop.get("_player") as AnimationPlayer).current_animation == "captain/idle")
	actor.free()
	source_model.free()
	workshop.queue_free()
	await process_frame
