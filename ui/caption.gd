extends CanvasLayer
## The words on screen: spoken lines, and the stage directions around them.
##
## Two registers, drawn differently on purpose. A SAY is someone talking and gets the
## box, the name and the typewriter reveal. An ACTION is the screenplay describing what
## the picture should show - it appears in italics at the top and goes away on its own.
##
## The actions are here because the picture cannot show them yet. When there is real art
## they stop being necessary and can be switched off in one place, without the screenplay
## or the cutscene knowing anything changed.

signal advanced  ## The reader pressed on. The cutscene waits for this between lines.

const Portrait := preload("res://ui/portrait.gd")

const REVEAL_CPS := 42.0  ## Characters per second. Slow enough to read, fast enough not to nag.

@export var show_actions := true
## Seconds to hold a finished line before moving on by itself. Zero waits for a keypress.
## Non-zero is how the scene gets watched end to end - in a headless check, or by someone
## judging whether the timing of the jokes works without their hand on the space bar.
@export var auto_advance_secs := 0.0

var _box: PanelContainer
var _speaker_label: Label
var _line_label: RichTextLabel
var _action_label: Label

var _full_line := ""
var _revealed := 0.0
var _awaiting := false
var _portrait: Portrait


func _ready() -> void:
	layer = 10
	_build()


func _build() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# A full-screen Control swallows every mouse event by default, which is how the
	# room ended up ignoring clicks entirely. Only the buttons want the mouse.
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("margin_left", 80)
	root.add_theme_constant_override("margin_right", 80)
	root.add_theme_constant_override("margin_top", 50)
	root.add_theme_constant_override("margin_bottom", 60)
	add_child(root)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 18)
	root.add_child(column)

	_action_label = Label.new()
	_action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.62))
	_action_label.add_theme_font_size_override("font_size", 24)
	_action_label.visible = false
	_action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_action_label)

	# A spacer that eats the middle, so the dialogue box sits at the bottom and the
	# action caption at the top without either being anchored by hand.
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	# The portrait sits beside the box, not above it, so a tall face does not push the
	# words off the bottom of the screen.
	var speech_row := HBoxContainer.new()
	speech_row.add_theme_constant_override("separation", 14)
	speech_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(speech_row)

	_portrait = Portrait.new()
	_portrait.name = "Portrait"
	speech_row.add_child(_portrait)

	_box = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.88)
	style.border_color = Color(0.70, 0.58, 0.36, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(26)
	_box.add_theme_stylebox_override("panel", style)
	_box.visible = false
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speech_row.add_child(_box)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	_box.add_child(inner)

	_speaker_label = Label.new()
	_speaker_label.add_theme_color_override("font_color", Color(0.93, 0.78, 0.45))
	_speaker_label.add_theme_font_size_override("font_size", 26)
	inner.add_child(_speaker_label)

	_line_label = RichTextLabel.new()
	_line_label.bbcode_enabled = false
	_line_label.fit_content = true
	_line_label.scroll_active = false
	_line_label.custom_minimum_size = Vector2(0, 96)
	_line_label.add_theme_font_size_override("normal_font_size", 30)
	_line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_line_label)


func say(speaker: String, text: String, character_id := "", colour := Color()) -> void:
	_box.visible = true
	if _portrait and not character_id.is_empty():
		_portrait.speak(character_id, speaker, colour)
	_speaker_label.text = speaker
	_full_line = text
	_revealed = 0.0
	_line_label.text = ""
	_awaiting = true


func action(text: String) -> void:
	if not show_actions:
		return
	_action_label.text = text
	_action_label.visible = true


func clear_action() -> void:
	_action_label.visible = false


func hide_box() -> void:
	_box.visible = false
	if _portrait:
		_portrait.dismiss()


var _settled := 0.0


func _process(delta: float) -> void:
	if not _awaiting:
		return
	if _revealed < float(_full_line.length()):
		_revealed = min(_revealed + REVEAL_CPS * delta, float(_full_line.length()))
		_line_label.text = _full_line.substr(0, int(_revealed))
		_settled = 0.0
		return

	if auto_advance_secs > 0.0:
		_settled += delta
		if _settled >= auto_advance_secs:
			_awaiting = false
			advanced.emit()


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed)
	if not pressed or not _awaiting:
		return

	# First press finishes the reveal, second moves on. Reading speed differs between
	# people far more than any single characters-per-second setting can allow for.
	if _revealed < float(_full_line.length()):
		_revealed = float(_full_line.length())
		_line_label.text = _full_line
	else:
		_awaiting = false
		if _portrait:
			_portrait.settle()
		advanced.emit()
	get_viewport().set_input_as_handled()
