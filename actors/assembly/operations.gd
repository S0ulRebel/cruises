class_name AssemblyOperations
extends RefCounted
## Explicit authoring operations. No scene mutation occurs at startup. Failures
## validate before changing the scene, and saving requires one explicit destination.

const CARRIER_META := &"assembly_bone_carrier"
const SOURCE_GROUP_META := &"assembly_source_group"


static func generate_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


static func create_part(source_path: String) -> Dictionary:
	if source_path.is_empty() or not ResourceLoader.exists(source_path, "PackedScene"):
		return _failure("Choose an existing 3D model or scene.")
	var source := ResourceLoader.load(source_path, "PackedScene") as PackedScene
	if source == null or not source.can_instantiate():
		return _failure("The selected resource is not an instantiable scene.")
	var model := source.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if not model is Node3D:
		model.free()
		return _failure("Character parts must have a 3D root node.")
	var part := AssemblyPart.new()
	part.name = "Part"
	part.part_id = generate_id()
	part.source_path = source_path
	model.name = "Model"
	part.add_child(model)
	initialize_source_composition(part)
	_expand_and_clone(part)
	ensure_owned(part, part)
	return _success({"part": part})


## Native adoption snapshots must be captured after putting the chosen node under
## its new wrapper as Model. Restore the first snapshot before unwrapping on undo.
static func capture_source_composition(part: AssemblyPart) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if is_instance_valid(part):
		_capture_source_nodes(part.get_node_or_null("Model"), result)
	return result


## Explicit import/adoption only. A saved prefab's entire hierarchy is source
## content, even when it already contains nested parts and generated carriers.
## Capture once before/after and restore after on redo to keep stable identities.
static func initialize_source_composition(part: AssemblyPart) -> void:
	if not is_instance_valid(part):
		return
	var model := part.get_node_or_null("Model")
	if model == null:
		return
	for nested in collect_parts(model):
		nested.part_id = generate_id()
	_mark_source_group(model, part.part_id)


static func restore_source_composition(states: Array) -> void:
	for state: Dictionary in states:
		var node: Node = state.get("node")
		if not is_instance_valid(node):
			continue
		if node is AssemblyPart and state.has("part_id"):
			(node as AssemblyPart).part_id = state.part_id
		if bool(state.get("had_source_group", false)):
			node.set_meta(SOURCE_GROUP_META, state.get("source_group"))
		elif node.has_meta(SOURCE_GROUP_META):
			node.remove_meta(SOURCE_GROUP_META)


static func collect_parts(root: Node) -> Array[AssemblyPart]:
	var result: Array[AssemblyPart] = []
	if not is_instance_valid(root):
		return result
	if root is AssemblyPart:
		result.append(root)
	for child in root.get_children():
		result.append_array(collect_parts(child))
	return result


static func nearest_part(node: Node) -> AssemblyPart:
	var current := node
	while is_instance_valid(current):
		if current is AssemblyPart:
			return current
		current = current.get_parent()
	return null


static func ensure_owned(node: Node, scene_root: Node) -> void:
	if not is_instance_valid(node) or not is_instance_valid(scene_root):
		return
	if node != scene_root and scene_root.is_ancestor_of(node):
		node.owner = scene_root
	for child in node.get_children():
		ensure_owned(child, scene_root)


static func validate_transform(value: Transform3D) -> String:
	if not value.origin.is_finite() or not value.basis.x.is_finite() or not value.basis.y.is_finite() or not value.basis.z.is_finite():
		return "Position, rotation and scale must be finite."
	if absf(value.basis.determinant()) < 0.00000001 or value.basis.x.length() < 0.00001 or value.basis.y.length() < 0.00001 or value.basis.z.length() < 0.00001:
		return "Scale must remain nonzero on every axis."
	return ""


