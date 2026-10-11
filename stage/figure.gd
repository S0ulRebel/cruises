extends Node2D
@export var actor_id := ""
@onready var _animation: AnimationPlayer = $AnimationPlayer

func set_speaking(speaking: bool) -> void:
	_animation.play("speaking" if speaking else "RESET")
	_animation.advance(0.0)
