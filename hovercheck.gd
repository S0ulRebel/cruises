extends SceneTree
## The wording the player reads before they click.
##
## Phrasing is the whole value of this feature, and it is the part that silently goes
## wrong: a crate that says "Look at Crate" while holding the rapier that opens it is
## worse than no caption at all, because it tells the player there is nothing here.

func _init() -> void:
	var failures := 0
	var Hotspot := load("res://systems/interaction/hotspot.gd")

	var crate = Hotspot.new()
	crate.display_name = "Crate"
	crate.needs_item = "rapier"
	crate.gives_item = "key"
	failures += _check("a locked crate with empty hands reads as a look",
		crate.phrase(crate.resolve("")) == "Look at Crate", crate.phrase(crate.resolve("")))
	failures += _check("holding the right item changes the wording",
		crate.phrase(crate.resolve("rapier"), "Rapier") == "Use Rapier on Crate",
		crate.phrase(crate.resolve("rapier"), "Rapier"))

	var bowl = Hotspot.new()
	bowl.display_name = "Fishbowl"
	bowl.gives_item = "fishbowl"
	failures += _check("something you can just pick up says Take",
		bowl.phrase(bowl.resolve("")) == "Take Fishbowl", bowl.phrase(bowl.resolve("")))

	var person = Hotspot.new()
	person.display_name = "Santi Wong"
	person.conversation = "res://screenplay/santi_galley.json"
	failures += _check("a person reads as a conversation",
		person.phrase(person.resolve("")) == "Talk to Santi Wong",
		person.phrase(person.resolve("")))

	var scenery = Hotspot.new()
	scenery.display_name = "Porthole"
	scenery.description = "Fog."
	failures += _check("plain scenery reads as a look",
		scenery.phrase(scenery.resolve("")) == "Look at Porthole",
		scenery.phrase(scenery.resolve("")))

	print("\n%s" % ("ALL CHECKS PASSED" if failures == 0 else "%d CHECK(S) FAILED" % failures))
	quit(1 if failures > 0 else 0)


func _check(what: String, ok: bool, got := "") -> int:
	print("%s  %s%s" % ["ok  " if ok else "FAIL", what, "" if ok else "  -> got '%s'" % got])
	return 0 if ok else 1
