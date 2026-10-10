class_name Speech
extends RefCounted
## Turns a line of dialogue into a timed sequence of mouth poses.
##
## There is no recorded voice, so the timing comes from the text: how many words, how
## fast this character talks, where the punctuation is. The LETTERS decide the shape -
## "oo" is a different mouth from "ee" - which is the whole reason this reads as
## speech rather than as a jaw flapping at a constant rate.
##
## Approximate on purpose. English spelling is not phonetic, so a letter map is wrong
## about a good fraction of words, and at the size a face is drawn nobody is lip
## reading. Being wrong in a plausible rhythm looks like talking; being right would
## cost a pronunciation dictionary and look identical.
##
## Pure logic with no nodes in it, so it can be checked without rendering anything -
## see speechcheck.tscn. The data it reads is authored by the face-animation session:
##
##     data/speech/letter_shapes.json   letter -> jaw and the three lip shapes
##     data/speech/voices.json          per-character speaking style

const SHAPES_PATH := "res://data/speech/letter_shapes.json"
const VOICES_PATH := "res://data/speech/voices.json"

## A mouth at rest, if the data does not say. The head is modelled MID-WORD, so a
## closed mouth is not an all-zero pose: the jaw brings the teeth together but the
## lips stay apart, and it takes some PRESSED to seal them. letter_shapes.json carries
## the real value per project; this is only the fallback when the file is missing.
const REST_FALLBACK := { "jaw": 0.0, "wide": 0.0, "round": 0.0, "pressed": 0.35 }

