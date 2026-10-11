class_name GameState
extends Node
## One explicitly wired session store, independent of the HUD.
signal inventory_changed
signal selection_changed(item_id: String)
var flags: Dictionary = {}
var held: Array[String] = []
var selection := ""
@export var items: Array[ItemDefinition] = []

func item(item_id: String) -> ItemDefinition:
	for definition in items:
		if definition.content_id == item_id:
			return definition
	return null

func add(item_id: String) -> bool:
	if item_id.is_empty() or item_id in held or item(item_id) == null:
		return false
	held.append(item_id)
	inventory_changed.emit()
	return true

func remove(item_id: String) -> void:
	held.erase(item_id)
	if selection == item_id:
		selection = ""
		selection_changed.emit(selection)
	inventory_changed.emit()

func select(item_id: String) -> void:
	if not item_id.is_empty() and item_id not in held:
		return
	selection = "" if selection == item_id else item_id
	selection_changed.emit(selection)
	inventory_changed.emit()
