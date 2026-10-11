class_name ItemIcon
extends RefCounted
## Variable icon content uses an authored rendering rig and an explicit definition.
const RIG := preload("res://ui/icon_renderer/icon_renderer.tscn")
static var _cache: Dictionary = {}

static func of(item_id: String, host: Node, definition: ItemDefinition = null) -> Texture2D:
	if definition == null or definition.model_scene == null or DisplayServer.get_name() == "headless":
		return null
	var key := item_id + ":" + definition.model_scene.resource_path
	if _cache.has(key):
		return _cache[key]
	var rig := RIG.instantiate()
	host.add_child(rig)
	var texture: Texture2D = await rig.render(definition.model_scene)
	rig.queue_free()
	_cache[key] = texture
	return texture
