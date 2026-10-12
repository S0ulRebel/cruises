@tool
class_name CWCommands
extends RefCounted
## The editor's single transaction boundary. Core operations never silently save.

const Ops = preload("res://addons/character_workshop/core/assembly_operations.gd")
const Part = preload("res://addons/character_workshop/runtime/part.gd")
const Mask = preload("res://addons/character_workshop/runtime/mesh_mask.gd")
const MeshOps = preload("res://addons/character_workshop/core/mesh_operations.gd")

signal changed

var undo: EditorUndoRedoManager
var scene_root: Node3D

var animation_library := "workshop"

func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}

func _valid_part(part: Node3D) -> String:
	if not is_instance_valid(scene_root) or not is_instance_valid(part):
		return "Open a character assembly and select one of its parts."
	if part == scene_root or not scene_root.is_ancestor_of(part) or not part is Part:
		return "The selected node is not a part in this character assembly."
	return Ops.validate_transform(part.global_transform)

func _begin(title: String) -> void:
	undo.create_action(title, UndoRedo.MERGE_DISABLE, scene_root)

func _finish() -> void:
	undo.add_do_method(self, "_notify")
	undo.add_undo_method(self, "_notify")
	undo.commit_action()

func _notify() -> void:
	changed.emit()

func _insert(part: Node, parent: Node, index: int = -1) -> void:
	if part.get_parent() != null:
		part.get_parent().remove_child(part)
	parent.add_child(part, true)
	if index >= 0:
		parent.move_child(part, mini(index, parent.get_child_count() - 1))
	Ops.ensure_owned(part, scene_root)

func _remove(part: Node) -> void:
	if part.get_parent() != null:
		part.get_parent().remove_child(part)

func add_source(path: String, world_position: Variant = null) -> Dictionary:
	if not is_instance_valid(scene_root):
		return _fail("Open or create a character assembly first.")
	var result: Dictionary = Ops.create_part(path)
	if not result.ok:
		return result
	var part: Node3D = result.part
	if world_position is Vector3:
		if not world_position.is_finite():
			part.free()
			return _fail("Choose a finite placement point.")
		part.position = scene_root.global_transform.affine_inverse() * world_position
	_begin("Add character part")
	undo.add_do_method(self, "_insert", part, scene_root)
	undo.add_undo_method(self, "_remove", part)
	undo.add_do_reference(part)
	_finish()
	return {"ok": true, "error": "", "part": part}

func rename_selected(part: Node3D, new_name: String) -> Dictionary:
	if not is_instance_valid(part) or (part != scene_root and not _valid_part(part).is_empty()):
		return _fail("Select a character or part to rename.")
	new_name = new_name.strip_edges()
	if new_name.is_empty() or new_name != new_name.validate_node_name():
		return _fail("Use a nonempty node name without . : @ / or quotation marks.")
	for sibling: Node in part.get_parent().get_children():
		if sibling != part and str(sibling.name) == new_name:
			return _fail("Another part at this level already has that name.")
	if str(part.name) == new_name:
		return {"ok": true, "part": part}
	var references := Ops.capture_references(scene_root)
	var paths := _rename_paths()
	var animations := _rename_animations(part)
	_begin("Rename character part")
	undo.add_do_property(part, "name", new_name)
	undo.add_do_method(Ops, "rebase_references", references)
	undo.add_do_method(self, "_apply_rename_paths", paths, true)
	undo.add_do_method(self, "_apply_rename_animations", animations, true)
	undo.add_undo_property(part, "name", part.name)
	undo.add_undo_method(Ops, "restore_references", references)
	undo.add_undo_method(self, "_apply_rename_paths", paths, false)
	undo.add_undo_method(self, "_apply_rename_animations", animations, false)
	_finish()
	return {"ok": true, "part": part}

func _rename_paths() -> Array:
	var paths: Array = []
	for node: Node in _all_nodes(scene_root):
		for property: Dictionary in node.get_property_list():
			if property.type != TYPE_NODE_PATH or not (int(property.usage) & PROPERTY_USAGE_STORAGE):
				continue
			var path: NodePath = node.get(property.name)
			if path.is_empty():
				continue
			var target := node.get_node_or_null(NodePath(path.get_concatenated_names()))
			if target != null:
				paths.append({"node": node, "key": property.name, "path": path, "target": target})
	return paths

