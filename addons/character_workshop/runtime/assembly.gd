@tool
class_name CWAssembly
extends Node3D
## Ordinary saved scene content is the entire character. This node supplies
## metadata and editor validation only. No authoring service is loaded by saved
## characters; native skeletons, skins and attachments drive their runtime behavior.

@export var assembly_id: String = ""
@export_multiline var author_notes: String = ""


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: Array[String] = []
	var ids := {}
	_append_part_warnings(self, ids, warnings)
	return PackedStringArray(warnings)


## Keep validation inside the metadata boundary: an exported character must not
## need editor operations (or their save/binding dependencies) merely to load.
func _append_part_warnings(node: Node, ids: Dictionary, warnings: Array[String]) -> void:
	if node is CWPart:
		var part := node as CWPart
		if part.part_id.is_empty():
			warnings.append("Part %s is missing its stable identity." % part.name)
		elif ids.has(part.part_id):
			warnings.append("Parts %s and %s share an identity. Use Workshop Duplicate for independent instances." % [ids[part.part_id], part.name])
		else:
			ids[part.part_id] = part.name
	for child in node.get_children():
		_append_part_warnings(child, ids, warnings)
