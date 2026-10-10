# From a turnaround sheet to an animated character in Godot

Every step, in order, with the settings that matter. Deviating from any of them has cost
a day at least once, and the reason is given next to each so nobody has to rediscover it.

Read `ART_SPEC.md` first: it covers what the turnaround itself has to look like. This
document starts once an approved sheet exists.

    turnaround.png -> Tripo -> Mixamo -> Blender -> Godot

**Nothing is converted, rotated or re-posed between Tripo and Mixamo.** The mesh goes up
exactly as Tripo exports it. The Blender work happens on the way OUT of Mixamo, never on
the way in — a rotation applied before rigging is a conversion the pipeline does not ask
for, and Mixamo orients the character itself.


## 1. Cut the views

    python tools/crop_views.py art/characters/<id>/turnaround.png art/characters/<id>/views

Each figure is composited onto a shared canvas at a shared foot line rather than square
cropped, because a square crop around a tall narrow figure catches its neighbour. The tool
reports foot spread and centre spread; both must be 0 px.


## 2. Tripo — generate

Multiview, from the four cropped views. **Smart Mesh**, which gives quad topology and edge
loops around the eyes — that is what makes facial animation possible later. Texture at 8K.

Tripo will offer to rig the model. It does not matter whether you let it: the skeleton is
discarded in the next step.


## 3. Tripo — export

The export dialog, exactly:

| field | value | why |
| --- | --- | --- |
| Format | **FBX** | Mixamo takes fbx, obj or zip. Not glb. |
| preset | **Mixamo** | Tripo has a preset for this. Use it. |
| Texture Resolution | **8k** for the keeper, **512** for anything being uploaded | see below |
| Export Skeleton | **OFF** | the whole reason this works — see below |

**Export Skeleton must be OFF.** With it on, Tripo's FBX carries its own `mixamorig`
skeleton, Mixamo recognises it, skips the auto-rigger entirely and hands the file straight
back. The character then keeps Tripo's A-pose rest, while Mixamo's clips are authored
against Mixamo's own rest, and every limb rotation starts from the wrong angle — the mesh
tears and the hands roll. With it off, Mixamo builds its own skeleton in its own
convention and the clips fit.

**Texture resolution.** The 8K export is ~122 MB and cannot be pushed through the browser
bridge, which caps at 10 MB. Export **512** for the copy that goes to Mixamo — the texture
plays no part in rigging — and keep the 8K map to re-apply in Blender at step 6. The UVs
are identical, so it lines up.

The download arrives as a zip holding `tripo_convert_<uuid>.fbx` plus its `.fbm` texture
folder. Mixamo accepts the zip as-is.


## 4. Mixamo — rig

Upload the zip. The auto-rigger runs in three steps:

1. **Orient** — the character should already be upright and facing front. He will be: this
   is the round trip that fixes orientation. Do not pre-rotate anything to help it.
2. **Place markers** — chin, wrists, elbows, knees, groin, with *Use Symmetry* on so only
   one side needs placing. **Skeleton LOD: Standard Skeleton (65)**, which is the one that
   includes finger bones; `actors/parts/animator.gd` filters on them.
3. Wait ~2 minutes, then confirm.

If Mixamo jumps straight to a **Review** step without ever showing Orient or Place markers,
the upload still had a skeleton in it. Go back to step 3 and turn Export Skeleton off.


## 5. Mixamo — download the character and the clips

**The character:** clear any applied animation first (the × on the animation panel),
then Download → **FBX Binary (.fbx)**, Pose **T-pose**.

**Each clip:** search, click to apply, then Download →

| field | value |
| --- | --- |
| Format | FBX Binary (.fbx) |
| Skin | **Without Skin** |
| Frames per Second | **30** |
| Keyframe Reduction | none |

**Tick *In Place*** on anything that travels — the walk above all. The checkbox only
appears for clips with root motion. Doing it here is better than stripping the hips track
afterwards, because the clip is re-exported properly rather than patched.

