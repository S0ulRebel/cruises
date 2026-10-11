extends SceneTree
## Turn every generated model into a prefab scene you can drag into any room.
##
##     godot --path . --headless --script tools/make_prefabs.gd
##
## One scene per prop, at props/<name>/<name>.tscn, with:
##
##   <Name>          Node3D, or StaticBody3D where the thing blocks the way
##     Model         the .glb, scaled to its REAL size and stood on the floor
##     <Name>Shape   the collision box, for the solid ones
##
## Three things are baked in here so no room has to know them:
##
## - SCALE. Tripo normalises everything to about 1.0 on its longest axis, so a model's
##   own size means nothing; dimensions_m from the prop's asset.json is what makes a
##   desk 1.8 m and an inkwell 8 cm.
## - WHICH WAY IS UP. Tripo's idea of up varies run to run - the chest arrives on its
##   back, the compass and the rapier stand on edge so all four views could show their
##   face. That correction belongs once, in the prefab, not in every room that uses it.
## - THE FLOOR. Every prefab's origin is the point it stands on, so placing one is
##   dropping it at a spot on the floor rather than working out half its height.

## name: [solid, spin degrees]
const PROPS := {
	"captain_desk":  [true,  Vector3.ZERO],
	"captain_chair": [true,  Vector3.ZERO],
	"supply_crate":  [true,  Vector3.ZERO],
	"pirate_chest":  [true,  Vector3(90, 180, 0)],
	"bowl_stand":    [true,  Vector3.ZERO],
	"porthole":      [false, Vector3.ZERO],
	"fishbowl":      [false, Vector3(-90, 0, 0)],
	"compass":       [false, Vector3(-90, 0, 0)],
	"brass_inkwell": [false, Vector3.ZERO],
	"rapier":        [false, Vector3(-90, 0, 0)],
	"key":           [false, Vector3.ZERO],
}


func _init() -> void:
	var made := 0
	for name in PROPS:
		if _make(name, bool(PROPS[name][0]), PROPS[name][1]):
			made += 1
	if _make_count_fingers():
		made += 1
	if _furnish_bowl():
		made += 1
	print("%d prefabs" % made)
	quit()


## Count Fingers, as his own prefab. He is an actor, not a prop: he drifts, he has
## lines, and he could be dropped into a different bowl or a bucket tomorrow.
##
## His rest turn is measured in the ENGINE. His .glb drops into Godot standing on his
## tail with his nose along +Y; -90 about X with 90 of yaw lays him level and presents
## his flank, which is the only angle that shows a whole fish to a camera looking down
## into a bowl. Blender says nothing useful about this - its glTF importer turns the
## file to its own Z-up on the way in, so a profile that looks level there is no guide
## at all to where he lands here.
const FISH_MODEL := "res://art/characters/count_fingers/count_fingers_mesh.glb"
## Metres, nose to tail. His sheet says 6-8 cm; the bowl is already far bigger than a
## real one for the same reason, and at 15 cm in a 52 cm bowl he read as a speck.
const FISH_LENGTH := 0.27
const FISH_REST := Vector3(-90.0, 90.0, 0.0)


func _make_count_fingers() -> bool:
	if not ResourceLoader.exists(FISH_MODEL):
		push_warning("count_fingers: no model")
		return false
	var root := Node3D.new()
	root.name = "CountFingers"
	root.set_script(load("res://actors/parts/fish.gd"))

	var model := (load(FISH_MODEL) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	root.add_child(model)

	var bounds := _bounds(model)
	var longest: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var fit: float = FISH_LENGTH / maxf(longest, 0.0001)
	var rest := Basis(Vector3.RIGHT, deg_to_rad(FISH_REST.x))
	rest = Basis(Vector3.UP, deg_to_rad(FISH_REST.y)) * rest
	# Turn and centre together: the offset has to be the centre AFTER the turn, or
	# laying him flat swings him out through the glass.
	model.transform = Transform3D(rest.scaled(Vector3.ONE * fit),
		-(rest * bounds.get_center()) * fit)

	_claim(root, root)
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		return false
	DirAccess.make_dir_recursive_absolute("res://actors/count_fingers")
	var out := "res://actors/count_fingers/count_fingers.tscn"
	if ResourceSaver.save(packed, out) != OK:
		return false
	print("%-16s %s" % ["count_fingers", out])
	return true


## Put the water and the fish inside the bowl prefab, so the bowl is one thing you
## drag rather than three you have to remember to drag together.
func _furnish_bowl() -> bool:
	const BOWL := "res://props/fishbowl/fishbowl.tscn"
	const FISH := "res://actors/count_fingers/count_fingers.tscn"
	if not (ResourceLoader.exists(BOWL) and ResourceLoader.exists(FISH)):
		return false
	var root := (load(BOWL) as PackedScene).instantiate() as Node3D
	# Inside radius of the glass, from the prop's own sidecar.
	const RADIUS := 0.26

	# A flat disc is enough for the surface: it is only ever seen from above the
	# waterline at this camera. Well below the rim - the gap between the water and the
	# rim is what says "bowl" rather than "full dish".
	var water := CylinderMesh.new()
	water.top_radius = RADIUS - 0.016
	water.bottom_radius = water.top_radius
	water.height = 0.004
	water.radial_segments = 48
	var pool := MeshInstance3D.new()
	pool.name = "Water"
	pool.mesh = water
	pool.position.y = RADIUS * 0.58
	var wet := StandardMaterial3D.new()
	wet.albedo_color = Color(0.35, 0.62, 0.70, 0.45)
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.roughness = 0.08
	pool.material_override = wet
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pool)

	var fish := (load(FISH) as PackedScene).instantiate() as Node3D
	fish.position = Vector3(0.0, RADIUS * 0.52, 0.0)
	root.add_child(fish)

	_claim(root, root)
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		return false
	if ResourceSaver.save(packed, BOWL) != OK:
		return false
	print("%-16s %s  + water + Count Fingers" % ["fishbowl", BOWL])
	return true