static func capture_attachment(part: AssemblyPart) -> Dictionary:
	if not is_instance_valid(part):
		return {}
	var parent := part.get_parent()
	var carrier := parent as BoneAttachment3D if _is_carrier(parent) else null
	return {
		"parent": parent,
		"index": part.get_index() if parent != null else 0,
		"transform": part.transform,
		"top_level": part.top_level,
		"owner": part.owner,
		"attachment_mode": part.attachment_mode,
		"target_path": part.target_path,
		"bone_name": part.bone_name,
		"carrier": carrier,
		"carrier_parent": carrier.get_parent() if carrier != null else null,
		"carrier_index": carrier.get_index() if carrier != null and carrier.get_parent() != null else 0,
		"carrier_transform": carrier.transform if carrier != null else Transform3D.IDENTITY,
		"reference_states": capture_references(_authoring_root(part)),
	}


static func restore_attachment(part: AssemblyPart, state: Dictionary) -> void:
	if not is_instance_valid(part) or state.is_empty():
		return
	var parent: Node = state.get("parent")
	if parent != null and not is_instance_valid(parent):
		return
	var carrier: BoneAttachment3D = state.get("carrier")
	var carrier_parent: Node = state.get("carrier_parent")
	if carrier != null and (not is_instance_valid(carrier) or not is_instance_valid(carrier_parent)):
		return
	var old_parent := part.get_parent()
	if old_parent != null:
		old_parent.remove_child(part)
	_detach_empty_carrier(old_parent)
	if carrier != null and carrier.get_parent() == null:
		carrier_parent.add_child(carrier)
		carrier_parent.move_child(carrier, mini(int(state.get("carrier_index", 0)), carrier_parent.get_child_count() - 1))
		carrier.transform = state.get("carrier_transform", Transform3D.IDENTITY)
		_sync_carrier(carrier)
	if parent != null:
		parent.add_child(part)
		parent.move_child(part, mini(int(state.get("index", 0)), parent.get_child_count() - 1))
	part.top_level = state.get("top_level", false)
	part.transform = state.get("transform", Transform3D.IDENTITY)
	part.attachment_mode = state.get("attachment_mode", AssemblyPart.AttachmentMode.FREE)
	part.target_path = state.get("target_path", NodePath())
	part.bone_name = state.get("bone_name", "")
	var owner: Node = state.get("owner")
	if is_instance_valid(owner) and owner.is_ancestor_of(part):
		if carrier != null:
			ensure_owned(carrier, owner)
		ensure_owned(part, owner)
	restore_references(state.get("reference_states", []))
	part.update_configuration_warnings()


