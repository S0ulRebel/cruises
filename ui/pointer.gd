class_name Pointer
extends CanvasLayer
## Cursor caption; its appearance is authored in pointer.tscn.
@export var cursor_offset := Vector2(18, -34)
@export var edge_margin := 24.0
@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = $Panel/Label
var _target := ""
var _verb := ""

func point_at(target_name: String, verb_text := "") -> void:
	_target = target_name
	_verb = verb_text
	_label.text = verb_text if not verb_text.is_empty() else target_name
	_panel.visible = not _label.text.is_empty()

func clear() -> void:
	_target = ""
	_verb = ""
	_panel.hide()

func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	var mouse := get_viewport().get_mouse_position()
	var at := mouse + cursor_offset
	var screen := get_viewport().get_visible_rect().size
	if at.x + _panel.size.x > screen.x - edge_margin:
		at.x = mouse.x - _panel.size.x - cursor_offset.x
	if at.y < edge_margin:
		at.y = mouse.y - cursor_offset.y
	_panel.position = at