func _apply_rename_paths(paths: Array, forward: bool) -> void:
	for entry: Dictionary in paths:
		entry.node.set(entry.key, _renamed_path(entry.node, entry.target, entry.path) if forward else entry.path)

func _renamed_path(base: Node, target: Node, old: NodePath) -> NodePath:
	var names := str(target.get_path()) if old.is_absolute() else str(base.get_path_to(target))
	var suffix := str(old.get_concatenated_subnames())
	return NodePath(names + (":" + suffix if not suffix.is_empty() else ""))

func _rename_animations(part: Node) -> Array:
	var states: Array = []
	for node: Node in _all_nodes(scene_root):
		if not node is AnimationPlayer:
			continue
		var base: Node = node.get_node_or_null(node.root_node)
		if base == null:
			continue
		for key: StringName in node.get_animation_library_list():
			var original: AnimationLibrary = node.get_animation_library(key)
			var copy: AnimationLibrary
			var tracks: Array = []
			for clip: StringName in original.get_animation_list():
				var animation := original.get_animation(clip)
				for index: int in animation.get_track_count():
					var path := animation.track_get_path(index)
					var target := base.get_node_or_null(NodePath(path.get_concatenated_names()))
					if target == null:
						continue
					var base_inside := part == base or part.is_ancestor_of(base)
					var target_inside := part == target or part.is_ancestor_of(target)
					if base_inside == target_inside and not (path.is_absolute() and target_inside):
						continue
					if copy == null:
						copy = original.duplicate(true)
					tracks.append({"animation": copy.get_animation(clip), "index": index, "base": base, "target": target, "path": path})
			if copy != null:
				states.append({"player": node, "key": key, "old": original, "next": copy, "tracks": tracks})
	return states

func _apply_rename_animations(states: Array, forward: bool) -> void:
	for entry: Dictionary in states:
		if forward:
			for track: Dictionary in entry.tracks:
				track.animation.track_set_path(track.index, _renamed_path(track.base, track.target, track.path))
		entry.player.remove_animation_library(entry.key)
		entry.player.add_animation_library(entry.key, entry.next if forward else entry.old)

func transform_selected(part: Node3D, before: Transform3D, after: Transform3D) -> Dictionary:
	var error := ""
	if is_instance_valid(part) and part == scene_root and part.is_inside_tree():
		error = Ops.validate_transform(part.global_transform)
	else:
		error = _valid_part(part)
	if not error.is_empty():
		return _fail(error)
	error = Ops.validate_transform(after)
	if not error.is_empty():
		return _fail(error)
	if not part.global_transform.is_equal_approx(before):
		return _fail("The part moved during this edit. Try the transform again.")
	if before.is_equal_approx(after):
		return {"ok": true, "part": part}
	# Record local transforms so native undo follows an authored parent or bone.
	var parent_inverse := Transform3D.IDENTITY
	var parent := part.get_parent() as Node3D
	if parent != null and not part.top_level:
		parent_inverse = parent.global_transform.affine_inverse()
	_begin("Transform character part")
	undo.add_do_property(part, "transform", parent_inverse * after)
	undo.add_undo_property(part, "transform", part.transform)
	_finish()
	return {"ok": true, "part": part}

func install_animation_library(result: Dictionary) -> Dictionary:
	if not result.get("ok", false):
		return result
	var player: AnimationPlayer = result.get("player")
	var model: Node3D = result.get("model")
	var library: AnimationLibrary = result.get("library")
	if player == null or model == null or library == null or not scene_root.is_ancestor_of(model):
		return _fail("Choose a model in the current assembly as the animation target.")
	var created: bool = result.get("created", false)
	var library_key := animation_library
	var previous: AnimationLibrary = player.get_animation_library(library_key) if player.has_animation_library(library_key) else null
	_begin("Borrow character animation clips")
	if created:
		undo.add_do_method(self, "_insert", player, model)
		undo.add_undo_method(self, "_remove", player)
		undo.add_do_reference(player)
	undo.add_do_method(self, "_set_library", player, library, library_key)
	undo.add_undo_method(self, "_set_library", player, previous, library_key)
	_finish()
	return {"ok": true, "error": ""}

