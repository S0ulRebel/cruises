class_name Inventory
extends CanvasLayer
## Inventory is a view/controller for the explicitly supplied session store.
signal selected(item_id: String)
signal opened
signal closed
@export var state: GameState
const ENTRY := preload("res://ui/inventory_entry.tscn")
const QUICK_ENTRY := preload("res://ui/quick_entry.tscn")
@onready var _panel: PanelContainer = $Quick/Panel
@onready var _bar: HBoxContainer = $Quick/Panel/Bar
@onready var _bag: PanelContainer = $Center/Bag
@onready var _grid: GridContainer = $Center/Bag/Column/Grid
@onready var _detail_name: Label = $Center/Bag/Column/DetailName
@onready var _detail_look: Label = $Center/Bag/Column/DetailLook
var _open := false
var _generation := 0
var held: Array[String]:
	get:
		return state.held if state else []
var selection: String:
	get:
		return state.selection if state else ""

func _ready() -> void:
	if state:
		setup(state)

func setup(store: GameState) -> void:
	if state and state.inventory_changed.is_connected(_refresh):
		state.inventory_changed.disconnect(_refresh)
		state.selection_changed.disconnect(_on_selection)
	state = store
	if state:
		state.inventory_changed.connect(_refresh)
		state.selection_changed.connect(_on_selection)
	_refresh()

func add(item_id: String) -> bool:
	return state.add(item_id) if state else false

func remove(item_id: String) -> void:
	if state:
		state.remove(item_id)

func has(item_id: String) -> bool:
	return item_id in held

func select(item_id: String) -> void:
	if state:
		state.select(item_id)

func _on_selection(item_id: String) -> void:
	for container in [_bar, _grid]:
		for button in container.get_children():
			button.button_pressed = button.get_meta("item_id", "") == item_id
	selected.emit(item_id)

func describe(item_id: String) -> String:
	var definition := state.item(item_id) if state else null
	return definition.description if definition else "Something unremarkable."

func display_name(item_id: String) -> String:
	var definition := state.item(item_id) if state else null
	return definition.display_name if definition else item_id

func is_open() -> bool:
	return _open

func toggle() -> void:
	_open = not _open
	_bag.visible = _open
	if _open:
		opened.emit()
		await _fill_bag()
	else:
		_generation += 1
		closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle") and not event.is_echo():
		get_viewport().set_input_as_handled()
		toggle()

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _fill_bag() -> void:
	_generation += 1
	var token := _generation
	_clear(_grid)
	_detail_name.text = "Nothing." if held.is_empty() else ""
	_detail_look.text = "His pockets are as empty as the log." if held.is_empty() else ""
	for item_id in held.duplicate():
		if token != _generation or not _open:
			return
		var button := ENTRY.instantiate() as Button
		button.set_meta("item_id", item_id)
		button.button_pressed = item_id == selection
		button.tooltip_text = display_name(item_id)
		button.text = display_name(item_id).substr(0, 1).to_upper()
		button.pressed.connect(_select_and_describe.bind(item_id))
		button.mouse_entered.connect(_show_detail.bind(item_id))
		button.focus_entered.connect(_show_detail.bind(item_id))
		_grid.add_child(button)
		var icon: Texture2D = await ItemIcon.of(item_id, self, state.item(item_id) if state else null)
		if token != _generation or not is_instance_valid(button):
			return
		if icon:
			button.icon = icon
			button.text = ""
	if _grid.get_child_count() > 0:
		_grid.get_child(0).grab_focus.call_deferred()

func _select_and_describe(item_id: String) -> void:
	select(item_id)
	_show_detail(item_id)

func _show_detail(item_id: String) -> void:
	_detail_name.text = display_name(item_id)
	_detail_look.text = describe(item_id)

func _refresh() -> void:
	if not is_node_ready():
		return
	_clear(_bar)
	_panel.visible = not held.is_empty()
	for item_id in held:
		var button := QUICK_ENTRY.instantiate() as Button
		button.text = display_name(item_id)
		button.set_meta("item_id", item_id)
		button.button_pressed = item_id == selection
		button.pressed.connect(select.bind(item_id))
		_bar.add_child(button)
	if _open:
		_fill_bag.call_deferred()
