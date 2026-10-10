# The dresser

A character is a rigged **body** plus **pieces** worn on it. Ported from Pillage
People, where it already works; the reasons for the design are in the files' own
headers and are not repeated here. This covers what is different in this game.

    dresser.gd       puts pieces on a body and takes them off
    outfit_piece.gd  one piece: its slot, how it is worn, where it sits
    outfit.gd        a whole character as a list of pieces
    skin_copy.gd     gives an unrigged piece the body's skin weights
    rig_space.gd     fit space: metres, T-pose, feet on the floor, Y up, facing +Z

`dressercheck.tscn` proves all of it on a real rigged body. Run it before trusting a
change:

    godot --headless --path . res://dressercheck.tscn

## What changed in the port

**Three slots for women.** `corset` goes over a shirt and under a coat; `skirt`
replaces trousers; `dress` replaces shirt and trousers together, because it is one
garment from shoulder to hem and cannot be split at the waist without a seam showing.

**Conflicting slots come off automatically.** `OutfitPiece.CONFLICTS` lists which
slots are the same cloth twice. Worn together the symptom is z-fighting, and
z-fighting on a moving character reads as a shader bug rather than as a mistake in the
outfit, so the dresser takes the loser off and says so.

**A pinned piece names a ROLE, not a bone.** Pillage People wrote `mixamorig_Head`
into every hat. That is right for anything Mixamo auto-rigs and useless for anything
else, and this cast will not all be humanoid. A hat now says `role = "head"` and the
dresser resolves it against the body it is going on:

1. the bone the piece names outright, if it set one
2. what the body's own `<body>.roles.json` says plays that role
3. the Mixamo names in `OutfitPiece.ROLE_BONES`
4. nothing - and that is an error, not a silent attach to bone zero

So a fish or a parrot only needs a file beside its body:

    {"head": "skull", "chest": "thorax"}

A humanoid needs no file at all.

## The workshop

    godot --path . res://actors/outfit/workshop.tscn

Where a piece is tried on and nudged into place. It lists everything in the model
folders by file name - nothing has to be registered - guesses a first fit from the
body's bones, and saves what you tune to `actors/outfit/pieces/`. A piece fitted once
is fitted for every outfit that wears it.

`retarget.gd` comes with it: a new body arrives from Tripo with a skeleton and no
clips, so the workshop lends it the captain's. It copies how far each bone has turned
from its own rest rather than the rotations as written, which is what lets rigs with
different rest poses and units share a clip.

Paths repointed for this game: bodies and pieces are looked for in
`art/models/characters` and `actors/outfit/placeholders`, and clips are borrowed from
`captain_live_animated.glb`.
