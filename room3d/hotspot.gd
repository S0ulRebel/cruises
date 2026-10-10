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

## Where the character stands to interact. A hotspot high on a wall cannot be walked
## to, so the approach point is authored separately from the thing itself.
@export var approach: Vector3 = Vector3.ZERO
## Shown when the cursor is over it.
@export var display_name := "thing"
## The response to LOOK. The bulk of an adventure game's writing lives in these.
@export_multiline var description := ""
## Picked up on USE rather than operated. The id it adds to the inventory.
@export var gives_item := ""
## Refuses USE until this item is held. Empty means no requirement.
@export var needs_item := ""
## Said when USE is attempted without `needs_item`.
@export_multiline var refusal := ""
## A conversation file, for hotspots that are people.
@export_file("*.json") var conversation := ""

signal looked(text: String)
signal used(item_given: String)
signal refused(text: String)
signal talked(conversation_path: String)


func _ready() -> void:
	input_ray_pickable = true
	if approach == Vector3.ZERO:
		# A sensible default beats a hotspot that cannot be reached: stand just in
		# front of it, on the floor.
		approach = global_position + Vector3(0, -global_position.y, 0.9)


## What clicking this does, given what the player is carrying. Returns the verb used,
## so the caller can decide whether to walk over first.
func resolve(held: String) -> Verb:
	if not conversation.is_empty():
		return Verb.TALK
	if not gives_item.is_empty() or not needs_item.is_empty():
		return Verb.USE if needs_item.is_empty() or needs_item == held else Verb.LOOK
	return Verb.LOOK


func interact(verb: Verb, held: String) -> void:
	match verb:
		Verb.TALK:
			talked.emit(conversation)
		Verb.USE:
			if not needs_item.is_empty() and needs_item != held:
				refused.emit(refusal if not refusal.is_empty()
					else "That is not going to work.")
				return
			used.emit(gives_item)
		_:
			looked.emit(description if not description.is_empty()
				else "It is a %s." % display_name)
