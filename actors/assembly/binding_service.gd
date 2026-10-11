@tool
class_name CharacterBindingService
extends RefCounted
## Explicit editor conversion. Prepares an off-tree replacement; never edits the
## working scene or source models. The editor commits the swap with undo/redo.

static func bind_part(part: Node3D, donor: Node3D) -> Dictionary:
	if part == null or donor == null or not part.is_inside_tree() or not donor.is_inside_tree():
		return _failure("Choose a part and a donor in the current scene.")
	var current_model := part.get_node_or_null("Model") as Node3D
	if current_model == null:
		return _failure("The selected part has no Model to bind.")
	var data := part.get("binding_data") as Resource
	var source: Node3D
	var source_transform := current_model.transform
	if data != null and data.has_meta("source_scene"):
		source = (data.get_meta("source_scene") as PackedScene).instantiate() as Node3D
		source_transform = data.get_meta("source_transform", Transform3D.IDENTITY)
	else:
		source = current_model.duplicate() as Node3D
	var result := _prepare(part, donor, source, source_transform)
	source.free()
	return result


static func _prepare(part: Node3D, donor: Node3D, model: Node3D, source_transform: Transform3D, deferred_work := false) -> Dictionary:
	if donor == part or part.is_ancestor_of(donor):
		return _failure("The donor must be separate from the part being bound.")
	var donor_model := donor.get_node_or_null("Model") as Node3D
	if donor_model == null:
		donor_model = donor
	var selected_skeleton := donor as Skeleton3D
	if selected_skeleton != null:
		var donor_part := AssemblyOperations.nearest_part(donor)
		donor_model = donor_part.get_node("Model") as Node3D if donor_part != null else donor.get_parent() as Node3D
	var rigs := donor_model.find_children("*", "Skeleton3D", true, false)
	if selected_skeleton != null:
		rigs = [selected_skeleton]
	else:
		rigs = rigs.filter(func(rig: Node) -> bool: return AssemblyOperations.nearest_part(rig) == AssemblyOperations.nearest_part(donor_model))
	if rigs.size() != 1:
		return _failure("Choose a donor model with one skeleton, or select the exact donor skeleton.")
	var skeleton := rigs[0] as Skeleton3D
	if skeleton.get_bone_count() == 0:
		return _failure("The donor skeleton contains no bones.")
	var frame_error := RigSpace.validate_frame(skeleton, donor_model)
	if not frame_error.is_empty():
		return _failure(frame_error)
	if absf(skeleton.global_transform.basis.determinant()) < 0.000001:
		return _failure("The donor has a zero scale; correct it before binding.")
	var source_meshes := _meshes(model)
	if source_meshes.is_empty():
		return _failure("The part contains no mesh geometry.")
	# Faces keep their local rig by default. Binding must never discard their data.
	for source in source_meshes:
		if source.mesh is ArrayMesh and (source.mesh as ArrayMesh).get_blend_shape_count() > 0:
			return _failure("This part has blend shapes. Attach its complete local rig to a bone instead of donor binding.")
		if source.skin != null:
			var own := source.get_node_or_null(source.skeleton) as Skeleton3D
			if own == null:
				return _failure("This part has an unresolved local skeleton; preserve or repair its rig first.")
			for bone in own.get_bone_count():
				if skeleton.find_bone(own.get_bone_name(bone)) < 0:
					return _failure("The local rig differs from the donor. Preserve it with a parent/bone attachment.")
	var body_meshes: Array[MeshInstance3D] = []
	var search_root := donor_model
	if donor_model is Skeleton3D:
		search_root = donor_model.get_parent() as Node3D
	for mesh_node in _meshes(search_root):
		if not part.is_ancestor_of(mesh_node) and AssemblyOperations.nearest_part(mesh_node) == AssemblyOperations.nearest_part(skeleton) and mesh_node.skin != null and mesh_node.get_node_or_null(mesh_node.skeleton) == skeleton:
			body_meshes.append(mesh_node)
	if body_meshes.is_empty():
		return _failure("The selected skeleton has no weighted donor mesh to sample.")
	var dresser := Dresser.new()
	dresser.flat = false
	# Dresser is used only to prepare geometry. It is never added to the saved scene.
	dresser.set("_model", donor_model)
	dresser.set("_skeleton", skeleton)
	var frame := RigSpace.frame_of(skeleton, donor_model)
	dresser.set("_frame", frame)
	dresser.set("_body_meshes", body_meshes)
	var copier := SkinCopy.new(skeleton, body_meshes, frame)
	if copier.size() == 0:
		dresser.free()
		return _failure("The donor mesh has no valid skin weights to transfer.")
	dresser.set("_copier", copier)
	var fit := frame * skeleton.global_transform.affine_inverse() * part.global_transform * source_transform
	if absf(fit.basis.determinant()) < 0.000001:
		dresser.free()
		return _failure("The part has a zero scale; correct it before binding.")
	var output := ArrayMesh.new()
	var jobs: Array[Dictionary] = []
	var into_skeleton := frame.affine_inverse()
	for source in source_meshes:
		if source.mesh == null:
			continue
		for surface in source.mesh.get_surface_count():
			if source.mesh is ArrayMesh and (source.mesh as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				dresser.free()
				return _failure("Only triangle meshes can be bound to the donor.")
			var arrays := source.mesh.surface_get_arrays(surface).duplicate(true)
			if not deferred_work and not dresser.call("_bind_surface", arrays, source, model, fit, into_skeleton):
				dresser.free()
				return _failure("No valid donor weights were found for this surface.")
			var flags := 0
			if source.mesh is ArrayMesh:
				for channel in 4:
					var shift: int = Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT + channel * Mesh.ARRAY_FORMAT_CUSTOM_BITS
					flags |= (source.mesh as ArrayMesh).surface_get_format(surface) & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << shift)
			if deferred_work:
				var own: Dictionary = dresser.call("_own_weights", source)
				var to_fit := fit * RigSpace.chain(source, model) if own.is_empty() else fit * (own.frame as Transform3D)
				jobs.append({"arrays": arrays, "own": own, "to_fit": to_fit, "flags": flags, "material": source.get_active_material(surface)})
			else:
				output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
				output.surface_set_material(output.get_surface_count() - 1, source.get_active_material(surface))
	dresser.free()
	if output.get_surface_count() == 0 and jobs.is_empty():
		return _failure("The part contains no drawable triangles.")
	var skin := Skin.new()
	for bone in skeleton.get_bone_count():
		skin.add_named_bind(skeleton.get_bone_name(bone), skeleton.get_bone_global_rest(bone).affine_inverse())
	var replacement := MeshInstance3D.new()
	replacement.name = "Model"
	replacement.mesh = output
	replacement.skin = skin
	# Geometry now lives in donor skeleton space. Keep the existing Part placement
	# and compensate only the new Model child's authoring offset.
	replacement.transform = part.global_transform.affine_inverse() * skeleton.global_transform
	replacement.skeleton = NodePath("../" + String(part.get_path_to(skeleton)))
	var metadata := Resource.new()
	metadata.set_meta("source_path", part.get("source_path"))
	# Provenance uses a packed original model, so rebinding uses the unconverted data.
	var source_copy := model.duplicate() as Node3D
	_claim(source_copy, source_copy)
	var source_snapshot := PackedScene.new()
	var pack_error := source_snapshot.pack(source_copy)
	source_copy.free()
	if pack_error != OK:
		replacement.free()
		return _failure("Could not preserve the source model for future re-binding.")
	metadata.set_meta("source_scene", source_snapshot)
	metadata.set_meta("source_transform", source_transform)
	metadata.set_meta("fit_transform", fit)
	metadata.set_meta("donor_path", part.get_path_to(skeleton))
	return {"ok": true, "error": "", "model": replacement, "binding_data": metadata, "skeleton": skeleton, "jobs": jobs, "copier": copier, "into_skeleton": into_skeleton}


