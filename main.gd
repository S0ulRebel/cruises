extends Node3D
## The game.
##
## One scene, in the order the player meets it: the cold open plays, then you are
## standing in Captain Livé's quarters, and you can walk and talk.
##
## It was four separate test harnesses before this, one per system, because that is the
## order they were built in. Four demos that each work is not a game, and the joins are
## where the problems live - so they are joined.
##
## Everything is built in code rather than saved into a .tscn. While the shape is still
## moving, a scene file is a second place to keep in step and a worse one to read a diff
## of. It becomes a .tscn when the layout settles.

const Stage := preload("res://stage/stage.gd")
const Caption := preload("res://ui/caption.gd")
const Choices := preload("res://ui/choices.gd")
const Cutscene := preload("res://cutscene/cutscene.gd")
const Dialogue := preload("res://dialogue/dialogue.gd")
const Room3D := preload("res://room3d/room3d.gd")
const Mover := preload("res://actors/mover/mover.gd")
const BorrowClips := preload("res://actors/parts/borrow_clips.gd")
const Animator := preload("res://actors/parts/animator.gd")
const Hotspot := preload("res://room3d/hotspot.gd")
const Inventory := preload("res://ui/inventory.gd")

## Skip the cold open and start in the room. Defaults ON while the room is being built:
## the cold open is a 35-second 2D cutscene, and sitting through it before every test is
## how a person stops testing - and how you conclude the 3D room is not there at all.
## Turn it off to see the game as a player meets it.
@export var skip_cold_open := true

## Who is in the first room, and where. Heights are from the character sheets.
##
## Scene 1 of the cold open: Livé in his quarters with Count Fingers, and Santi comes
## in to complain. Nobody else is in the room.
const CAST := [
	{ "id": "live", "name": "Captain Livé", "height": 1.9, "colour": "#1c1a1f", "at": Vector3(-1.4, 0, 1.2),
	  "model": "res://art/characters/captain_live/captain_live_hands.glb" },
	{ "id": "santi", "name": "Santi Wong", "height": 1.7, "colour": "#efe6d8", "at": Vector3(2.2, 0, 0.2),
	  "model": "res://art/characters/santi_wong/santi_wong_animated.glb",
	  "talk": "res://screenplay/santi_galley.json" },
]

var _caption: Caption
var _choices: Choices
var _dialogue: Dialogue
var _room: Room3D
var _player: Mover
var _cast: Dictionary = {}
var _movers: Dictionary = {}
var _inventory: Inventory
var _busy := false  ## A cutscene or conversation is running; the room ignores clicks.
var _auto := false


func _ready() -> void:
	# Clicking a 3D body does nothing unless the viewport is asked to do the picking.
	# Off by default, and the failure is silent.
	get_viewport().physics_object_picking = true

	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	_auto = "--auto" in args

	var screenplay: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://screenplay/cold_open.json"))
	_cast = screenplay.get("cast", {})

	_caption = Caption.new()
	_caption.name = "Caption"
	if _auto:
		_caption.auto_advance_secs = 1.2
	add_child(_caption)

	_choices = Choices.new()
	_choices.name = "Choices"
	if _auto:
		_choices.auto_pick_secs = 0.5
	add_child(_choices)

	_dialogue = Dialogue.new()
	_dialogue.name = "Dialogue"
	add_child(_dialogue)
	_dialogue.setup(_caption, _choices)
	_dialogue.set_cast(_cast)
	_dialogue.verbose = _auto

	_inventory = Inventory.new()
	_inventory.name = "Inventory"
	add_child(_inventory)

	if skip_cold_open or "--skip" in args:
		_enter_room()
	else:
		await _play_cold_open()
		_enter_room()


