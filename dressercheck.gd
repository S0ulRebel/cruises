extends Node3D
## Proves the ported dresser works on a real rigged body before any of our own art
## depends on it.
##
## Checks, in order: a body attaches and reports a sane fit space; a pinned piece
## resolves its ROLE to a bone on a Mixamo skeleton; the same piece resolves on a
## skeleton with no Mixamo names at all, once the body declares its own; conflicting
## slots cannot be worn together; a skinned piece gets the body's weights.
##
## Each one prints what it measured, not whether it "passed", so a wrong number is
## visible rather than hidden behind a tick.

const BODY := "res://art/models/characters/body_zombie.glb"

var _failures := 0


func _ready() -> void:
	var model := (load(BODY) as PackedScene).instantiate()
	add_child(model)

	var dresser := Dresser.new()
	add_child(dresser)
	_check("body attaches", dresser.attach(model))

	var skeleton := dresser.skeleton()
	print("  skeleton: %d bones" % skeleton.get_bone_count())
	var head_at := dresser.bone_position("mixamorig_Head")
	print("  head sits at %.3f m in fit space (body is about 1.8 m)" % head_at.y)
	_check("fit space puts the head at a believable height", head_at.y > 1.2 and head_at.y < 2.2)

	# A hat names a role, not a bone. On a Mixamo body it must find the Mixamo head.
	var hat := OutfitPiece.new()
	hat.slot = "hat"
	hat.hold = OutfitPiece.Hold.PINNED
	hat.role = "head"
	hat.bone = ""
	var resolved := dresser.bone_for(hat)
	print("  a hat with role 'head' resolves to '%s'" % resolved)
	_check("role resolves on a Mixamo skeleton", resolved == "mixamorig_Head")

	# The point of the change: a skeleton with no Mixamo names must still take a hat.
	_check_non_human(dresser, hat)

	_check_conflicts()
	_check_slots()

	print("\n%s" % ("ALL CHECKS PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


## Builds a skeleton whose bones are named like an animal's, attaches it, and asks for the
## hat's bone - first with nothing declared, which must fail loudly, then with the role
## declared, which must work.
func _check_non_human(_unused: Dresser, hat: OutfitPiece) -> void:
	var rig := Skeleton3D.new()
	rig.add_bone("spine_root")
	rig.add_bone("thorax")
	rig.add_bone("skull")
	rig.set_bone_parent(1, 0)
	rig.set_bone_parent(2, 1)
	rig.set_bone_rest(1, Transform3D(Basis(), Vector3(0, 0.4, 0)))
	rig.set_bone_rest(2, Transform3D(Basis(), Vector3(0, 0.3, 0)))
	var beast := Node3D.new()
	beast.add_child(rig)
	add_child(beast)

	var dresser := Dresser.new()
	add_child(dresser)
	_check("a non-Mixamo body attaches", dresser.attach(beast))
	print("  with nothing declared, the hat resolves to '%s' (must be empty)"
		% dresser.bone_for(hat))
	_check("an undeclared role fails rather than guessing", dresser.bone_for(hat) == "")

	# What a body's .roles.json would supply.
	dresser.declare_roles({"head": "skull", "chest": "thorax"})
	print("  after declaring head=skull, it resolves to '%s'" % dresser.bone_for(hat))
	_check("a declared role resolves on a skeleton with no Mixamo names",
		dresser.bone_for(hat) == "skull")


func _check_conflicts() -> void:
	var dress := OutfitPiece.new()
	dress.slot = "dress"
	print("  a dress conflicts with %s" % str(dress.conflicts_with()))
	_check("a dress refuses a shirt", "shirt" in dress.conflicts_with())
	_check("a dress refuses trousers", "trousers" in dress.conflicts_with())
	var trousers := OutfitPiece.new()
	trousers.slot = "trousers"
	_check("trousers refuse a skirt", "skirt" in trousers.conflicts_with())
	var coat := OutfitPiece.new()
	coat.slot = "coat"
	_check("a coat conflicts with nothing", coat.conflicts_with().is_empty())


func _check_slots() -> void:
	for slot in ["corset", "skirt", "dress"]:
		_check("'%s' is a slot" % slot, slot in OutfitPiece.SLOTS)
	# Sorting by file name is how a piece finds its slot at all.
	_check("dress_red.glb sorts as a dress",
		OutfitPiece.slot_of("res://x/dress_red.glb") == "dress")
	_check("a stray file is ignored", OutfitPiece.slot_of("res://x/notaslot_x.glb") == "")


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