func _set_library(player: AnimationPlayer, value: AnimationLibrary, library_key: String) -> void:
	player.stop()
	if player.has_animation_library(library_key):
		player.remove_animation_library(library_key)
	if value != null:
		player.add_animation_library(library_key, value)

func repair_references(states: Array) -> Dictionary:
	if not is_instance_valid(scene_root):
		return _fail("Open a character assembly first.")
	var before: Array = Ops.capture_references(scene_root)
	_begin("Repair moved character references")
	undo.add_do_method(Ops, "rebase_references", states)
	undo.add_undo_method(Ops, "restore_references", before)
	_finish()
	return {"ok": true, "error": ""}

func duplicate_selected(part: Node3D) -> Dictionary:
	var error := _valid_part(part)
	if not error.is_empty():
		return _fail(error)
	var result: Dictionary = Ops.duplicate_part(part)
	if not result.ok:
		return result
	var copy: Node3D = result.part
	copy.transform = scene_root.global_transform.affine_inverse() * part.global_transform
	_begin("Duplicate character part")
	undo.add_do_method(self, "_insert", copy, scene_root)
	undo.add_do_method(Ops, "rebase_references", result.get("reference_states", []))
	undo.add_undo_method(self, "_remove", copy)
	undo.add_do_reference(copy)
	_finish()
	return {"ok": true, "error": "", "part": copy}

func toggle_hidden(part: Node3D) -> Dictionary:
	var error := _valid_part(part)
	if not error.is_empty():
		return _fail(error)
	_begin("Show character part" if not part.visible else "Hide character part")
	undo.add_do_property(part, "visible", not part.visible)
	undo.add_undo_property(part, "visible", part.visible)
	_finish()
	return {"ok": true, "error": "", "part": part}

func attach_selected(part: Node3D, target: Node3D, mode: int, bone: String = "") -> Dictionary:
	var error := _valid_part(part)
	if not error.is_empty():
		return _fail(error)
	# Validate by performing the authoring operation once, then restore before commit.
	var before: Dictionary = Ops.capture_attachment(part)
	var result: Dictionary = Ops.attach(part, target, mode, bone, scene_root)
	if not result.ok:
		return result
	var after: Dictionary = Ops.capture_attachment(part)
	Ops.restore_attachment(part, before)
	_begin("Attach character part" if mode != 0 else "Detach character part")
	undo.add_do_method(Ops, "restore_attachment", part, after)
	undo.add_undo_method(Ops, "restore_attachment", part, before)
	_retain_carriers(before, after)
	_finish()
	return {"ok": true, "error": "", "part": part}

func _retain_carriers(before: Dictionary, after: Dictionary = {}) -> void:
	# Existing scene parents must never be passed to add_do_reference: discarding
	# an undone action would then delete an unrelated, still-authored parent.
	var old: Node = before.get("carrier")
	var next: Node = after.get("carrier")
	if old != next:
		if is_instance_valid(old):
			undo.add_undo_reference(old)
		if is_instance_valid(next):
			undo.add_do_reference(next)

func dependents(part: Node3D) -> Array:
	var result: Array = []
	for other: Node3D in Ops.collect_parts(scene_root):
		if other == part:
			continue
		var depends := part.is_ancestor_of(other)
		for state: Dictionary in Ops.capture_references(other):
			var target: Node = state.get("target")
			if Ops.nearest_part(state.base) == other and is_instance_valid(target) and (target == part or part.is_ancestor_of(target)):
				depends = true
		if depends:
			result.append(other)
	return result

func _loses_skin_donor(children: Array, removed: Node3D) -> bool:
	for child: Node3D in children:
		for state: Dictionary in Ops.capture_references(child):
			var target: Node = state.get("target")
			if Ops.nearest_part(state.base) != child or state.key not in [&"skeleton", &"donor_path"] or not is_instance_valid(target):
				continue
			if (target == removed or removed.is_ancestor_of(target)) and not children.has(Ops.nearest_part(target)):
				return true
	return false

