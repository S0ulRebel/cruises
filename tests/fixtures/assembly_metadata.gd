@tool
extends Resource
## Fixture for external/nested mutable state, never loaded by gameplay.
@export var offset := Vector3(0.1, 0.2, 0.3)
@export var material: Material
@export var related: Array[Resource] = []