## The cutscene runs on a flat 2D stage in front of everything. It is a different kind
## of picture from the room - staged, not navigable - so it gets its own surface rather
## than being faked with the room camera.
func _play_cold_open() -> void:
	_busy = true
	var stage := Stage.new()
	stage.name = "ColdOpenStage"
	add_child(stage)

	_caption.show_actions = true
	var cutscene := Cutscene.new()
	add_child(cutscene)
	cutscene.setup(stage, _caption)
	cutscene.verbose = _auto
	if cutscene.load_screenplay("res://screenplay/cold_open.json"):
		cutscene.play()
		await cutscene.finished

	stage.queue_free()
	cutscene.queue_free()
	_busy = false


func _enter_room() -> void:
	# Stage directions are a cutscene device. In the room, the picture shows you.
	_caption.show_actions = false

	_room = Room3D.new()
	_room.name = "CaptainQuarters"
	add_child(_room)
	_add_furniture()

	for entry in CAST:
		var mover := _build_mover(entry)
		_room.add_child(mover)
		mover.global_position = entry["at"]
		_movers[entry["id"]] = mover
		if entry["id"] == "live":
			_player = mover
		if entry.has("talk"):
			_add_talk_trigger(mover, entry)

	_add_hotspots()
	_start_sound()
	_room.floor_clicked.connect(_on_floor_clicked)
	print("In the room. Click the floor to walk, click Santi to talk. Esc quits.")

	var args2 := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	# A screenshot run wants the scene left alive to photograph; the self-check quits
	# when it is done, so the two cannot both run.
	if _auto and not ("--shot" in args2 or "--record" in args2):
		await _self_check()
	if "--record" in args2:
		await _record()
	if "--shot" in args2:
		if "--talking" in OS.get_cmdline_user_args() + OS.get_cmdline_args():
			var santi: Mover = _movers["santi"]
			_approach_and_talk(santi, "res://screenplay/santi_galley.json")
			await get_tree().create_timer(5.5).timeout
		await _save_shot()


func _on_floor_clicked(point: Vector3) -> void:
	if _busy:
		return
	_player.walk_to(point)


## Clicking a character walks you over and starts the conversation. Walking first is
## not decoration: a conversation that begins while the captain is across the room
## reads as two people shouting at each other.
func _add_talk_trigger(mover: Mover, entry: Dictionary) -> void:
	var area := Area3D.new()
	area.name = "Clickable"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = float(entry["height"])
	capsule.radius = 0.45
	shape.shape = capsule
	shape.position = Vector3(0, float(entry["height"]) * 0.5, 0)
	area.add_child(shape)
	area.input_ray_pickable = true
	mover.add_child(area)

	var conversation := String(entry["talk"])
	area.input_event.connect(
		func(_c: Node, event: InputEvent, _p: Vector3, _n: Vector3, _s: int) -> void:
			var click := event as InputEventMouseButton
			if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and not _busy:
				get_viewport().set_input_as_handled()
				_approach_and_talk(mover, conversation))


func _approach_and_talk(target: Mover, conversation: String) -> void:
	_busy = true
	# Stop short of them rather than walking into their chest.
	var toward := (_player.global_position - target.global_position).normalized()
	var spot := target.global_position + toward * 1.1
	spot.y = 0.0
	_player.walk_to(spot)
	await _player.arrived

	if _dialogue.load_conversation(conversation):
		_dialogue.play()
		await _dialogue.finished
	_busy = false


## Music only for now. Generated with Suno, cut into a seamless loop by
## tools/make_loop.py.
##
## There is no ambience bed. Suno's Sounds tab caps a loop at 14 seconds, and what it
## produced for a ship's cabin was closer to noise than to room tone - a 10 second
## cycle of distinctive creaks that announces itself on every repeat. Silence under the
## score is better than that. The player below is a list rather than a single stream so
## an ambience layer can be added back without restructuring: the two have to be mixed
## against each other, not baked together, so the score can duck for a dramatic beat
## while the room keeps breathing.
##
## Quiet on purpose. Dialogue is the content of a point-and-click; the score is the
## thing you notice only when it is missing.
const MUSIC := "res://art/audio/music/quarters_theme.ogg"

