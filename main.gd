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
const Pointer := preload("res://ui/pointer.gd")

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
	# `assets` is the folder under art/characters and the key in the speech data. It is
	# not the same as `id`: the id is what the screenplay calls them, which is short
	# because a writer types it a thousand times. Keeping both means a character can be
	# renamed in the script without moving any files.
	{ "id": "live", "name": "Captain Livé", "assets": "captain_live",
	  "height": 1.9, "colour": "#1c1a1f", "at": Vector3(-1.4, 0, 1.2),
	  "model": "res://art/characters/captain_live/captain_live_hands.glb" },
	{ "id": "santi", "name": "Santi Wong", "assets": "santi_wong",
	  "height": 1.7, "colour": "#efe6d8", "at": Vector3(2.2, 0, 0.2),
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
var _pointer: Pointer
var _hovered: Node = null
var _busy := false  ## A cutscene or conversation is running; the room ignores clicks.
## Puzzle state. Set by item combinations and by conversations, read by both. Flat
## names rather than a tree, because a puzzle that needs a tree of state is a puzzle
## nobody will solve.
var _flags: Dictionary = {}
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
	# The screenplay names the characters; CAST knows where their art lives. Merge the
	# asset ids in rather than making the writer put folder names in a script file -
	# without this the portrait looks for art/characters/live/ and silently finds
	# nothing, so a character with a perfectly good head shows the placeholder.
	for entry in CAST:
		var id := String(entry["id"])
		if _cast.has(id):
			_cast[id]["assets"] = entry.get("assets", id)

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
	# One flag store for the whole game. Prising the crate open and asking Santi about
	# the captive now write to the same place.
	_dialogue.use_flags(_flags)
	_dialogue.verbose = _auto

	_pointer = Pointer.new()
	_pointer.name = "Pointer"
	add_child(_pointer)

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
	await _add_furniture()

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
		if "--hover" in args2:
			# Put the cursor on something clickable so the caption and the highlight
			# are in the picture. Without a real mouse position there is nothing to
			# photograph - hover state does not exist until something is under it.
			# By TYPE, not by name: the hotspot and the mesh it lights up are both
			# called "Crate", and find_child returns whichever comes first.
			var crate: Hotspot = null
			for node in _room.find_children("*", "Area3D", true, false):
				if node is Hotspot and (node as Hotspot).display_name == "Crate":
					crate = node as Hotspot
					break
			if crate:
				Input.warp_mouse(_room.camera.unproject_position(crate.global_position))
				await get_tree().process_frame
				await get_tree().process_frame
				_hover_hotspot(crate)
			await get_tree().create_timer(0.4).timeout
		if "--bag" in args2:
			# The inventory open, with its rendered icons in it. Its own flag because
			# the icons are a separate render path from the portrait and have broken
			# separately - a grey tile behind every item, from the same cause.
			for item in ["compass", "rolled_charts", "brass_inkwell"]:
				_inventory.add(item)
			await _inventory.toggle()
			await get_tree().create_timer(0.6).timeout
		if "--talking" in OS.get_cmdline_user_args() + OS.get_cmdline_args():
			# Through the REAL conversation, not a say() of our own. Calling say()
			# directly bypasses the cast lookup, which is exactly where the portrait
			# was broken - it photographed fine while the game showed nothing.
			_caption.auto_advance_secs = 1.4
			_choices.auto_pick_secs = 0.4
			var santi: Mover = _movers["santi"]
			_approach_and_talk(santi, "res://screenplay/santi_galley.json")
			# Wait for a line whose speaker actually has a head piece, rather than
			# shooting at a fixed time and catching Santi or a choice menu.
			var waited := 0.0
			while waited < 30.0:
				await get_tree().create_timer(0.2).timeout
				waited += 0.2
				if _caption.speaking_with_portrait():
					break
			await get_tree().create_timer(0.5).timeout
		await _save_shot()


## Name what is under the cursor, and say what clicking would do. The verb depends on
## what is being carried, so this is recomputed on hover rather than cached - picking
## up the rapier changes what the crate offers without the cursor leaving it.
func _hover_hotspot(spot: Hotspot) -> void:
	if _busy:
		return
	_hovered = spot
	_highlight(spot, true)
	var verb := spot.resolve(_inventory.selection)
	var held := _inventory.display_name(_inventory.selection) if not _inventory.selection.is_empty() else ""
	_pointer.point_at(spot.display_name, spot.phrase(verb, held))


func _hover_person(mover: Node3D, who: String) -> void:
	if _busy:
		return
	_hovered = mover
	_pointer.point_at(who, "Talk to %s" % who)


func _unhover(what: Node) -> void:
	if _hovered != what:
		return
	_highlight(what, false)
	_hovered = null
	_pointer.clear()


## A rim of light on whatever the cursor is over. Cheap, readable over any backdrop,
## and it does not shift the thing it is marking - an outline that grows the silhouette
## reads as the object moving.
func _highlight(what: Node, on: bool) -> void:
	# A hotspot has no mesh of its own, so it names one - see _hotspot().
	var target: Node = what
	if what.has_meta("visual"):
		var named := _room.find_child(String(what.get_meta("visual")), true, false)
		if named:
			target = named
	for node in _meshes_of(target):
		var mesh := node as MeshInstance3D
		# material_override beats any surface override, so a mesh that has one has to
		# be lit through it - setting a surface override on a box built by _add_box
		# changes nothing at all, silently.
		if mesh.material_override is BaseMaterial3D:
			_set_glow(mesh.material_override as BaseMaterial3D, on)
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material is BaseMaterial3D:
				var lit: BaseMaterial3D = mesh.get_surface_override_material(surface) as BaseMaterial3D
				if lit == null:
					lit = (material as BaseMaterial3D).duplicate()
					mesh.set_surface_override_material(surface, lit)
				_set_glow(lit, on)


## A lift rather than a glow. Warm, not white, so it reads as lamplight catching the
## thing rather than as a selection box - and faint, because 0.9 turned the crate into
## a lantern. The player needs to know it is clickable, not be dazzled by it.
func _set_glow(material: BaseMaterial3D, on: bool) -> void:
	material.emission_enabled = on
	material.emission = Color("#c79a52")
	material.emission_energy_multiplier = 0.18 if on else 0.0


## Every mesh in or under a node, including the node itself. A generated prop is a
## mesh inside a scene; a placeholder box IS the mesh.
func _meshes_of(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		out.append(child)
	return out


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
	var who := String(entry.get("name", entry["id"]))
	area.mouse_entered.connect(_hover_person.bind(mover, who))
	area.mouse_exited.connect(_unhover.bind(mover))


func _approach_and_talk(target: Mover, conversation: String) -> void:
	_busy = true
	_pointer.clear()
	# Stop short of them rather than walking into their chest, and face them when we
	# get there. A character carries an obstacle, so the path already goes around them
	# rather than through - this is only about where to stop.
	var spot := Approach.default_for(target.global_position, _player.global_position, 1.1)
	var map := get_world_3d().navigation_map
	if map.is_valid():
		spot = NavigationServer3D.map_get_closest_point(map, spot)
	var toward := target.global_position - spot
	toward.y = 0.0
	var facing := rad_to_deg(atan2(toward.x, toward.z)) if toward.length() > 0.001 else NAN
	_player.walk_to(spot, facing)
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


## What is in Livé's quarters, as data rather than as a list of calls.
##
## A const so the navigation check can build the same room the game does - a check
## against a hand-copied layout stops testing the game the moment either drifts.
## `solid` false is scenery: it is drawn, but nothing is cut out of the floor for it.
## A piece with a `model` is real art and the box is only its collision; one without is
## still a grey box standing in until its turnaround exists. `size` is the true size in
## metres either way - Tripo normalises everything it generates to roughly 1.0, so a
## desk and an inkwell come back the same size and the sidecar's dimensions_m is what
## makes one furniture and the other something you could lose in a pocket.
const FURNITURE := [
	{ "name": "desk", "at": Vector3(-3.6, 0.38, -1.4), "size": Vector3(1.8, 0.76, 0.9),
	  "colour": "#4a2f16", "model": "res://art/props/captain_desk/captain_desk.glb" },
	# 0.5 x 1.0 x 0.5 from the chair's own sidecar. The box that stood here was 1.9 m
	# tall, which is a wardrobe, not a chair.
	{ "name": "chair", "at": Vector3(-3.6, 0.50, -2.1), "size": Vector3(0.5, 1.0, 0.5),
	  "colour": "#3a2416", "model": "res://art/props/captain_chair/captain_chair.glb",
	  "spin": Vector3(-90, 180, 0) },
	# The nailed supply crate - its own prop, not the brass skull chest. Both are 0.9 m
	# cubes and for one commit the chest stood in for it; the owner kept them separate.
	{ "name": "crate", "at": Vector3(3.9, 0.45, 1.9), "size": Vector3(0.9, 0.9, 0.9),
	  "colour": "#4a2f16", "model": "res://art/props/supply_crate/supply_crate.glb",
	  "spin": Vector3(0, 0, 0) },
	# The skull chest, against the right wall, as in docs/reference/room_target.png.
	{ "name": "chest", "at": Vector3(4.0, 0.45, -0.6), "size": Vector3(0.9, 0.9, 0.9),
	  "colour": "#4a2f16", "model": "res://art/props/pirate_chest/pirate_chest.glb",
	  "spin": Vector3(90, 180, 0) },
	# Set into the back wall, so it blocks nothing on the floor. The brass ring is the
	# art; the weather behind it is still the flat blue the box used to be.
	{ "name": "porthole", "at": Vector3(0.0, 1.55, -3.4), "size": Vector3(0.9, 0.9, 0.9),
	  "colour": "#86a9c9", "solid": false,
	  "model": "res://art/props/porthole/porthole.glb" },
]

## Small things standing on the furniture. Not FURNITURE, because they are not solid -
## you walk up to the desk, not around a compass - and because they are picked up.
const DRESSING := [
	{ "name": "compass", "at": Vector3(-3.9, 0.78, -1.25), "size": Vector3(0.09, 0.03, 0.09),
	  "model": "res://art/props/compass/compass.glb", "lie_flat": true },
	{ "name": "brass_inkwell", "at": Vector3(-3.1, 0.80, -1.55), "size": Vector3(0.08, 0.07, 0.08),
	  "model": "res://art/props/brass_inkwell/brass_inkwell.glb" },
	# Lying on the desk holding down a chart, which is what its hotspot says it does.
	{ "name": "rapier", "at": Vector3(-3.3, 0.79, -1.15), "size": Vector3(0.25, 0.14, 1.05),
	  "model": "res://art/props/rapier/rapier.glb", "lie_flat": true },
]


## Awaits the navigation sync at the end, so callers must await it too.
func _add_furniture() -> void:
	for piece in FURNITURE:
		if piece.has("model"):
			_add_prop(piece)
			_add_collision(piece["at"], piece["size"])
		else:
			_add_box(piece["at"], piece["size"], Color(String(piece["colour"])),
				bool(piece.get("solid", true)), String(piece["name"]))
	for piece in DRESSING:
		_add_prop(piece)
	_add_prop({ "name": "bowl_stand", "at": BOWL_AT + Vector3(0.0, BOWL_STAND_HEIGHT * 0.5, 0.0),
		"size": Vector3(0.6, BOWL_STAND_HEIGHT, 0.6),
		"model": "res://art/props/bowl_stand/bowl_stand.glb" })
	_add_collision(BOWL_AT + Vector3(0.0, BOWL_STAND_HEIGHT * 0.5, 0.0),
		Vector3(0.6, BOWL_STAND_HEIGHT, 0.6))
	# Count Fingers comes off the desk and onto his own pedestal in the foreground,
	# left, where the owner's target render puts him - near the camera, big enough that
	# his face reads, and where the dialogue bar may cover him without losing anything.
	_add_fishbowl(BOWL_AT + Vector3(0.0, BOWL_STAND_HEIGHT, 0.0))

	# Everything solid is in, so the walkable area can be worked out. Bake once here
	# rather than per prop: baking is not cheap and nothing walks before this point.
	_room.rebake_navigation()
	# And wait for the server to actually answer before anyone is allowed to click.
	# See Room3D.await_navigation - the first sync does not carry the mesh.
	await _room.await_navigation()


## Count Fingers' bowl. Built from primitives rather than modelled, because a glass
## sphere is the one prop a generator is worst at and a SphereMesh is exactly right.
##
## Three shells, not one. A single hemisphere with a transparent material reads as a
## soap bubble - there is no edge anywhere, so the eye has nothing to tell it the glass
## has substance. An inner shell a few millimetres smaller gives the rim a visible
## thickness and gives every silhouette edge a doubled line, which is what makes it
## look like a vessel instead of a sphere of tint.
## The generated bowl. Still sealed - the owner opens the mouth in Blender by eye,
## because the dish Tripo reconstructed is not axis aligned and a measured cut kept
## taking the bite out of the far side.
const BOWL_MODEL := "res://art/props/fishbowl/fishbowl.glb"
## Where Count Fingers lives, and how high his pedestal stands him. The bowl sits on
## top of the stand, so one number moves both.
const BOWL_AT := Vector3(-2.9, 0.0, 1.5)
const BOWL_STAND_HEIGHT := 0.65

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

	# The generated bowl if there is one, primitives if not. The generated mesh has the
	# brass rim and the turned shape the design has and a sphere never will; what it
	# does NOT have is glass, because a generator delights its textures and cannot make
	# a transparent surface. So the mesh comes from the art and the glass comes from
	# here - its own texture is dropped entirely by the override.
	var model := load(BOWL_MODEL) as PackedScene if ResourceLoader.exists(BOWL_MODEL) else null
	if model:
		var mesh_root := model.instantiate() as Node3D
		# Tripo read the bowl's mouth as a dish on the FRONT of a sphere, so the model
		# arrives lying on its back. Stood up first, then measured: fitting it by an
		# unrotated box sizes it by its depth and leaves it floating off the stand.
		var upright := Basis.from_euler(Vector3(deg_to_rad(-90.0), 0.0, 0.0))
		var box: AABB = Transform3D(upright, Vector3.ZERO) * _visual_bounds(mesh_root)
		var fit: float = (RADIUS * 2.0) / maxf(box.size.y, 0.001)
		mesh_root.transform = Transform3D(upright.scaled(Vector3.ONE * fit),
			Vector3(-box.get_center().x * fit, -box.position.y * fit,
				-box.get_center().z * fit))
		for node in mesh_root.find_children("*", "MeshInstance3D", true, false):
			var vis := node as MeshInstance3D
			vis.material_override = glass
			vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bowl.add_child(mesh_root)
	else:
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


## A generated prop, scaled to its real size and stood on the floor.
##
## Tripo normalises everything to roughly 1.0 on its longest axis, so the model's own
## size means nothing - `size` from the sidecar is what makes a desk 1.8 m and an
## inkwell 8 cm. Scaled uniformly by the longest axis rather than stretched to fit the
## box, because a prop squashed to match a guessed depth looks wrong in a way nobody
## can point at.
func _add_prop(piece: Dictionary) -> void:
	var scene: PackedScene = load(String(piece["model"]))
	if scene == null:
		push_warning("%s: no model at %s" % [piece["name"], piece["model"]])
		return
	var model := scene.instantiate() as Node3D
	model.name = String(piece["name"]).capitalize()
	_room.add_child(model)

	# _visual_bounds measures in the model's OWN space, before its transform - so the
	# scale and rotation have to be applied to the box by hand rather than measured
	# again afterwards.
	var local := _visual_bounds(model)
	if local.size.x <= 0.0:
		push_warning("%s: model has no visible mesh" % piece["name"])
		return

	# Some props are modelled standing on edge so that all four views could show the
	# face of them - the compass is a disc photographed head-on. Lay it down first.
	var basis := Basis.IDENTITY
	if bool(piece.get("lie_flat", false)):
		basis = Basis.from_euler(Vector3(deg_to_rad(-90.0), 0.0, 0.0))
	# Tripo orients a multiview reconstruction so the FRONT view faces up, which lands
	# the chest in the room on its back with the skull pointing at the ceiling. There
	# is nothing in the mesh to detect that from - a 0.9 m cube has no up - so it is
	# stated per piece rather than guessed.
	if piece.has("spin"):
		# Applied as three separate turns, X then Y then Z, rather than one Euler:
		# Basis.from_euler's own order put the crate back on its face when a Y turn
		# was added to stand it up, and "stand it up, THEN turn it round" is the only
		# order that means anything to whoever is placing a prop.
		var spin: Vector3 = piece["spin"]
		basis = Basis(Vector3.RIGHT, deg_to_rad(spin.x)) * basis
		basis = Basis(Vector3.UP, deg_to_rad(spin.y)) * basis
		basis = Basis(Vector3.BACK, deg_to_rad(spin.z)) * basis

	var size: Vector3 = piece["size"]
	var longest: float = maxf(local.size.x, maxf(local.size.y, local.size.z))
	var wanted: float = maxf(size.x, maxf(size.y, size.z))
	var factor: float = wanted / maxf(longest, 0.0001)
	basis = basis.scaled(Vector3.ONE * factor)

	# Where the model's own box ends up once rotated and scaled, so it can be moved to
	# sit centred on the spot the data gives.
	var placed: AABB = Transform3D(basis, Vector3.ZERO) * local
	model.transform = Transform3D(basis, Vector3(piece["at"]) - placed.get_center())


## The collision for a prop whose art has arrived. Separate from the mesh, because a
## generated model's own shape is far more detail than a walkable area needs and the
## box is what the navigation bake reads.
func _add_collision(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.position = at
	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = size
	shape.shape = collider
	body.add_child(shape)
	body.add_to_group(Room3D.NAV_SOURCE)
	_room.add_child(body)


## A piece of furniture: a visual box and a solid body the same size.
##
## The body is what makes it a thing rather than a picture. It stops the character
## walking through it, it is what the walkable area is cut around (see Room3D.NAV_SOURCE),
## and it is what a click has to land on. A mesh with no body is scenery.
func _add_box(at: Vector3, size: Vector3, colour: Color, solid := true, label := "") -> void:
	var mesh := MeshInstance3D.new()
	if not label.is_empty():
		mesh.name = label.capitalize()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	mesh.material_override = mat
	_room.add_child(mesh)
	if not solid:
		return

	var body := StaticBody3D.new()
	body.name = "Solid"
	body.position = at
	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = size
	shape.shape = collider
	body.add_child(shape)
	body.add_to_group(Room3D.NAV_SOURCE)
	_room.add_child(body)


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
## The things worth clicking, as data for the same reason as FURNITURE. `stand` is the
## fallback approach; ZERO means work it out from wherever the character happens to be.
const HOTSPOTS := [
	{ "label": "Porthole", "at": Vector3(0.0, 1.55, -3.3), "stand": Vector3(0.0, 0, -2.4), "visual": "Porthole",
	  "props": { "description": "Fog. The same fog as yesterday, and no closer to telling us where we are." } },
	{ "label": "Desk", "at": Vector3(-3.6, 0.8, -1.4), "stand": Vector3(-3.6, 0, -0.3), "visual": "Desk",
	  "props": { "description": "Charts, a compass, and a dried-out inkwell. He navigates by instinct and blames the charts." } },
	{ "label": "Fishbowl", "at": Vector3(-3.3, 0.95, -1.2), "stand": Vector3(-3.0, 0, -0.3), "visual": "Fishbowl",
	  "props": { "description": "Count Fingers regards you the way a customs officer regards a crate.",
	             "gives_item": "fishbowl",
	             "combinations": {
	               "brass_inkwell": { "say": "He holds the inkwell over the bowl. Count Fingers does not blink, because he cannot, but the intent is there." },
	               "compass": { "say": "The needle swings towards the fish and stays there. Livé decides not to think about that." },
	             } } },
	# Without this the crate cannot be opened: its answer is the rapier and nothing in
	# the room handed one out. Caught by playcombo.gd, which walks the real data and
	# refuses a combination keyed on an item the player can never be holding.
	{ "label": "Rapier", "at": Vector3(-3.3, 0.86, -1.15), "stand": Vector3(-3.3, 0, -0.3),
	  "props": { "description": "Thin, French, and considerably better travelled than most men. It is holding down a chart.",
	             "gives_item": "rapier" } },
	{ "label": "Compass", "at": Vector3(-3.9, 0.82, -1.25), "stand": Vector3(-3.9, 0, -0.3), "visual": "Compass",
	  "props": { "description": "The needle swings, settles, and points at nothing in particular. Much like its owner.",
	             "gives_item": "compass" } },
	{ "label": "Inkwell", "at": Vector3(-3.1, 0.84, -1.55), "stand": Vector3(-3.1, 0, -0.3), "visual": "Brass_inkwell",
	  "props": { "description": "Dry since the second week. He writes the log from memory, which is why it is a work of fiction.",
	             "gives_item": "brass_inkwell" } },
	{ "label": "Crate", "at": Vector3(3.9, 0.9, 1.9), "stand": Vector3(3.9, 0, 2.9), "visual": "Crate",
	  "props": { "description": "Stencilled LE CHAOS NAVIGUE TOUJOURS PLUS LOIN. Nailed shut.",
	             "refusal": "It is nailed shut, and the captain is not going to use his fingers.",
	             "combinations": {
	               "rapier": { "say": "The lid comes up with a noise like a small argument. Inside: a key, and three years of damp.",
	                           "gives": "key", "sets": "crate_open", "solved": true },
	               "compass": { "say": "He holds the compass to the crate. The needle, loyal to nothing, points at the crate." },
	               "brass_inkwell": { "say": "He considers prising the lid with an inkwell, and his hand stops before his pride does." },
	               "fishbowl": { "say": "Count Fingers regards the crate. The crate, being a crate, does not regard him back." },
	             } } },
]


func _add_hotspots() -> void:
	for entry in HOTSPOTS:
		_hotspot(String(entry["label"]), entry["at"], entry["stand"], entry["props"],
			String(entry.get("visual", "")))


## `visual` names the room child to light up on hover. A hotspot is an invisible area;
## the thing the player sees is a separate mesh, and without this the caption appears
## while nothing on screen responds.
func _hotspot(label: String, at: Vector3, stand: Vector3, props: Dictionary,
		visual := "") -> void:
	var spot := Area3D.new()
	spot.set_script(Hotspot)
	spot.name = label
	spot.position = at
	spot.display_name = label
	if stand != Vector3.ZERO:
		var where := Approach.new()
		where.at = stand
		spot.approach = where
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
	spot.combined.connect(func(item: String, outcome: Dictionary) -> void:
		_apply_outcome(spot, item, outcome))

	spot.input_event.connect(
		func(_c: Node, event: InputEvent, _p: Vector3, _n: Vector3, _s: int) -> void:
			var click := event as InputEventMouseButton
			if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and not _busy:
				get_viewport().set_input_as_handled()
				_approach_hotspot(spot))
	if not visual.is_empty():
		spot.set_meta("visual", visual)
	spot.mouse_entered.connect(_hover_hotspot.bind(spot))
	spot.mouse_exited.connect(_unhover.bind(spot))


## Walk over, then act. Acting from across the room reads as telekinesis.
##
## Which verb it is decides WHERE he stands, not just what happens when he gets there -
## see room3d/approach.gd. Resolved before the walk, because the verb is already known
## from what he is carrying.
func _approach_hotspot(spot: Hotspot) -> void:
	_busy = true
	_pointer.clear()
	var verb := spot.resolve(_inventory.selection)
	var where := spot.resolve_approach(verb, _player.global_position)
	_player.walk_to(where["at"], where["facing"])
	await _player.arrived
	spot.interact(verb, _inventory.selection)
	_busy = false


## What using one item on one thing actually does. The hotspot decides WHETHER, the
## room decides what happens - because moving items, setting flags and saying lines
## are the room's business and a hotspot that did them would need to know about the
## inventory, the caption and the flags.
func _apply_outcome(spot: Hotspot, item: String, outcome: Dictionary) -> void:
	# `takes` first: a key still in your pocket after it has opened the door is a key
	# you will keep trying on every other door.
	if outcome.has("takes"):
		_inventory.remove(String(outcome["takes"]))
	elif bool(outcome.get("solved", false)):
		# The intended answer consumes the item it was solved with unless the data
		# says otherwise, which is right far more often than not.
		if outcome.get("keeps", false) == false:
			_inventory.remove(item)
	if outcome.has("gives"):
		_inventory.add(String(outcome["gives"]))
	if outcome.has("sets"):
		_flags[String(outcome["sets"])] = true
	if bool(outcome.get("solved", false)):
		# Solved once. Clearing the combinations stops the same line firing twice and
		# stops a consumed item being conjured back out of a crate already open.
		spot.combinations = {}
		spot.needs_item = ""
		spot.gives_item = ""
	if outcome.has("say"):
		await _say_as_player(String(outcome["say"]))


func _say_as_player(text: String) -> void:
	var person: Dictionary = _cast.get("live", {})
	_caption.say(String(person.get("name", "Captain Livé")), text,
		String(person.get("assets", "captain_live")),
		Color(String(person.get("colour", "#1c1a1f"))))
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