func remove_selected(part: Node3D, policy: String = "cancel") -> Dictionary:
	var error := _valid_part(part)
	if not error.is_empty():
		return _fail(error)
	var children := dependents(part)
	if not children.is_empty() and policy not in ["keep_free", "remove_all"]:
		return _fail("This part has %d dependent part(s). Choose Keep as free parts or Remove all." % children.size())
	if policy == "keep_free" and _loses_skin_donor(children, part):
		return _fail("A skinned dependent needs this donor. Rebind it to another donor first, or choose Remove all. Keeping it free would orphan its skin.")
	var before: Dictionary = Ops.capture_attachment(part)
	var child_states: Array = []
	for child: Node3D in children:
		child_states.append({"part": child, "state": Ops.capture_attachment(child), "nested": part.is_ancestor_of(child)})
	_begin("Remove character part")
	undo.add_do_method(self, "_remove_with_dependents", part, child_states, policy)
	undo.add_undo_method(self, "_restore_removed", part, before, child_states)
	undo.add_undo_reference(part)
	for state: Dictionary in child_states:
		if policy == "keep_free":
			_retain_carriers(state.state)
		elif not state.nested:
			undo.add_undo_reference(state.part)
	_finish()
	return {"ok": true, "error": ""}

func _remove_with_dependents(part: Node3D, children: Array, policy: String) -> void:
	for entry: Dictionary in children:
		if policy == "keep_free":
			Ops.attach(entry.part, scene_root, 0, "", scene_root)
		elif not entry.nested:
			_remove(entry.part)
	_remove(part)

func _restore_removed(part: Node3D, state: Dictionary, children: Array) -> void:
	Ops.restore_attachment(part, state)
	for entry: Dictionary in children:
		Ops.restore_attachment(entry.part, entry.state)

func replace_selected(part: Node3D, path: String, policy: String = "cancel") -> Dictionary:
	var error := _valid_part(part)
	if not error.is_empty():
		return _fail(error)
	var children := dependents(part)
	if not children.is_empty() and policy not in ["keep_free", "remove_all", "reconnect"]:
		return _fail("Choose how to handle dependent parts before replacing this part.")
	if policy == "keep_free" and _loses_skin_donor(children, part):
		return _fail("A skinned dependent needs this donor. Choose reconnect with a compatible rig, Remove all, or rebind the dependent first.")
	var result: Dictionary = Ops.create_part(path)
	if not result.ok:
		return result
	var replacement: Node3D = result.part
	replacement.name = part.name
	replacement.set("part_id", part.get("part_id"))
	replacement.visible = part.visible
	var before: Dictionary = Ops.capture_attachment(part)
	var child_states: Array = []
	for child: Node3D in children:
		child_states.append({"part": child, "state": Ops.capture_attachment(child), "nested": part.is_ancestor_of(child)})
	# Reconnect only when every original target/bone exists in the replacement.
	var links: Array = []
	if policy == "reconnect":
		for child: Node3D in children:
			var target: Node = child.get_node_or_null(child.get("target_path"))
			if target == null or not part.is_ancestor_of(target):
				replacement.free()
				return _fail("A dependent target is stale; detach it before replacement.")
			var relative: NodePath = part.get_path_to(target)
			var kept_target := children.has(Ops.nearest_part(target))
			var new_target: Node3D = target as Node3D if kept_target else replacement.get_node_or_null(relative) as Node3D
			if new_target == null or (int(child.get("attachment_mode")) == 2 and (not new_target is Skeleton3D or new_target.find_bone(str(child.get("bone_name"))) < 0)):
				replacement.free()
				return _fail("Replacement lacks target %s or its bone. Choose Keep as free parts instead." % relative)
			var refs: Array = []
			for reference: Dictionary in Ops.capture_references(child):
				var old_target: Node = reference.get("target")
				if Ops.nearest_part(reference.base) != child or not is_instance_valid(old_target) or children.has(Ops.nearest_part(old_target)) or not part.is_ancestor_of(old_target):
					continue
				var fresh: Node = replacement.get_node_or_null(part.get_path_to(old_target))
				if fresh == null or (reference.key in [&"skeleton", &"donor_path"] and not _compatible_skeletons(old_target, fresh)):
					replacement.free()
					return _fail("Replacement changes a dependent donor rig. Rebind that garment explicitly before replacing this donor.")
				var mapped: Dictionary = reference.duplicate()
				mapped.target = fresh
				refs.append(mapped)
			links.append({"part": child, "target": new_target, "mode": child.get("attachment_mode"), "bone": child.get("bone_name"), "references": refs})
	# Prepare matching carriers once. Redo restores these same objects rather than
	# creating a new, untracked BoneAttachment on every history traversal.
	_replace(part, replacement, before, child_states, links, policy)
	_undo_replace(part, replacement, before, child_states)
	_begin("Replace character part")
	undo.add_do_method(self, "_replace", part, replacement, before, child_states, links, policy)
	undo.add_undo_method(self, "_undo_replace", part, replacement, before, child_states)
	undo.add_do_reference(replacement)
	undo.add_undo_reference(part)
	for entry: Dictionary in child_states:
		if policy != "remove_all":
			var after: Dictionary = {}
			for link: Dictionary in links:
				if link.part == entry.part:
					after = link.get("after", {})
			_retain_carriers(entry.state, after)
		elif not entry.nested:
			undo.add_undo_reference(entry.part)
	_finish()
	return {"ok": true, "error": "", "part": replacement}

