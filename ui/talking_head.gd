class_name TalkingHead
extends SubViewportContainer
## The speaker's head, rendered live into the dialogue panel.
##
## Why a render of the 3D head rather than drawn sprites: the head already exists, and
## it already has a mouth that opens. A sprite set would be 7 to 17 distinct mouth
## states per character, each needing teeth and a tongue that are not in the source
## drawings and cannot be inpainted - 63 to 126 images for a cast of nine, all of
## which have to be kept consistent with a character that is still changing. The head
## costs nothing beyond the one we already generate, and the dialogue text drives it
## with no per-line assets at all.
##
## It is deliberately NOT lit by the room. A portrait that darkens when the character
## steps behind a crate reads as a bug, not as atmosphere. Two fixed lights here, and
## if a baked-light texture arrives later the material simply goes unshaded and even
## these come out - see PORTRAIT_LIGHTING below.
##
## Only one character speaks at a time, so one head is resident rather than nine.

## Where a character's head piece lives. `%s` is the character id.
const HEAD_PATH := "res://art/characters/%s/pieces/head/head_face.glb"

## The bone the jaw rotates on, and the three lip shapes, as authored by the
## face-animation session. Named here rather than guessed at per character.
const JAW_BONE := "Jaw"
const SHAPES := ["WIDE", "ROUND", "PRESSED"]

## Set true once heads ship with the artist's lighting baked into a SECOND texture.
## The material then goes unshaded and the lamps are skipped, so the panel looks
## exactly like the turnaround instead of like a lit model.
##
## False for now, and measured rather than assumed: Tripo DELIGHTS during texturing,
## so the only texture we have is flat albedo. Drawn unshaded it comes out a flat
## orange with no form at all - the nose, brow and cheeks disappear. Until a
## baked-light texture exists the portrait has to be lit.
const PORTRAIT_LIGHTING := false

@export var panel_size := Vector2i(300, 300)
## How much of the head is in frame. 1.0 is chin to crown; less crops in on the mouth.
## Height of the head as a fraction of the panel. 1.0 is chin-to-crown exactly edge
## to edge; a little under leaves a margin without wasting the panel on empty air.
@export var framing := 0.86

var _viewport: SubViewport
var _root: Node3D
var _camera: Camera3D
var _skeleton: Skeleton3D
var _mesh: MeshInstance3D
var _jaw := -1
var _jaw_rest := Transform3D.IDENTITY
var _shape_index: Dictionary = {}
var _who := ""


func _ready() -> void:
	custom_minimum_size = panel_size
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.size = panel_size
	_viewport.transparent_bg = true
	# Its OWN 3D world. Without this the head is added to the room's world and stands
	# in the middle of the floor as a severed head, lit by the room and casting a
	# shadow - and the panel shows the room instead of the head.
	_viewport.own_world_3d = true
	_viewport.world_3d = World3D.new()
	# Only redraw while someone is talking. A dialogue panel that re-renders a head
	# every frame of a conversation nobody is having is pure waste.
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	_root = Node3D.new()
	_viewport.add_child(_root)
	_build_camera()
	if not PORTRAIT_LIGHTING:
		_build_lights()


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_camera.current = true
	_root.add_child(_camera)


## Two lamps, fixed, so the portrait looks the same wherever the character is standing.
func _build_lights() -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-18.0, 28.0, 0.0)
	key.light_energy = 1.5
	_root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-5.0, -120.0, 0.0)
	fill.light_energy = 0.5
	_root.add_child(fill)


