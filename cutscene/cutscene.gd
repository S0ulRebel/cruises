extends Node
## Plays a screenplay file, one beat at a time.
##
## The screenplay is data, not code, so a scene can be rewritten, reordered or retimed
## without opening the editor - which matters when the writer is not the programmer and
## the joke depends on how long the silence runs. Every beat is a small dictionary with
## a `t` saying what kind it is; anything this player does not recognise is skipped with
## a warning rather than crashing, so a newer screenplay still runs on an older build.
##
## Beats understood today:
##   location  id                     switch the backdrop, clear the stage
##   enter     who: [ids]             put people on stage
##   say       who, text              a spoken line; waits for the reader
##   action    text                   a stage direction, shown while the next beat plays
##   wait      secs                   hold. The comic timing lives here.
##   sfx       id, caption            a sound; captioned until there is audio
##   shake     secs, power            the ship convulses
##   flicker   secs                   the lights go
##   end                              stop

signal finished

const Stage := preload("res://stage/stage.gd")
const Caption := preload("res://ui/caption.gd")

## Print each beat with the time it started. The timing of this scene is the joke, so
## being able to read the running order off a log is worth the four lines it costs.
var verbose := false

var _stage: Stage
var _caption: Caption
var _screenplay: Dictionary = {}
var _cast: Dictionary = {}
var _started_ms := 0


func _describe(beat: Dictionary) -> String:
	var kind := String(beat.get("t", ""))
	match kind:
		"say":
			var who: Dictionary = _cast.get(String(beat.get("who", "")), {})
			return "%s: \"%s\"" % [who.get("name", "?"), beat.get("text", "")]
		"action":
			return "  (%s)" % beat.get("text", "")
		"location":
			var places: Dictionary = _screenplay.get("locations", {})
			var place: Dictionary = places.get(String(beat.get("id", "")), {})
			return "-- %s --" % place.get("name", beat.get("id", "?"))
		"enter":
			return "  enter: %s" % ", ".join(PackedStringArray(beat.get("who", [])))
		_:
			return "  [%s]" % kind


func setup(stage: Stage, caption: Caption) -> void:
	_stage = stage
	_caption = caption


func load_screenplay(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("No screenplay at %s" % path)
		return false

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Screenplay at %s is not a JSON object" % path)
		return false

	_screenplay = parsed
	_cast = _screenplay.get("cast", {})
	_stage.set_cast(_cast)
	return true


func play() -> void:
	_started_ms = Time.get_ticks_msec()
	for beat_variant in _screenplay.get("beats", []):
		if typeof(beat_variant) != TYPE_DICTIONARY:
			continue
		var beat: Dictionary = beat_variant
		var kind := String(beat.get("t", ""))
		if verbose:
			print("[%6.2fs] %s" % [(Time.get_ticks_msec() - _started_ms) / 1000.0, _describe(beat)])

		match kind:
			"location":
				var id := String(beat.get("id", ""))
				var places: Dictionary = _screenplay.get("locations", {})
				_stage.set_location(places.get(id, {}))
				_caption.hide_box()
				_caption.clear_action()

			"enter":
				_stage.enter(beat.get("who", []))

			"action":
				_caption.action(String(beat.get("text", "")))

			"say":
				var who := String(beat.get("who", ""))
				var person: Dictionary = _cast.get(who, {})
				_stage.set_speaker(who)
				_caption.say(String(person.get("name", who)), String(beat.get("text", "")), who,
					Color(String(person.get("colour", "#4a4f5a"))))
				await _caption.advanced
				_stage.set_speaker("")
				_caption.clear_action()

			"wait":
				_caption.hide_box()
				await _hold(float(beat.get("secs", 1.0)))

			"sfx":
				# No audio yet, so the sound is captioned. Swapped for a real stream later
				# without the screenplay changing.
				_caption.action(String(beat.get("caption", "(sound)")))
				await _hold(0.7)

			"shake":
				await _shake(float(beat.get("secs", 1.0)), float(beat.get("power", 10.0)))

			"flicker":
				await _flicker(float(beat.get("secs", 1.0)))

			"end":
				break

			_:
				push_warning("Unknown beat '%s' - skipped" % kind)

	_caption.hide_box()
	finished.emit()


func _hold(secs: float) -> void:
	await get_tree().create_timer(secs).timeout


func _shake(secs: float, power: float) -> void:
	# Decay rather than a hard stop: a shake that ends on a frame boundary looks switched off.
	var elapsed := 0.0
	while elapsed < secs:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		_stage.shake_power = power * maxf(0.0, 1.0 - elapsed / secs)
	_stage.shake_power = 0.0


func _flicker(secs: float) -> void:
	var elapsed := 0.0
	while elapsed < secs:
		# Uneven gaps, because a regular blink reads as a strobe rather than failing power.
		var gap := randf_range(0.04, 0.22)
		_stage.set_light(randf_range(0.15, 0.4) if randf() < 0.5 else 1.0)
		await _hold(gap)
		elapsed += gap
	_stage.set_light(1.0)
