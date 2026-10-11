@tool
class_name CharacterBindingService
extends RefCounted
## Explicit editor conversion. Prepares an off-tree replacement; never edits the
## working scene or source models. The editor commits the swap with undo/redo.

static var _active_jobs: Dictionary = {}

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
	var rig_error := _validate_rig(skeleton)
	if not rig_error.is_empty():
		return _failure(rig_error)
	var frame_error := RigSpace.validate_frame(skeleton, donor_model)
	if not frame_error.is_empty():
		return _failure(frame_error)
	if not AssemblyOperations.validate_transform(skeleton.global_transform).is_empty() or not AssemblyOperations.validate_transform(part.global_transform).is_empty() or not AssemblyOperations.validate_transform(source_transform).is_empty():
		return _failure("Correct nonfinite or zero-scale part/donor transforms before binding.")
	var source_meshes := _meshes(model)
	if source_meshes.is_empty():
		return _failure("The part contains no mesh geometry.")
	# Faces keep their local rig by default. Binding must never discard their data.
	for source in source_meshes:
		var source_error := _validate_mesh(source)
		if not source_error.is_empty():
			return _failure(source_error)
		if source.mesh is ArrayMesh and (source.mesh as ArrayMesh).get_blend_shape_count() > 0:
			return _failure("This part has blend shapes. Attach its complete local rig to a bone instead of donor binding.")
		if source.skin != null:
			var own := source.get_node_or_null(source.skeleton) as Skeleton3D
			if own == null:
				return _failure("This part has an unresolved local skeleton; preserve or repair its rig first.")
			var local_frame_error := RigSpace.validate_frame(own, model)
			if not local_frame_error.is_empty():
				return _failure(local_frame_error)
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
	for body in body_meshes:
		var body_error := _validate_mesh(body)
		if not body_error.is_empty():
			return _failure(body_error)
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
	if not AssemblyOperations.validate_transform(fit).is_empty():
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
			var source_material := source.get_active_material(surface)
			var output_material := source_material.duplicate(true) as Material if source_material != null else null
			if deferred_work:
				var own: Dictionary = dresser.call("_own_weights", source, model) if arrays[Mesh.ARRAY_BONES] != null and arrays[Mesh.ARRAY_WEIGHTS] != null else {}
				var to_fit := fit * RigSpace.chain(source, model) if own.is_empty() else fit * (own.frame as Transform3D)
				jobs.append({"arrays": arrays, "own": own, "to_fit": to_fit, "flags": flags, "material": output_material})
			else:
				output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
				output.surface_set_material(output.get_surface_count() - 1, output_material)
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
	var source_copy := AssemblyOperations.independent_snapshot(model) as Node3D
	if source_copy == null:
		replacement.free()
		return _failure("Could not preserve an independent source snapshot for re-binding.")
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
	var input_signature := _input_signature(part, donor)
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
	_active_jobs[worker] = {"state": state, "model": result.model}
	while worker.is_alive():
		if cancel.is_valid() and cancel.call():
			state.cancel()
		if progress.is_valid():
			progress.call(state.fraction())
		await (Engine.get_main_loop() as SceneTree).process_frame
	var done: bool = state.outcome if state.joined else worker.wait_to_finish()
	_active_jobs.erase(worker)
	if cancel.is_valid() and cancel.call():
		state.cancel()
	if not done or state.is_cancelled():
		if is_instance_valid(result.model):
			(result.model as Node).free()
		return _failure("Binding cancelled; the original part is unchanged.")
	if not is_instance_valid(part) or not is_instance_valid(donor) or not is_instance_valid(result.skeleton) or not part.is_inside_tree() or not donor.is_inside_tree() or part.get_node_or_null("Model") != original or not part.global_transform.is_equal_approx(authored) or not original.transform.is_equal_approx(original_transform) or not donor.global_transform.is_equal_approx(donor_transform):
		(result.model as Node).free()
		return _failure("The part or donor changed during binding. Run Bind again for the current fit.")
	if _input_signature(part, donor) != input_signature:
		(result.model as Node).free()
		return _failure("Source geometry or the donor rig changed during binding. Run Bind again for the current inputs.")
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


## Plugin teardown may stop process_frame entirely. Join explicitly before the
## editor frees its dock/SceneTree, instead of leaving a running Thread coroutine.
static func cancel_pending_jobs() -> void:
	for thread: Thread in _active_jobs.keys():
		var entry: Dictionary = _active_jobs[thread]
		var state := entry.state as BindingWork
		state.cancel()
		state.outcome = thread.wait_to_finish()
		state.joined = true
		if is_instance_valid(entry.model):
			(entry.model as Node).free()
	_active_jobs.clear()


