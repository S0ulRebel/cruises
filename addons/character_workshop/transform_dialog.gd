@tool
extends PanelContainer
## Exact local fitting fields. Applying delegates one native undo action; this
## dialog never previews transforms or changes the scene directly.

signal request(action: String, value: Variant)

const Ops = preload("res://addons/character_workshop/core/assembly_operations.gd")

var _part: Node3D
var _parent: Node
var _before_global := Transform3D.IDENTITY
var _before_local := Transform3D.IDENTITY
var _parent_world := Transform3D.IDENTITY
var _rotation_order := EULER_ORDER_YXZ
var _top_level := false
var _initial_position := Vector3.ZERO
var _initial_rotation := Vector3.ZERO
var _initial_scale := Vector3.ONE
var _seeded_fields: Dictionary = {}


func _ready() -> void:
	%TransformCancel.pressed.connect(cancel)
	%TransformApply.pressed.connect(_apply)


func open_for(part: Node3D) -> void:
	cancel()
	%TransformError.text = ""
	%TransformError.hide()
	if not is_instance_valid(part) or not part.is_inside_tree():
		return
	_part = part
	_parent = part.get_parent()
	_before_global = part.global_transform
	_before_local = part.transform
	_top_level = part.top_level
	_parent_world = _effective_parent_world(part)
	_rotation_order = part.rotation_order
	_initial_position = part.position
	_initial_rotation = part.rotation_degrees
	_initial_scale = part.scale
	_set_fields("Position", _initial_position)
	_set_fields("Rotation", _initial_rotation)
	_set_fields("Scale", _initial_scale)
	_seeded_fields = {"Position": _fields("Position"), "Rotation": _fields("Rotation"), "Scale": _fields("Scale")}
	%TransformTitle.text = "Fine adjust · " + str(part.name)
	if _top_level:
		%TransformSpace.text = "World coordinates (top-level part)"
	elif _parent is Node3D:
		%TransformSpace.text = "Local coordinates relative to " + str(_parent.name)
	else:
		%TransformSpace.text = "Scene coordinates (character root)"
	show()
	%PositionX.get_line_edit().grab_focus()


func cancel() -> void:
	hide()
	_part = null
	_parent = null


func _set_fields(prefix: String, value: Vector3) -> void:
	for index: int in 3:
		get_node("%" + prefix + ["X", "Y", "Z"][index]).value = value[index]


func _fields(prefix: String) -> Vector3:
	return Vector3(get_node("%" + prefix + "X").value, get_node("%" + prefix + "Y").value, get_node("%" + prefix + "Z").value)


func _precise_fields(prefix: String, original: Vector3) -> Vector3:
	var value := _fields(prefix)
	var seeded: Vector3 = _seeded_fields[prefix]
	# Display precision must never round an axis the author did not edit.
	for index: int in 3:
		if value[index] == seeded[index]:
			value[index] = original[index]
	return value


func _effective_parent_world(part: Node3D) -> Transform3D:
	var parent := part.get_parent() as Node3D
	return parent.global_transform if parent != null and not part.top_level else Transform3D.IDENTITY


func _current_error() -> String:
	if not is_instance_valid(_part) or not _part.is_inside_tree():
		return "This part was removed. Close this window and select another part."
	if _part.get_parent() != _parent or _part.top_level != _top_level:
		return "This part's attachment changed. Reopen Fine adjustment to use its new coordinates."
	if not _effective_parent_world(_part).is_equal_approx(_parent_world):
		return "The parent moved while this window was open. Reopen Fine adjustment before applying."
	if _part.rotation_order != _rotation_order or not _part.transform.is_equal_approx(_before_local) or not _part.global_transform.is_equal_approx(_before_global):
		return "This part moved while this window was open. Reopen Fine adjustment before applying."
	return ""


func _error(message: String) -> void:
	%TransformError.text = message
	%TransformError.show()


func _apply() -> void:
	var error := _current_error()
	if not error.is_empty():
		_error(error)
		return
	# SpinBox commits typed text when Apply takes focus, as in native Inspector.
	var position := _precise_fields("Position", _initial_position)
	var rotation := _precise_fields("Rotation", _initial_rotation)
	var scale := _precise_fields("Scale", _initial_scale)
	if not position.is_finite() or not rotation.is_finite() or not scale.is_finite():
		_error("Position, rotation and scale must be finite.")
		return
	var basis: Basis = _before_local.basis
	# Preserve the exact authored basis (including shear) when only moving.
	if not rotation.is_equal_approx(_initial_rotation) or not scale.is_equal_approx(_initial_scale):
		var radians := Vector3(deg_to_rad(rotation.x), deg_to_rad(rotation.y), deg_to_rad(rotation.z))
		basis = Basis.from_euler(radians, _rotation_order).scaled_local(scale)
	var local := Transform3D(basis, position)
	error = Ops.validate_transform(local)
	if not error.is_empty():
		_error(error)
		return
	var after := _parent_world * local
	error = Ops.validate_transform(after)
	if not error.is_empty():
		_error(error)
		return
	request.emit("transform", {"part": _part, "before": _before_global, "after": after})
	cancel()
