extends Node
## Builds Captain Livé's quarters from the tables below and writes it out as scenes.
##
##     godot --path . -- --pack
##
## This is a TOOL, not the game. The game opens
## rooms/captains_cabin/captains_cabin.tscn and never runs a line of this file; the
## owner moves things by dragging them in the editor, which is CONVENTIONS.md Part 0.
## What this is for is the first build of a room, and rebuilding one after the tables
## change - it beats re-typing a hundred Vector3s by hand, and the scene it writes
## matches what was on screen exactly.
##
## It lives in tools/ rather than in main.gd because every line of it ran at startup
## for the whole of the project so far, which is how main.gd reached 1,243 lines and
## how moving a chair became "edit a Vector3, render a screenshot, squint at it".
##
## It writes three kinds of file:
##
##   actors/<assets>/<assets>.tscn    one per character
##   rooms/<room>/<room>.tscn         the room, instancing all of it
##
## Prop prefabs are NOT written here - tools/make_prefabs.gd does those, from each
## prop's own asset.json. This file only places them.

const Room3D := preload("res://room3d/room3d.gd")
const Mover := preload("res://actors/mover/mover.gd")
const Animator := preload("res://actors/parts/animator.gd")
const BorrowClips := preload("res://actors/parts/borrow_clips.gd")
const Hotspot := preload("res://room3d/hotspot.gd")
const Approach := preload("res://room3d/approach.gd")

## Where the finished room goes.
const CABIN := "res://rooms/captains_cabin/captains_cabin.tscn"

var _room: Room3D
var _movers: Dictionary = {}


## Build the cabin, write every scene, and report. The caller quits afterwards.
func build_and_pack(host: Node) -> void:
	await _build_room(host)
	_pack_room()


## Who is in the first room, and where. Heights are from the character sheets.
##
## Scene 1 of the cold open: Livé in his quarters with Count Fingers, and Santi comes
## in to complain. Nobody else is in the room.
## Who is in the first room. Data rather than code so the game and
## tools/build_cabin.gd read the same list - see data/cast.json.
const CAST_PATH := "res://data/cast.json"


## The cast, with `at` turned back into a Vector3. Dictionaries rather than a typed
## resource because this is read in two places and written by hand.
static func load_cast() -> Array:
	if not FileAccess.file_exists(CAST_PATH):
		push_error("no cast at %s" % CAST_PATH)
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAST_PATH))
	if not (parsed is Dictionary):
		return []
	var out: Array = []
	for entry in parsed.get("cast", []):
		var row: Dictionary = (entry as Dictionary).duplicate()
		var at: Array = row.get("at", [0, 0, 0])
		row["at"] = Vector3(float(at[0]), float(at[1]), float(at[2]))
		out.append(row)
	return out




## Build the cabin from the data tables instead of opening the scene. Kept for one
## job: regenerating the scene after the tables change, with `--pack`. The game does
## not take this path.
func _build_room(host: Node) -> void:
	_room = Room3D.new()
	_room.name = "CaptainQuarters"
	host.add_child(_room)
	await _add_furniture()

	for entry in load_cast():
		var mover := _build_mover(entry)
		_room.add_child(mover)
		mover.global_position = entry["at"]
		_movers[entry["id"]] = mover
		if entry.has("talk"):
			_add_click_area(mover, entry)

	_add_hotspots()


## Save the built room as rooms/captains_cabin/captains_cabin.tscn.
##
## PackedScene only keeps nodes whose `owner` is the scene root, and nothing built in
## code has an owner, so the tree is walked and claimed first. Run once:
##
##     godot --path . -- --pack


## Save the built room as rooms/captains_cabin/captains_cabin.tscn.
##
## PackedScene only keeps nodes whose `owner` is the scene root, and nothing built in
## code has an owner, so the tree is walked and claimed first. Run once:
##
##     godot --path . -- --pack
func _pack_room() -> void:
	_pack_cast()
	_claim(_room, _room)
	var packed := PackedScene.new()
	var err := packed.pack(_room)
	if err != OK:
		push_error("pack_room: could not pack (%d)" % err)
		return
	err = ResourceSaver.save(packed, CABIN)
	if err != OK:
		push_error("pack_room: could not save %s (%d)" % [CABIN, err])
		return
	print("packed %d nodes to %s" % [_count(_room), CABIN])


