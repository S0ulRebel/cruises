extends Button
@onready var _label: Label = $Label
@onready var _highlight: TextureRect = $Highlight
@onready var _chevron: TextureRect = $Chevron

func _ready() -> void:
	focus_entered.connect(_update_focus)
	focus_exited.connect(_update_focus)
	mouse_entered.connect(_update_focus)
	mouse_exited.connect(_update_focus)
	resized.connect(_fit_height)
	_update_focus()

func configure(index: int, response: String) -> void:
	_label.text = "%d.  %s" % [index + 1, response]
	_fit_height.call_deferred()

func _fit_height() -> void:
	if is_instance_valid(_label):
		custom_minimum_size.y = maxf(44.0, _label.get_line_count() * 36.0 + 8.0)

func _update_focus() -> void:
	var active := has_focus() or is_hovered()
	_highlight.visible = active
	_chevron.visible = has_focus()
	_label.modulate = Color("#fff0ca") if active else Color("#32190e")
