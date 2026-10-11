extends VScrollBar
## Mirrors the content range while saved atlas controls render the scrollbar.
@onready var _thumb: TextureRect = $Thumb
var _content: Range
var _syncing := false

func bind_content(content: Range) -> void:
	_content = content
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_changed.connect(_update_content)
	_sync()

func _process(_delta: float) -> void:
	_sync()

func _sync() -> void:
	if not is_instance_valid(_content):
		hide()
		return
	_syncing = true
	min_value = _content.min_value
	max_value = _content.max_value
	page = _content.page
	value = _content.value
	_syncing = false
	visible = max_value - min_value > page
	if visible:
		var height := maxf(28.0, size.y * page / (max_value - min_value))
		_thumb.size.y = minf(size.y, height)
		_thumb.position.y = (size.y - _thumb.size.y) * (value - min_value) / maxf(1.0, max_value - page - min_value)

func _update_content(amount: float) -> void:
	if not _syncing and is_instance_valid(_content):
		_content.value = amount