## Claim the nodes we built, and STOP at anything that is an instance of another
## scene. Claiming a .glb's internal MeshInstance3D makes Godot save it as an editable
## child with its full state, which writes the whole mesh into the .tscn - the first
## attempt came out 8.7 MB with 24 ArrayMeshes inlined, duplicating the GLBs and
## guaranteeing the scene goes stale the moment one is re-exported.
## Each character as a prefab at actors/<assets>/<assets>.tscn, then swapped in the
## room for an instance of itself.
##
## Packed from the LIVE node rather than rebuilt by the prefab tool, because building a
## character is forty lines of capsule, model, feet-on-the-floor and animation tree, and
## the one thing worse than that living in main.gd is it living in main.gd AND in a
## generator, where the two drift and nobody notices which one the game used.


## Claim the nodes we built, and STOP at anything that is an instance of another
## scene. Claiming a .glb's internal MeshInstance3D makes Godot save it as an editable
## child with its full state, which writes the whole mesh into the .tscn - the first
## attempt came out 8.7 MB with 24 ArrayMeshes inlined, duplicating the GLBs and
## guaranteeing the scene goes stale the moment one is re-exported.
## Each character as a prefab at actors/<assets>/<assets>.tscn, then swapped in the
## room for an instance of itself.
##
## Packed from the LIVE node rather than rebuilt by the prefab tool, because building a
## character is forty lines of capsule, model, feet-on-the-floor and animation tree, and
## the one thing worse than that living in main.gd is it living in main.gd AND in a
## generator, where the two drift and nobody notices which one the game used.
func _pack_cast() -> void:
	for entry in load_cast():
		var id := String(entry["id"])
		var mover := _movers.get(id) as Node3D
		if mover == null:
			continue
		var folder := "res://actors/%s" % entry["assets"]
		var out := "%s/%s.tscn" % [folder, entry["assets"]]

		# Unlit, like every prop. A CHILD rather than a script on the root, because
		# the root already has mover.gd - and setting the material directly does not
		# survive packing: it lives on a node inside the imported .glb, which is not
		# saved, and the character comes back a black silhouette.
		if mover.get_node_or_null("Unlit") == null:
			var flat := Node3D.new()
			flat.name = "Unlit"
			flat.set_script(load("res://props/parts/unlit.gd"))
			flat.set("target", NodePath(".."))
			mover.add_child(flat)

		_claim(mover, mover)
		var packed := PackedScene.new()
		if packed.pack(mover) != OK:
			push_error("%s: pack failed" % id)
			continue
		DirAccess.make_dir_recursive_absolute(folder)
		if ResourceSaver.save(packed, out) != OK:
			push_error("%s: could not save %s" % [id, out])
			continue

		# Swap the built node for an instance of what we just saved, so the room holds
		# a reference to the prefab rather than another copy of its guts.
		var where := mover.transform
		_room.remove_child(mover)
		mover.queue_free()
		var instance := (load(out) as PackedScene).instantiate() as Node3D
		instance.name = id
		instance.transform = where
		_room.add_child(instance)
		_movers[id] = instance
		print("%-16s %s" % [entry["assets"], out])




