@tool
class_name CharacterDefinition
extends Resource
## Screenplay identity and presentation. Placement belongs to a location scene.
@export var content_id := ""
@export var asset_id := ""
@export var display_name := ""
@export var colour := Color.WHITE
@export_file("*.json") var conversation := ""
@export var portrait_scene: PackedScene

func cast_entry() -> Dictionary:
	return {"name": display_name, "assets": asset_id, "colour": colour.to_html(),
		"portrait_scene": portrait_scene}