func _start_sound() -> void:
	for path in [MUSIC]:
		if not ResourceLoader.exists(path):
			push_warning("no audio at %s" % path)
			continue
		var player := AudioStreamPlayer.new()
		player.name = "Music" if path == MUSIC else "Ambience"
		var stream := load(path) as AudioStream
		# Looping is set on the STREAM, not by restarting on finished: a restart leaves
		# a gap of at least one frame, which is audible on a quiet room tone.
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		player.stream = stream
		player.volume_db = -14.0 if path == MUSIC else -20.0
		add_child(player)
		player.play()


func _add_furniture() -> void:
	_add_box(Vector3(-3.6, 0.38, -1.4), Vector3(1.8, 0.76, 0.9), Color("#4a2f16"))   # desk
	_add_box(Vector3(-3.6, 0.95, -2.1), Vector3(0.5, 1.9, 0.5), Color("#3a2416"))    # chair
	_add_box(Vector3(3.9, 0.45, 1.9), Vector3(0.9, 0.9, 0.9), Color("#4a2f16"))      # crate
	_add_box(Vector3(0.0, 1.55, -3.4), Vector3(0.9, 0.9, 0.08), Color("#86a9c9"))    # porthole
	_add_fishbowl(Vector3(-3.3, 0.76, -1.2))                                         # on the desk


## Count Fingers' bowl. Built from primitives rather than modelled, because a glass
## sphere is the one prop a generator is worst at and a SphereMesh is exactly right.
##
## Three shells, not one. A single hemisphere with a transparent material reads as a
## soap bubble - there is no edge anywhere, so the eye has nothing to tell it the glass
## has substance. An inner shell a few millimetres smaller gives the rim a visible
## thickness and gives every silhouette edge a doubled line, which is what makes it
## look like a vessel instead of a sphere of tint.
func _add_fishbowl(at: Vector3) -> void:
	# Bigger than a real bowl for a 7 cm fish, deliberately. At a true 17 cm the bowl
	# was 40 px across from the room camera and Count Fingers was a speck - and he is a
	# character with lines, not set dressing. Scaled until he reads.
	const RADIUS := 0.26
	const WALL := 0.010

	var bowl := Node3D.new()
	bowl.name = "Fishbowl"
	bowl.position = at
	_room.add_child(bowl)

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.72, 0.86, 0.92, 0.22)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.0
	glass.roughness = 0.04
	# Both faces, because the inside of the far wall is visible through the near one.
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.refraction_enabled = false

	for radius in [RADIUS, RADIUS - WALL]:
		var shell := SphereMesh.new()
		shell.radius = radius
		shell.height = radius * 2.0
		shell.is_hemisphere = true
		shell.radial_segments = 48
		shell.rings = 24
		var piece := MeshInstance3D.new()
		piece.mesh = shell
		# A hemisphere is the TOP half, so it is turned over to make a bowl.
		piece.rotation.x = PI
		piece.position.y = radius
		piece.material_override = glass
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bowl.add_child(piece)

	# The water, sitting a little below the rim. A flat disc is enough: the surface is
	# only ever seen from above the waterline at this camera.
	var water := CylinderMesh.new()
	water.top_radius = RADIUS - WALL * 1.6
	water.bottom_radius = water.top_radius
	water.height = 0.004
	water.radial_segments = 48
	var pool := MeshInstance3D.new()
	pool.mesh = water
	# Well below the rim. At 0.82 the bowl read as a full, shallow dish; the gap between
	# the waterline and the rim is what says "bowl".
	pool.position.y = RADIUS * 0.58
	var wet := StandardMaterial3D.new()
	wet.albedo_color = Color(0.35, 0.62, 0.70, 0.45)
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.roughness = 0.08
	pool.material_override = wet
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bowl.add_child(pool)

	_add_count_fingers(bowl, RADIUS)


