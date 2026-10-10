# Modular characters, and cloth

Decided 10 Oct 2026, while there were two characters instead of nine.

## The approach

Ported from Pillage People, which already has it working: `actors/outfit/dresser.gd`,
`skin_copy.gd`, `rig_space.gd`, `outfit_piece.gd`, `retarget.gd`, and a fitting
workshop (`workshop.tscn`, F6). Nothing here is new design — it is a port.

A character is a rigged `body` plus pieces named `<slot>_<name>.glb`:

| Slot | Worn how |
| --- | --- |
| `body` | the rigged base everything goes on |
| `head` | bends at the neck |
| `jaw`, `hair`, `face`, `hat`, `accessory` | rigid, ride a bone |
| `shirt`, `coat`, `trousers`, `waist`, `boots` | bend with the body |
| `corset`, `skirt`, `dress` | bend with the body - added for this game, see below |

Three slots Pillage People does not have, because this cast has women in it:

- **`skirt`** replaces `trousers`. One slot or the other, never both.
- **`dress`** replaces `shirt` AND `trousers` together, because it is one garment from
  shoulder to hem and cannot be split at the waist without a seam showing.
- **`corset`** sits over `shirt` and under `coat`. It is its own slot rather than a
  second `shirt` because the dresser wears exactly one piece per slot.

The dresser must refuse `dress` worn with `shirt`, `trousers` or `skirt`, and `skirt`
worn with `trousers` - otherwise the conflict shows up as z-fighting rather than as an
error.

**A female body is a different build, so it needs its own `body_` file and its own
fits.** Pillage People's own note applies unchanged: a fit is in metres on the body it
was made on, and a coat cut for one build will not sit on another. Plan for at least
two bodies from the start rather than retrofitting one.

Pieces arrive **unrigged, in the body's T-pose**, and the dresser copies the body's
weights onto them. A sleeve modelled hanging down gets weighted to the ribs instead of
the arm, so the T-pose is not optional.

## Why, in order of what it actually buys

**The head becomes replaceable.** Our characters cannot talk because their mouths are
painted on (see `FACES.md`). Modular means regenerating one head with an open mouth
rather than redoing a whole character — model, texture, rig, clips and scene placement.

**The polygon budget goes where it is seen.** Measured on Captain Livé, attributing
each polygon to the bone it is mostly weighted to:

| region | polys | share |
| --- | --- | --- |
| head + neck | 5,092 | 46.7% |
| legs + feet | 2,596 | 23.8% |
| hands | 1,290 | 11.8% |
| torso + hips | 1,083 | 9.9% |
| arms | 846 | 7.8% |
| **total** | **10,907** | |

That 46.7% includes his hat, hair and feather, all weighted to the head bone. Generate
the head on its own, with the hat as its own piece, and the whole budget goes to the
face. Bodies that are always under a coat can then be cheap.

**Reuse.** A cruise ship is full of background people. One body, many heads and
outfits.

## What it does NOT fix

**Clipping.** Separate meshes interpenetrate exactly as happily as fused ones. Livé's
hand goes through his coat either way. Modularity is a precondition for fixing it, not
the fix.

## Cloth

### SoftBody3D does not work for this

`SoftBody3D` exists in 4.7.2 and simulates, but **it does not collide**. Measured: a
12x12 cloth dropped from y 1.0 onto a 10x10 static floor box at y 0.0, mask 1 against
layer 1, `simulation_precision` 10.

    tick  60  mean y  -3.006  lowest y  -3.006
    tick 300  mean y -54.780  lowest y -54.780

It free-falls through the floor, and mean equals lowest at every sample, so the sheet
does not even deform on the way down. The same result under the default engine and
under `GodotPhysics3D`, so it is not a Jolt-versus-Godot-Physics question.

### SpringBoneSimulator3D is the route

Present in 4.7.2, with `SpringBoneCollisionSphere3D`, `SpringBoneCollisionCapsule3D`
and `SpringBoneCollisionPlane3D`. It is a `SkeletonModifier3D`: a bone chain is given
`stiffness`, `drag`, `gravity` and a `radius`, and it collides with collision shapes
parented into the skeleton.

So "the coat moves when a hand touches it" is: capsules on the forearms and hands, a
short bone chain down each coat tail, the coat skinned to those bones. Bone-driven, so
it costs almost nothing next to a cloth solve, and it is the approach VRM uses for
hair and cloaks.

**This is untested on our characters** and cannot be tested until a coat exists as its
own mesh with its own bones — which is the modular work above. Do not record it as
working until it has been measured the way SoftBody3D was.


## Adding slots, and non-human characters

A slot costs **two lines**, both in `actors/outfit/outfit_piece.gd`: a name in `SLOTS`
and an entry in `DEFAULTS` saying whether it bends with the body or rides a bone.
Nothing registers a piece anywhere else - the workshop lists whatever is in the folder
and sorts it by the part of the file name before the first underscore. So `tail`,
`wing`, `fin`, `tentacle`, `shell`, `extra_arm` are all cheap to add.

What is **not** free is the bone names. `DEFAULTS` pins hats, hair and masks to
`mixamorig_Head` and accessories to `mixamorig_Spine2`. A body without those bones has
nothing for a pinned piece to hang on. Two consequences:

- A non-human that still has a humanoid skeleton - a gnome, an ogre, anything Mixamo
  will auto-rig - works with no changes at all. It is just another `body_` file.
- A non-human whose skeleton is its own shape - a fish, a bird, a crab - needs the
  pinned bone named per body rather than per slot. That is a small change to make
  during the port, and much cheaper than discovering it later.

Skinned pieces do not have this problem: they copy whatever weights the body has, so
they work on any skeleton.

The dresser refuses a body with no skeleton at all. Count Fingers is currently unrigged
(see `tools/unrig.py` and why), so he does not go through this system - which is fine,
a fish wears nothing.
