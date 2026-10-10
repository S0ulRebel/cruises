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

const ITEMS := {
	"fishbowl": { "name": "Count Fingers", "look": "A goldfish with the temperament of a harbour master." },
	"rapier": { "name": "Rapier", "look": "Thin, French, and considerably better travelled than most men." },
	"ladle": { "name": "Ladle", "look": "It smells of yesterday's soup. And the day before's." },
	"key": { "name": "Brass key", "look": "Small, cold, and far too clean for this ship." },
}

var held: Array[String] = []
var selection := ""

var _bar: HBoxContainer
var _panel: PanelContainer


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
