@tool
extends RefCounted
## Explicit Save/Save As authoring only. No scene construction or startup writes.

const Ops = preload("res://addons/character_workshop/core/assembly_operations.gd")
var _seen: Dictionary = {}
var _meshes: Array[Dictionary] = []

func store(root: Node, scene_path: String) -> Dictionary:
	if not is_instance_valid(root) or scene_path.is_empty() or scene_path.get_extension().to_lower() != "tscn":
		return {"ok": false, "error": "Choose an explicit .tscn destination for mesh storage."}
	_seen.clear()
	_meshes.clear()
	_collect_nodes(root, root)
	if _meshes.is_empty():
		return {"ok": true, "directory": "", "count": 0}
	var directory := scene_path.get_basename().path_join("meshes")
	var owned := _owned_paths(scene_path)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		return {"ok": false, "error": "Cannot create mesh output folder: " + directory}
	for entry in _meshes:
		var destination := directory.path_join(entry.name + ".res")
		if FileAccess.file_exists(destination) and not owned.has(ProjectSettings.globalize_path(destination).simplify_path()):
			return {"ok": false, "error": "Refusing to overwrite a mesh not referenced by this saved scene. Choose another scene path: " + destination}
	# Children (including shadow/source meshes) come first so binary parents
	# reference their explicit files instead of duplicating that geometry inline.
	for entry in _meshes:
		var mesh: Mesh = entry.mesh
		var destination := directory.path_join(entry.name + ".res")
		var error := ResourceSaver.save(mesh, destination, ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_CHANGE_PATH)
		if error != OK:
			return {"ok": false, "error": "Could not save mesh to %s: %s" % [destination, error_string(error)]}
		# FLAG_CHANGE_PATH is temporary inside ResourceSaver; retain the explicit
		# authoring path on this independent live resource for the native scene save.
		mesh.take_over_path(destination)
	return {"ok": true, "directory": directory, "count": _meshes.size()}

func _owned_paths(scene_path: String) -> Dictionary:
	var result: Dictionary = {}
	var pending: Array[String] = []
	if FileAccess.file_exists(scene_path):
		pending.append(scene_path)
	var visited: Dictionary = {}
	while not pending.is_empty():
		var source: String = pending.pop_back()
		if visited.has(source):
			continue
		visited[source] = true
		for dependency in ResourceLoader.get_dependencies(source):
			var path: String = dependency.split("::")[-1]
			if path.begins_with("uid://"):
				var uid := ResourceUID.text_to_id(path)
				path = ResourceUID.get_id_path(uid) if ResourceUID.has_id(uid) else ""
			if path.is_empty():
				continue
			result[ProjectSettings.globalize_path(path).simplify_path()] = true
			if path.get_extension() in ["tscn", "tres", "res"] and FileAccess.file_exists(path):
				pending.append(path)
	return result

func _collect_nodes(node: Node, root: Node) -> void:
	var part := Ops.nearest_part(node)
	var identity := part.part_id if part != null else str(root.get_path_to(node))
	var relative := str(part.get_path_to(node)) if part != null else str(root.get_path_to(node))
	for property: Dictionary in node.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name not in [&"script", &"owner"]:
			_collect_value(node.get(property.name), identity, relative + "/" + str(property.name))
	for child in node.get_children():
		_collect_nodes(child, root)

func _collect_value(value: Variant, identity: String, route: String) -> void:
	if value is Resource:
		if value is Script or value is PackedScene or value is Texture:
			return
		var resource: Resource = value
		var id := resource.get_instance_id()
		if _seen.has(id):
			return
		_seen[id] = true
		for property: Dictionary in resource.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name not in [&"script", &"resource_path"]:
				_collect_value(resource.get(property.name), identity, route + "/" + str(property.name))
		if resource is Mesh:
			var name := identity.validate_filename().to_snake_case().left(40) + "_" + route.sha256_text().left(12)
			_meshes.append({"mesh": resource, "name": name})
	elif value is Array:
		for index in value.size():
			_collect_value(value[index], identity, route + "/" + str(index))
	elif value is Dictionary:
		for key in value:
			_collect_value(value[key], identity, route + "/" + str(key))