static func attach(part: AssemblyPart, target: Node3D, mode: int, bone: String, scene_root: Node3D) -> Dictionary:
	if not is_instance_valid(part) or not is_instance_valid(scene_root) or part == scene_root:
		return _failure("Choose a part inside the edited scene.")
	if not scene_root.is_ancestor_of(part):
		return _failure("Add the part to the edited scene before attaching it.")
	if mode == AssemblyPart.AttachmentMode.SKINNED:
		return _failure("Skinned conversion requires the explicit binding service.")
	if mode not in [AssemblyPart.AttachmentMode.FREE, AssemblyPart.AttachmentMode.PARENT, AssemblyPart.AttachmentMode.BONE]:
		return _failure("Unknown attachment mode.")
	if mode == AssemblyPart.AttachmentMode.FREE:
		target = scene_root
	if not is_instance_valid(target) or (target != scene_root and not scene_root.is_ancestor_of(target)):
		return _failure("The attachment target must belong to the edited scene.")
	if target == part or part.is_ancestor_of(target):
		return _failure("A part cannot attach to itself or one of its descendants.")
	if mode == AssemblyPart.AttachmentMode.BONE:
		if not target is Skeleton3D:
			return _failure("Bone attachment requires a Skeleton3D target.")
		if bone.is_empty() or (target as Skeleton3D).find_bone(bone) < 0:
			return _failure("The selected bone does not exist on this skeleton.")
	var world := _world_transform(part)
	var error := validate_transform(world)
	if not error.is_empty():
		return _failure(error)
	var parent_world := _world_transform(target)
	if mode == AssemblyPart.AttachmentMode.BONE:
		parent_world *= (target as Skeleton3D).get_bone_global_pose((target as Skeleton3D).find_bone(bone))
	error = validate_transform(parent_world)
	if not error.is_empty():
		return _failure("The target has an invalid transform: " + error)
	var local := parent_world.affine_inverse() * world
	error = validate_transform(local)
	if not error.is_empty():
		return _failure(error)
	var before := capture_attachment(part)
	var old_parent := part.get_parent()
	var carrier: BoneAttachment3D
	var new_parent: Node3D = target
	if mode == AssemblyPart.AttachmentMode.BONE:
		carrier = BoneAttachment3D.new()
		carrier.name = "Attachment_" + part.part_id.substr(0, 8)
		carrier.set_meta(CARRIER_META, true)
		carrier.bone_name = bone
		target.add_child(carrier)
		_sync_carrier(carrier)
		new_parent = carrier
	old_parent.remove_child(part)
	new_parent.add_child(part)
	# top_level would bypass an attachment entirely. Preserve placement while making
	# the deliberate new parent effective; before/after snapshots retain this flag.
	part.top_level = false
	part.transform = local
	part.attachment_mode = mode
	part.target_path = part.get_path_to(target)
	part.bone_name = bone if mode == AssemblyPart.AttachmentMode.BONE else ""
	ensure_owned(carrier if carrier != null else part, scene_root)
	# Resolve actual target objects before moving nodes. A mesh bound to a donor
	# outside this part must keep that donor even when hierarchy depth changes.
	rebase_references(before.get("reference_states", []), part)
	var detached := _detach_empty_carrier(old_parent)
	part.update_configuration_warnings()
	return _success({"before": before, "after": capture_attachment(part), "carrier": carrier, "detached_carrier": detached})


static func duplicate_part(part: AssemblyPart) -> Dictionary:
	if not is_instance_valid(part):
		return _failure("Choose an existing part to duplicate.")
	# Imported compositions may themselves contain AssemblyParts and bone carriers.
	# Keep their recorded source group; later attachments remain separate instances.
	var source_group := str(part.get_meta(SOURCE_GROUP_META, part.part_id))
	var copy := part.duplicate(Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS) as AssemblyPart
	if copy == null:
		return _failure("This part could not be duplicated.")
	_prune_dependent_parts(copy, source_group)
	for nested in collect_parts(copy):
		nested.part_id = generate_id()
	_remap_source_group(copy, source_group, copy.part_id)
	# A duplicated nested source part becomes its own independent grouping root.
	if copy.has_meta(SOURCE_GROUP_META):
		copy.remove_meta(SOURCE_GROUP_META)
	copy.attachment_mode = AssemblyPart.AttachmentMode.SKINNED if part.attachment_mode == AssemblyPart.AttachmentMode.SKINNED else AssemblyPart.AttachmentMode.FREE
	if copy.attachment_mode != AssemblyPart.AttachmentMode.SKINNED:
		copy.target_path = NodePath()
	copy.bone_name = ""
	copy.top_level = false
	_expand_and_clone(copy)
	ensure_owned(copy, copy)
	var references := _duplicate_references(part, copy)
	return _success({"part": copy, "world_transform": _world_transform(part), "reference_states": references})


## Private authoring/provenance snapshot. Hierarchy and authored identities are
## retained; mutable Resources are independent and all descendants belong to the
## copied root for explicit PackedScene packing. No live node/resource is changed.
static func independent_snapshot(root: Node) -> Node:
	if not is_instance_valid(root):
		return null
	var copy := root.duplicate(Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS)
	if copy == null:
		return null
	_expand_and_clone(copy)
	ensure_owned(copy, copy)
	return copy


