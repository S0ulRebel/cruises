@tool
class_name CharacterAssembly
extends Node3D
## Ordinary saved scene content is the entire character. This node supplies
## metadata and editor validation only; the plugin is not required at runtime.

@export var assembly_id: String = ""
@export_multiline var author_notes: String = ""


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var ids := {}
	for part in AssemblyOperations.collect_parts(self):
		if part.part_id.is_empty():
			warnings.append("Part %s is missing its stable identity." % part.name)
		elif ids.has(part.part_id):
			warnings.append("Parts %s and %s share an identity. Use Workshop Duplicate for independent instances." % [ids[part.part_id], part.name])
		else:
			ids[part.part_id] = part.name
	return warnings
