extends Node
## Only changing item content is instanced; lights, camera and viewport are authored.
@export var frame_contents := true
@export var view_direction := Vector3(0.75, 0.55, 1.0)
@onready var viewport: SubViewport = $Viewport
@onready var content: Node3D = $Viewport/Content
@onready var camera: Camera3D = $Viewport/Camera

func render(scene: PackedScene) -> Texture2D:
	var model := scene.instantiate() as Node3D
	if model == null:
		return null
	content.add_child(model)
	await get_tree().process_frame
	var bounds := AABB()
	var first := true
	for node in content.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		var box := visual.global_transform * visual.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first:
		return null
	if frame_contents:
		var reach := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		var distance := reach / tan(deg_to_rad(camera.fov * 0.5)) * 0.72
		camera.global_position = bounds.get_center() + view_direction.normalized() * distance
		camera.look_at(bounds.get_center())
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var texture := ImageTexture.create_from_image(viewport.get_texture().get_image())
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return texture
