extends SceneTree
## Shared reporting/deadlines. The external runner also rejects engine errors.
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check("a check overrides _run", false)
	finish()

func check(label: String, ok: bool, detail := "") -> bool:
	if not ok:
		failures += 1
	print("%s %s%s" % ["ok" if ok else "FAIL", label,
		"" if detail.is_empty() else " — " + detail])
	return ok

func wait_for(predicate: Callable, seconds := 5.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await physics_frame
	return bool(predicate.call())

func instantiate_scene(path: String) -> Node:
	if not check("scene exists: " + path, ResourceLoader.exists(path)):
		return null
	var scene := load(path) as PackedScene
	if not check("scene loads: " + path, scene != null):
		return null
	return scene.instantiate()

func finish() -> void:
	if failures == 0:
		print("CHECKS PASSED: " + get_script().resource_path.get_file())
	else:
		print("CHECKS FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