## Read-only validation shared by native editor saves and explicit snapshots.
static func validate_scene_save(root: Node, output_path: String) -> Dictionary:
	if not is_instance_valid(root):
		return _failure("Choose an authored character scene to save.")
	if output_path.is_empty() or output_path.get_extension().to_lower() != "tscn":
		return _failure("Choose an explicit .tscn output path.")
	if not output_path.begins_with("res://") and not output_path.begins_with("user://") and not output_path.is_absolute_path():
		return _failure("The output must be a res://, user:// or absolute path.")
	var absolute := ProjectSettings.globalize_path(output_path).simplify_path()
	var ids := {}
	for part in collect_parts(root):
		if part.part_id.is_empty() or ids.has(part.part_id):
			return _failure("Every part must have a unique, nonempty identity before saving.")
		ids[part.part_id] = true
		var source_absolute := ProjectSettings.globalize_path(part.source_path).simplify_path()
		var same_source := source_absolute.nocasecmp_to(absolute) == 0 if OS.has_feature("windows") else source_absolute == absolute
		if not part.source_path.is_empty() and same_source:
			return _failure("Save the assembled character to its own path, not over a part's source scene.")
		var error := validate_transform(part.transform)
		if not error.is_empty():
			return _failure("Part %s: %s" % [part.name, error])
		if part.attachment_mode != AssemblyPart.AttachmentMode.FREE:
			var target := part.get_node_or_null(part.target_path) if not part.target_path.is_empty() else null
			if target == null:
				return _failure("Part %s has a missing attachment target." % part.name)
			if part.attachment_mode == AssemblyPart.AttachmentMode.BONE and (not target is Skeleton3D or (target as Skeleton3D).find_bone(part.bone_name) < 0):
				return _failure("Part %s has a missing skeleton/bone." % part.name)
	for reference: Dictionary in capture_references(root):
		if reference.key in [&"skeleton", &"donor_path"] and not reference.target is Skeleton3D:
			return _failure("A skinned mesh or binding references a missing donor skeleton. Repair the reference before saving.")
	if not DirAccess.dir_exists_absolute(absolute.get_base_dir()):
		return _failure("The chosen output folder does not exist.")
	return _success({"path": output_path})


static func save_scene(root: Node, output_path: String) -> Dictionary:
	var validated := validate_scene_save(root, output_path)
	if not validated.ok:
		return validated
	# Packing a private expanded copy avoids changing ownership or resource paths in
	# the live scene, including when the destination is unwritable.
	var copy := independent_snapshot(root)
	if copy == null:
		return _failure("The authored scene could not be copied for saving.")
	var packed := PackedScene.new()
	var pack_error := packed.pack(copy)
	copy.free()
	if pack_error != OK:
		return _failure("The scene could not be packed (%s)." % error_string(pack_error))
	var save_error := ResourceSaver.save(packed, output_path)
	if save_error != OK:
		return _failure("The scene could not be saved (%s)." % error_string(save_error))
	return _success({"path": output_path, "scene": packed})


static func _expand_and_clone(root: Node) -> void:
	var resources := {}
	_expand_node(root, resources)