## Main-thread scene sampling and resource installation; only private arrays and
## read-only weight samples enter the worker. Cancellation never commits a Model.
static func bind_part_async(part: Node3D, donor: Node3D, progress := Callable(), cancel := Callable()) -> Dictionary:
	if part == null or donor == null or not part.is_inside_tree() or not donor.is_inside_tree():
		return _failure("Choose a part and donor in the current scene.")
	var original := part.get_node_or_null("Model") as Node3D
	if original == null:
		return _failure("The selected part has no Model.")
	var authored := part.global_transform
	var original_transform := original.transform
	var donor_transform := donor.global_transform
	var data := part.get("binding_data") as Resource
	var source := (data.get_meta("source_scene") as PackedScene).instantiate() as Node3D if data != null and data.has_meta("source_scene") else original.duplicate() as Node3D
	var source_transform: Transform3D = data.get_meta("source_transform", original.transform) if data != null else original.transform
	var result := _prepare(part, donor, source, source_transform, true)
	source.free()
	if not result.ok:
		return result
	if cancel.is_valid() and cancel.call():
		(result.model as Node).free()
		return _failure("Binding cancelled; the original part is unchanged.")
	var state := BindingWork.new()
	var worker := Thread.new()
	var started := worker.start(_work.bind(result.jobs, result.copier, result.into_skeleton, state))
	if started != OK:
		(result.model as Node).free()
		return _failure("Could not start the binding worker.")
	while worker.is_alive():
		if cancel.is_valid() and cancel.call():
			state.cancel()
		if progress.is_valid():
			progress.call(state.fraction())
		await (Engine.get_main_loop() as SceneTree).process_frame
	var done: bool = worker.wait_to_finish()
	if not done or state.is_cancelled():
		(result.model as Node).free()
		return _failure("Binding cancelled; the original part is unchanged.")
	if not is_instance_valid(part) or not is_instance_valid(donor) or not is_instance_valid(result.skeleton) or not part.is_inside_tree() or not donor.is_inside_tree() or part.get_node_or_null("Model") != original or not part.global_transform.is_equal_approx(authored) or not original.transform.is_equal_approx(original_transform) or not donor.global_transform.is_equal_approx(donor_transform):
		(result.model as Node).free()
		return _failure("The part or donor changed during binding. Run Bind again for the current fit.")
	var output := (result.model as MeshInstance3D).mesh as ArrayMesh
	(result.model as MeshInstance3D).skeleton = NodePath("../" + String(part.get_path_to(result.skeleton)))
	(result.binding_data as Resource).set_meta("donor_path", part.get_path_to(result.skeleton))
	for job: Dictionary in result.jobs:
		output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, job.arrays, [], {}, job.flags)
		output.surface_set_material(output.get_surface_count() - 1, job.material)
	result.erase("jobs")
	result.erase("copier")
	result.erase("into_skeleton")
	if progress.is_valid():
		progress.call(1.0)
	return result