static func _input_signature(part: Node3D, donor: Node3D) -> PackedByteArray:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for value in [part, donor]:
		var own := AssemblyOperations.nearest_part(value)
		var model := own.get_node_or_null("Model") as Node3D if own != null else value as Node3D
		if model == null:
			continue
		hash.update(var_to_bytes([model.get_instance_id(), model.global_transform]))
		var nodes: Array[Node] = [model]
		nodes.append_array(model.find_children("*", "Node3D", true, false))
		for node in nodes:
			if AssemblyOperations.nearest_part(node) != own:
				continue
			if node is Skeleton3D:
				var skeleton := node as Skeleton3D
				hash.update(var_to_bytes([skeleton.get_instance_id(), skeleton.global_transform]))
				for bone in skeleton.get_bone_count():
					hash.update(var_to_bytes([skeleton.get_bone_name(bone), skeleton.get_bone_global_rest(bone)]))
			elif node is MeshInstance3D:
				var mesh := node as MeshInstance3D
				hash.update(var_to_bytes([mesh.get_instance_id(), mesh.global_transform]))
				if mesh.mesh != null:
					for surface in mesh.mesh.get_surface_count():
						hash.update(var_to_bytes(mesh.mesh.surface_get_arrays(surface)))
						var material := mesh.get_active_material(surface)
						hash.update(var_to_bytes(material.get_instance_id() if material != null else 0))
						if material != null:
							for property in material.get_property_list():
								if not (int(property.usage) & PROPERTY_USAGE_STORAGE):
									continue
								var material_value: Variant = material.get(property.name)
								if material_value is Resource:
									material_value = material_value.get_instance_id()
								elif material_value is RID:
									continue
								hash.update(var_to_bytes([property.name, material_value]))
				if mesh.skin != null:
					for bind in mesh.skin.get_bind_count():
						hash.update(var_to_bytes([mesh.skin.get_bind_name(bind), mesh.skin.get_bind_bone(bind), mesh.skin.get_bind_pose(bind)]))
	return hash.finish()


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
	var joined := false
	var outcome := false
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


static func _validate_rig(skeleton: Skeleton3D) -> String:
	for bone in skeleton.get_bone_count():
		if not AssemblyOperations.validate_transform(skeleton.get_bone_global_rest(bone)).is_empty():
			return "The rig has a nonfinite or singular rest transform: " + String(skeleton.get_bone_name(bone))
	return ""


static func _validate_mesh(instance: MeshInstance3D) -> String:
	var ancestor: Node = instance
	while ancestor != null:
		if ancestor is Node3D and not AssemblyOperations.validate_transform((ancestor as Node3D).transform).is_empty():
			return "Correct the nonfinite or zero-scale mesh/parent transform before binding: " + String(ancestor.name)
		ancestor = ancestor.get_parent()
	if instance.mesh == null:
		return ""
	var skin := instance.skin
	if skin != null:
		var skeleton := instance.get_node_or_null(instance.skeleton) as Skeleton3D
		if skeleton == null:
			return "Repair the mesh's missing skeleton before binding: " + String(instance.name)
		var rig_error := _validate_rig(skeleton)
		if not rig_error.is_empty():
			return rig_error
		for bind in skin.get_bind_count():
			var bone := skin.get_bind_bone(bind)
			if bone == -1:
				bone = skeleton.find_bone(skin.get_bind_name(bind))
			if bone < 0 or bone >= skeleton.get_bone_count() or not AssemblyOperations.validate_transform(skin.get_bind_pose(bind)).is_empty():
				return "Repair the invalid skin bind %d on %s before binding." % [bind, instance.name]
	for surface in instance.mesh.get_surface_count():
		var arrays := instance.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if not vertex.is_finite():
				return "The mesh contains a nonfinite vertex: " + String(instance.name)
		if skin == null:
			continue
		if arrays[Mesh.ARRAY_BONES] == null and arrays[Mesh.ARRAY_WEIGHTS] == null:
			continue
		if arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null:
			return "The skinned surface is missing bone weights: " + String(instance.name)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if vertices.is_empty() or bones.size() != weights.size() or bones.size() not in [vertices.size() * 4, vertices.size() * 8]:
			return "The skinned surface needs matching four or eight influences per vertex: " + String(instance.name)
		for influence in weights.size():
			var weight := weights[influence]
			if not is_finite(weight) or weight < 0.0 or (weight > 0.0 and (bones[influence] < 0 or bones[influence] >= skin.get_bind_count())):
				return "The surface has an invalid weighted skin index on " + String(instance.name)
	return ""


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