## The fish himself, floating inside the bowl. Loaded unrigged: see actors/parts/fish.gd
## for why there is no skeleton to animate.
const COUNT_FINGERS := "res://art/characters/count_fingers/count_fingers_mesh.glb"
## Metres, nose to tail. From his design sheet: "~6-8 cm".
const FISH_LENGTH := 0.15

func _add_count_fingers(bowl: Node3D, radius: float) -> void:
	if not ResourceLoader.exists(COUNT_FINGERS):
		push_warning("Count Fingers: no model at %s" % COUNT_FINGERS)
		return
	var model := (load(COUNT_FINGERS) as PackedScene).instantiate() as Node3D

	# Scale off his measured length rather than a guessed factor, so a re-export at a
	# different size does not quietly put a trout in the bowl.
	var bounds := _visual_bounds(model)
	var longest: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest > 0.0:
		model.scale = Vector3.ONE * (FISH_LENGTH / longest)

	var swimmer := Node3D.new()
	swimmer.name = "CountFingers"
	swimmer.set_script(load("res://actors/parts/fish.gd"))
	# Below the waterline, off-centre, nose out of the glass towards the room.
	swimmer.position = Vector3(0.0, radius * 0.36, 0.0)
	swimmer.add_child(model)
	model.position = -bounds.get_center() * model.scale.x
	bowl.add_child(swimmer)


