extends Node3D
## Count Fingers, hovering in his bowl.
##
## Moved as a whole node rather than animated on a skeleton. Tripo's non-humanoid
## auto-rigger produced a skeleton with every bone at the origin - twice - and
## tools/repair_rig.py measured the best possible placement at 81 mm from the vertices
## those bones should sit inside, against a 20 mm tolerance. There is no rig to animate.
##
## It costs nothing, because a goldfish in a bowl is almost entirely rigid-body motion:
## he hangs in the water, drifts, and turns to look at you. The parts a skeleton would
## buy - tail flex, mouth, brows - are the second iteration.
##
## Three frequencies that do not divide into each other, so the loop never visibly
## repeats. A single sine reads as a metronome within about four seconds.

## Metres. Small - the design sheet says 6-8 cm.
@export var drift := 0.012
@export var bob := 0.009
## Degrees.
@export var yaw := 22.0
@export var pitch := 7.0

var _home: Vector3
var _t := 0.0


func _ready() -> void:
	_home = position


func _process(delta: float) -> void:
	_t += delta
	position = _home + Vector3(
		sin(_t * 0.37) * drift,
		sin(_t * 0.73) * bob,
		cos(_t * 0.29) * drift)
	rotation_degrees = Vector3(
		sin(_t * 0.61) * pitch,
		sin(_t * 0.23) * yaw,
		sin(_t * 0.43) * pitch * 0.4)
