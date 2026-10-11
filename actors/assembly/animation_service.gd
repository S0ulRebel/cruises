@tool
class_name CharacterAnimationService
extends RefCounted
## Explicit authoring action: add borrowed animation to a donor model. No startup
## borrowing and no shared source animation mutations.

static func borrow(model: Node3D, source_path: String) -> Dictionary:
	if model == null or not model.is_inside_tree() or not ResourceLoader.exists(source_path, "PackedScene"):
		return {"ok": false, "error": "Choose a model in the scene and an animation source model."}
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	if model is Skeleton3D:
		rigs = [model]
	else:
		rigs = rigs.filter(func(rig: Node) -> bool: return AssemblyOperations.nearest_part(rig) == AssemblyOperations.nearest_part(model))
	if rigs.size() != 1:
		return {"ok": false, "error": "Choose a model with one donor skeleton."}
	var frame_error := RigSpace.validate_frame(rigs[0], model)
	if not frame_error.is_empty():
		return {"ok": false, "error": frame_error}
	var source := (load(source_path) as PackedScene).instantiate()
	var sources := source.find_children("*", "AnimationPlayer", true, false)
	var source_rigs := source.find_children("*", "Skeleton3D", true, false)
	if sources.is_empty() or source_rigs.is_empty():
		source.free()
		return {"ok": false, "error": "The animation source has no player or skeleton."}
	frame_error = RigSpace.validate_frame(source_rigs[0], source)
	if not frame_error.is_empty():
		source.free()
		return {"ok": false, "error": frame_error}
	var matching := 0
	for bone in (rigs[0] as Skeleton3D).get_bone_count():
		if (source_rigs[0] as Skeleton3D).find_bone((rigs[0] as Skeleton3D).get_bone_name(bone)) >= 0:
			matching += 1
	source.free()
	if matching == 0:
		return {"ok": false, "error": "The rigs have no matching bone names; provide an explicit retarget mapping first."}
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var player: AnimationPlayer
	var created := players.is_empty()
	if created:
		player = AnimationPlayer.new()
		player.name = "AnimationPlayer"
		model.add_child(player)
	else:
		player = players[0] as AnimationPlayer
	var player_root := player.get_node_or_null(player.root_node)
	if player_root == null:
		if created:
			model.remove_child(player)
			player.free()
		return {"ok": false, "error": "The animation player's root is missing."}
	var library := Retarget.library(source_path, model, rigs[0], player_root)
	for name in library.get_animation_list():
		if String(name).get_file() in ["idle", "walk", "run"]:
			library.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	if library.get_animation_list().is_empty():
		if created:
			model.remove_child(player)
			player.free()
		return {"ok": false, "error": "No compatible animation tracks were produced."}
	# Return the prepared library/player. The editor registers undoable installation.
	if created:
		model.remove_child(player)
	return {"ok": true, "error": "", "player": player, "created": created, "library": library, "model": model}