## Explicit authoring snapshots. The editor can retain target objects before a
## native rename/reparent; no reference repair runs on opening or startup.
static func capture_references(root: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(root):
		return result
	if root is AssemblyPart:
		var part := root as AssemblyPart
		if not part.target_path.is_empty():
			result.append(_reference(part, part, &"target_path", part.target_path, false))
		if part.binding_data != null and part.binding_data.has_meta("donor_path"):
			var path := NodePath(part.binding_data.get_meta("donor_path"))
			result.append(_reference(part, part.binding_data, &"donor_path", path, true))
		for index in part.geometry_masks.size():
			var mask := part.geometry_masks[index]
			if mask != null and _has_property(mask, &"source_node_path"):
				var path := NodePath(mask.get("source_node_path"))
				if not path.is_empty():
					var reference := _reference(part, mask, &"source_node_path", path, false)
					reference["mask_index"] = index
					result.append(reference)
	if root is MeshInstance3D:
		var mesh := root as MeshInstance3D
		if not mesh.skeleton.is_empty() and (mesh.skin != null or mesh.get_node_or_null(mesh.skeleton) is Skeleton3D):
			result.append(_reference(mesh, mesh, &"skeleton", mesh.skeleton, false))
	for child in root.get_children():
		result.append_array(capture_references(child))
	return result


static func restore_references(states: Array) -> void:
	for state: Dictionary in states:
		_write_reference(state, state.get("value", NodePath()))


## Call after inserting a duplicate, or after an explicit hierarchy operation.
## Resolving nodes before movement prevents stale relative paths from being
## mistaken for a different same-named skeleton after movement.
static func rebase_references(states: Array, skip_target_part: AssemblyPart = null) -> void:
	for state: Dictionary in states:
		var base: Node = state.get("base")
		var target: Node = state.get("target")
		if not is_instance_valid(base) or not is_instance_valid(target):
			continue
		if base == skip_target_part and state.get("key") == &"target_path":
			continue
		if _root_node(base) != _root_node(target):
			continue
		_write_reference(state, base.get_path_to(target))


static func _reference(base: Node, object: Object, key: StringName, value: NodePath, metadata: bool) -> Dictionary:
	return {"base": base, "object": object, "key": key, "value": value, "metadata": metadata, "target": base.get_node_or_null(value)}


static func _write_reference(state: Dictionary, value: NodePath) -> void:
	var object: Object = state.get("object")
	if not is_instance_valid(object):
		return
	if bool(state.get("metadata", false)):
		object.set_meta(state.key, value)
	else:
		object.set(state.key, value)


static func _duplicate_references(source: AssemblyPart, copy: AssemblyPart) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for state: Dictionary in capture_references(source):
		var source_base: Node = state.base
		var base := copy.get_node_or_null(source.get_path_to(source_base))
		if base == null:
			continue # Explicitly omitted dependent part.
		if base == copy and state.key == &"target_path" and copy.attachment_mode != AssemblyPart.AttachmentMode.SKINNED:
			continue
		var target: Node = state.target
		if is_instance_valid(target) and (target == source or source.is_ancestor_of(target)):
			target = copy.get_node_or_null(source.get_path_to(target))
		var object: Object = base
		if bool(state.metadata):
			object = (base as AssemblyPart).binding_data
		elif state.has("mask_index"):
			var index := int(state.mask_index)
			if not base is AssemblyPart or index >= (base as AssemblyPart).geometry_masks.size():
				continue
			object = (base as AssemblyPart).geometry_masks[index]
		var reference := {"base": base, "object": object, "key": state.key, "value": state.value, "metadata": state.metadata, "target": target}
		if state.has("mask_index"):
			reference["mask_index"] = state.mask_index
		result.append(reference)
	return result


static func _authoring_root(part: AssemblyPart) -> Node:
	if is_instance_valid(part.owner) and part.owner.is_ancestor_of(part):
		return part.owner
	var current: Node = part
	while current.get_parent() is Node3D:
		current = current.get_parent()
	return current


static func _root_node(node: Node) -> Node:
	var current := node
	while current.get_parent() != null:
		current = current.get_parent()
	return current


static func _has_property(object: Object, name: StringName) -> bool:
	for property in object.get_property_list():
		if property.name == name:
			return true
	return false


static func _expand_node(node: Node, resources: Dictionary) -> void:
	# Imported roots are expanded deliberately only while authoring. Their original
	# path is retained on AssemblyPart, while local override resources save inline.
	node.scene_file_path = ""
	for property in node.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE) or property.name in [&"script", &"owner"]:
			continue
		var value: Variant = node.get(property.name)
		if value is Resource or value is Array or value is Dictionary:
			node.set(property.name, _clone_value(value, resources))
	for child in node.get_children():
		_expand_node(child, resources)