func _replace(old: Node3D, replacement: Node3D, state: Dictionary, children: Array, links: Array, policy: String) -> void:
	if policy != "remove_all":
		for entry: Dictionary in children:
			Ops.attach(entry.part, scene_root, 0, "", scene_root)
	else:
		for entry: Dictionary in children:
			if not entry.nested:
				_remove(entry.part)
	_remove(old)
	Ops.restore_attachment(replacement, state)
	Ops.ensure_owned(replacement, scene_root)
	for link: Dictionary in links:
		if link.has("after"):
			Ops.restore_attachment(link.part, link.after)
		else:
			if link.mode == 3:
				link.part.set("attachment_mode", 3)
				link.part.set("target_path", link.part.get_path_to(link.target))
			else:
				Ops.attach(link.part, link.target, link.mode, link.bone, scene_root)
			Ops.rebase_references(link.references)
			link.after = Ops.capture_attachment(link.part)

func _compatible_skeletons(old: Node, fresh: Node) -> bool:
	if not old is Skeleton3D or not fresh is Skeleton3D or old.get_bone_count() != fresh.get_bone_count():
		return false
	for index: int in old.get_bone_count():
		if old.get_bone_name(index) != fresh.get_bone_name(index) or not old.get_bone_global_rest(index).is_equal_approx(fresh.get_bone_global_rest(index)):
			return false
	return true

func _undo_replace(old: Node3D, replacement: Node3D, state: Dictionary, children: Array) -> void:
	for entry: Dictionary in children:
		if replacement.is_ancestor_of(entry.part):
			Ops.attach(entry.part, scene_root, 0, "", scene_root)
	_remove(replacement)
	Ops.restore_attachment(old, state)
	for entry: Dictionary in children:
		Ops.restore_attachment(entry.part, entry.state)

func adopt_selected(node: Node3D) -> Dictionary:
	if not is_instance_valid(scene_root) or not is_instance_valid(node) or node == scene_root or not scene_root.is_ancestor_of(node):
		return _fail("Select a model in the open assembly's scene tree.")
	if Ops.nearest_part(node) != null:
		return _fail("This model is already inside a character part.")
	var part: Node3D = Part.new()
	part.set("part_id", Ops.generate_id())
	part.set("source_path", node.scene_file_path)
	part.name = node.name
	var state := {"parent": node.get_parent(), "index": node.get_index(), "name": node.name, "transform": node.transform, "owners": _owners(node)}
	_begin("Adopt model as character part")
	undo.add_do_method(self, "_adopt", node, part, state)
	undo.add_undo_method(self, "_unadopt", node, part, state)
	undo.add_do_reference(part)
	_finish()
	return {"ok": true, "error": "", "part": part}

func _owners(node: Node) -> Array:
	var entries: Array = [{"node": node, "owner": node.owner}]
	for child: Node in node.get_children():
		entries.append_array(_owners(child))
	return entries

