@tool
class_name Approach
extends Resource
## Where a character stands to do one particular thing to one particular object, and
## which way they face while doing it.
##
## The default - walk to the nearest walkable point and turn toward the thing - is
## right most of the time and needs no authoring. This exists for when it is not.
##
## It is per ACTION, not per object, because the right place to stand depends on what
## you are doing. You talk to someone from the front. You take the key out of their
## back pocket from behind. Same person, same click, two different spots.

## Where to stand, in room space. ZERO means "work it out": the nearest point on the
## walkable area to the object.
@export var at := Vector3.ZERO
## Which way to face on arrival, in degrees. Ignored unless `face` is EXPLICIT.
@export var facing_degrees := 0.0
## FACE_OBJECT turns toward the thing being interacted with, which is almost always
## what you want. EXPLICIT uses `facing_degrees`, for standing behind someone while
## looking the other way. KEEP leaves whatever direction the walk ended in.
enum Face { FACE_OBJECT, EXPLICIT, KEEP }
@export var face: Face = Face.FACE_OBJECT
## How far from the object to stop when `at` is ZERO and the spot is worked out.
@export var standoff := 0.9


## A spot in front of `origin`, used when nothing was authored.
static func default_for(origin: Vector3, from: Vector3, standoff_distance := 0.9) -> Vector3:
	var toward := from - origin
	toward.y = 0.0
	if toward.length() < 0.001:
		toward = Vector3.BACK
	return origin + toward.normalized() * standoff_distance + Vector3(0, -origin.y, 0)
