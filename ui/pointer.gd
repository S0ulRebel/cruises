class_name Pointer
extends CanvasLayer
## What is under the cursor, and what clicking it would do.
##
## The difference between a scene and a tech demo. Without this the player clicks
## blind: nothing says a crate is a crate, nothing distinguishes scenery from a thing
## worth trying, and nothing warns that the click will USE the held rapier rather than
## just look at it.
##
## Deliberately a caption rather than a cursor swap. Three verbs with three cursor
## shapes is a thing the player has to learn; a line of text saying "Open the crate
## with the rapier" is a thing they can read. It also costs no art, which matters
## while every piece of art is still being generated.

## Follows the cursor, offset so the text is not under the pointer itself.
const OFFSET := Vector2(18, -34)
## How far the label may sit from the screen edge before it flips to the other side.
const EDGE := 24.0

var _label: Label
var _panel: PanelContainer
var _target := ""
var _verb := ""


func _ready() -> void:
	layer = 11
	_build()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.82)
	style.border_color = Color(0.70, 0.58, 0.36, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 20)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)


## Name what the cursor is over. `verb_text` is the whole phrase, already worked out by
## whoever knows the rules - this only draws it.
func point_at(name: String, verb_text := "") -> void:
	if name == _target and verb_text == _verb:
		return
	_target = name
	_verb = verb_text
	_label.text = verb_text if not verb_text.is_empty() else name
	_panel.visible = not _label.text.is_empty()


func clear() -> void:
	_target = ""
	_verb = ""
	_panel.visible = false


func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	var at := get_viewport().get_mouse_position() + OFFSET
	var size := _panel.size
	var screen := Vector2(get_viewport().get_visible_rect().size)
	# Flip rather than clamp: a label pinned to the edge sits over the thing it is
	# naming, which is the one place it must not be.
	if at.x + size.x > screen.x - EDGE:
		at.x = get_viewport().get_mouse_position().x - size.x - OFFSET.x
	if at.y < EDGE:
		at.y = get_viewport().get_mouse_position().y - OFFSET.y
	_panel.position = at
