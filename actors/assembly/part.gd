@tool
class_name AssemblyPart
extends Node3D
## An authored instance, not a category or equipment slot. This script never builds
## geometry, rebinds rigs, restores placement, or saves resources on startup.

enum AttachmentMode { FREE, PARENT, BONE, SKINNED }

@export var part_id: String = ""
@export_file("*.tscn", "*.scn", "*.glb", "*.gltf") var source_path: String = ""
@export var attachment_mode: AttachmentMode = AttachmentMode.FREE
## Relative to this part. Paths identify the actual authored target, including a
## skeleton inside another part; they never resolve via a global character registry.
@export var target_path: NodePath
@export var bone_name: String = ""
@export var binding_data: Resource
@export var geometry_masks: Array[Resource] = []


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if part_id.is_empty():
		warnings.append("This part has no stable identity. Add/duplicate parts through Character Workshop.")
	if not has_node("Model"):
		warnings.append("This part has no Model child. Imported local rigs and geometry belong under Model.")
	if attachment_mode != AttachmentMode.FREE:
		var target := get_node_or_null(target_path) if not target_path.is_empty() else null
		if target == null:
			warnings.append("The attachment target is missing. Choose a target or detach explicitly.")
		elif attachment_mode == AttachmentMode.BONE:
			if not target is Skeleton3D or (target as Skeleton3D).find_bone(bone_name) < 0:
				warnings.append("The selected skeleton/bone no longer exists. Reattach explicitly.")
	if attachment_mode == AttachmentMode.SKINNED and binding_data == null:
		warnings.append("This skinned part has no binding provenance. Bind explicitly in Character Workshop.")
	return warnings
