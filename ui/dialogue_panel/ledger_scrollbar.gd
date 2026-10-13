extends VScrollBar
## Mirrors the content range while saved atlas controls render the scrollbar.
@onready var _thumb: TextureRect = $Thumb
@onready var _track: NinePatchRect = $Track
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
		return
	_syncing = true
	min_value = _content.min_value
	max_value = _content.max_value
	page = _content.page
	value = _content.value
	_syncing = false
	# Keep the authored track visible even when the passage fits the viewport.
	show()
	var extent := max_value - min_value
	var track_height := _track.size.y * _track.scale.y
	var height := track_height if extent <= page else maxf(28.0, track_height * page / extent)
	_thumb.size.y = minf(track_height, height)
	_thumb.position.y = _track.position.y + (track_height - _thumb.size.y) * (value - min_value) / maxf(1.0, extent - page)

func _update_content(amount: float) -> void:
	if not _syncing and is_instance_valid(_content):
		_content.value = amount
