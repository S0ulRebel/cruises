@tool
extends Control
## A camera pane over the actual edited world. Tool cameras never enter the assembly.

signal request(action: String, value: Variant)

const Ops = preload("res://actors/assembly/operations.gd")
const MeshOps = preload("res://actors/assembly/mesh_exclusion/operations.gd")
const AXES := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
const AXIS_COLORS := [Color(0.98, 0.35, 0.35), Color(0.45, 0.9, 0.49), Color(0.36, 0.63, 1.0)]

@export var view_title := "Assembly view"
@export var detail_view := false
@export_enum("Perspective", "Front", "Side", "Top") var initial_preset := "Perspective"

@onready var camera: Camera3D = %Camera
@onready var viewport: SubViewport = %PreviewWorld
@onready var overlay: Control = %Overlay

var scene_root: Node3D
var selected: Node3D
var tool := "move"
var _target := Vector3(0, 0.8, 0)
var _distance := 3.0
var _yaw := 0.42
var _pitch := 0.12
var _ortho_size := 2.4
var _preset := "Perspective"
var _drag: Dictionary = {}
var _hover_axis := -1
var _face_mesh: MeshInstance3D
var _face_source: Mesh
var _faces: Dictionary = {}
var _pending_frame_node: Node3D
var _editor_window: Window
var _has_geometry := false
var _framed_node: Node3D
var _frame_follows_layout := true
var local_axes := false
var snap_enabled := false
var move_step := 0.05
var rotate_step := 15.0
var scale_step := 0.1
var show_grid := true
var show_bounds := false
var attachment_candidate: Node3D
var drop_at_cursor := false
var _drop_preview: Dictionary = {}


func _ready() -> void:
	%ViewTitle.text = view_title
	for name: String in ["Perspective", "Front", "Side", "Top"]:
		%ViewPreset.add_item(name)
	%ViewPreset.item_selected.connect(func(index: int): set_preset(%ViewPreset.get_item_text(index)))
	%FrameAll.pressed.connect(frame_all)
	%FrameSelected.pressed.connect(frame_selected)
	overlay.gui_input.connect(_view_input)
	overlay.draw.connect(_draw_overlay)
	overlay.resized.connect(_resize_surface)
	overlay.mouse_exited.connect(func(): _hover_axis = -1; overlay.queue_redraw())
	overlay.set_drag_forwarding(Callable(), _can_drop_data, _drop_data)
	visibility_changed.connect(_visibility_changed)
	_editor_window = get_window()
	_editor_window.focus_exited.connect(cancel_drag)
	_resize_surface()
	set_preset(initial_preset)
	set_tool(tool)
	set_context(scene_root, selected)
	if is_instance_valid(scene_root) and scene_root.is_inside_tree():
		frame_all()
	set_process(true)


func _exit_tree() -> void:
	cancel_drag()
	if is_instance_valid(_editor_window) and _editor_window.focus_exited.is_connected(cancel_drag):
		_editor_window.focus_exited.disconnect(cancel_drag)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not _drop_preview.is_empty() and not get_viewport().gui_is_dragging():
		_drop_preview.clear()
	if not _drag.is_empty() and not is_instance_valid(_drag.get("part")):
		_drag.clear()
	if is_instance_valid(scene_root) and scene_root.is_inside_tree():
		# The native editor can move a scene to another viewport during tab changes.
		var world: World3D = scene_root.get_world_3d()
		if viewport.world_3d != world:
			viewport.world_3d = world
			camera.make_current()
	overlay.queue_redraw()


func set_context(root: Node3D, part: Node3D) -> void:
	var root_changed := root != scene_root
	var selection_changed := part != selected
	if root_changed or selection_changed:
		cancel_drag()
	if root_changed:
		_pending_frame_node = null
		_framed_node = null
	scene_root = root
	selected = part
	if not is_node_ready():
		return
	var valid := is_instance_valid(root) and root.is_inside_tree()
	var had_geometry := _has_geometry
	_has_geometry = valid and not _meshes(root).is_empty()
	viewport.disable_3d = not valid
	%Empty.visible = not _has_geometry
	%FrameAll.disabled = not valid
	%FrameSelected.disabled = not is_instance_valid(selected)
	if valid:
		viewport.world_3d = root.get_world_3d()
		camera.make_current()
	if valid and (root_changed or (_has_geometry and not had_geometry)):
		frame_all()
	elif selection_changed and detail_view and is_instance_valid(selected):
		frame_selected()
	overlay.queue_redraw()


