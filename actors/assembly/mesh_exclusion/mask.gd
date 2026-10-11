@tool
class_name MeshExclusionMask
extends Resource
## Persistent authoring metadata, with no loading-time reconstruction or saves.
## Faces are triangle ordinals in each ORIGINAL source surface, in reference pose.

@export var source_mesh: Mesh
@export var topology_fingerprint := ""
@export var excluded_faces: Dictionary = {}
@export var source_node_path: NodePath