func _add_box(at: Vector3, size: Vector3, colour: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	mesh.material_override = mat
	_room.add_child(mesh)


func _build_mover(entry: Dictionary) -> Mover:
	var mover := CharacterBody3D.new()
	mover.set_script(Mover)
	mover.name = String(entry["id"])
	mover.character_height = float(entry["height"])

	var height := float(entry["height"])
	var radius := 0.26

	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = height
	capsule.radius = radius
	collider.shape = capsule
	collider.position = Vector3(0, height * 0.5, 0)
	mover.add_child(collider)

	var body := Node3D.new()
	body.name = "Body"
	mover.add_child(body)

	# A real model if one has been delivered, the placeholder block if not. Both land
	# in the same slot, so the room does not know or care which it got.
	if entry.has("model") and ResourceLoader.exists(String(entry["model"])):
		_attach_model(body, String(entry["model"]), float(entry.get("yaw", 0.0)), String(entry["name"]))
		return mover

	var mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.height = height
	capsule_mesh.radius = radius
	mesh.mesh = capsule_mesh
	mesh.position = Vector3(0, height * 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(String(entry["colour"]))
	mesh.material_override = mat
	body.add_child(mesh)

	# A nose, so facing is readable on a capsule. Goes with the real model.
	var nose := MeshInstance3D.new()
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.12, 0.12, 0.24)
	nose.mesh = nose_mesh
	nose.position = Vector3(0, height * 0.82, radius)
	nose.material_override = mat
	body.add_child(nose)

	var tag := Label3D.new()
	tag.text = String(entry["name"])
	tag.position = Vector3(0, height + 0.22, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.004
	tag.modulate = Color(1, 1, 1, 0.85)
	body.add_child(tag)

	return mover


## Drop a glTF character into a body slot.
##
## Deliberately does NOT scale the instantiated node. A skinned mesh carries inverse
## bind matrices that do not scale with it, so scaling the root looks correct by its
## bounds and renders visibly distorted - which is exactly what happened the first
## time. Size is set per-file by `nodes/root_scale` in the .glb.import, the same way
## Pillage People does it.
##
## `yaw` turns the model on the spot without changing which way the body steers, for
## models authored facing the other way.
func _attach_model(body: Node3D, path: String, yaw: float, who: String) -> void:
	var scene: PackedScene = load(path)
	if scene == null:
		push_error("Could not load %s" % path)
		return
	var model := scene.instantiate() as Node3D
	if model == null:
		push_error("%s is not a 3D scene" % path)
		return
	model.name = "Model"
	model.rotation.y = deg_to_rad(yaw)
	body.add_child(model)

	# Stand it up if it arrived Z-up, measured rather than assumed so a model that is
	# already upright is not tipped over.
	var bounds := _visual_bounds(body)
	if bounds.size.z > bounds.size.y * 1.4:
		model.rotation.x = deg_to_rad(90.0)
		bounds = _visual_bounds(body)

	# Feet on the floor, whatever the model's own origin was.
	model.position.y = -bounds.position.y
	print("%s: %.2f x %.2f x %.2f m" % [who, bounds.size.x, bounds.size.y, bounds.size.z])

	# Clips are baked into the character file by tools/merge_animations.py, not copied
	# onto it here. A Blender action stores rotations relative to the armature's OWN
	# rest, so the same action applies to a differently-rested rig correctly; copying
	# track values between skeletons in the engine does not, and shears the mesh.
	_use_baked_clips(model, who)


## Characters arrive from the generator with a skeleton and no animation at all. The
## clips are borrowed from one donor rig and retargeted onto whoever needs them, so a
## new character costs nothing in animation work - see actors/parts/retarget.gd, which
## takes how far each bone has turned from its own T-pose rather than copying raw
## rotations, so differing units and rest poses cancel out.
const CLIP_SOURCE := "res://art/animations/hymotion/walk.fbx"  # needs an A-posed rig
const LOOPING := ["idle", "walk", "run", "swim"]

## Play the clips the character file already carries.
func _use_baked_clips(model: Node3D, who: String) -> void:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_warning("%s: no baked clips" % who)
		return
	var player := players[0] as AnimationPlayer
	var clips := player.get_animation_list()
	for name in ["idle", "walk", "run", "swim"]:
		if player.has_animation(name):
			player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	print("%s: %d baked clips - %s" % [who, clips.size(), ", ".join(clips)])

	# A character whose file carries hand poses gets the layered tree, so a pose can
	# play over whatever the arms are doing. One without them keeps the plain player:
	# an Add2 layer with no clip to feed it is a node that does nothing, and building
	# the graph anyway would hide which characters actually have hands.
	if _has_hand_poses(player):
		_build_tree(model, player, who)
		return

	# Start on the idle. The walk is started by the mover when he actually sets off -
	# see actors/mover/mover.gd. Playing "walk" here left him jogging on the spot in
	# every shot where nobody had clicked the floor yet.
	if player.has_animation("idle"):
		player.play("idle")
	elif clips.size() > 0:
		player.play(clips[0])


## The hand library, in the order a pose is most likely wanted. HAND_REST is what the
## layer holds when nothing has asked for anything: an empty hand at the side is
## slightly curled, never flat, and a flat one reads as a mannequin.
const HAND_POSES := ["hand_relaxed", "hand_open_palm", "hand_point", "hand_grip", "hand_fist"]
const HAND_REST := "hand_relaxed"


func _has_hand_poses(player: AnimationPlayer) -> bool:
	for name in HAND_POSES:
		if player.has_animation(name):
			return true
	return false


## Swap the plain player for the layered graph in actors/parts/animator.gd. The mover
## drives it from here on - see Mover._play - so nothing calls player.play() after this.
func _build_tree(model: Node3D, player: AnimationPlayer, who: String) -> void:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		push_warning("%s: hand poses but no skeleton" % who)
		return
	var skeleton := skeletons[0] as Skeleton3D

	# A pose clip is two identical keys a second apart. Looping it keeps the layer
	# holding the pose instead of running off the end of a one-shot and freezing on
	# whatever the blend happened to be mid-transition.
	for name in HAND_POSES:
		if player.has_animation(name):
			player.get_animation(name).loop_mode = Animation.LOOP_LINEAR

	var tree := AnimationTree.new()
	tree.name = "Layers"
	model.add_child(tree)
	var path := String(model.get_path_to(skeleton))
	var graph := Animator.build(tree, player, path, ["idle", "walk"] as Array[String])

	var hand := graph.get_node("hands_clip") as AnimationNodeAnimation
	if hand != null and player.has_animation(HAND_REST):
		hand.animation = HAND_REST
		tree.set("parameters/hands/add_amount", 1.0)

	print("%s: layered tree at '%s'" % [who, path])
	Animator.describe(graph, skeleton, path)


func _lend_clips(model: Node3D, who: String) -> void:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		push_warning("%s: no skeleton, so no animation" % who)
		return
	var skeleton := skeletons[0] as Skeleton3D

	var player := AnimationPlayer.new()
	player.name = "Clips"
	model.add_child(player)

	var library := BorrowClips.library(CLIP_SOURCE, skeleton, model)
	if library.get_animation_list().is_empty():
		push_warning("%s: clip source gave nothing" % who)
		return
	player.add_animation_library("", library)

	print("%s: %d clips - %s" % [who, library.get_animation_list().size(),
		", ".join(library.get_animation_list())])
	var opening := player.get_animation_list()[0] if player.get_animation_list().size() > 0 else ""
	if player.has_animation(opening):
		player.play(opening)


## Combined bounds of every mesh under a node, in that node's own space.
##
## Transforms are accumulated locally rather than read from global_transform, because
## this runs while the character is still being assembled and not yet in the tree -
## global_transform is only valid once a node is inside it.
func _visual_bounds(root: Node) -> AABB:
	var total := AABB()
	var started := false
	for entry in _meshes_under(root, Transform3D.IDENTITY):
		var mesh: MeshInstance3D = entry[0]
		var where: Transform3D = entry[1]
		var box: AABB = where * mesh.mesh.get_aabb()
		total = box if not started else total.merge(box)
		started = true
	return total


func _meshes_under(node: Node, carried: Transform3D) -> Array:
	var out: Array = []
	for child in node.get_children():
		var here := carried
		var spatial := child as Node3D
		if spatial:
			here = carried * spatial.transform
		var mesh := child as MeshInstance3D
		if mesh and mesh.mesh:
			out.append([mesh, here])
		out.append_array(_meshes_under(child, here))
	return out


## Walks the whole thing unattended: across the room, then a conversation. Checks the
## joins, which is where four separately working systems usually fail.
func _self_check() -> void:
	await get_tree().physics_frame
	print("-- self check --")
	var santi: Mover = _movers["santi"]
	_approach_and_talk(santi, "res://screenplay/santi_galley.json")
	var waited := 0.0
	while _busy and waited < 90.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	print("approach + conversation finished in %.1f s" % waited)
	print("flags: %s" % [_dialogue.flags.keys()])
	get_tree().quit()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()


## Render one frame to disk. A character that loads without error can still be the
## wrong size, sunk into the floor or facing backwards, and none of that shows up in
## a log line.
func _save_shot() -> void:
	for i in 8:
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "res://shot.png"
	image.save_png(path)
	print("saved %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	get_tree().quit()


## The things in Livé's quarters worth clicking. Authored here while there is no room
## editor; each becomes a node in the room scene once there is one.
func _add_hotspots() -> void:
	_hotspot("Porthole", Vector3(0.0, 1.55, -3.3), Vector3(0.0, 0, -2.4), {
		"description": "Fog. The same fog as yesterday, and no closer to telling us where we are.",
	})
	_hotspot("Desk", Vector3(-3.6, 0.8, -1.4), Vector3(-3.6, 0, -0.3), {
		"description": "Charts, a compass, and a dried-out inkwell. He navigates by instinct and blames the charts.",
	})
	_hotspot("Fishbowl", Vector3(-3.3, 0.95, -1.2), Vector3(-3.0, 0, -0.3), {
		"description": "Count Fingers regards you the way a customs officer regards a crate.",
		"gives_item": "fishbowl",
	})
	_hotspot("Crate", Vector3(3.9, 0.9, 1.9), Vector3(3.9, 0, 2.9), {
		"description": "Stencilled LE CHAOS NAVIGUE TOUJOURS PLUS LOIN. Nailed shut.",
		"needs_item": "rapier",
		"refusal": "It is nailed shut, and the captain is not going to use his fingers.",
		"gives_item": "key",
	})


func _hotspot(label: String, at: Vector3, stand: Vector3, props: Dictionary) -> void:
	var spot := Area3D.new()
	spot.set_script(Hotspot)
	spot.name = label
	spot.position = at
	spot.display_name = label
	spot.approach = stand
	for key in props:
		spot.set(key, props[key])

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 0.9, 0.9)
	shape.shape = box
	spot.add_child(shape)
	_room.add_child(spot)

	spot.looked.connect(func(text: String) -> void: _say_as_player(text))
	spot.refused.connect(func(text: String) -> void: _say_as_player(text))
	spot.talked.connect(func(path: String) -> void: _run_dialogue(path))
	spot.used.connect(func(item: String) -> void:
		if _inventory.add(item):
			_say_as_player("Taken: %s." % _inventory.display_name(item))
		else:
			_say_as_player("He already has it."))

	spot.input_event.connect(
		func(_c: Node, event: InputEvent, _p: Vector3, _n: Vector3, _s: int) -> void:
			var click := event as InputEventMouseButton
			if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and not _busy:
				get_viewport().set_input_as_handled()
				_approach_hotspot(spot))


## Walk over, then act. Acting from across the room reads as telekinesis.
func _approach_hotspot(spot: Hotspot) -> void:
	_busy = true
	_player.walk_to(spot.approach)
	await _player.arrived
	spot.interact(spot.resolve(_inventory.selection), _inventory.selection)
	_busy = false


func _say_as_player(text: String) -> void:
	var person: Dictionary = _cast.get("live", {})
	_caption.say(String(person.get("name", "Captain Livé")), text)
	await _caption.advanced
	_caption.hide_box()


func _run_dialogue(path: String) -> void:
	if path.is_empty() or not _dialogue.load_conversation(path):
		return
	_dialogue.play()
	await _dialogue.finished


## Record the scene to a numbered image sequence, for encoding into a video.
##
## Godot's own movie-writer mode drives the clock from the frame rate, which stalls
## anything that awaits a real timer - and this scene is built out of awaits. Grabbing
## the viewport instead plays at normal speed and captures what actually happens.
##
## Frames are counted, not timed: get_process_delta_time() is zero on a node that is
## not processing, which spins the loop forever.
func _record() -> void:
	var dir := ProjectSettings.globalize_path("res://recording")
	DirAccess.make_dir_recursive_absolute(dir)

	var every := 2            # keep every other rendered frame -> 30 fps from 60
	var limit := 30 * 120     # a ceiling, not a target

	# Stop when the scene stops, rather than after a guessed number of seconds. A
	# recording padded with a still room is a recording nobody watches to the end.
	var santi: Mover = _movers["santi"]
	var done := false
	_dialogue.finished.connect(func() -> void: done = true, CONNECT_ONE_SHOT)
	_approach_and_talk(santi, "res://screenplay/santi_galley.json")

	var kept := 0
	var seen := 0
	var tail := 0
	while kept < limit:
		if done:
			tail += 1
			if tail > 45:   # a second and a half to let the last line land
				break
		await RenderingServer.frame_post_draw
		seen += 1
		if seen % every != 0:
			continue
		get_viewport().get_texture().get_image().save_png("%s/f%05d.png" % [dir, kept])
		kept += 1
		if kept % 150 == 0:
			print("  %d frames" % kept)
	print("recorded %d frames to %s" % [kept, dir])
	get_tree().quit()