static func _work(jobs: Array[Dictionary], copier: SkinCopy, into: Transform3D, state: BindingWork) -> bool:
	for index in jobs.size():
		state.surface = index
		state.surfaces = jobs.size()
		var job := jobs[index]
		if not Dresser.bind_surface_data(job.arrays, job.own, job.to_fit, into, copier, state.step):
			return false
	return true


class BindingWork extends RefCounted:
	var mutex := Mutex.new()
	var stopped := false
	var progress := 0.0
	var surface := 0
	var surfaces := 1
	func step(vertex: int, count: int) -> bool:
		mutex.lock()
		progress = (surface + float(vertex) / maxf(count, 1.0)) / surfaces
		var allowed := not stopped
		mutex.unlock()
		return allowed
	func cancel() -> void:
		mutex.lock()
		stopped = true
		mutex.unlock()
	func is_cancelled() -> bool:
		mutex.lock()
		var value := stopped
		mutex.unlock()
		return value
	func fraction() -> float:
		mutex.lock()
		var value := progress
		mutex.unlock()
		return value


static func _meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		result.append(root)
	for child in root.find_children("*", "MeshInstance3D", true, false):
		result.append(child as MeshInstance3D)
	return result


static func _claim(node: Node, root: Node) -> void:
	node.scene_file_path = ""
	for child in node.get_children():
		child.owner = root
		_claim(child, root)


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
