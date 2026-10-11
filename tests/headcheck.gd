extends Node
## Proves the talking head survives Godot, which nobody has tested.
##
## The rig was built and verified in Blender. Everything between there and here can
## still drop it: glTF import renames bones, blend shapes can arrive unnamed or in a
## different order, and a SubViewport can render a perfectly correct head as a black
## square. So this loads the real file, reports what Godot actually found, drives a
## real line of dialogue through it, and saves frames to look at.

const LINE := "You took the compass, and I want it back now."
const WHO := "captain_live"
const FRAMES := 6
const ArtOutput := preload("res://tests/art_output.gd")

var _head: TalkingHead
var _failures := 0


func _ready() -> void:
	var panel := Control.new()
	panel.size = Vector2(300, 300)
	add_child(panel)

	_head = (load("res://ui/talking_head.tscn") as PackedScene).instantiate() as TalkingHead
	panel.add_child(_head)
	await get_tree().process_frame
	var definition := CharacterDefinition.new()
	definition.content_id = "live"
	definition.asset_id = WHO
	definition.display_name = "Captain Live"
	definition.portrait_scene = load("res://ui/portraits/captain_live.tscn") as PackedScene
	_head.set_characters([definition])

	var loaded := _head.show_character(WHO)
	_check("the head piece loads", loaded)
	var report := _head.rig_report()
	print("  skeleton %s, %d bones, jaw bone index %d, shapes %s"
		% [report["has_skeleton"], report["bones"], report["jaw_bone"], report["shapes_found"]])
	_check("Godot found a skeleton", report["has_skeleton"])
	_check("the jaw bone survived the import", int(report["jaw_bone"]) >= 0)
	for name in TalkingHead.SHAPES:
		_check("the %s blend shape survived the import" % name,
			name in report["shapes_found"])

	var keys := Speech.plan(LINE, WHO)
	_check("the line plans", keys.size() > 10)
	var length := Speech.duration(keys)
	print("  driving %.2f s of speech through the rig" % length)

	# Walk the line and save frames spread across it, so the shapes can be judged by
	# eye rather than trusted because the weights were set.
	var dir := ArtOutput.new_run("headcheck")
	var widest := 0.0
	for i in FRAMES:
		var t: float = length * float(i) / float(FRAMES - 1)
		var pose: Dictionary = Speech.sample(keys, t)
		widest = maxf(widest, pose["jaw"])
		_head.apply(pose, WHO)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var viewport := _head.get_node("Viewport") as SubViewport
		var image: Image = viewport.get_texture().get_image()
		var path := "%s/frame_%d.png" % [dir, i]
		_check("frame saved", image.save_png(path) == OK)
		var filled := _coverage(image)
		print("  t %.2f s  jaw %.2f wide %.2f round %.2f pressed %.2f  -> %.1f%% of the panel drawn"
			% [t, pose["jaw"], pose["wide"], pose["round"], pose["pressed"], filled * 100.0])
		# A head that renders as an empty panel is the failure this exists to catch.
		_check("frame %d is not blank" % i, filled > 0.08)

	_check("the jaw opened during the line", widest > 0.4)

	# Can the mouth close at all? The head is modelled mid-word, so a shut mouth needs
	# the jaw down AND the lips pressed. If PRESSED at full strength still leaves them
	# parted, the shape is too weak and that is the face session's to fix, not a
	# number to tune here.
	for pressed in [0.35, 0.70, 1.00]:
		_head.apply({ "jaw": 0.0, "wide": 0.0, "round": 0.0, "pressed": pressed }, WHO)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var vp := _head.get_node("Viewport") as SubViewport
		var img: Image = vp.get_texture().get_image()
		_check("closed-mouth frame saved", img.save_png("%s/closed_%d.png" % [dir, int(pressed * 100)]) == OK)
	print("  closed-mouth frames written at pressed 0.35, 0.70 and 1.00")
	print("  frames written to %s" % ProjectSettings.globalize_path(dir))
	print("\n%s" % ("ALL CHECKS PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


## How much of the panel has anything drawn in it. Transparent background, so a head
## that failed to load, or a camera pointing at nothing, comes out near zero.
func _coverage(image: Image) -> float:
	var hits := 0
	var total := 0
	var step := 4
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			total += 1
			if image.get_pixel(x, y).a > 0.1:
				hits += 1
	return 0.0 if total == 0 else float(hits) / float(total)


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