## Put a character's head in the panel. Returns false if they have no head piece yet,
## so the caller can fall back to a placeholder rather than showing an empty box.
func show_character(character_id: String) -> bool:
	if character_id == _who:
		return _skeleton != null
	_who = character_id
	for child in _root.get_children():
		if child != _camera and not (child is DirectionalLight3D):
			child.queue_free()
	_skeleton = null
	_mesh = null
	_jaw = -1
	_shape_index.clear()

	var path := HEAD_PATH % character_id
	if not ResourceLoader.exists(path):
		return false
	var scene := load(path) as PackedScene
	if scene == null:
		return false
	var head := scene.instantiate() as Node3D
	_root.add_child(head)

	var skeletons := head.find_children("*", "Skeleton3D", true, false)
	_skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	var meshes := head.find_children("*", "MeshInstance3D", true, false)
	_mesh = meshes[0] as MeshInstance3D if not meshes.is_empty() else null
	if _skeleton:
		_jaw = _skeleton.find_bone(JAW_BONE)
		if _jaw >= 0:
			_jaw_rest = _skeleton.get_bone_rest(_jaw)
	if _mesh and _mesh.mesh:
		for i in _mesh.mesh.get_blend_shape_count():
			_shape_index[_mesh.mesh.get_blend_shape_name(i)] = i
	if PORTRAIT_LIGHTING:
		_unshade(head)

	_frame_on_face(head)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return _skeleton != null


## Draw the texture exactly as painted, with no engine lighting at all. Tripo delights
## during texturing, so this currently looks flat; it is right the moment a
## baked-light texture replaces it, and nothing here has to change.
func _unshade(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		for surface in mesh_node.get_surface_override_material_count():
			var material := mesh_node.get_active_material(surface)
			if material is BaseMaterial3D:
				var flat: BaseMaterial3D = material.duplicate()
				flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh_node.set_surface_override_material(surface, flat)


## Point the camera at the face, worked out from where the head actually is rather
## than from numbers that only suit one character.
func _frame_on_face(head: Node3D) -> void:
	var bounds := _bounds_of(head)
	if bounds.size == Vector3.ZERO:
		return
	# Aim slightly below the middle: a portrait is about the mouth and eyes, and the
	# top of a skull is dead space.
	# Aim at the FACE, not the middle of the bounding box: the head piece includes a
	# long neck, so centring on the box puts the chin halfway down the panel and wastes
	# the top third on empty air.
	var target := bounds.get_center() + Vector3(0, bounds.size.y * 0.12, 0)
	# Fit the face height, which is roughly the top half of the piece once the neck is
	# discounted, into `framing` of the panel.
	var face_height: float = bounds.size.y * 0.72
	var distance: float = (face_height / framing) * 0.5 / tan(deg_to_rad(_camera.fov * 0.5))
	_camera.global_position = target + Vector3(0, 0, maxf(distance, 0.25))
	_camera.look_at(target)


func _bounds_of(root: Node) -> AABB:
	var out := AABB()
	var first := true
	for node in root.find_children("*", "VisualInstance3D", true, false):
		var vis := node as VisualInstance3D
		var box := vis.global_transform * vis.get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out


## Set the mouth. `pose` is what Speech.sample returns.
func apply(pose: Dictionary, character_id: String) -> void:
	if _skeleton and _jaw >= 0:
		var degrees := Speech.jaw_degrees(pose, character_id)
		_skeleton.set_bone_pose_rotation(_jaw,
			_jaw_rest.basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, deg_to_rad(degrees)))
	if _mesh == null:
		return
	for name in SHAPES:
		if not _shape_index.has(name):
			continue
		var key: String = name.to_lower()
		_mesh.set_blend_shape_value(_shape_index[name], float(pose.get(key, 0.0)))


## Shut the mouth and stop re-rendering. Between lines, and when the panel closes.
func settle(character_id: String) -> void:
	apply(Speech.rest(), character_id)
	await get_tree().process_frame
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


## What the head is capable of, for the check harness: whether the jaw and each shape
## were actually found rather than silently missing.
func rig_report() -> Dictionary:
	return {
		"character": _who,
		"has_skeleton": _skeleton != null,
		"jaw_bone": _jaw,
		"shapes_found": _shape_index.keys(),
		"bones": _skeleton.get_bone_count() if _skeleton else 0,
	}
