class_name Portrait
extends Control
## The speaker's face, beside the dialogue box.
##
## This is where the generated talking-head work lands, and the reason it is worth
## having at all: a character 250-390 px tall on screen has a head about 50 px across,
## so nothing an actor does with their face is visible in the room. The portrait is the
## only place a performance can be seen.
##
## Two assets per character, not one per line. A talking LOOP plays for as long as any
## line is on screen and an IDLE still shows between lines; pre-rendering a clip per
## line would be thousands of files, would have to be regenerated every time the writer
## changes a word, and would still only differ from the loop in ways nobody watching a
## 50 px mouth can see.
##
## A character with no art gets a placeholder - their colour, their name, and a mouth
## that opens and closes while they speak. Hiding the panel instead would mean never
## seeing the layout until the art arrives, and the layout is the thing worth judging
## now: whether a 300 px face beside the box leaves enough room for the words.

const DIR := "res://art/portraits"
const TalkingHeadScript := preload("res://ui/talking_head.gd")

@export var panel_size := Vector2(300, 300)

var _frame: PanelContainer
var _still: TextureRect
var _loop: VideoStreamPlayer
var _blank: Control
var _blank_name: Label
var _head: TalkingHead
var _plan: Array = []
var _who := ""
var _colour := Color("#4a4f5a")
var _talking := false
var _mouth := 0.0


func _ready() -> void:
	custom_minimum_size = panel_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	_frame = PanelContainer.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.9)
	style.border_color = Color(0.70, 0.58, 0.36, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6)
	_frame.add_theme_stylebox_override("panel", style)
	_frame.visible = false
	add_child(_frame)

	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(stack)

	_still = TextureRect.new()
	_still.set_anchors_preset(Control.PRESET_FULL_RECT)
	_still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_still)

	_loop = VideoStreamPlayer.new()
	_loop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loop.expand = true
	_loop.loop = true
	_loop.visible = false
	_loop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_loop)

	_blank = Control.new()
	_blank.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blank.draw.connect(_draw_blank)
	stack.add_child(_blank)

	_blank_name = Label.new()
	_blank_name.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_blank_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blank_name.add_theme_font_size_override("font_size", 22)
	_blank_name.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_blank_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blank.add_child(_blank_name)

	# The real thing: the character's own head, rendered live and driven by the text.
	# It sits on top of the placeholder and is only shown for characters who have a
	# head piece, so a character still in the pipeline falls back rather than leaving
	# an empty box.
	_head = TalkingHeadScript.new()
	_head.set_anchors_preset(Control.PRESET_FULL_RECT)
	_head.panel_size = Vector2i(int(panel_size.x) - 12, int(panel_size.y) - 12)
	_head.visible = false
	stack.add_child(_head)


## Show this character, talking. Called when a line appears.
##
## `line` is the dialogue itself, because the LETTERS drive the mouth - see
## ui/speech.gd. Without it the head still appears, it just does not talk.
func speak(character_id: String, display := "", colour := Color(), line := "") -> void:
	if character_id != _who:
		_load(character_id)
	if not display.is_empty():
		_blank_name.text = display
	if colour.a > 0.0:
		_colour = colour
	_talking = true
	_plan = Speech.plan(line, character_id) if _head.visible else []
	if _head.visible:
		_head.apply(Speech.sample(_plan, 0.0), _who)
	if _loop.stream != null:
		_loop.visible = true
		if not _loop.is_playing():
			_loop.play()
	# With no talking clip the still simply stays up, which reads as a portrait rather
	# than as something broken.


## How far through the line the reader is, 0..1.
##
## Driven by the TYPEWRITER rather than by the mouth's own clock, so the two cannot
## drift apart: the mouth stops exactly when the last letter appears, and it stops
## early if the reader skips ahead. Two independent clocks would mean a character
## still chewing after the sentence finished.
func set_progress(fraction: float) -> void:
	if not _talking or _plan.is_empty() or not _head.visible:
		return
	var t: float = clampf(fraction, 0.0, 1.0) * Speech.duration(_plan)
	_head.apply(Speech.sample(_plan, t), _who)


## Stop talking but keep the face up, between lines in the same conversation.
func settle() -> void:
	_talking = false
	_plan = []
	if _head.visible:
		_head.settle(_who)
	if _loop.is_playing():
		_loop.stop()
	_loop.visible = false
	if _blank.visible:
		_blank.queue_redraw()


func dismiss() -> void:
	settle()
	_frame.visible = false
	_who = ""


func _load(character_id: String) -> void:
	_who = character_id
	var still_path := "%s/%s.png" % [DIR, character_id]
	var loop_path := "%s/%s_talk.ogv" % [DIR, character_id]

	_still.texture = load(still_path) if ResourceLoader.exists(still_path) else null
	_loop.stream = load(loop_path) if ResourceLoader.exists(loop_path) else null
	_loop.visible = false

	# A head piece beats everything else. Flat art is the fallback for characters who
	# have not been through the per-piece pipeline yet.
	_head.visible = _head.show_character(character_id)
	var has_art: bool = _head.visible or _still.texture != null or _loop.stream != null
	_still.visible = not _head.visible
	_blank.visible = not has_art
	_blank_name.text = character_id.capitalize()
	_frame.visible = true


func _process(delta: float) -> void:
	if not _blank.visible:
		return
	# A mouth that opens and closes while a line is on screen. Not lip sync - it is a
	# stand-in that makes it obvious at a glance who is speaking and when they stop.
	var wanted := (sin(Time.get_ticks_msec() * 0.011) * 0.5 + 0.5) if _talking else 0.0
	_mouth = lerpf(_mouth, wanted, clampf(delta * 14.0, 0.0, 1.0))
	_blank.queue_redraw()


func _draw_blank() -> void:
	var size := _blank.size
	if size.x < 4.0 or size.y < 4.0:
		return
	_blank.draw_rect(Rect2(Vector2.ZERO, size), _colour.darkened(0.45))

	# A head shape, so the panel reads as a face rather than a coloured square.
	var centre := Vector2(size.x * 0.5, size.y * 0.44)
	var head := minf(size.x, size.y) * 0.30
	_blank.draw_circle(centre, head, _colour)
	_blank.draw_arc(centre, head, 0.0, TAU, 48, _colour.lightened(0.35), 2.0, true)

	var eye := head * 0.13
	_blank.draw_circle(centre + Vector2(-head * 0.34, -head * 0.18), eye, _colour.darkened(0.7))
	_blank.draw_circle(centre + Vector2(head * 0.34, -head * 0.18), eye, _colour.darkened(0.7))

	var mouth_w := head * 0.46
	var mouth_h := head * (0.05 + 0.30 * _mouth)
	_blank.draw_rect(Rect2(centre + Vector2(-mouth_w * 0.5, head * 0.30),
		Vector2(mouth_w, mouth_h)), _colour.darkened(0.7))