static func _claim(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path.is_empty():
			_claim(child, root)




static func _count(node: Node) -> int:
	var n := 1
	for child in node.get_children():
		n += _count(child)
	return n


## Name what is under the cursor, and say what clicking would do. The verb depends on
## what is being carried, so this is recomputed on hover rather than cached - picking
## up the rapier changes what the crate offers without the cursor leaving it.
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
	{ "name": "desk", "prop": "captain_desk", "at": Vector3(-3.6, 0.38, -1.4), "size": Vector3(1.8, 0.76, 0.9),
	  "colour": "#4a2f16", "model": "res://art/props/captain_desk/captain_desk.glb" },
	# 0.5 x 1.0 x 0.5 from the chair's own sidecar. The box that stood here was 1.9 m
	# tall, which is a wardrobe, not a chair.
	# The owner's own generation, which arrives upright and needs no spin. 1.35 m to
	# the crest rather than the sidecar's 1.0: it is a throne behind a 0.76 m desk and
	# at 1.0 nothing of it clears the desktop.
	{ "name": "chair", "prop": "captain_chair", "at": Vector3(-3.6, 0.675, -2.15), "size": Vector3(0.62, 1.35, 0.62),
	  "colour": "#3a2416", "model": "res://art/props/captain_chair/captain_chair.glb" },
	# The nailed supply crate - its own prop, not the brass skull chest. Both are 0.9 m
	# cubes and for one commit the chest stood in for it; the owner kept them separate.
	{ "name": "crate", "prop": "supply_crate", "at": Vector3(3.9, 0.45, 1.9), "size": Vector3(0.9, 0.9, 0.9),
	  "colour": "#4a2f16", "model": "res://art/props/supply_crate/supply_crate.glb",
	  "spin": Vector3(0, 0, 0) },
	# The skull chest, against the right wall, as in docs/reference/room_target.png.
	{ "name": "chest", "prop": "pirate_chest", "at": Vector3(4.0, 0.45, -0.6), "size": Vector3(0.9, 0.9, 0.9),
	  "colour": "#4a2f16", "model": "res://art/props/pirate_chest/pirate_chest.glb",
	  "spin": Vector3(90, 180, 0) },
	# Set into the back wall, so it blocks nothing on the floor. The brass ring is the
	# art; the weather behind it is still the flat blue the box used to be.
	{ "name": "porthole", "prop": "porthole", "at": Vector3(0.0, 1.55, -3.4), "size": Vector3(0.9, 0.9, 0.9),
	  "colour": "#86a9c9", "solid": false,
	  "model": "res://art/props/porthole/porthole.glb" },
]



## Awaits the navigation sync at the end, so callers must await it too.
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
			var folder := String(piece.get("prop", piece["name"]))
			var prefab := "res://props/%s/%s.tscn" % [folder, folder]
			_add_prop(piece)
			if not ResourceLoader.exists(prefab):
				_add_collision(piece["at"], piece["size"],
					String(piece["name"]).to_pascal_case())
		else:
			_add_box(piece["at"], piece["size"], Color(String(piece["colour"])),
				bool(piece.get("solid", true)), String(piece["name"]))
	for piece in DRESSING:
		_add_prop(piece)
	_add_prop({ "name": "bowl_stand", "at": BOWL_AT + Vector3(0.0, BOWL_STAND_HEIGHT * 0.5, 0.0),
		"size": Vector3(0.6, BOWL_STAND_HEIGHT, 0.6) })
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
	# The bowl is a prefab like every other prop; it brings its own glass with it.
	const PREFAB := "res://props/fishbowl/fishbowl.tscn"
	var bowl := (load(PREFAB) as PackedScene).instantiate() as Node3D
	bowl.name = "Fishbowl"
	bowl.position = at
	_room.add_child(bowl)



## A generated prop, scaled to its real size and stood on the floor.
##
## Tripo normalises everything to roughly 1.0 on its longest axis, so the model's own
## size means nothing - `size` from the sidecar is what makes a desk 1.8 m and an
## inkwell 8 cm. Scaled uniformly by the longest axis rather than stretched to fit the
## box, because a prop squashed to match a guessed depth looks wrong in a way nobody
## can point at.