static var _shapes: Dictionary = {}
static var _voices: Dictionary = {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_shapes = _read(SHAPES_PATH)
	_voices = _read(VOICES_PATH)


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Speech: no data at %s; mouths will not move." % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## The speaking style for a character, falling back to _default. An unknown character
## still talks rather than standing there with their mouth shut.
## The mouth at rest, from the data. NOT all zeros - see REST_FALLBACK.
static func rest() -> Dictionary:
	_load()
	var pose: Variant = _shapes.get("rest")
	if pose is Dictionary:
		return {
			"jaw": float(pose.get("jaw", 0.0)),
			"wide": float(pose.get("wide", 0.0)),
			"round": float(pose.get("round", 0.0)),
			"pressed": float(pose.get("pressed", 0.35)),
		}
	return REST_FALLBACK.duplicate()


static func voice(character_id: String) -> Dictionary:
	_load()
	if _voices.has(character_id):
		return _voices[character_id]
	return _voices.get("_default", {
		"wpm": 150.0, "jaw_max": 22.0, "jaw_closed": -3.25,
		"shape_gain": 0.85, "pause_hold": 0.36, "comma_hold": 0.18, "undershoot": 0.15,
	})


## The pose for one letter or digraph, or null if the map has nothing for it.
static func pose_for(token: String) -> Variant:
	_load()
	for section in ["digraphs", "vowels", "consonants"]:
		var table: Dictionary = _shapes.get(section, {})
		if table.has(token):
			return table[token]
	return null


## Split a line into the units that each get their own mouth pose: a digraph if the
## map knows one, otherwise a single character. Punctuation comes through as itself so
## the timing can hold on it.
static func tokenise(text: String) -> PackedStringArray:
	_load()
	var digraphs: Dictionary = _shapes.get("digraphs", {})
	var out := PackedStringArray()
	var lower := text.to_lower()
	var i := 0
	while i < lower.length():
		var two := lower.substr(i, 2)
		# Digraphs before single letters, or "oo" is read as two separate vowels and
		# the mouth bounces where it should hold.
		if two.length() == 2 and digraphs.has(two):
			out.append(two)
			i += 2
			continue
		out.append(lower[i])
		i += 1
	return out


## A line of dialogue as keyframes:
##     [{ "t": seconds, "jaw": 0..1, "wide": 0..1, "round": 0..1, "pressed": 0..1 }]
##
## jaw is a FRACTION of the character's jaw_max rather than degrees, so one letter map
## serves every character and a mumbler and a bellower read from the same table.
static func plan(text: String, character_id: String) -> Array:
	_load()
	var v := voice(character_id)
	var wpm: float = float(v.get("wpm", 150.0))
	var undershoot: float = clampf(float(v.get("undershoot", 0.15)), 0.0, 1.0)
	var pause_hold: float = float(v.get("pause_hold", 0.36))
	var comma_hold: float = float(v.get("comma_hold", 0.18))
	var gain: float = float(v.get("shape_gain", 1.0))

	if text.strip_edges().is_empty():
		return []
	var words: int = text.split(" ", false).size()
	if words == 0:
		return []
	# How long the whole line should take, then shared out over the sounds in it.
	var total: float = float(words) / maxf(wpm, 1.0) * 60.0

	var tokens := tokenise(text)
	var sounds := 0
	for token in tokens:
		if pose_for(token) != null:
			sounds += 1
	if sounds == 0:
		return []
	var step: float = total / float(sounds)

	var keys: Array = []
	var t := 0.0
	var at_rest := rest()
	keys.append(_key(t, at_rest))
	for token in tokens:
		if token == "." or token == "!" or token == "?":
			# Shut, and hold. A full stop you can see is most of what makes a rhythm
			# read as sentences rather than as one continuous noise.
			keys.append(_key(t, at_rest))
			t += pause_hold
			keys.append(_key(t, at_rest))
			continue
		if token == "," or token == ";" or token == ":":
			keys.append(_key(t, at_rest))
			t += comma_hold
			keys.append(_key(t, at_rest))
			continue
		var pose: Variant = pose_for(token)
		if pose == null:
			continue
		# Undershoot pulls every target back toward rest: the difference between
		# someone enunciating and someone mumbling through a sentence.
		var reach: float = 1.0 - undershoot
		keys.append({
			"t": t,
			"jaw": float(pose.get("jaw", 0.0)) * reach,
			"wide": float(pose.get("wide", 0.0)) * reach * gain,
			"round": float(pose.get("round", 0.0)) * reach * gain,
			"pressed": float(pose.get("pressed", 0.0)) * reach * gain,
		})
		t += step
	keys.append(_key(t, at_rest))
	return keys


static func _key(t: float, pose: Dictionary) -> Dictionary:
	return { "t": t, "jaw": pose["jaw"], "wide": pose["wide"],
		"round": pose["round"], "pressed": pose["pressed"] }


## The mouth at time `t`, interpolated between keyframes.
##
## The three lip shapes are clamped to sum to 1. They ADD on the mesh, so an
## overlapping ROUND and PRESSED mid-transition can otherwise push the lips further
## than either shape ever does alone, into a shape nobody authored.
static func sample(keys: Array, t: float) -> Dictionary:
	if keys.is_empty():
		return rest()
	if t <= float(keys[0]["t"]):
		return _strip(keys[0])
	var last: Dictionary = keys[keys.size() - 1]
	if t >= float(last["t"]):
		return _strip(last)

	for i in keys.size() - 1:
		var a: Dictionary = keys[i]
		var b: Dictionary = keys[i + 1]
		var ta: float = float(a["t"])
		var tb: float = float(b["t"])
		if t < ta or t > tb:
			continue
		var span: float = tb - ta
		var f: float = 0.0 if span <= 0.0 else (t - ta) / span
		return _clamp_shapes({
			"jaw": lerpf(float(a["jaw"]), float(b["jaw"]), f),
			"wide": lerpf(float(a["wide"]), float(b["wide"]), f),
			"round": lerpf(float(a["round"]), float(b["round"]), f),
			"pressed": lerpf(float(a["pressed"]), float(b["pressed"]), f),
		})
	return _strip(last)


static func _strip(key: Dictionary) -> Dictionary:
	return _clamp_shapes({ "jaw": float(key["jaw"]), "wide": float(key["wide"]),
		"round": float(key["round"]), "pressed": float(key["pressed"]) })


static func _clamp_shapes(pose: Dictionary) -> Dictionary:
	var sum: float = pose["wide"] + pose["round"] + pose["pressed"]
	if sum > 1.0:
		var scale: float = 1.0 / sum
		pose["wide"] *= scale
		pose["round"] *= scale
		pose["pressed"] *= scale
	pose["jaw"] = clampf(pose["jaw"], 0.0, 1.0)
	return pose


## How long a line takes to say, for whoever is holding the caption up.
static func duration(keys: Array) -> float:
	return 0.0 if keys.is_empty() else float(keys[keys.size() - 1]["t"])


## The jaw angle in DEGREES for this character, from a 0..1 pose. The mesh is modelled
## with the mouth already open, so closed is a NEGATIVE angle - see voices.json.
static func jaw_degrees(pose: Dictionary, character_id: String) -> float:
	var v := voice(character_id)
	var closed: float = float(v.get("jaw_closed", -3.25))
	var widest: float = float(v.get("jaw_max", 22.0))
	return lerpf(closed, widest, clampf(float(pose.get("jaw", 0.0)), 0.0, 1.0))