func _adopt(node: Node3D, part: Node3D, state: Dictionary) -> void:
	_remove(node)
	_insert(part, state.parent, state.index)
	part.transform = state.transform
	part.add_child(node)
	node.name = "Model"
	node.transform = Transform3D.IDENTITY
	if not state.has("composition_after"):
		state.composition_before = Ops.capture_source_composition(part)
		Ops.initialize_source_composition(part)
		state.composition_after = Ops.capture_source_composition(part)
	else:
		Ops.restore_source_composition(state.composition_after)
	Ops.ensure_owned(part, scene_root)

func _unadopt(node: Node3D, part: Node3D, state: Dictionary) -> void:
	Ops.restore_source_composition(state.get("composition_before", []))
	_remove(node)
	_remove(part)
	state.parent.add_child(node)
	state.parent.move_child(node, mini(state.index, state.parent.get_child_count() - 1))
	node.name = state.name
	node.transform = state.transform
	for entry: Dictionary in state.owners:
		entry.node.owner = entry.owner

func mask_for(part: Node3D, mesh: MeshInstance3D) -> Resource:
	if part == null or mesh == null:
		return null
	for value: Resource in part.get("geometry_masks"):
		if value is Mask and value.source_node_path == part.get_path_to(mesh):
			return value
	return null

func reference_mesh(part: Node3D, mesh: MeshInstance3D) -> Mesh:
	var mask := mask_for(part, mesh)
	return mask.source_mesh if mask != null else mesh.mesh

func change_geometry(part: Node3D, mesh: MeshInstance3D, selected: Dictionary, operation: String) -> Dictionary:
	var error := _valid_part(part)
	if not error.is_empty():
		return _fail(error)
	if mesh == null or mesh.mesh == null or Ops.nearest_part(mesh) != part:
		return _fail("Select a mesh owned by this part. Select an attached part separately to edit its geometry.")
	for value: Resource in part.get("geometry_masks"):
		if value is Mask and part.get_node_or_null(value.source_node_path) == null:
			return _fail("An exclusion target was moved or renamed. Repair the retained mesh references first.")
	var previous := mask_for(part, mesh)
	var source := reference_mesh(part, mesh)
	if previous != null:
		error = MeshOps.validate(source, previous)
		if not error.is_empty():
			return _fail(error)
	var next: Resource = Mask.new()
	next.source_mesh = source
	next.topology_fingerprint = MeshOps.fingerprint(source)
	next.source_node_path = part.get_path_to(mesh)
	next.excluded_faces = previous.excluded_faces.duplicate(true) if previous != null else {}
	var source_overrides: Array = previous.get_meta("source_surface_overrides", []) if previous != null else _overrides(mesh)
	next.set_meta("source_surface_overrides", source_overrides)
	if operation == "reset":
		next.excluded_faces = {}
	else:
		for surface: Variant in selected:
			var faces: PackedInt32Array = next.excluded_faces.get(surface, PackedInt32Array())
			for face: int in selected[surface]:
				var index := faces.find(face)
				if operation == "exclude" and index < 0:
					faces.append(face)
				elif operation == "restore" and index >= 0:
					faces.remove_at(index)
			faces.sort()
			if faces.is_empty():
				next.excluded_faces.erase(surface)
			else:
				next.excluded_faces[surface] = faces
	var built: Dictionary = MeshOps.build(source, next.excluded_faces)
	if not built.ok:
		return built
	var old_masks: Array[Resource] = []
	old_masks.assign(part.get("geometry_masks"))
	var new_masks: Array[Resource] = old_masks.duplicate()
	if previous != null:
		new_masks.erase(previous)
	if operation != "reset" and not next.excluded_faces.is_empty():
		new_masks.append(next)
	var collision: Array = []
	for node: Node in _all_nodes(part):
		if (node is CollisionShape3D or node is CollisionPolygon3D) and Ops.nearest_part(node) == part:
			collision.append({"node": node, "disabled": node.disabled})
	# Every mask on one part shares the pre-exclusion baseline. A second mesh must
	# not capture the already-disabled state and keep collision disabled after Reset.
	var collision_original: Dictionary = previous.get_meta("collision_original", {}).duplicate() if previous != null else {}
	if collision_original.is_empty():
		for value: Resource in old_masks:
			if value is Mask and value.has_meta("collision_original"):
				collision_original = value.get_meta("collision_original").duplicate()
				break
	if collision_original.is_empty():
		for entry: Dictionary in collision:
			collision_original[part.get_path_to(entry.node)] = entry.disabled
	next.set_meta("collision_original", collision_original)
	_begin("%s mesh faces" % operation.capitalize())
	var derived: Mesh = source if next.excluded_faces.is_empty() else built.mesh
	var override_values: Array = source_overrides if next.excluded_faces.is_empty() else []
	if not next.excluded_faces.is_empty():
		override_values.resize(derived.get_surface_count())
		for from_surface: Variant in built.surface_map:
			if int(from_surface) < source_overrides.size():
				override_values[built.surface_map[from_surface]] = source_overrides[int(from_surface)]
	undo.add_do_method(self, "_apply_mesh", mesh, derived, override_values)
	undo.add_undo_method(self, "_apply_mesh", mesh, mesh.mesh, _overrides(mesh))
	undo.add_do_property(part, "geometry_masks", new_masks)
	undo.add_undo_property(part, "geometry_masks", old_masks)
	# Existing authored collision is not rebuilt: disable it explicitly when changing
	# geometry so removed regions cannot remain collidable. Undo restores its state.
	if not next.excluded_faces.is_empty():
		for entry: Dictionary in collision:
			undo.add_do_property(entry.node, "disabled", true)
			undo.add_undo_property(entry.node, "disabled", entry.disabled)
	elif new_masks.is_empty():
		for entry: Dictionary in collision:
			var path: NodePath = part.get_path_to(entry.node)
			if collision_original.has(path):
				undo.add_do_property(entry.node, "disabled", collision_original[path])
				undo.add_undo_property(entry.node, "disabled", entry.disabled)
	_finish()
	return {"ok": true, "error": "", "part": part, "collision_disabled": collision.size() if not next.excluded_faces.is_empty() else 0}

