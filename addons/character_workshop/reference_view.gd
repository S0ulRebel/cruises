@tool
extends VBoxContainer
## A 2D reference, independent of the assembly world and its saved nodes.

signal add_paths(paths: Array)
signal browse_requested
var texture: Texture2D
var image_path := ""
var zoom := 1.0
var center := Vector2(0.5, 0.5)
var _dragging := false
@onready var surface: Control = %ImageSurface

func _ready() -> void:
	%FitReference.pressed.connect(fit)
	%BrowseReference.pressed.connect(func(): browse_requested.emit())
	surface.draw.connect(_draw_image)
	surface.gui_input.connect(_input_image)
	surface.resized.connect(surface.queue_redraw)
	surface.set_drag_forwarding(Callable(), _can_drop, _drop)
	visibility_changed.connect(func(): _dragging = false)

func set_image(path: String) -> void:
	if path == image_path and (path.is_empty() or (texture != null and FileAccess.file_exists(path))):
		return
	image_path = path
	texture = null
	var error := OK
	if not path.is_empty():
		var image := Image.new()
		error = image.load(ProjectSettings.globalize_path(path)) if FileAccess.file_exists(path) else ERR_FILE_NOT_FOUND
		if error == OK:
			texture = ImageTexture.create_from_image(image)
	%ReferenceName.text = path.get_file() if not path.is_empty() else "Character reference"
	%ReferenceName.tooltip_text = path
	%ReferenceEmpty.text = "Add a reference image to compare\nwhile assembling your character." if path.is_empty() else "Reference unavailable:\n" + path.get_file() + "\nLocate it again with Add images."
	%ReferenceEmpty.visible = texture == null
	%BrowseReference.visible = texture == null
	%FitReference.disabled = texture == null
	fit()

func image_rect() -> Rect2:
	if texture == null:
		return Rect2()
	var dimensions := Vector2(texture.get_size())
	var fit_scale := minf(surface.size.x / dimensions.x, surface.size.y / dimensions.y)
	var displayed := dimensions * fit_scale * zoom
	return Rect2(surface.size * 0.5 - displayed * center, displayed)

func fit() -> void:
	zoom = 1.0
	center = Vector2(0.5, 0.5)
	if is_instance_valid(surface):
		surface.queue_redraw()

func zoom_at(factor: float, point: Vector2) -> void:
	var previous := image_rect()
	if previous.size.x <= 0 or previous.size.y <= 0:
		return
	var coordinate := (point - previous.position) / previous.size
	zoom = clampf(zoom * factor, 0.1, 30.0)
	var next := image_rect()
	center = coordinate + (surface.size * 0.5 - point) / next.size
	surface.queue_redraw()

func pan(delta: Vector2) -> void:
	var rect := image_rect()
	if rect.size.x > 0 and rect.size.y > 0:
		center -= delta / rect.size
		surface.queue_redraw()

func _draw_image() -> void:
	if texture != null:
		surface.draw_texture_rect(texture, image_rect(), false)

func _input_image(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			_dragging = event.pressed
			surface.grab_focus()
			surface.accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_at(1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15, event.position)
			surface.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		pan(event.relative)
		surface.accept_event()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F, KEY_HOME]:
		fit()
		surface.accept_event()

func _can_drop(_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or data.get("type") != "files":
		return false
	var files: Variant = data.get("files")
	return (files is Array or files is PackedStringArray) and not files.is_empty() and Array(files).all(func(path): return str(path).get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"])

func _drop(_position: Vector2, data: Variant) -> void:
	add_paths.emit(Array(data.files))
