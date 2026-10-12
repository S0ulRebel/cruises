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
			var identities: Dictionary = {}
			for part in parts:
				identities[part.part_id] = true
			check("Captain template has independently identified editable parts", not parts.is_empty() and identities.size() == parts.size() and not identities.has(""))
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
	_check_drawable_bounds()
	_check_zero_hips_retarget()
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
	await _check_bad_skin_inputs(assembly, donor, piece)
	var result := CharacterBindingService.bind_part(piece, donor)
	if not check("explicit garment binding prepares independent replacement", bool(result.get("ok", false)), result.get("error", "")):
		assembly.free()
		finish()
		return
	check("preparing binding leaves original scene intact", piece.get_node("Model") == original)
	var provenance := (result.binding_data.get_meta("source_scene") as PackedScene).instantiate()
	var material_before := (provenance.get_node("Body") as MeshInstance3D).get_active_material(0) as BaseMaterial3D
	var derived_material := (result.model as MeshInstance3D).get_active_material(0) as BaseMaterial3D
	var saved_colour := derived_material.albedo_color
	var retained_material := original_mesh.get_active_material(0) as BaseMaterial3D
	var retained_colour := retained_material.albedo_color
	retained_material.albedo_color = Color.GREEN
	check("editing the undo-retained original cannot change saved rebind provenance", material_before.albedo_color == saved_colour)
	retained_material.albedo_color = retained_colour
	var second_provenance := (result.binding_data.get_meta("source_scene") as PackedScene).instantiate()
	var second_material := (second_provenance.get_node("Body") as MeshInstance3D).get_active_material(0) as BaseMaterial3D
	material_before.albedo_color = Color.ORANGE
	check("two provenance instances retain independent editable materials", second_material.albedo_color == saved_colour)
	material_before.albedo_color = saved_colour
	second_provenance.free()
	derived_material.albedo_color = Color.PINK
	check("bound material edits leave original provenance independent", material_before != derived_material and material_before.albedo_color == saved_colour)
	derived_material.albedo_color = saved_colour
	provenance.free()
	var asynchronous := await CharacterBindingService.bind_part_async(piece, donor)
	check("worker binding returns an independent prepared Model", asynchronous.get("ok", false), asynchronous.get("error", ""))
	if asynchronous.get("ok", false):
		var prepared := asynchronous.model as MeshInstance3D
		check("worker and synchronous binding produce the same positions", prepared.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == (result.model as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
		prepared.free()
	var cancelled := await CharacterBindingService.bind_part_async(piece, donor, Callable(), func(): return true)
	check("cancelled binding leaves the authored model untouched", not cancelled.ok and piece.get_node("Model") == original)
	var cancel_polls := [0]
	var running_cancel := await CharacterBindingService.bind_part_async(piece, donor, Callable(), func():
		cancel_polls[0] += 1
		return cancel_polls[0] > 1)
	check("active worker cancellation completes without replacing the original", not running_cancel.ok and cancel_polls[0] > 1 and piece.get_node("Model") == original)
	var before_worker := piece.transform
	var edited_while_binding := [false]
	var stale := await CharacterBindingService.bind_part_async(piece, donor, func(fraction: float):
		if fraction < 1.0 and not edited_while_binding[0]:
			edited_while_binding[0] = true
			piece.position.x += 0.02)
	check("editing during a worker rejects its stale result", edited_while_binding[0] and not stale.ok and piece.get_node("Model") == original)
	piece.transform = before_worker
	var edited_material := [false]
	var stale_material := await CharacterBindingService.bind_part_async(piece, donor, func(fraction: float):
		if fraction < 1.0 and not edited_material[0]:
			edited_material[0] = true
			retained_material.albedo_color = Color.PURPLE)
	check("material edits during binding reject stale prepared resources", edited_material[0] and not stale_material.ok and piece.get_node("Model") == original)
	retained_material.albedo_color = retained_colour
	var joined := await CharacterBindingService.bind_part_async(piece, donor, func(fraction: float):
		if fraction < 1.0:
			CharacterBindingService.cancel_pending_jobs())
	check("editor teardown cancellation joins its worker and leaves the source intact", not joined.ok and piece.get_node("Model") == original)
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
	var body_tree := _preview_tree(donor.get_node("Model"), borrowed.player, "BodyTree", "captain/idle")
	var face_player := AnimationPlayer.new()
	face_player.name = "LocalFacePlayer"
	donor.get_node("Model").add_child(face_player)
	var face_library := AnimationLibrary.new()
	var face_clip := Animation.new()
	face_clip.length = 1.0
	face_library.add_animation("face_idle", face_clip)
	face_player.add_animation_library("", face_library)
	_preview_tree(donor.get_node("Model"), face_player, "LocalFaceTree", "face_idle")
	AssemblyOperations.ensure_owned(donor, assembly)
	var output_dir := "user://workshop_integration_" + AssemblyOperations.generate_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var output := output_dir.path_join("actor.tscn")
	var exported := CharacterActorExportService.export_actor(assembly, output)
	check("gameplay actor export succeeds at explicit output", bool(exported.get("ok", false)), exported.get("error", ""))
	check("export keeps the author's original body animation tree active", body_tree.active)
	if exported.get("ok", false):
		print("COLD_WORKSHOP_ACTOR=" + output)
		await _cold(output)
	assembly.free()
	await process_frame
	Dresser.clear_bound_cache()
	finish()


func _preview_tree(model: Node3D, player: AnimationPlayer, label: String, clip: String) -> AnimationTree:
	var tree := AnimationTree.new()
	tree.name = label
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	var graph := AnimationNodeBlendTree.new()
	var animation := AnimationNodeAnimation.new()
	animation.animation = clip
	graph.add_node("Idle", animation)
	graph.connect_node("output", 0, "Idle")
	tree.tree_root = graph
	tree.active = true
	return tree


func _check_bad_skin_inputs(assembly: Node3D, donor: AssemblyPart, garment: AssemblyPart) -> void:
	var body: MeshInstance3D
	for node in donor.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).skin != null:
			body = node
			break
	var original_mesh := body.mesh
	var arrays := original_mesh.surface_get_arrays(0).duplicate(true)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	bones[0] = body.skin.get_bind_count() + 1
	weights[0] = 1.0
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var invalid_mesh := ArrayMesh.new()
	invalid_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var malformed := AssemblyOperations.create_part("res://art/models/characters/body_zombie.glb").part as AssemblyPart
	malformed.name = "InvalidSkinFixture"
	assembly.add_child(malformed)
	var local_mesh := malformed.get_node("Model").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	local_mesh.mesh = invalid_mesh
	var original := malformed.get_node("Model")
	var rejected := CharacterBindingService.bind_part(malformed, donor)
	check("malformed source skin indices reject without replacing the model", not rejected.ok and malformed.get_node("Model") == original and String(rejected.error).contains("skin index"))
	arrays[Mesh.ARRAY_BONES] = null
	arrays[Mesh.ARRAY_WEIGHTS] = null
	var unweighted_mesh := ArrayMesh.new()
	unweighted_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	local_mesh.mesh = unweighted_mesh
	var unweighted := CharacterBindingService.bind_part(malformed, donor)
	check("an unweighted surface inside a rigged model accepts explicit donor binding", unweighted.ok, unweighted.error)
	if unweighted.ok:
		(unweighted.model as Node).free()
	var unweighted_worker := await CharacterBindingService.bind_part_async(malformed, donor)
	check("worker handles an unweighted rigged surface without guessing local weights", unweighted_worker.ok, unweighted_worker.error)
	if unweighted_worker.ok:
		(unweighted_worker.model as Node).free()
	malformed.free()
	body.mesh = invalid_mesh
	var bad_donor := CharacterBindingService.bind_part(garment, donor)
	check("malformed donor skin indices reject before sampling", not bad_donor.ok and String(bad_donor.error).contains("skin index"))
	var bad_worker := await CharacterBindingService.bind_part_async(garment, donor)
	check("malformed skin rejects before starting a binding worker", not bad_worker.ok and String(bad_worker.error).contains("skin index"))
	body.mesh = original_mesh
	var clone := donor.get_node("Model").duplicate() as Node3D
	var cloned_mesh := clone.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	cloned_mesh.skin = cloned_mesh.skin.duplicate() as Skin
	cloned_mesh.skin.set_bind_bone(0, -1)
	cloned_mesh.skin.set_bind_name(0, "MissingBone")
	check("unresolved named skin binds are reported before conversion", not CharacterBindingService._validate_mesh(cloned_mesh).is_empty())
	clone.free()


func _check_drawable_bounds() -> void:
	var assembly := CharacterAssembly.new()
	var part := AssemblyPart.new()
	part.part_id = AssemblyOperations.generate_id()
	assembly.add_child(part)
	var instance := MeshInstance3D.new()
	instance.name = "Model"
	part.add_child(instance)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3(0, 100, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	instance.mesh = ArrayMesh.new()
	(instance.mesh as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var bounds := CharacterActorExportService._drawable_bounds(instance, assembly)
	check("gameplay collision bounds ignore excluded unused vertices", bounds.found and is_equal_approx((bounds.bounds as AABB).size.y, 1.0))
	assembly.free()


func _check_zero_hips_retarget() -> void:
	var model := Node3D.new()
	var rig := Skeleton3D.new()
	rig.name = "Rig"
	model.add_child(rig)
	rig.add_bone("Hips")
	rig.add_bone("Head")
	rig.set_bone_parent(1, 0)
	rig.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3.UP))
	var measured := Retarget._Rig.new(rig, model)
	var clip := Animation.new()
	clip.length = 1.0
	var track := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(track, NodePath("Rig:Hips"))
	clip.position_track_insert_key(track, 0.0, Vector3.ZERO)
	clip.position_track_insert_key(track, 1.0, Vector3(0, 0.1, 0.2))
	var copied := Retarget._copy(clip, measured, measured, "Rig")
	var finite := copied.get_track_count() == 1
	for key in copied.track_get_key_count(0):
		finite = finite and (copied.track_get_key_value(0, key) as Vector3).is_finite()
	check("retargeting an origin-height hips rig produces finite motion", finite and (copied.track_get_key_value(0, copied.track_get_key_count(0) - 1) as Vector3).is_equal_approx(Vector3(0, 0.1, 0.2)))
	root.add_child(model)
	var source := model.duplicate() as Node3D
	var source_rig := source.get_node("Rig") as Skeleton3D
	source_rig.add_bone("Unmapped")
	source_rig.set_bone_parent(2, 0)
	source_rig.set_bone_rest(2, Transform3D(Basis.IDENTITY, Vector3.RIGHT))
	var player := AnimationPlayer.new()
	source.add_child(player)
	var empty_target_clip := Animation.new()
	empty_target_clip.length = 1.0
	var unmapped := empty_target_clip.add_track(Animation.TYPE_ROTATION_3D)
	empty_target_clip.track_set_path(unmapped, NodePath("Rig:Unmapped"))
	empty_target_clip.rotation_track_insert_key(unmapped, 0, Quaternion.IDENTITY)
	empty_target_clip.rotation_track_insert_key(unmapped, 1, Quaternion(Vector3.UP, 0.2))
	var library := AnimationLibrary.new()
	library.add_animation("walk", empty_target_clip)
	player.add_animation_library("", library)
	var folder := "user://workshop_unmapped_" + AssemblyOperations.generate_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var saved := AssemblyOperations.save_scene(source, folder + "/source.tscn")
	check("unmapped animation fixture saves to an isolated explicit output", saved.ok)
	if saved.ok:
		var rejected := CharacterAnimationService.borrow(model, saved.path)
		check("borrowed names with no compatible tracks are rejected transactionally", not rejected.ok and model.find_children("*", "AnimationPlayer", true, false).is_empty())
	source.free()
	model.free()


func _cold(path: String) -> void:
	var actor := instantiate_scene(path) as CharacterBody3D
	if actor == null:
		return
	root.add_child(actor)
	# This assertion isolates AnimationTree ownership. Locomotion's physics tick
	# legitimately switches a stationary actor back to idle and races this probe.
	actor.set_physics_process(false)
	await process_frame
	check("gameplay actor authors movement services once", actor.has_node("BodyShape") and actor.has_node("Agent") and actor.has_node("Obstacle"))
	check("gameplay actor includes independent authored parts", AssemblyOperations.collect_parts(actor).size() == 2)
	var garment := actor.get_node("Body/ArbitraryGarment") as AssemblyPart
	var mesh := garment.get_node("Model") as MeshInstance3D
	check("cold binding metadata retains source for refitting", garment.binding_data != null and garment.binding_data.has_meta("source_scene"))
	check("cold bound skin target resolves", mesh.get_node_or_null(mesh.skeleton) is Skeleton3D)
	check("export disables only the tree competing with locomotion", not (actor.get_node("Body/Donor/Model/BodyTree") as AnimationTree).active and (actor.get_node("Body/Donor/Model/LocalFaceTree") as AnimationTree).active)
	var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	actor.call("_play", "walk")
	check("exported actor dispatches borrowed walk", player.current_animation == "captain/walk")
	var authored := garment.transform
	garment.position += Vector3(0.1, 0.1, 0)
	garment.scale *= Vector3(1.1, 0.9, 1.0)
	var edited := garment.transform
	await create_timer(0.12).timeout
	check("borrowed walk survives an unrelated active local animation tree", player.current_animation == "captain/walk")
	check("animated skinned part retains authored edits", garment.transform.is_equal_approx(edited) and not edited.is_equal_approx(authored))
	actor.call("_play", "idle")
	check("exported actor dispatches borrowed idle", player.current_animation == "captain/idle")
	actor.free()
	await process_frame