func set_tool(mode: String) -> void:
	if mode != tool:
		cancel_drag()
	tool = mode if mode in ["move", "rotate", "scale", "attach"] else "move"
	if not is_node_ready():
		return
	%ViewHint.text = "Pick parent · Esc cancels" if tool == "attach" else "W/E/R · F frame · Ctrl snap"
	%ViewHint.tooltip_text = "Right-drag or Alt-left orbits; middle-drag pans; wheel zooms. Home frames all."
	overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if tool == "attach" else Control.CURSOR_ARROW
	overlay.queue_redraw()

func set_fitting_options(local: bool, snapping: bool, move: float, rotation: float, scale: float) -> void:
	if local != local_axes or snapping != snap_enabled or move != move_step or rotation != rotate_step or scale != scale_step:
		cancel_drag()
	local_axes = local
	snap_enabled = snapping
	move_step = maxf(move, 0.000001)
	rotate_step = maxf(rotation, 0.000001)
	scale_step = maxf(scale, 0.000001)


func set_face_selection(mesh: MeshInstance3D, source: Mesh, faces: Dictionary) -> void:
	_face_mesh = mesh
	_face_source = source
	_faces = faces
	if is_node_ready():
		overlay.queue_redraw()


func set_preset(value: String) -> void:
	cancel_drag()
	_preset = value
	match value:
		"Front":
			_yaw = 0.0
			_pitch = 0.0
		"Side":
			_yaw = PI * 0.5
			_pitch = 0.0
		"Top":
			_yaw = 0.0
			_pitch = PI * 0.495
		_:
			_yaw = 0.42
			_pitch = 0.12
	if not is_node_ready():
		return
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE if value == "Perspective" else Camera3D.PROJECTION_ORTHOGONAL
	for index: int in %ViewPreset.item_count:
		if %ViewPreset.get_item_text(index) == value:
			%ViewPreset.select(index)
	_update_camera()


func frame_all() -> void:
	if is_node_ready() and is_instance_valid(scene_root) and scene_root.is_inside_tree():
		_frame(scene_root)


func frame_selected() -> void:
	if is_node_ready() and is_instance_valid(selected) and selected.is_inside_tree():
		_frame(selected)
	else:
		frame_all()


func cancel_drag() -> void:
	if not _drag.is_empty():
		var part: Node3D = _drag.get("part")
		if is_instance_valid(part) and part.is_inside_tree():
			part.global_transform = _drag.before
		_drag.clear()
	if is_node_ready():
		overlay.queue_redraw()


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_drag()
	if is_node_ready():
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
		if is_visible_in_tree() and detail_view and is_instance_valid(scene_root):
			call_deferred("frame_selected")
		elif is_visible_in_tree() and is_instance_valid(_pending_frame_node):
			call_deferred("_finish_pending_frame")


func _resize_surface() -> void:
	# The authored stretched SubViewportContainer keeps render pixels/input 1:1.
	if _frame_follows_layout and is_instance_valid(_framed_node):
		_pending_frame_node = _framed_node
	if is_instance_valid(_pending_frame_node):
		call_deferred("_finish_pending_frame")
	overlay.queue_redraw()


func _finish_pending_frame() -> void:
	if is_instance_valid(_pending_frame_node) and _pending_frame_node.is_inside_tree() and overlay.size.x >= 4.0 and overlay.size.y >= 4.0:
		_frame(_pending_frame_node)


func _update_camera() -> void:
	if not is_node_ready():
		return
	var offset := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	camera.position = _target + offset * _distance
	camera.look_at(_target, Vector3.UP)
	camera.size = _ortho_size
	# An extreme far/near ratio makes perspective frustum extraction singular in
	# Compatibility rendering. Scale the clipping planes with this tool camera.
	camera.near = maxf(0.0001, _distance * 0.001)
	camera.far = maxf(10.0, _distance * 30.0)
	overlay.queue_redraw()


func _frame(node: Node3D) -> void:
	cancel_drag()
	if overlay.size.x < 4.0 or overlay.size.y < 4.0:
		_pending_frame_node = node
		call_deferred("_finish_pending_frame")
		return
	_pending_frame_node = null
	_framed_node = node
	_frame_follows_layout = true
	var bounds := _world_bounds(node)
	_target = bounds.get_center()
	var diameter := maxf(bounds.size.length(), 0.25)
	var aspect := maxf(0.2, overlay.size.x / maxf(overlay.size.y, 1.0))
	_ortho_size = maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z) / aspect) * 1.35
	_ortho_size = maxf(_ortho_size, 0.25)
	_distance = diameter * 0.65 / tan(deg_to_rad(camera.fov * 0.5)) / minf(aspect, 1.0)
	_distance = maxf(_distance, 0.25)
	_update_camera()


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if not is_instance_valid(node):
		return result
	if node is MeshInstance3D and node.mesh != null and node.is_visible_in_tree():
		result.append(node)
	for child: Node in node.get_children():
		result.append_array(_meshes(child))
	return result


