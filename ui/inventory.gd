class_name Inventory
extends CanvasLayer
## What the captain is carrying, and the bar it shows up in.
##
## Kept deliberately thin. An adventure game's inventory is a list of ids and one
## selection - everything interesting happens when an id meets a hotspot, and that
## belongs in the room, not here.
##
## Items are data: an id, a name, a line of description. No scene, no resource file.
## A puzzle item that needs its own behaviour is a hotspot, not an inventory entry.

signal selected(item_id: String)
signal opened
signal closed

## An item's `id` is also the folder its model lives in - art/props/<id>/<id>.glb -
## so the inventory icon is rendered from the prop itself rather than drawn twice.
## An item with no model still works; it gets a lettered tile.
const ITEMS := {
	"fishbowl": { "name": "Count Fingers", "look": "A goldfish with the temperament of a harbour master." },
	"rapier": { "name": "Rapier", "look": "Thin, French, and considerably better travelled than most men." },
	"ladle": { "name": "Ladle", "look": "It smells of yesterday's soup. And the day before's." },
	"key": { "name": "Brass key", "look": "Small, cold, and far too clean for this ship." },
	"compass": { "name": "Compass", "look": "The needle swings, settles, and points at nothing in particular. Much like its owner." },
	"rolled_charts": { "name": "Rolled charts", "look": "Three charts of three different seas, none of them this one." },
	"brass_inkwell": { "name": "Brass inkwell", "look": "Dry since the second week. He writes the log from memory, which is why it is a work of fiction." },
}

## The key that opens and closes the bag.
const TOGGLE_ACTION := KEY_I
const ItemIconScript := preload("res://ui/item_icon.gd")

var held: Array[String] = []
var selection := ""

var _bar: HBoxContainer
var _panel: PanelContainer
var _bag: PanelContainer
var _grid: GridContainer
var _detail_name: Label
var _detail_look: Label
var _open := false


func _ready() -> void:
	layer = 9
	_build()


func add(item_id: String) -> bool:
	if item_id.is_empty() or item_id in held:
		return false
	held.append(item_id)
	_refresh()
	return true


func remove(item_id: String) -> void:
	held.erase(item_id)
	if selection == item_id:
		select("")
	_refresh()


func has(item_id: String) -> bool:
	return item_id in held


## Selecting is a toggle: clicking the held item again puts it down, so the player is
## never stuck holding something with no way to stop.
func select(item_id: String) -> void:
	selection = "" if item_id == selection else item_id
	selected.emit(selection)
	_refresh()
	if _open:
		_fill_bag.call_deferred()


func describe(item_id: String) -> String:
	var entry: Dictionary = ITEMS.get(item_id, {})
	return String(entry.get("look", "Something unremarkable."))


func display_name(item_id: String) -> String:
	var entry: Dictionary = ITEMS.get(item_id, {})
	return String(entry.get("name", item_id))


func _build() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("margin_top", 14)
	root.add_theme_constant_override("margin_left", 80)
	add_child(root)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.8)
	style.border_color = Color(0.70, 0.58, 0.36, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.visible = false
	root.add_child(_panel)

	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 8)
	_panel.add_child(_bar)
	_build_bag()


## The bag proper: the thing that opens. The bar along the top is a quick view of what
## is held; this is where you look at something.
func _build_bag() -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_bag = PanelContainer.new()
	_bag.visible = false
	_bag.custom_minimum_size = Vector2(620, 420)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.96)
	style.border_color = Color(0.70, 0.58, 0.36, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(22)
	_bag.add_theme_stylebox_override("panel", style)
	centre.add_child(_bag)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_bag.add_child(column)

	var title := Label.new()
	title.text = "Carrying"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#b49268"))
	column.add_child(title)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	column.add_child(_grid)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 22)
	column.add_child(_detail_name)

	_detail_look = Label.new()
	_detail_look.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_look.custom_minimum_size = Vector2(0, 56)
	_detail_look.add_theme_font_size_override("font_size", 18)
	_detail_look.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	column.add_child(_detail_look)

	var hint := Label.new()
	hint.text = "I  to close"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	column.add_child(hint)


func is_open() -> bool:
	return _open


## Open or shut the bag. Emits so the room can stop listening for clicks while it is
## up - walking off mid-rummage reads as the click going through the panel.
func toggle() -> void:
	_open = not _open
	_bag.visible = _open
	if _open:
		opened.emit()
		await _fill_bag()
	else:
		closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == TOGGLE_ACTION:
		get_viewport().set_input_as_handled()
		toggle()


func _fill_bag() -> void:
	for child in _grid.get_children():
		child.queue_free()
	if held.is_empty():
		_detail_name.text = "Nothing."
		_detail_look.text = "His pockets are as empty as the log."
		return
	_detail_name.text = ""
	_detail_look.text = ""
	for item_id in held:
		_grid.add_child(await _slot(item_id))


## One tile. The icon is rendered from the item's own model; an item with no model
## yet falls back to its initial, so a puzzle can hand out something before the art
## for it exists.
func _slot(item_id: String) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(128, 128)
	button.toggle_mode = true
	button.button_pressed = (item_id == selection)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = display_name(item_id)
	button.pressed.connect(func() -> void:
		select(item_id)
		_show_detail(item_id))
	button.mouse_entered.connect(_show_detail.bind(item_id))

	var icon: Texture2D = await ItemIconScript.of(item_id, self)
	if icon != null:
		button.icon = icon
		button.expand_icon = true
	else:
		button.text = display_name(item_id).substr(0, 1).to_upper()
		button.add_theme_font_size_override("font_size", 44)
	return button


func _show_detail(item_id: String) -> void:
	_detail_name.text = display_name(item_id)
	_detail_look.text = describe(item_id)


func _refresh() -> void:
	for child in _bar.get_children():
		child.queue_free()
	_panel.visible = not held.is_empty()

	for item_id in held:
		var button := Button.new()
		button.text = display_name(item_id)
		button.toggle_mode = true
		button.button_pressed = (item_id == selection)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(select.bind(item_id))
		_bar.add_child(button)