func _make(name: String, solid: bool, spin: Vector3) -> bool:
	var model_path := "res://art/props/%s/%s.glb" % [name, name]
	var sidecar := "res://art/props/%s/asset.json" % name
	if not ResourceLoader.exists(model_path):
		push_warning("%s: no model" % name)
		return false
	var size := _real_size(sidecar)
	if size == Vector3.ZERO:
		push_warning("%s: no dimensions_m in asset.json" % name)
		return false

	var title := name.to_pascal_case()
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.name = title

	var model := (load(model_path) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	root.add_child(model)

	# Turn it the right way up FIRST, then measure: a box measured before the turn
	# sizes the thing by its depth and stands it on its face.
	var basis := Basis(Vector3.RIGHT, deg_to_rad(spin.x))
	basis = Basis(Vector3.UP, deg_to_rad(spin.y)) * basis
	basis = Basis(Vector3.BACK, deg_to_rad(spin.z)) * basis
	var box: AABB = Transform3D(basis, Vector3.ZERO) * _bounds(model)

	# Scaled by the LONGEST axis rather than stretched to fit the box: a prop squashed
	# to match a guessed depth looks wrong in a way nobody can point at.
	var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	var wanted: float = maxf(size.x, maxf(size.y, size.z))
	var fit: float = wanted / maxf(longest, 0.0001)
	model.transform = Transform3D(basis.scaled(Vector3.ONE * fit),
		Vector3(-box.get_center().x * fit, -box.position.y * fit, -box.get_center().z * fit))

	if solid:
		var shape := CollisionShape3D.new()
		shape.name = "%sShape" % title
		var collider := BoxShape3D.new()
		collider.size = size
		shape.shape = collider
		shape.position = Vector3(0.0, size.y * 0.5, 0.0)
		root.add_child(shape)
		# What the walkable area is cut around - see room3d/room3d.gd.
		root.add_to_group("nav_source")

	# A prop that has its own component wears it: props/<name>/<name>.gd. The fishbowl
	# is the only one so far - it needs glass, which no generator can make.
	var component := "res://props/%s/%s.gd" % [name, name]
	if ResourceLoader.exists(component):
		root.set_script(load(component))
		if "glass" in root:
			root.set("glass", root.get_path_to(model))

	_claim(root, root)
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("%s: pack failed" % name)
		return false
	DirAccess.make_dir_recursive_absolute("res://props/%s" % name)
	var out := "res://props/%s/%s.tscn" % [name, name]
	if ResourceSaver.save(packed, out) != OK:
		push_error("%s: save failed" % name)
		return false
	print("%-16s %s  %.2f x %.2f x %.2f m" % [name, out, size.x, size.y, size.z])
	return true


static func _real_size(sidecar: String) -> Vector3:
	if not FileAccess.file_exists(sidecar):
		return Vector3.ZERO
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(sidecar))
	if not (parsed is Dictionary) or not parsed.has("dimensions_m"):
		return Vector3.ZERO
	var d: Dictionary = parsed["dimensions_m"]
	return Vector3(float(d.get("width", 0.0)), float(d.get("height", 0.0)),
		float(d.get("depth", 0.0)))


static func _bounds(root: Node) -> AABB:
	var out := AABB()
	var first := true
	for node in root.find_children("*", "VisualInstance3D", true, false):
		var vis := node as VisualInstance3D
		var box := vis.transform * vis.get_aabb()
		var walk := vis.get_parent()
		while walk != null and walk != root:
			box = (walk as Node3D).transform * box
			walk = walk.get_parent()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out


## Claim what we built and STOP at anything that is an instance of another scene:
## claiming a .glb's internal MeshInstance3D makes Godot save it in full, which writes
## the whole mesh into the .tscn.
static func _claim(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path.is_empty():
			_claim(child, root)
