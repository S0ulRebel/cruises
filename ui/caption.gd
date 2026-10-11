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

var _box: NinePatchRect
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

	_build_box(column)


## The speech frame: one piece of art holding the portrait AND the words.
##
## The frame was two panels side by side until the art arrived. It is one, so the
## portrait lives INSIDE it, on the parchment, with the text beside it - which is also
## why the text is ink rather than white.
##
## Nine-sliced, so it stretches to any width without the rope or the brass corners
## distorting. FRAME_BORDER is the painted border measured off the art rather than
## guessed; the patch margin is larger than it because the corner bosses overhang.
## The bar cut out of the art session's production master by
## tools/trim_dialogue_frame.py. Derived rather than referenced: NinePatchRect
## ignores both region_rect and an AtlasTexture region and nine-slices the WHOLE
## source, which drew the top rail squashed and the bar 185 px tall instead of 330.
const FRAME := "res://art/ui/dialogue_frame_bar.png"
## The painted border, measured off the art itself: the parchment runs y 39..345 of
## 387, so 43 px of rope and wood at the widest edge.
const FRAME_BORDER := 43.0
## How much of each edge the nine-slice keeps un-stretched. Bigger than the border
## because the brass corner pieces reach further in than the rope does.
const FRAME_PATCH := 96
## How tall the bar is drawn. The art is 5.4:1, and at the width the margins leave on
## a 1920 screen that is what it comes to; much taller and the rope stretches.
const BAR_HEIGHT := 330.0

func _build_box(column: VBoxContainer) -> void:
	_box = NinePatchRect.new()
	_box.texture = load(FRAME) if ResourceLoader.exists(FRAME) else null
	_box.patch_margin_left = FRAME_PATCH
	_box.patch_margin_right = FRAME_PATCH
	_box.patch_margin_top = FRAME_PATCH
	_box.patch_margin_bottom = FRAME_PATCH
	_box.visible = false
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Hold the art's own proportions: the frame is 5.4 times as wide as it is tall and
	# a bar stretched taller than that stops reading as one piece of wood.
	_box.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	column.add_child(_box)

	# Inset to the parchment, in the frame's own pixels scaled to however wide the bar
	# ends up. A fixed inset would float off the parchment the moment the window
	# changed size.
	var inset := MarginContainer.new()
	inset.set_anchors_preset(Control.PRESET_FULL_RECT)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := int(FRAME_BORDER + 10.0)
	inset.add_theme_constant_override("margin_left", pad)
	inset.add_theme_constant_override("margin_right", pad)
	inset.add_theme_constant_override("margin_top", pad)
	inset.add_theme_constant_override("margin_bottom", pad)
	_box.add_child(inset)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(row)

	# Sized to the parchment, not guessed: the bar is BAR_HEIGHT tall, the nine-slice
	# draws FRAME_BORDER of painted wood at 1:1 top and bottom, and the inset adds its
	# own padding. What is left is all the height the portrait may have, and anything
	# larger pushes the head down over the rope.
	_portrait = Portrait.new()
	_portrait.name = "Portrait"
	var face: float = BAR_HEIGHT - 2.0 * float(pad)
	_portrait.panel_size = Vector2(face, face)
	_portrait.framed = false
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_portrait)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(inner)

	_speaker_label = Label.new()
	# Ink on parchment, not gold on black. The frame changed what reads.
	_speaker_label.add_theme_color_override("font_color", Color("#6d3b1c"))
	_speaker_label.add_theme_font_size_override("font_size", 26)
	inner.add_child(_speaker_label)

	_line_label = RichTextLabel.new()
	_line_label.bbcode_enabled = false
	_line_label.fit_content = true
	_line_label.scroll_active = false
	_line_label.custom_minimum_size = Vector2(0, 96)
	_line_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_line_label.add_theme_font_size_override("normal_font_size", 30)
	_line_label.add_theme_color_override("default_color", Color("#2e2015"))
	_line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_line_label)


func say(speaker: String, text: String, character_id := "", colour := Color()) -> void:
	_box.visible = true
	if _portrait and not character_id.is_empty():
		_portrait.speak(character_id, speaker, colour, text)
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


## Whether a line is on screen AND its speaker has a rendered head rather than the
## placeholder. For the screenshot runs, so they photograph the thing they are for.
func speaking_with_portrait() -> bool:
	if _box == null or not _box.visible or _portrait == null:
		return false
	var head: Node = _portrait.get("_head")
	return head != null and head.visible


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
		# The mouth follows the letters appearing, not a clock of its own.
		if _portrait:
			_portrait.set_progress(_revealed / maxf(1.0, float(_full_line.length())))
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
