class_name Hotspot
extends Area3D
## A thing in the room worth clicking.
##
## Everything a point-and-click is made of: a door, a fishbowl, a cutlass on a desk.
## The player clicks it, the character walks over, and then one of a few things happens
## depending on what they were trying to do with it.
##
## The verbs are deliberately few. SCUMM shipped with twelve and spent years cutting
## them down, because a wall of verbs means the player brute-forces every one against
## every object instead of thinking. Three covers it: look at it, use or take it, talk
## to it. Which one fires is decided by context and by what is held, not by the player
## picking from a menu first.

enum Verb { LOOK, USE, TALK }

## Where the character stands to interact, per action.
##
## Keyed by verb NAME rather than by enum value, so adding a fourth verb later is one
## entry here and nothing else. An action with no entry falls back to `approach`, and
## `approach` with nothing authored falls back to the nearest walkable point. Nothing
## has to be filled in for a hotspot that behaves normally.
##
##     spot.approaches["TALK"] = front_of_him
##     spot.approaches["USE"]  = behind_him     # picking his pocket
@export var approaches: Dictionary = {}
## The fallback approach, used by any action without its own entry.
@export var approach: Approach
## Shown when the cursor is over it.
@export var display_name := "thing"
## The response to LOOK. The bulk of an adventure game's writing lives in these.
@export_multiline var description := ""
## Picked up on USE rather than operated. The id it adds to the inventory.
@export var gives_item := ""
## Refuses USE until this item is held. Empty means no requirement.
##
## The simple case: one lock, one key. For a hotspot where several items each do
## something different, use `combinations` instead - this stays because most hotspots
## are a lock or they are nothing, and making every one of them a table would be a
## table of one row.
@export var needs_item := ""
## Said when USE is attempted without `needs_item`, or with an item no combination
## covers. The generic "that is not going to work" is the least interesting line in an
## adventure game, so it is worth writing one per hotspot.
@export_multiline var refusal := ""

## What specific items do to this thing: `{ item_id: { ... } }`.
##
## This is where a puzzle game lives. A crate is not a lock that opens for one key -
## it is a thing you can prise with a rapier, bang with a ladle, or pour ink over, and
## two of those should say something rather than nothing. A wrong answer that is
## WRITTEN is a joke; a wrong answer that is silent is a bug the player blames
## themselves for.
##
## Each entry may carry:
##     say      what the character says. The whole point of the wrong answers.
##     gives    an item id added to the inventory
##     takes    an item id consumed - a key that stays in your pocket after it has
##              opened the door is a key you will keep trying on other doors
##     sets     a flag name, for the conversation and puzzle state to read
##     solved   true if this is the intended answer, so the hotspot can change state
##
## Checked BEFORE needs_item, so a hotspot can have both: a lock, and something funny
## to say to the people who try the wrong key.
@export var combinations: Dictionary = {}
## A conversation file, for hotspots that are people.
@export_file("*.json") var conversation := ""

signal looked(text: String)
signal used(item_given: String)
signal refused(text: String)
signal talked(conversation_path: String)
## A combination fired. Carries the whole entry, so the room can say the line, move
## the items and set the flag without knowing what any particular puzzle means.
signal combined(item_id: String, outcome: Dictionary)


func _ready() -> void:
	input_ray_pickable = true


## The approach for one action, or the fallback, or null for "work it out".
func approach_for(verb: Verb) -> Approach:
	var key: String = Verb.keys()[verb]
	if approaches.has(key) and approaches[key] is Approach:
		return approaches[key]
	return approach


## Where to stand and which way to face, resolved against the walkable area. `from` is
## where the character is now, so an unauthored hotspot is approached from the side he
## is already on rather than from an arbitrary one.
##
## Returns {"at": Vector3, "facing": float}. facing is NAN for "keep whatever you had".
func resolve_approach(verb: Verb, from: Vector3) -> Dictionary:
	var spec := approach_for(verb)
	var standoff: float = spec.standoff if spec else 0.9
	var at: Vector3 = spec.at if spec and spec.at != Vector3.ZERO 		else Approach.default_for(global_position, from, standoff)

	# Snap onto the walkable area. An authored point that drifted off the mesh, or a
	# computed one inside a wall, would otherwise leave the character walking forever.
	var map := get_world_3d().navigation_map
	if map.is_valid():
		at = NavigationServer3D.map_get_closest_point(map, at)

	var facing := NAN
	if spec == null or spec.face == Approach.Face.FACE_OBJECT:
		var toward := global_position - at
		toward.y = 0.0
		if toward.length() > 0.001:
			facing = rad_to_deg(atan2(toward.x, toward.z))
	elif spec.face == Approach.Face.EXPLICIT:
		facing = spec.facing_degrees
	return {"at": at, "facing": facing}


## What clicking this does, given what the player is carrying. Returns the verb used,
## so the caller can decide whether to walk over first.
func resolve(held: String) -> Verb:
	if not conversation.is_empty():
		return Verb.TALK
	# Holding something this thing has an answer for is a USE, even a funny one.
	if not held.is_empty() and combinations.has(held):
		return Verb.USE
	if not gives_item.is_empty() or not needs_item.is_empty():
		return Verb.USE if needs_item.is_empty() or needs_item == held else Verb.LOOK
	return Verb.LOOK


## What clicking this would read as, for the cursor caption. The player should know
## before they click whether they are about to look at the crate or prise it open with
## the rapier they are carrying.
##
## `held_name` is the display name of the held item, not its id - "Rapier", not
## "rapier" - because this is prose, not a lookup.
func phrase(verb: Verb, held_name := "") -> String:
	match verb:
		Verb.TALK:
			return "Talk to %s" % display_name
		Verb.USE:
			if not held_name.is_empty() and not needs_item.is_empty():
				return "Use %s on %s" % [held_name, display_name]
			if not held_name.is_empty():
				return "Use %s on %s" % [held_name, display_name]
			if not gives_item.is_empty():
				return "Take %s" % display_name
			return "Use %s" % display_name
		_:
			# A hotspot that WANTS something says so, so the player knows it is a lock
			# rather than scenery, without being told which key.
			if not needs_item.is_empty() and held_name.is_empty():
				return "Look at %s" % display_name
			return "Look at %s" % display_name


func interact(verb: Verb, held: String) -> void:
	match verb:
		Verb.TALK:
			talked.emit(conversation)
		Verb.USE:
			# A written outcome for this exact item beats both the lock and the
			# generic refusal, including when the outcome is "that did nothing, and
			# here is a line about it".
			if not held.is_empty() and combinations.has(held):
				combined.emit(held, combinations[held])
				return
			# Something is being used ON this, and this had no answer for it. Say so.
			# Without this a hotspot that has combinations but no needs_item swallows
			# every unlisted item in silence, which reads as a broken click.
			if not held.is_empty() and not combinations.is_empty():
				refused.emit(refusal if not refusal.is_empty()
					else "That is not going to work.")
				return
			if not needs_item.is_empty() and needs_item != held:
				refused.emit(refusal if not refusal.is_empty()
					else "That is not going to work.")
				return
			used.emit(gives_item)
		_:
			looked.emit(description if not description.is_empty()
				else "It is a %s." % display_name)