static func _clone_value(value: Variant, resources: Dictionary) -> Variant:
	if value is Resource:
		# Scripts and source PackedScenes are definitions, not editable per-part state.
		# Imported textures remain source references; materials using them are cloned.
		if value is Script or value is PackedScene or value is Texture:
			return value
		var resource := value as Resource
		var id := resource.get_instance_id()
		if resources.has(id):
			return resources[id]
		# Storage setters for graphs/libraries can add nodes and connections. Start
		# with a fresh instance and populate each property exactly once; rewriting a
		# pre-populated duplicate invokes those additive setters a second time.
		var definition: Script = resource.get_script()
		var copy: Resource = definition.new() if definition != null else ClassDB.instantiate(resource.get_class())
		resources[id] = copy
		for property in resource.get_property_list():
			if not (int(property.usage) & PROPERTY_USAGE_STORAGE) or property.name in [&"script", &"resource_path"]:
				continue
			var nested: Variant = resource.get(property.name)
			copy.set(property.name, _clone_value(nested, resources))
		copy.resource_local_to_scene = true
		return copy
	if value is Array:
		var copy: Array = value.duplicate()
		for i in copy.size():
			copy[i] = _clone_value(value[i], resources)
		return copy
	if value is Dictionary:
		var copy: Dictionary = value.duplicate()
		for key in copy:
			copy[key] = _clone_value(value[key], resources)
		return copy
	return value


static func _capture_source_nodes(node: Node, states: Array[Dictionary]) -> void:
	if not is_instance_valid(node):
		return
	var state := {"node": node, "had_source_group": node.has_meta(SOURCE_GROUP_META), "source_group": node.get_meta(SOURCE_GROUP_META, "")}
	if node is AssemblyPart:
		state["part_id"] = (node as AssemblyPart).part_id
	states.append(state)
	for child in node.get_children():
		_capture_source_nodes(child, states)


static func _mark_source_group(node: Node, group_id: String) -> void:
	node.set_meta(SOURCE_GROUP_META, group_id)
	for child in node.get_children():
		_mark_source_group(child, group_id)


static func _remap_source_group(node: Node, old_id: String, new_id: String) -> void:
	if str(node.get_meta(SOURCE_GROUP_META, "")) == old_id:
		node.set_meta(SOURCE_GROUP_META, new_id)
	for child in node.get_children():
		_remap_source_group(child, old_id, new_id)


static func _prune_dependent_parts(node: Node, source_group: String) -> void:
	for child in node.get_children():
		var source_member := not source_group.is_empty() and str(child.get_meta(SOURCE_GROUP_META, "")) == source_group
		if (child is AssemblyPart or _is_carrier(child)) and not source_member:
			node.remove_child(child)
			child.free()
		else:
			_prune_dependent_parts(child, source_group)


static func _is_carrier(node: Node) -> bool:
	return is_instance_valid(node) and node is BoneAttachment3D and bool(node.get_meta(CARRIER_META, false))


static func _detach_empty_carrier(node: Node) -> BoneAttachment3D:
	if _is_carrier(node) and node.get_child_count() == 0 and node.get_parent() != null:
		node.get_parent().remove_child(node)
		return node as BoneAttachment3D
	return null


static func _sync_carrier(carrier: BoneAttachment3D) -> void:
	var skeleton := carrier.get_parent() as Skeleton3D
	if skeleton != null:
		var index := skeleton.find_bone(carrier.bone_name)
		if index >= 0:
			carrier.bone_idx = index
			carrier.transform = skeleton.get_bone_global_pose(index)


static func _world_transform(node: Node3D) -> Transform3D:
	if node.is_inside_tree():
		return node.global_transform
	var result := node.transform
	var current := node
	while not current.top_level:
		var parent := current.get_parent()
		if not parent is Node3D:
			break
		current = parent as Node3D
		result = current.transform * result
	return result


static func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}


static func _success(extra: Dictionary = {}) -> Dictionary:
	var result := {"ok": true, "error": ""}
	result.merge(extra)
	return result
