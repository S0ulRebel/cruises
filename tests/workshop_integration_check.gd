extends "res://tests/check.gd"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "cold":
		await _cold(args[1])
		finish()
		return
	for template in ["empty", "rigged_starter", "captain_portrait"]:
		var scene := instantiate_scene("res://actors/assembly/templates/%s.tscn" % template)
		root.add_child(scene)
		check("template opens without invalid configuration: " + template, (scene as CharacterAssembly)._get_configuration_warnings().is_empty())
		if template == "captain_portrait":
			var parts := AssemblyOperations.collect_parts(scene)
			check("Captain template has five independent editable parts", parts.size() == 5)
			for part in parts:
				check("template attachment target valid: " + String(part.name), part._get_configuration_warnings().is_empty())
			var skel := scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			check("Captain template preserves Head and Jaw", skel.get_bone_count() == 2 and skel.find_bone("Jaw") >= 0)
			var face_meshes := scene.get_node("SpeakingHead/Model").find_children("*", "MeshInstance3D", true, false)
			check("Captain template preserves three facial shapes", (face_meshes[0] as MeshInstance3D).mesh is ArrayMesh and ((face_meshes[0] as MeshInstance3D).mesh as ArrayMesh).get_blend_shape_count() == 3)
			skel.set_bone_pose_rotation(skel.find_bone("Jaw"), Quaternion(Vector3.RIGHT, 0.3))
			await process_frame
			skel.reset_bone_poses()
		scene.free()
	var assembly := CharacterAssembly.new()
	assembly.name = "IntegrationAssembly"
	root.add_child(assembly)
	var donor_result := AssemblyOperations.create_part("res://art/models/characters/body_zombie.glb")
	var donor := donor_result.part as AssemblyPart
	donor.name = "Donor"
	assembly.add_child(donor)
	AssemblyOperations.ensure_owned(donor, assembly)
	var piece_result := AssemblyOperations.create_part("res://actors/outfit/placeholders/coat_placeholder.tscn")
	var piece := piece_result.part as AssemblyPart
	piece.name = "ArbitraryGarment"
	piece.position = Vector3(0, 0.8, 0)
	assembly.add_child(piece)
	AssemblyOperations.ensure_owned(piece, assembly)
	var original := piece.get_node("Model") as Node3D
	var original_mesh := original.get_node("Body") as MeshInstance3D
	var original_vertices: PackedVector3Array = original_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var expected := original_mesh.global_transform * original_vertices[0]
	var result := CharacterBindingService.bind_part(piece, donor)
	if not check("explicit garment binding prepares independent replacement", bool(result.get("ok", false)), result.get("error", "")):
		assembly.free()
		finish()
		return
	check("preparing binding leaves original scene intact", piece.get_node("Model") == original)
	var asynchronous := await CharacterBindingService.bind_part_async(piece, donor)
	check("worker binding returns an independent prepared Model", asynchronous.get("ok", false), asynchronous.get("error", ""))
	if asynchronous.get("ok", false):
		var prepared := asynchronous.model as MeshInstance3D
		check("worker and synchronous binding produce the same positions", prepared.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == (result.model as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
		prepared.free()
	var cancelled := await CharacterBindingService.bind_part_async(piece, donor, Callable(), func(): return true)
	check("cancelled binding leaves the authored model untouched", not cancelled.ok and piece.get_node("Model") == original)
	var mesh := result.model as MeshInstance3D
	var bound_vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check("binding preserves reference-pose world position", expected.distance_to(piece.global_transform * mesh.transform * bound_vertices[0]) < 0.0001)
	piece.remove_child(original)
	piece.add_child(mesh)
	piece.binding_data = result.binding_data
	piece.attachment_mode = AssemblyPart.AttachmentMode.SKINNED
	piece.target_path = piece.get_path_to(result.skeleton)
	AssemblyOperations.ensure_owned(piece, assembly)
	check("bound mesh resolves selected skeleton", mesh.get_node_or_null(mesh.skeleton) == result.skeleton)
	piece.position.x += 0.15
	var rebound := CharacterBindingService.bind_part(piece, donor)
	check("explicit rebind retains original source provenance", bool(rebound.get("ok", false)), rebound.get("error", ""))
	if rebound.get("ok", false):
		var rebound_mesh := rebound.model as MeshInstance3D
		var rebound_vertices: PackedVector3Array = rebound_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		check("rebind incorporates authored movement exactly once", (piece.global_transform * rebound_mesh.transform * rebound_vertices[0]).distance_to(expected + Vector3(0.15, 0, 0)) < 0.0001)
		rebound_mesh.free()
	original.free()
	var head_result := AssemblyOperations.create_part("res://art/characters/captain_live/pieces/head/head_face.glb")
	var head := head_result.part as AssemblyPart
	head.name = "SpeakingHead"
	assembly.add_child(head)
	check("facial donor conversion is rejected without mutation", not CharacterBindingService.bind_part(head, donor).ok and head.has_node("Model"))
	check("body animation borrowing rejects a local facial rig cleanly", not CharacterAnimationService.borrow(head.get_node("Model"), "res://art/characters/captain_live/captain_live_animated.glb").ok)
	head.free()
	var borrowed := CharacterAnimationService.borrow(donor.get_node("Model"), "res://art/characters/captain_live/captain_live_animated.glb")
	check("borrowed clips prepare cleanly", bool(borrowed.get("ok", false)), borrowed.get("error", ""))
	if borrowed.get("ok", false):
		var player := borrowed.player as AnimationPlayer
		if borrowed.created:
			donor.get_node("Model").add_child(player)
		player.add_animation_library("captain", borrowed.library)
		AssemblyOperations.ensure_owned(donor, assembly)
	var output_dir := "user://workshop_integration_" + AssemblyOperations.generate_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var output := output_dir.path_join("actor.tscn")
	var exported := CharacterActorExportService.export_actor(assembly, output)
	check("gameplay actor export succeeds at explicit output", bool(exported.get("ok", false)), exported.get("error", ""))
	if exported.get("ok", false):
		print("COLD_WORKSHOP_ACTOR=" + output)
		await _cold(output)
	assembly.free()
	await process_frame
	Dresser.clear_bound_cache()
	finish()


func _cold(path: String) -> void:
	var actor := instantiate_scene(path) as CharacterBody3D
	if actor == null:
		return
	root.add_child(actor)
	await process_frame
	check("gameplay actor authors movement services once", actor.has_node("BodyShape") and actor.has_node("Agent") and actor.has_node("Obstacle"))
	check("gameplay actor includes independent authored parts", AssemblyOperations.collect_parts(actor).size() == 2)
	var garment := actor.get_node("Body/ArbitraryGarment") as AssemblyPart
	var mesh := garment.get_node("Model") as MeshInstance3D
	check("cold binding metadata retains source for refitting", garment.binding_data != null and garment.binding_data.has_meta("source_scene"))
	check("cold bound skin target resolves", mesh.get_node_or_null(mesh.skeleton) is Skeleton3D)
	var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	actor.call("_play", "walk")
	check("exported actor dispatches borrowed walk", player.current_animation == "captain/walk")
	var authored := garment.transform
	garment.position += Vector3(0.1, 0.1, 0)
	garment.scale *= Vector3(1.1, 0.9, 1.0)
	var edited := garment.transform
	await create_timer(0.12).timeout
	check("animated skinned part retains authored edits", garment.transform.is_equal_approx(edited) and not edited.is_equal_approx(authored))
	actor.call("_play", "idle")
	check("exported actor dispatches borrowed idle", player.current_animation == "captain/idle")
	actor.free()
	await process_frame
