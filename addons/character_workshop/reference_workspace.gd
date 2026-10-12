@tool
extends RefCounted
## Editor preferences only; never serialized into a character scene.

var read_preferences: Callable
var write_preferences: Callable
var _sessions: Dictionary = {}
var _current: Node
var _state: Dictionary = {}
var _saved_path := ""

func set_context(root: Node) -> bool:
	if root == _current and is_instance_valid(root):
		if _scene_path(root) != _saved_path:
			_saved_path = _scene_path(root)
			persist()
		return false
	_current = root
	_saved_path = _scene_path(root)
	_state = {"paths": [], "active": "", "mode": "3d"}
	for id: int in _sessions.keys():
		if _sessions[id].root.get_ref() == null:
			_sessions.erase(id)
	if not is_instance_valid(root):
		return true
	var id := root.get_instance_id()
	if _sessions.has(id):
		_state = _sessions[id].state
	else:
		var stored: Variant = read_preferences.call() if read_preferences.is_valid() else {}
		if stored is Dictionary and stored.get(_saved_path) is Dictionary:
			var entry: Dictionary = stored[_saved_path]
			if entry.get("paths") is Array:
				for path: Variant in entry.paths:
					if path is String and not path.is_empty() and not _state.paths.has(path):
						_state.paths.append(path)
			_state.active = str(entry.get("active", ""))
			_state.mode = "reference" if entry.get("mode") == "reference" else "3d"
		_sessions[id] = {"root": weakref(root), "state": _state}
	if not _state.paths.has(_state.active):
		_state.active = _state.paths[0] if not _state.paths.is_empty() else ""
	return true

func state() -> Dictionary:
	return _state.duplicate(true)

func _scene_path(node: Node) -> String:
	if not is_instance_valid(node):
		return ""
	if not node.scene_file_path.is_empty():
		return node.scene_file_path
	# Exported actors expose their owned Body assembly to the workshop.
	return node.owner.scene_file_path if is_instance_valid(node.owner) else ""

func update(paths: Array, active: String, mode: String) -> void:
	if not is_instance_valid(_current):
		return
	_state.paths = paths.duplicate()
	_state.active = active
	_state.mode = mode
	persist()

func persist() -> void:
	if _saved_path.is_empty() or not write_preferences.is_valid():
		return
	var stored: Variant = read_preferences.call() if read_preferences.is_valid() else {}
	var values: Dictionary = stored.duplicate(true) if stored is Dictionary else {}
	values[_saved_path] = state()
	write_preferences.call(values)
