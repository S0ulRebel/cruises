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

## Where a character's hat, hair and the rest sit on their portrait head. The head
## piece is a bare face - no hat, no hair - so the portrait is not the character until
## these go on. See the file itself for where the numbers come from.
const PIECES_PATH := "res://data/pieces.json"

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
	# transparent_bg alone is not enough: a fresh World3D has no environment, so the
	# project's default one draws its sky and the portrait sits on a grey-blue tile
	# instead of on the parchment. The world has to arrive already carrying it -
	# own_world_3d copies the environment ONCE, when the world is assigned, and never
	# looks again.
	var world := World3D.new()
	world.environment = _portrait_environment()
	_viewport.own_world_3d = true
	_viewport.world_3d = world
	# Only redraw while someone is talking. A dialogue panel that re-renders a head
	# every frame of a conversation nobody is having is pure waste.
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	_root = Node3D.new()
	_viewport.add_child(_root)
	_build_camera()
	if not PORTRAIT_LIGHTING:
		_build_lights()


## Clear to nothing, and light the face only with the two lamps below.
static func _portrait_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.60, 0.58)
	env.ambient_light_energy = 0.45
	return env


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

	# The bare head decides the framing; a piece marked in_frame may then push the top
	# of it up, and nothing else can. A hat belongs in the picture, but the captain's
	# plume is a foot of feather and counting it would shrink his face to a thumbnail.
	var bare := _bounds_of(head)
	var framed := _add_pieces(character_id, head)
	for node in framed:
		bare = bare.merge(_bounds_of(node))
	_frame_on_face(bare)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return _skeleton != null


## Hang the character's hat and the rest on the head.
##
## Siblings of the head mesh rather than BoneAttachment3D children: the portrait head
## does not move - only its jaw does - and a bone attachment would add the Head bone's
## rest transform on top of a placement that was measured in the mesh's own space.
## The moment the head starts turning in the panel this becomes a BoneAttachment3D on
## JAW_BONE's parent, and the offsets stay as they are.
## Returns the pieces that are allowed to affect the framing.
func _add_pieces(character_id: String, head: Node3D) -> Array[Node3D]:
	var framed: Array[Node3D] = []
	for piece in _pieces_for(character_id):
		var path := String(piece.get("model", ""))
		if not ResourceLoader.exists(path):
			push_warning("TalkingHead: %s has no model at %s" % [character_id, path])
			continue
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var node := scene.instantiate() as Node3D
		var scale: float = float(piece.get("scale", 1.0))
		var euler: Array = piece.get("rotation_degrees", [0.0, 0.0, 0.0])
		var offset: Array = piece.get("offset", [0.0, 0.0, 0.0])
		var basis := Basis.from_euler(Vector3(
			deg_to_rad(float(euler[0])), deg_to_rad(float(euler[1])), deg_to_rad(float(euler[2]))))
		node.transform = Transform3D(basis.scaled(Vector3.ONE * scale),
			Vector3(float(offset[0]), float(offset[1]), float(offset[2])))
		head.add_child(node)
		if bool(piece.get("in_frame", true)):
			framed.append(node)
	return framed


static func _pieces_for(character_id: String) -> Array:
	if not FileAccess.file_exists(PIECES_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PIECES_PATH))
	if not (parsed is Dictionary):
		return []
	var mine: Variant = parsed.get(character_id)
	if not (mine is Dictionary):
		return []
	var out: Array = []
	for name in mine:
		out.append(mine[name])
	return out


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
func _frame_on_face(bounds: AABB) -> void:
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
	var half: float = (face_height / framing) * 0.5
	# If a hat reaches above what that would show, pull back by exactly enough to get
	# it in - rather than re-fitting the whole box, which would drop the chin and the
	# neck into frame and shrink the face for no gain.
	var wanted_top: float = bounds.position.y + bounds.size.y
	half = maxf(half, wanted_top - target.y)
	var distance: float = half / tan(deg_to_rad(_camera.fov * 0.5))
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
