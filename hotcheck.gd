extends Node3D
## Exercises the hotspot verbs without a mouse: look, blocked use, successful use.

const Hotspot := preload("res://room3d/hotspot.gd")
const Inventory := preload("res://ui/inventory.gd")

func _ready() -> void:
	var inv := Inventory.new()
	add_child(inv)

	var crate := Area3D.new()
	crate.set_script(Hotspot)
	crate.display_name = "Crate"
	crate.description = "Nailed shut."
	crate.needs_item = "rapier"
	crate.refusal = "It is nailed shut."
	crate.gives_item = "key"
	add_child(crate)

	var log: Array[String] = []
	crate.looked.connect(func(t): log.append("LOOK: " + t))
	crate.refused.connect(func(t): log.append("REFUSED: " + t))
	crate.used.connect(func(i): log.append("GAVE: " + i); inv.add(i))

	print("empty-handed  -> verb %d" % crate.resolve(""))
	crate.interact(crate.resolve(""), "")

	print("holding ladle -> verb %d" % crate.resolve("ladle"))
	crate.interact(Hotspot.Verb.USE, "ladle")

	print("holding rapier-> verb %d" % crate.resolve("rapier"))
	crate.interact(crate.resolve("rapier"), "rapier")

	for line in log: print("  " + line)
	print("inventory: %s" % [inv.held])
	print("selection toggle: ")
	inv.select("key"); print("  selected '%s'" % inv.selection)
	inv.select("key"); print("  selected '%s' (toggled off)" % inv.selection)
	get_tree().quit()