func _overrides(mesh: MeshInstance3D) -> Array:
	var values: Array = []
	for surface: int in mesh.mesh.get_surface_count():
		values.append(mesh.get_surface_override_material(surface))
	return values

func _apply_mesh(instance: MeshInstance3D, mesh: Mesh, overrides: Array) -> void:
	instance.mesh = mesh
	for index: int in mesh.get_surface_count():
		instance.set_surface_override_material(index, overrides[index] if index < overrides.size() else null)

func _all_nodes(node: Node) -> Array:
	var nodes: Array = [node]
	for child: Node in node.get_children():
		nodes.append_array(_all_nodes(child))
	return nodes

func apply_binding(part: Node3D, result: Dictionary, donor: Node3D) -> Dictionary:
	var error := _valid_part(part)
	if not error.is_empty():
		return _fail(error)
	if not result.get("ok", false):
		return result
	if not dependents(part).is_empty():
		return _fail("Detach this part's dependent attachments before converting its Model.")
	if not part.get("geometry_masks").is_empty():
		return _fail("Reset this part's mesh exclusions before binding, then reapply them to the bound result.")
	var old: Node = part.get_node_or_null("Model")
	var model: Node = result.get("model")
	if old == null or model == null or model.get_parent() != null:
		return _fail("The binding service did not return a standalone Model.")
	var before := {"binding_data": part.get("binding_data"), "attachment_mode": part.get("attachment_mode"), "target_path": part.get("target_path"), "bone_name": part.get("bone_name")}
	var target: Node = result.get("skeleton", donor)
	var after := {"binding_data": result.get("binding_data"), "attachment_mode": 3, "target_path": part.get_path_to(target), "bone_name": ""}
	_begin("Bind character clothing")
	undo.add_do_method(self, "_swap_model", part, old, model, after)
	undo.add_undo_method(self, "_swap_model", part, model, old, before)
	undo.add_do_reference(model)
	undo.add_undo_reference(old)
	_finish()
	return {"ok": true, "error": "", "part": part}

func _swap_model(part: Node3D, old: Node, model: Node, data: Dictionary) -> void:
	_remove(old)
	part.add_child(model)
	model.name = "Model"
	Ops.ensure_owned(model, scene_root)
	for key: String in data:
		part.set(key, data[key])