func _world_bounds(node: Node3D) -> AABB:
	var found := false
	var result := AABB(node.global_position, Vector3.ONE * 0.1)
	for mesh: MeshInstance3D in _meshes(node):
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		result = result.merge(bounds) if found else bounds
		found = true
	return result


func pick_part(position: Vector2) -> Node3D:
	if not is_instance_valid(scene_root):
		return null
	var origin := camera.project_ray_origin(position)
	var direction := camera.project_ray_normal(position)
	var distance := INF
	var result: Node3D
	for mesh: MeshInstance3D in _meshes(scene_root):
		var inverse := mesh.global_transform.affine_inverse()
		var local_origin: Vector3 = inverse * origin
		var local_direction: Vector3 = (inverse.basis * direction).normalized()
		if mesh.get_aabb().intersects_ray(local_origin, local_direction) == null:
			continue
		var hit: Dictionary = MeshOps.ray_face(mesh.mesh, local_origin, local_direction)
		if hit.is_empty():
			continue
		var world: Vector3 = mesh.global_transform * hit.position
		var current := origin.distance_to(world)
		var part: Node3D = Ops.nearest_part(mesh)
		if is_instance_valid(part) and current < distance:
			result = part
			distance = current
	return result


func _view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		overlay.grab_focus()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_frame_follows_layout = false
				var amount := 0.87 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.15
				_distance = clampf(_distance * amount, 0.03, 100000.0)
				_ortho_size = clampf(_ortho_size * amount, 0.01, 100000.0)
				_update_camera()
			overlay.accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and not event.alt_pressed:
			var payload := {"camera": camera, "event": event, "handled": false}
			request.emit("view_input", payload)
			if payload.handled:
				overlay.accept_event()
				return
			if event.pressed:
				_left_press(event.position)
			else:
				_finish_drag()
			overlay.accept_event()
			return
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT or (event.alt_pressed and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			cancel_drag()
			_frame_follows_layout = false
			_yaw -= event.relative.x * 0.008
			_pitch = clampf(_pitch + event.relative.y * 0.008, -PI * 0.495, PI * 0.495)
			_preset = "Perspective"
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			%ViewPreset.select(0)
			_update_camera()
			overlay.accept_event()
		elif event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			cancel_drag()
			_frame_follows_layout = false
			var unit := _world_per_pixel(_target)
			_target += (-camera.global_basis.x * event.relative.x + camera.global_basis.y * event.relative.y) * unit
			_update_camera()
			overlay.accept_event()
		elif not _drag.is_empty():
			_drag_to(event.position, event.ctrl_pressed)
			overlay.accept_event()
		else:
			_hover_axis = _gizmo_hit(event.position)
			if tool == "attach":
				request.emit("hover_attach", pick_part(event.position))
			overlay.queue_redraw()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_command_or_control_pressed() and event.keycode in [KEY_Z, KEY_Y]:
			# Let native Undo/Redo run after the uncommitted drag is restored.
			cancel_drag()
			return
		if event.alt_pressed or (event.is_command_or_control_pressed() and event.keycode != KEY_D):
			# Keep native file/run/navigation shortcuts available to the editor.
			return
		match event.keycode:
			KEY_ESCAPE:
				cancel_drag()
				if tool == "attach":
					request.emit("tool", "move")
			KEY_W, KEY_E, KEY_R:
				if not event.ctrl_pressed and not event.alt_pressed:
					var mode := "move" if event.keycode == KEY_W else ("rotate" if event.keycode == KEY_E else "scale")
					set_tool(mode)
					request.emit("tool", mode)
			KEY_F:
				frame_selected()
			KEY_HOME:
				frame_all()
			KEY_DELETE:
				cancel_drag()
				request.emit("remove", null)
			KEY_D:
				if event.ctrl_pressed:
					cancel_drag()
					request.emit("duplicate", null)
			_:
				return
		overlay.accept_event()


func _left_press(position: Vector2) -> void:
	if not is_instance_valid(scene_root):
		return
	var axis := _gizmo_hit(position)
	if tool == "attach":
		var target := pick_part(position)
		if is_instance_valid(target):
			request.emit("attach_target", target)
		return
	if axis == -1:
		var part := pick_part(position)
		request.emit("select", part)
		# A selection click only selects; fitting starts on its visible handles.
		return
	if not is_instance_valid(selected):
		return
	request.emit("begin_transform", selected)
	_drag = {
		"part": selected,
		"before": selected.global_transform,
		"position": position,
		"axis": axis,
		"mode": tool,
		"world_per_pixel": _world_per_pixel(selected.global_position),
		"gizmo_length": _gizmo_length(),
	}


func _drag_to(position: Vector2, snap: bool) -> void:
	var part: Node3D = _drag.get("part")
	if not is_instance_valid(part):
		_drag.clear()
		return
	var before: Transform3D = _drag.before
	var transform := before
	var delta: Vector2 = position - _drag.position
	var axis: int = _drag.axis
	var world_axis: Vector3 = _transform_axis(before.basis, axis) if axis >= 0 and axis < 3 else Vector3.ZERO
	var screen_axis := Vector2.ZERO
	var ratio: float = _drag.world_per_pixel
	snap = snap or snap_enabled
	if world_axis != Vector3.ZERO:
		if _drag.mode == "scale":
			world_axis = before.basis[axis].normalized()
		var start := camera.unproject_position(before.origin)
		var end := camera.unproject_position(before.origin + world_axis * float(_drag.gizmo_length))
		screen_axis = (end - start).normalized()
		ratio = float(_drag.gizmo_length) / maxf((end - start).length(), 1.0)
	match str(_drag.mode):
		"move":
			if axis == 3:
				var change := (camera.global_basis.x * delta.x - camera.global_basis.y * delta.y) * float(_drag.world_per_pixel)
				if snap:
					change = change.snapped(Vector3.ONE * move_step)
				transform.origin += change
			else:
				var amount := delta.dot(screen_axis) * ratio
				if snap:
					amount = snappedf(amount, move_step)
				transform.origin += world_axis * amount
		"rotate":
			var angle := (delta.x - delta.y) * 0.012
			if snap:
				angle = snappedf(angle, deg_to_rad(rotate_step))
			var rotation_axis := world_axis if axis < 3 else -camera.global_basis.z
			transform.basis = Basis(rotation_axis, angle) * before.basis
		"scale":
			var factor := 1.0 + (delta.x - delta.y) * 0.008 if axis == 3 else 1.0 + delta.dot(screen_axis) * 0.01
			if snap:
				factor = 1.0 + snappedf(factor - 1.0, scale_step)
			factor = maxf(factor, 0.05)
			if axis == 3:
				transform.basis = before.basis.scaled_local(Vector3.ONE * factor)
			else:
				transform.basis[axis] = before.basis[axis] * factor
	if Ops.validate_transform(transform).is_empty():
		part.global_transform = transform
	overlay.queue_redraw()


func _finish_drag() -> void:
	if _drag.is_empty():
		return
	var part: Node3D = _drag.get("part")
	if not is_instance_valid(part) or not part.is_inside_tree():
		_drag.clear()
		return
	var before: Transform3D = _drag.before
	var after := part.global_transform
	part.global_transform = before
	_drag.clear()
	if not before.is_equal_approx(after):
		request.emit("transform", {"part": part, "before": before, "after": after})
	overlay.queue_redraw()


func _world_per_pixel(point: Vector3) -> float:
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return camera.size / maxf(overlay.size.y, 1.0)
	var depth := maxf(0.01, (point - camera.global_position).dot(-camera.global_basis.z))
	return 2.0 * depth * tan(deg_to_rad(camera.fov * 0.5)) / maxf(overlay.size.y, 1.0)


func _gizmo_length() -> float:
	return _world_per_pixel(selected.global_position) * 68.0 if is_instance_valid(selected) else 0.1


func _gizmo_axis(index: int) -> Vector3:
	return _transform_axis(selected.global_basis, index)

func _transform_axis(basis: Basis, index: int) -> Vector3:
	return basis[index].normalized() if tool == "scale" or local_axes else AXES[index]


func _gizmo_hit(position: Vector2) -> int:
	if not is_instance_valid(selected) or not selected.is_inside_tree() or tool == "attach" or camera.is_position_behind(selected.global_position):
		return -1
	var center := camera.unproject_position(selected.global_position)
	if center.distance_to(position) < 10.0:
		return 3
	var nearest := 10.0
	var result := -1
	var length := _gizmo_length()
	for index: int in 3:
		var lines: PackedVector2Array = _ring(index, length) if tool == "rotate" else PackedVector2Array([center, camera.unproject_position(selected.global_position + _gizmo_axis(index) * length)])
		for point: int in lines.size() - 1:
			if lines[point].distance_to(lines[point + 1]) < 1.0:
				continue
			var near := Geometry2D.get_closest_point_to_segment(position, lines[point], lines[point + 1])
			var distance := near.distance_to(position)
			if distance < nearest:
				nearest = distance
				result = index
	return result


func _ring(index: int, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var first: Vector3 = _gizmo_axis((index + 1) % 3)
	var second: Vector3 = _gizmo_axis((index + 2) % 3)
	for step: int in 49:
		var angle := TAU * float(step) / 48.0
		var point := selected.global_position + (first * cos(angle) + second * sin(angle)) * radius
		result.append(camera.unproject_position(point))
	return result


func _draw_overlay() -> void:
	if not is_instance_valid(scene_root) or not scene_root.is_inside_tree():
		return
	if show_grid:
		_draw_grid()
	_draw_face_selection()
	_draw_drop_preview()
	if tool == "attach" and is_instance_valid(attachment_candidate):
		_draw_bounds(_world_bounds(attachment_candidate), Color(0.35, 0.85, 0.6, 0.65))
	if not is_instance_valid(selected) or not selected.is_inside_tree():
		return
	if show_bounds:
		_draw_bounds(_world_bounds(selected), Color(1.0, 0.78, 0.28, 0.25))
	else:
		_draw_selection_corners(_world_bounds(selected))
	if camera.is_position_behind(selected.global_position) or tool == "attach":
		return
	var center := camera.unproject_position(selected.global_position)
	var length := _gizmo_length()
	var font: Font = get_theme_default_font()
	for index: int in 3:
		var color: Color = AXIS_COLORS[index]
		var width := 4.0 if _hover_axis == index or _drag.get("axis", -1) == index else 2.5
		if tool == "rotate":
			overlay.draw_polyline(_ring(index, length), color, width, true)
		else:
			var end := camera.unproject_position(selected.global_position + _gizmo_axis(index) * length)
			overlay.draw_line(center, end, color, width, true)
			if tool == "scale":
				overlay.draw_rect(Rect2(end - Vector2.ONE * 4.0, Vector2.ONE * 8.0), color)
			else:
				var direction := (end - center).normalized()
				var side := Vector2(-direction.y, direction.x)
				overlay.draw_colored_polygon(PackedVector2Array([end, end - direction * 11.0 + side * 5.0, end - direction * 11.0 - side * 5.0]), color)
			overlay.draw_string(font, end + Vector2(5.0, -5.0), "XYZ"[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
	overlay.draw_circle(center, 6.0, Color(1.0, 0.82, 0.3))
	overlay.draw_circle(center, 8.0, Color(0.1, 0.12, 0.15), false, 2.0, true)


func _draw_grid() -> void:
	# Camera-local overlay only: no mesh, light, plane or grid enters the scene world.
	var step := pow(10.0, floor(log(maxf(_distance, 0.01)) / log(10.0))) * 0.1
	var center := Vector3(snappedf(_target.x, step), 0.0, snappedf(_target.z, step))
	for index: int in range(-10, 11):
		var color := Color(0.5, 0.58, 0.68, 0.11)
		_draw_world_line(center + Vector3(index * step, 0.0, -10.0 * step), center + Vector3(index * step, 0.0, 10.0 * step), color, 1.0)
		_draw_world_line(center + Vector3(-10.0 * step, 0.0, index * step), center + Vector3(10.0 * step, 0.0, index * step), color, 1.0)


func _draw_bounds(bounds: AABB, color := Color(1.0, 0.78, 0.28, 0.25)) -> void:
	var corners: Array[Vector3] = []
	for index: int in 8:
		corners.append(bounds.get_endpoint(index))
	for edge: Array in [[0, 1], [0, 2], [0, 4], [1, 3], [1, 5], [2, 3], [2, 6], [3, 7], [4, 5], [4, 6], [5, 7], [6, 7]]:
		_draw_world_line(corners[edge[0]], corners[edge[1]], color, 1.0)

func _draw_selection_corners(bounds: AABB) -> void:
	var rect := Rect2()
	var found := false
	for index: int in 8:
		var point := bounds.get_endpoint(index)
		if camera.is_position_behind(point):
			continue
		var screen := camera.unproject_position(point)
		rect = rect.expand(screen) if found else Rect2(screen, Vector2.ZERO)
		found = true
	if not found:
		return
	var length := minf(12.0, minf(rect.size.x, rect.size.y) * 0.2)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var inward := (rect.get_center() - corner).sign()
		overlay.draw_line(corner, corner + Vector2(inward.x * length, 0), Color(1.0, 0.78, 0.28, 0.65), 1.2)
		overlay.draw_line(corner, corner + Vector2(0, inward.y * length), Color(1.0, 0.78, 0.28, 0.65), 1.2)


func _draw_world_line(a: Vector3, b: Vector3, color: Color, width: float) -> void:
	if camera.is_position_behind(a) or camera.is_position_behind(b):
		return
	overlay.draw_line(camera.unproject_position(a), camera.unproject_position(b), color, width, true)


func _draw_face_selection() -> void:
	if not is_instance_valid(_face_mesh) or not _face_mesh.is_inside_tree() or _face_source == null or _faces.is_empty():
		return
	var drawn := 0
	for surface: Variant in _faces:
		if int(surface) < 0 or int(surface) >= _face_source.get_surface_count():
			continue
		var arrays: Array = _face_source.surface_get_arrays(int(surface))
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		for face: int in _faces[surface]:
			if drawn >= 6000:
				return
			var points := PackedVector2Array()
			for corner: int in 3:
				var index := face * 3 + corner
				if indices != null and not indices.is_empty():
					if index >= indices.size():
						break
					index = indices[index]
				if index >= vertices.size():
					break
				var point: Vector3 = _face_mesh.global_transform * vertices[index]
				if camera.is_position_behind(point):
					break
				points.append(camera.unproject_position(point))
			if points.size() == 3:
				overlay.draw_colored_polygon(points, Color(1.0, 0.5, 0.1, 0.28))
				points.append(points[0])
				overlay.draw_polyline(points, Color(1.0, 0.6, 0.1, 0.9), 1.0, true)
				drawn += 1


func placement_point(position: Vector2) -> Variant:
	if not is_instance_valid(scene_root):
		return null
	var origin := camera.project_ray_origin(position)
	var direction := camera.project_ray_normal(position)
	var anchor := selected.global_position if is_instance_valid(selected) else scene_root.global_position
	var plane := Plane(Vector3.UP, anchor.y)
	# Front/side rays can be parallel to the horizontal plane; use a screen
	# plane through the selection instead so orthographic fitting still works.
	if absf(direction.dot(Vector3.UP)) < 0.0001:
		plane = Plane(-camera.global_basis.z, anchor)
	return plane.intersects_ray(origin, direction)

func _can_drop_data(position: Vector2, data: Variant) -> bool:
	_drop_preview.clear()
	if not is_instance_valid(scene_root) or not data is Dictionary or data.get("type", "") != "files" or data.get("files", []).is_empty():
		return false
	for path: String in data.files:
		if path.get_extension().to_lower() not in ["tscn", "scn", "glb", "gltf", "fbx", "blend", "dae"] or not ResourceLoader.exists(path, "PackedScene"):
			return false
	var point: Variant = placement_point(position) if drop_at_cursor else null
	if drop_at_cursor and (not point is Vector3 or not point.is_finite()):
		return false
	_drop_preview = {"screen": position, "point": point, "caption": str(data.files[0]).get_file()}
	overlay.queue_redraw()
	return true


func _drop_data(position: Vector2, data: Variant) -> void:
	cancel_drag()
	if not _can_drop_data(position, data):
		return
	var point: Variant = _drop_preview.point
	_drop_preview.clear()
	request.emit("drop_assets", {"paths": data.files, "root": scene_root, "world_position": point})

func _draw_drop_preview() -> void:
	if _drop_preview.is_empty():
		return
	var screen: Vector2 = _drop_preview.screen
	var color := Color(0.45, 0.9, 0.65, 0.8)
	overlay.draw_circle(screen, 9.0, color, false, 1.5)
	overlay.draw_line(screen - Vector2(14, 0), screen + Vector2(14, 0), color, 1.2)
	overlay.draw_line(screen - Vector2(0, 14), screen + Vector2(0, 14), color, 1.2)
	var caption: String = _drop_preview.caption + (" · cursor position" if _drop_preview.point is Vector3 else " · authored position")
	overlay.draw_string(get_theme_default_font(), screen + Vector2(16, -12), caption, HORIZONTAL_ALIGNMENT_LEFT, 320, 12, color)