## A generated prop, scaled to its real size and stood on the floor.
##
## Tripo normalises everything to roughly 1.0 on its longest axis, so the model's own
## size means nothing - `size` from the sidecar is what makes a desk 1.8 m and an
## inkwell 8 cm. Scaled uniformly by the longest axis rather than stretched to fit the
## box, because a prop squashed to match a guessed depth looks wrong in a way nobody
## can point at.
func _add_prop(piece: Dictionary) -> void:
	# A prefab if the prop has one, which is every generated prop. It already carries
	# its real size, which way up it goes and its collision, and its origin is the
	# point it stands on - so placing it is dropping it at a spot on the floor. The
	# raw-.glb path below is the fallback for anything that has not been through
	# tools/make_prefabs.gd yet.
	# `prop` is the folder under props/, which is not always what the room calls the
	# thing: the room says "crate" and the prefab is supply_crate. Getting this wrong
	# is silent - the raw .glb path below just runs instead, and the prop turns up
	# unscaled with a loose collision box beside it.
	var folder := String(piece.get("prop", piece["name"]))
	var prefab := "res://props/%s/%s.tscn" % [folder, folder]
	if ResourceLoader.exists(prefab):
		var thing := (load(prefab) as PackedScene).instantiate() as Node3D
		thing.name = String(piece["name"]).to_pascal_case()
		var at: Vector3 = piece["at"]
		var tall: float = float((piece["size"] as Vector3).y)

		# No scaling here. The prefab is its real size, from the prop's own
		# asset.json, and that is the one place a prop's size is decided. Scaling the
		# instance from the room's `size` was tried and shrank the bowl stand: `size`
		# is the COLLISION box, which is not always the thing's visible extent.

		thing.position = Vector3(at.x, at.y - tall * 0.5, at.z)
		_room.add_child(thing)
		return

	var scene: PackedScene = load(String(piece["model"]))
	if scene == null:
		push_warning("%s: no model at %s" % [piece["name"], piece["model"]])
		return
	var model := scene.instantiate() as Node3D
	model.name = String(piece["name"]).to_pascal_case()
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


## The collision for a prop whose art has arrived. Separate from the mesh, because a
## generated model's own shape is far more detail than a walkable area needs and the
## box is what the navigation bake reads.
func _add_collision(at: Vector3, size: Vector3, label := "Solid") -> void:
	var body := StaticBody3D.new()
	# Named after the prop, because these end up in the authored scene where "Solid",
	# "Solid2", "Solid3" is a tree nobody can navigate.
	body.name = "%sSolid" % label if label != "Solid" else "Solid"
	body.position = at
	var shape := CollisionShape3D.new()
	shape.name = "%sShape" % body.name
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
## Characters arrive from the generator with a skeleton and no animation at all. The
## clips are borrowed from one donor rig and retargeted onto whoever needs them, so a
## new character costs nothing in animation work - see actors/parts/retarget.gd, which
## takes how far each bone has turned from its own T-pose rather than copying raw
## rotations, so differing units and rest poses cancel out.
const CLIP_SOURCE := "res://art/animations/hymotion/walk.fbx"  # needs an A-posed rig
const LOOPING := ["idle", "walk", "run", "swim"]

## Play the clips the character file already carries.

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

	# Parented to the character, NOT to the model. The model is an instanced .glb, and
	# a node added inside an instance is not saved when the character is packed as a
	# prefab - the first attempt produced a captain with no animation at all. Its
	# paths reach down into the model from here, which works across that boundary.
	var tree := AnimationTree.new()
	tree.name = "Layers"
	var actor := model.get_parent().get_parent()
	actor.add_child(tree)
	var path := String(tree.get_path_to(skeleton))
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
	if not visual.is_empty():
		spot.set_meta("visual", visual)
	_room.add_child(spot)


## Connect a hotspot to the game. Separate from building it because the hotspots now
## come out of the authored scene, and a lambda cannot be saved in a .tscn - the nodes
## survive the round trip and every connection in here does not.


## The capsule a character is clicked on. Geometry only - what a click DOES is wired
## by the game when it opens the scene, because a signal connection is a lambda and a
## lambda cannot be saved in a .tscn.
func _add_click_area(mover: Mover, entry: Dictionary) -> void:
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
