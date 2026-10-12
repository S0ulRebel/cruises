@tool
extends RefCounted
## Cruises-specific integration. Not included in the portable plugin folder.
const PortraitRig = preload("res://ui/portraits/portrait_rig.gd")
const Export = preload("actor_export_service.gd")
const Legacy = preload("legacy_outfit_service.gd")

func can_edit(root: Node) -> bool:
	return root is PortraitRig or (root is CharacterBody3D and root.get_node_or_null("Body") is CWAssembly)

func handles(object: Object) -> bool:
	return object is PortraitRig

func protected_root(root: Node) -> bool:
	return root is PortraitRig

func protected_destination(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var scene: PackedScene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	if scene == null:
		return false
	var state := scene.get_state()
	if state.get_node_count() == 0:
		return false
	for index in state.get_node_property_count(0):
		if state.get_node_property_name(0, index) != &"script":
			continue
		var script: Script = state.get_node_property_value(0, index)
		while script != null:
			if script.resource_path == "res://ui/portraits/portrait_rig.gd":
				return true
			script = script.get_base_script()
	return false

func export_actor(root: Node3D, output: String) -> Dictionary:
	return CWAssemblyOperations.save_scene(root, output) if root is CharacterBody3D else Export.export_actor(root, output)

func prepare_legacy(root: Node3D, source: String) -> Dictionary:
	return Legacy.prepare(root, source)
