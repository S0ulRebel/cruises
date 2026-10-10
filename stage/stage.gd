extends Node2D
## What you look at while the cutscene plays - and, for now, a stand-in for it.
##
## There is no art yet, so every character is a coloured block carrying their name and
## every location is two flat bands. That is deliberate rather than lazy: the point of
## this build is to find out whether the SCENE works - the order of the beats, how long
## the silence should be, whether the two cooks rhyme - and those questions are answered
## by blocks as well as by finished paintings. Art that arrives before the timing is
## settled is art that gets redrawn.
##
## Every placeholder is keyed by an id from the screenplay, so when a real backdrop or a
## real character turns up it drops into the same slot and nothing else changes.

const FLOOR_FRACTION := 0.72  ## Where the horizon sits. Low enough to leave headroom for the caption.
const FIGURE_HEIGHT := 520.0
const FIGURE_WIDTH := 190.0

var _location: Dictionary = {}
var _cast: Dictionary = {}
var _present: Array[String] = []
var _speaker := ""

## Set by the cutscene while the ship is coming apart. Kept here rather than on the
## camera because there is no camera yet, and a stage that can shake itself is one
## fewer thing to wire up.
var shake_power := 0.0
var light_level := 1.0

var _shake_offset := Vector2.ZERO


func _process(delta: float) -> void:
	if shake_power > 0.0:
		# Fresh offset every frame: a shake that interpolates reads as a sway.
		_shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_power
		queue_redraw()
	elif _shake_offset != Vector2.ZERO:
		_shake_offset = Vector2.ZERO
		queue_redraw()


func set_cast(cast: Dictionary) -> void:
	_cast = cast


func set_location(location: Dictionary) -> void:
	_location = location
	_present.clear()
	_speaker = ""
	queue_redraw()


func enter(ids: Array) -> void:
	for id in ids:
		var key := String(id)
		if not _present.has(key):
			_present.append(key)
	queue_redraw()


func set_speaker(who: String) -> void:
	_speaker = who
	queue_redraw()


func set_light(level: float) -> void:
	light_level = level
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	var o := _shake_offset
	var horizon := size.y * FLOOR_FRACTION

	var sky := _colour(_location.get("sky", "#222222"))
	var floor_col := _colour(_location.get("floor", "#111111"))
	draw_rect(Rect2(o + Vector2(-40, -40), size + Vector2(80, 80)), sky * light_level)
	draw_rect(Rect2(o + Vector2(-40, horizon), Vector2(size.x + 80, size.y - horizon + 40)), floor_col * light_level)

	if _present.is_empty():
		return

	# Spread whoever is on stage evenly, so a two-hander is centred and a crowd still fits.
	var span := size.x / float(_present.size() + 1)
	for i in _present.size():
		var id := _present[i]
		var person: Dictionary = _cast.get(id, {})
		var x := span * float(i + 1)
		_draw_figure(o + Vector2(x, horizon), person, id == _speaker)


func _draw_figure(foot: Vector2, person: Dictionary, speaking: bool) -> void:
	var body := _colour(person.get("colour", "#888888")) * light_level
	var accent := _colour(person.get("accent", "#ffffff")) * light_level

	# The one who is talking stands a little taller and keeps their outline. With no
	# faces and no animation, that is the only cue telling you who the voice belongs to.
	var height := FIGURE_HEIGHT * (1.06 if speaking else 1.0)
	var rect := Rect2(foot - Vector2(FIGURE_WIDTH * 0.5, height), Vector2(FIGURE_WIDTH, height))

	draw_rect(rect, body)
	draw_rect(rect, accent, false, 3.0 if speaking else 1.0)
	# A sash at chest height, purely so the blocks are not identical rectangles.
	draw_rect(Rect2(rect.position + Vector2(0, height * 0.42), Vector2(FIGURE_WIDTH, 26)), accent)

	var font := ThemeDB.fallback_font
	var label := String(person.get("name", "?"))
	var text_col := Color.WHITE if body.get_luminance() < 0.5 else Color.BLACK
	draw_string(font, rect.position + Vector2(0, height * 0.30), label,
		HORIZONTAL_ALIGNMENT_CENTER, FIGURE_WIDTH, 26, text_col * light_level)


func _colour(hex: Variant) -> Color:
	return Color(String(hex)) if String(hex).begins_with("#") else Color.MAGENTA
