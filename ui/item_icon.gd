class_name ItemIcon
extends RefCounted
## Turns an item's 3D model into a flat icon for the inventory.
##
## Rendered rather than drawn, for the same reason the dialogue portrait is: the model
## already exists and an icon drawn by hand is a second asset that has to be kept in
## step with it. A prop that gets regenerated gets a new icon for free.
##
## Rendered ONCE per item and cached. An inventory is open for seconds at a time and
## the contents do not move, so a live viewport per slot would be pure waste.
##
## Falls back to null for an item with no model, and the inventory draws a lettered
## tile instead - so an item invented by a puzzle before its art exists still works.

const MODEL_PATH := "res://art/props/%s/%s.glb"
const SIZE := 128

static var _cache: Dictionary = {}


## The icon for an item, or null if it has no model yet. `tree` is any node, used to
## host the off-screen viewport for the one frame it takes to draw.
static func of(item_id: String, host: Node) -> Texture2D:
	if _cache.has(item_id):
		return _cache[item_id]
	var path := MODEL_PATH % [item_id, item_id]
	if not ResourceLoader.exists(path):
		_cache[item_id] = null
		return null
	var texture := await _render(path, host)
	_cache[item_id] = texture
	return texture


static func _render(path: String, host: Node) -> Texture2D:
	var scene := load(path) as PackedScene
	if scene == null:
		return null

	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	# Its own world, or the item appears in the room as well - see ui/talking_head.gd,
	# where exactly that put a severed head on the floor.
	viewport.own_world_3d = true
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	host.add_child(viewport)

	var model := scene.instantiate() as Node3D
	viewport.add_child(model)

	# Lit, not unshaded: an icon is read as a shape before it is read as a thing, and
	# flat albedo on a flat background has no shape at all.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 1.6
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -130, 0)
	fill.light_energy = 0.6
	viewport.add_child(fill)

	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.current = true
	viewport.add_child(camera)

	await host.get_tree().process_frame
	var bounds := _bounds_of(model)
	if bounds.size == Vector3.ZERO:
		viewport.queue_free()
		return null
	# Three-quarter view from slightly above, which reads as an object rather than as
	# a silhouette. Distance from the model's own size, so a desk and an inkwell both
	# fill the tile.
	var reach: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var distance: float = reach / tan(deg_to_rad(camera.fov * 0.5)) * 0.72
	var direction := Vector3(0.75, 0.55, 1.0).normalized()
	camera.global_position = bounds.get_center() + direction * distance
	camera.look_at(bounds.get_center())

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return ImageTexture.create_from_image(image)


static func _bounds_of(root: Node) -> AABB:
	var out := AABB()
	var first := true
	for node in root.find_children("*", "VisualInstance3D", true, false):
		var vis := node as VisualInstance3D
		var box := vis.global_transform * vis.get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out
