extends SceneTree
## Proves the speech planner before anything is rendered.
##
## The expensive mistakes here are silent ones: a line that produces no keyframes at
## all, a mouth that never closes, two characters whose profiles produce identical
## timing, or shape weights that sum past 1 mid-transition and deform the lips into
## something nobody authored. None of those look like errors - they look like a face
## that is slightly wrong, which is the hardest kind of bug to notice.

const LINE := "You took the compass, and I want it back now."


func _init() -> void:
	var failures := 0
	failures += _check("the letter map loaded", not Speech.tokenise("ab").is_empty())
	failures += _check("digraphs beat single letters",
		Speech.tokenise("oo") == PackedStringArray(["oo"]))
	failures += _check("a single letter still resolves",
		Speech.tokenise("a") == PackedStringArray(["a"]))

	var live := Speech.plan(LINE, "captain_live")
	var santi := Speech.plan(LINE, "santi_wong")
	print("  Livé:  %d keys over %.2f s" % [live.size(), Speech.duration(live)])
	print("  Santi: %d keys over %.2f s" % [santi.size(), Speech.duration(santi)])
	failures += _check("the line produces keyframes", live.size() > 10)
	failures += _check("an empty line produces none", Speech.plan("   ", "captain_live").is_empty())

	# Santi talks at 170 wpm against Livé's 135, so the same words must take him less
	# time. If these match, the profile is not being read.
	failures += _check("the two voices differ in length",
		Speech.duration(santi) < Speech.duration(live) * 0.95)

	# Sample across the whole line and look at what the mouth actually does.
	var steps := 240
	var open_max := 0.0
	var closed_frames := 0
	var over_budget := 0
	var vowel_shapes_seen := { "wide": false, "round": false }
	for i in steps:
		var t: float = Speech.duration(live) * float(i) / float(steps - 1)
		var pose: Dictionary = Speech.sample(live, t)
		open_max = maxf(open_max, pose["jaw"])
		if pose["jaw"] < 0.02:
			closed_frames += 1
		if pose["wide"] + pose["round"] + pose["pressed"] > 1.0001:
			over_budget += 1
		if pose["wide"] > 0.3:
			vowel_shapes_seen["wide"] = true
		if pose["round"] > 0.3:
			vowel_shapes_seen["round"] = true

	print("  widest jaw %.2f, closed on %d of %d samples, %d samples over the shape budget"
		% [open_max, closed_frames, steps, over_budget])
	failures += _check("the mouth opens", open_max > 0.4)
	failures += _check("the mouth closes during the line", closed_frames > 4)
	failures += _check("the mouth is not shut the whole time", closed_frames < steps / 2)
	# The one the face session warned about and I warned them about: shapes add.
	failures += _check("shape weights never exceed 1 in total", over_budget == 0)
	failures += _check("WIDE is reached somewhere in the line", vowel_shapes_seen["wide"])
	failures += _check("ROUND is reached somewhere in the line", vowel_shapes_seen["round"])

	# Degrees, not fractions, is what the bone is actually set to. Closed must be the
	# negative rest angle, because the head was modelled mid-word.
	var shut: float = Speech.jaw_degrees({ "jaw": 0.0 }, "captain_live")
	var wide: float = Speech.jaw_degrees({ "jaw": 1.0 }, "captain_live")
	print("  Livé jaw range %.2f to %.2f degrees" % [shut, wide])
	failures += _check("closed is the negative rest angle", is_equal_approx(shut, -3.25))
	failures += _check("wide open is the profile maximum", is_equal_approx(wide, 16.0))

	print("\n%s" % ("ALL CHECKS PASSED" if failures == 0 else "%d CHECK(S) FAILED" % failures))
	quit(1 if failures > 0 else 0)


func _check(what: String, ok: bool) -> int:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	return 0 if ok else 1
