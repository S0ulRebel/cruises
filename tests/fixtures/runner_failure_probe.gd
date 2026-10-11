extends SceneTree
## Deliberately reproduces the old false-pass: engine error plus successful exit.
func _initialize() -> void:
	push_error("DELIBERATE RUNNER FAILURE PROBE")
	print("CHECKS PASSED: deliberately false")
	quit(0)
