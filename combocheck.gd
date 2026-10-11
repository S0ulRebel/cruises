extends SceneTree
## Using one item on one thing: the rules, without the room.
##
## The failures here are the quiet ones. A key that is not consumed gets tried on every
## other door for the rest of the game. A combination that fires twice hands out the
## same item again. A wrong answer that falls through to the generic refusal throws
## away the line someone wrote for it. None of those look broken; they look like the
## puzzle is badly designed.

func _init() -> void:
	var failures := 0
	var Hotspot := load("res://room3d/hotspot.gd")

	var crate = Hotspot.new()
	crate.display_name = "Crate"
	crate.refusal = "It is nailed shut."
	crate.combinations = {
		"rapier": { "say": "The lid comes up.", "gives": "key", "sets": "crate_open", "solved": true },
		"ladle": { "say": "He bangs the lid with a ladle. Nothing, except noise." },
	}

	# What the player is told before they click.
	failures += _check("empty-handed it reads as a look",
		crate.phrase(crate.resolve("")) == "Look at Crate", crate.phrase(crate.resolve("")))
	failures += _check("holding the right item offers a use",
		crate.resolve("rapier") == Hotspot.Verb.USE, str(crate.resolve("rapier")))
	failures += _check("holding a WRONG item that has a written answer still offers a use",
		crate.resolve("ladle") == Hotspot.Verb.USE, str(crate.resolve("ladle")))
	failures += _check("holding an item with no answer does not offer a use",
		crate.resolve("compass") != Hotspot.Verb.USE, str(crate.resolve("compass")))

	# What actually fires.
	var fired := { "item": "", "outcome": {} }
	var refused := [""]
	crate.combined.connect(func(item: String, outcome: Dictionary) -> void:
		fired["item"] = item
		fired["outcome"] = outcome)
	crate.refused.connect(func(text: String) -> void: refused[0] = text)

	crate.interact(Hotspot.Verb.USE, "ladle")
	failures += _check("a wrong-but-written item fires its own line, not the refusal",
		fired["item"] == "ladle" and refused[0] == "", "%s / %s" % [fired["item"], refused[0]])
	failures += _check("a wrong-but-written item is not marked solved",
		not bool(fired["outcome"].get("solved", false)))

	fired["item"] = ""
	crate.interact(Hotspot.Verb.USE, "compass")
	failures += _check("an item with no answer falls through to the refusal",
		fired["item"] == "" and refused[0] == "It is nailed shut.",
		"%s / %s" % [fired["item"], refused[0]])

	fired["item"] = ""
	crate.interact(Hotspot.Verb.USE, "rapier")
	failures += _check("the right item fires and is marked solved",
		fired["item"] == "rapier" and bool(fired["outcome"]["solved"]))
	failures += _check("the right item carries what it gives and what it sets",
		fired["outcome"].get("gives") == "key" and fired["outcome"].get("sets") == "crate_open")

	print("\n%s" % ("ALL CHECKS PASSED" if failures == 0 else "%d CHECK(S) FAILED" % failures))
	quit(1 if failures > 0 else 0)


func _check(what: String, ok: bool, got := "") -> int:
	print("%s  %s%s" % ["ok  " if ok else "FAIL", what, "" if ok else "  -> got '%s'" % got])
	return 0 if ok else 1
