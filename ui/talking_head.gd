class_name TalkingHead
extends SubViewportContainer
## Changes whole authored portrait scenes. No fitting, light or accessory builders.
const SHAPES := ["WIDE", "ROUND", "PRESSED"]
const PortraitRig := preload("res://ui/portraits/portrait_rig.gd")
@export var panel_size := Vector2i(224, 224)
@onready var _viewport: SubViewport = $Viewport
@onready var _root: Node3D = $Viewport/Content
var _characters: Dictionary = {}
var _rig: PortraitRig
var _skeleton: Skeleton3D
var _mesh: MeshInstance3D
var _jaw := -1
var _jaw_rest := Transform3D.IDENTITY
var _shape_index: Dictionary = {}
var _who := ""

func set_characters(characters: Array[CharacterDefinition]) -> void:
	_characters.clear()
	for definition in characters:
		_characters[definition.asset_id] = definition
		_characters[definition.content_id] = definition

func show_character(character_id: String) -> bool:
	if character_id == _who and _rig != null:
		_rig.show()
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		return _skeleton != null
	_who = character_id
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()
	_rig = null
	_skeleton = null
	_mesh = null
	_jaw = -1
	_shape_index.clear()
	var definition := _characters.get(character_id) as CharacterDefinition
	if definition == null or definition.portrait_scene == null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return false
	_rig = definition.portrait_scene.instantiate() as PortraitRig
	if _rig == null:
		push_error("Portrait scene must use portrait_rig.gd: %s" % character_id)
		return false
	_root.add_child(_rig)
	_skeleton = _rig.get_node_or_null(_rig.skeleton_path) as Skeleton3D
	_mesh = _rig.get_node_or_null(_rig.face_mesh_path) as MeshInstance3D
	# The same head asset may also be used on the world actor or another panel.
	# Give this portrait its own deformation resources, retaining source materials.
	if _mesh and _mesh.mesh:
		_mesh.mesh = _mesh.mesh.duplicate()
		if _mesh.skin:
			_mesh.skin = _mesh.skin.duplicate()
	if _skeleton:
		_jaw = _skeleton.find_bone(_rig.jaw_bone)
		if _jaw >= 0:
			_jaw_rest = _skeleton.get_bone_rest(_jaw)
	if _mesh and _mesh.mesh:
		for i in _mesh.mesh.get_blend_shape_count():
			_shape_index[_mesh.mesh.get_blend_shape_name(i)] = i
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	return _skeleton != null

func apply(pose: Dictionary, character_id: String) -> void:
	if _skeleton and _jaw >= 0:
		_skeleton.set_bone_pose_rotation(_jaw,
			_jaw_rest.basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, deg_to_rad(Speech.jaw_degrees(pose, character_id))))
	if _mesh:
		for shape in SHAPES:
			if _shape_index.has(shape):
				_mesh.set_blend_shape_value(_shape_index[shape], float(pose.get(shape.to_lower(), 0.0)))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func settle(character_id: String) -> void:
	apply(Speech.rest(), character_id)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func suspend() -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if is_instance_valid(_rig):
		_rig.hide()

func rig_report() -> Dictionary:
	return {"character": _who, "has_skeleton": _skeleton != null,
		"jaw_bone": _jaw, "shapes_found": _shape_index.keys(),
		"bones": _skeleton.get_bone_count() if _skeleton else 0}
