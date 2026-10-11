@tool
extends MeshInstance3D
@export var tick_count: int = 0


func on_tick() -> void:
	tick_count += 1