*Without Skin* gives the motion on Mixamo's standard skeleton, which is the right choice
once the character has been auto-rigged by Mixamo: both share a rest pose. *With Skin*
gives the character's own rig but in a different axis convention, and reconciling the two
frames is unsolved — see the note at the end.

The adventure set, and the Mixamo clips they come from:

| our name | Mixamo clip |
| --- | --- |
| idle | Idle |
| idle_look | Looking Around |
| walk | Walking (In Place) |
| talk | Talking |
| point | Pointing Forward |
| pick_up | Picking Up Object |
| shrug | Shrugging |
| think | Thinking |
| bow | Quick Formal Bow |


## 6. Blender — the character

    blender.exe --background --factory-startup ^
        --python tools/from_mixamo.py -- <mixamo.fbx> <basecolor.jpg> <out.glb> 1.9

This does four things, and prints a measurement for each so a silent failure is impossible:

- **Stands him up.** Mixamo's FBX is Y-up; Blender is Z-up and its importer leaves this
  file's data Y-up, so he arrives lying on his back. The turn is **−90° about X**. Not
  +90: both make Z the tallest axis and both pass a size check, but +90 stands him on his
  head. The tool checks head-above-feet by bone and refuses to write the file otherwise.
- **Bakes the size into the bones**, not onto a node. He arrives 1 cm tall. A scale above a
  Skeleton3D breaks skinning, so the armature data and the mesh data are scaled directly
  and the object scale is reset to 1.
- **Drops him onto the floor**, so the game does not have to correct for it.
- **Re-applies the 8K texture**, which the 512 upload left behind.

Expected output for a 1.9 m character: `head z +1.34, left foot z +0.12`, hips at ~0.92
(49% of height), armature object scale `(1.0, 1.0, 1.0)`, `floor Z +0.000`.


## 7. Blender — the clips

    blender.exe --background --factory-startup ^
        --python tools/merge_animations.py -- <character.glb> <clips folder> <out.glb>

`--factory-startup` is not optional. Blender's factory scene is 24 fps and the FBX importer
overwrites the scene rate from whatever file it reads, so a merge done at the wrong rate
silently rescales every clip already in the file. The rate is pinned at both ends.

FBX clips are imported with `automatic_bone_orientation=False` and `ignore_leaf_bones=False`.
With bone orientation on, Blender recomputes every bone's roll, the action's rotations stop
meaning the same thing on the character's bones, and the mesh tears — while every bone name
still matches, so a name check passes and the file looks fine until something draws it.

Then check it:

    python tools/inspect_clips.py <out.glb>

Every clip must report **65/65 bones matched** and **drift 0.0**. Drift above ~1 is root
motion that will fight the game's own movement; it means a clip was downloaded without
*In Place*.


## 8. Godot

In the character's `.import`:

| key | value | why |
| --- | --- | --- |
| `nodes/root_scale` | **1.0** | the size is already baked into the bones |
| `animation/fps` | **30** | matches the merge |
| `animation/remove_immutable_tracks` | **false** | otherwise a pinned hips track snaps back to the rest pose |

`.import` files are gitignored, so a fresh clone loses them. Anything that matters belongs
in the `.glb`, which is why the size is baked rather than left in `root_scale`.

Godot caches imports aggressively and will happily report the clip list from a previous
build. After replacing a `.glb`:

    rm -f .godot/imported/<name>.glb-*
    godot --headless --path . --import

Then run it and **look at it**:

    godot --path . -- --shot

The startup line prints the measured size and the clip list, which is the quickest check
that the right file was loaded.


## What is still open

**Clips downloaded *With Skin*.** Mixamo retargets its library animation onto the
character's own skeleton server-side, which is the better source in principle. Those files
are Y-up while the character has been stood up, so the hips rotation lands a quarter turn
out and he folds in half on the first frame. Three attempts at reconciling the two frames
all failed; the code for them is in `merge_animations.py` behind `MATCH_CLIP_FRAME=1` and
`RETARGET=1`, both off by default, with the reason each one failed written beside it.

Not needed while the art follows `ART_SPEC.md`: a character modelled palms-down gets a rest
pose in Mixamo's own convention, and the *Without Skin* clips fit without any of this.
