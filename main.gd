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
const Highlight := preload("res://ui/highlight/highlight.gd")

## Skip the cold open and start in the room. Defaults ON while the room is being built:
## the cold open is a 35-second 2D cutscene, and sitting through it before every test is
## how a person stops testing - and how you conclude the 3D room is not there at all.
## Turn it off to see the game as a player meets it.
@export var skip_cold_open := true

## The cabin, as authored. Built from the tables below only when this is missing or
## when --pack is regenerating it.
const CABIN := "res://rooms/captains_cabin/captains_cabin.tscn"

## Who is in the room, from data/cast.json - the same list tools/build_cabin.gd
## places when a room is first built.
const Cabin := preload("res://tools/build_cabin.gd")
@onready var _cast_list: Array = Cabin.load_cast()

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
	for entry in _cast_list:
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

	if "--pack" in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		# One-off: build the cabin from the tables and write it out as scenes. The
		# game never takes this path - see tools/build_cabin.gd.
		var builder: Node = preload("res://tools/build_cabin.gd").new()
		add_child(builder)
		await builder.build_and_pack(self)
		get_tree().quit()
		return
	await _open_room()

	add_child(preload("res://systems/audio/audio.gd").new())
	_room.floor_clicked.connect(_on_floor_clicked)
	print("In the room. Click the floor to walk, click Santi to talk. Esc quits.")

	var args2 := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	# A screenshot run wants the scene left alive to photograph; the self-check quits
	# when it is done, so the two cannot both run.
	if _auto and not ("--shot" in args2 or "--record" in args2):
		await _self_check()
	if "--record" in args2:
		await _record()
	# Stylised-lighting comparison. A tool, not the game - see tools/look_test.gd.
	var look := ""
	for i in args2.size():
		if args2[i] == "--look" and i + 1 < args2.size():
			look = args2[i + 1]
	if not look.is_empty():
		preload("res://tools/look_test.gd").apply(_room, look, self)
		await get_tree().process_frame

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


## The cabin as the owner authored it: every prop and character already placed, with
## the transforms he dragged them to. Nothing here decides where anything goes.
##
## What the scene cannot carry is the wiring. Signal connections in this project are
## lambdas, and a lambda has no resource path, so none of them survive into a .tscn -
## the nodes come back and every connection has to be made again here.
func _open_room() -> void:
	_room = (load(CABIN) as PackedScene).instantiate() as Room3D
	add_child(_room)

	for entry in _cast_list:
		var mover := _room.get_node_or_null(NodePath(String(entry["id"]))) as Mover
		if mover == null:
			push_error("%s: not in %s" % [entry["id"], CABIN])
			continue
		_movers[entry["id"]] = mover
		if entry["id"] == "live":
			_player = mover
		if entry.has("talk"):
			var area := mover.get_node_or_null("Clickable") as Area3D
			if area:
				_wire_talk(mover, area, entry)
			else:
				_add_talk_trigger(mover, entry)

	for node in _room.find_children("*", "Area3D", true, false):
		if node is Hotspot:
			_wire_hotspot(node as Hotspot)

	# The navigation mesh is baked, not saved: it is cut around the solid bodies and
	# those are exactly what the owner moves. Baking on load means dragging the crate
	# changes where he can walk, with no extra step to remember.
	_room.rebake_navigation()
	await _room.await_navigation()
func _hover_hotspot(spot: Hotspot) -> void:
	if _busy:
		return
	_hovered = spot
	Highlight.set_on(spot, true, _room)
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
	Highlight.set_on(what, false, _room)
	_hovered = null
	_pointer.clear()


## A rim of light on whatever the cursor is over. Cheap, readable over any backdrop,
## and it does not shift the thing it is marking - an outline that grows the silhouette
## reads as the object moving.
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
	_wire_talk(mover, area, entry)


## Connect a character's click area. Split from building it for the same reason as
## _wire_hotspot: the area is in the authored scene, its signals cannot be.
func _wire_talk(mover: Mover, area: Area3D, entry: Dictionary) -> void:
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


func _wire_hotspot(spot: Hotspot) -> void:
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
