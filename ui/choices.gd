extends CanvasLayer
## The list of things the player could say.
##
## Numbered, clickable, and keyboard-driven, because in a conversation-heavy game the
## player is choosing hundreds of times and reaching for the mouse each time is friction
## the jokes have to overcome.

signal picked(index: int)

## Seconds before an unattended run picks the first option. Zero waits for a human.
## With `once` on the content branches, picking the first available each time walks the
## whole conversation and then falls out of the exit - a free coverage check.
@export var auto_pick_secs := 0.0

var _panel: PanelContainer
var _list: VBoxContainer
var _count := 0


func _ready() -> void:
	layer = 11
	_build()


func _build() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# A full-screen Control swallows every mouse event by default, which is how the
	# room ended up ignoring clicks entirely. Only the buttons want the mouse.
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("margin_left", 80)
	root.add_theme_constant_override("margin_right", 80)
	root.add_theme_constant_override("margin_bottom", 60)
	add_child(root)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.88)
	style.border_color = Color(0.70, 0.58, 0.36, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_panel)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_panel.add_child(_list)


## Show the options and wait. Returns the index of the one chosen.
func ask(options: Array) -> int:
	for child in _list.get_children():
		child.queue_free()

	_count = options.size()
	for i in _count:
		var button := Button.new()
		button.text = "%d.  %s" % [i + 1, options[i]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.flat = true
		button.add_theme_font_size_override("font_size", 28)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: picked.emit(i))
		_list.add_child(button)

	_panel.visible = true
	if auto_pick_secs > 0.0:
		get_tree().create_timer(auto_pick_secs).timeout.connect(
			func() -> void:
				if _panel.visible:
					picked.emit(0), CONNECT_ONE_SHOT)
	var chosen: int = await picked
	_panel.visible = false
	return chosen


func dismiss() -> void:
	_panel.visible = false
	_count = 0


func _unhandled_key_input(event: InputEvent) -> void:
	if _count == 0 or not _panel.visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var number := key.keycode - KEY_1
	if number >= 0 and number < _count:
		picked.emit(number)
		get_viewport().set_input_as_handled()
