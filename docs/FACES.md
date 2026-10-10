# Faces, and why the characters cannot talk

Settled 10 Oct 2026, after three sessions spent a day costing rigs for a problem that
is not a rig problem.

## The measurement

Both characters rendered **untextured**, so paint cannot be mistaken for geometry
(`--factory-startup`, a flat clay material, sun lamps with `use_shadow=False` because
the captain's hat throws the whole face into shadow):

| character | lower face | mouth |
| --- | --- | --- |
| Captain Livé | one smooth surface, nose to chin | **painted into the basecolor map.** No lips, no crease, no opening |
| Santi Wong | sculpted upper and lower lip, closed | a crease. No opening |

Neither has teeth, tongue or any interior. Driving a jaw on either tears the skin and
shows the inside of the head.

## What that rules out

**A jaw bone.** Not for the reason first given — that Mixamo's auto-rigged rest
rotations are irregular per character. That argument is about *inherited* bones; a jaw
we add in Blender has whatever rest we choose and is identical across characters by
construction. It is ruled out because there is nothing to open.

**Blendshapes.** Same reason. No character has any (`0 shape keys` on every GLB), and
adding them would be deforming a closed surface into a closed surface.

**A portrait rendered from the 3D head.** There is nothing to render. This was the
attractive option — one face serving the panel and the scene — and it is not available.

**Texture swapping the mouth region.** Tripo's UV atlas scatters the face across the
whole map: the forward-facing polys in the mouth band span u 0.001–0.999, v 0.011–0.996.
There is no rectangle to replace; a mouth state would mean a whole new 8K texture.

## What is decided

The dialogue portrait is **2D mouth states, generated per character, swapped as
sprites** in the 300x300 panel: closed / slightly open / open, plus a blink and a
couple of expressions. Around five states, driven by text timing, not phonemes —
nobody reads phonemes at 300px. Teeth and tongue have to be generated; they are not in
the source art and cannot be inpainted.

Not Spine: a 300px portrait does not need a runtime. Not video: Godot 4.7.2 ships
`VideoStreamTheora` and nothing else — ClassDB lists no mp4, webm, mkv or avi importer.

**In-game talking is parked.** The owner called it nice-to-have, not mandatory, and it
is unavailable at any sane cost.

## What is not decided, and must not be guessed

- **Cinematics** may be pre-rendered video. The owner said "might". Generative video
  needs no geometry — it redraws pixels, so it can open a mouth our mesh cannot. If
  cinematics go that way, nothing in 3D needs a face.
- **VO** has never been raised, by anyone. That is not the same as "no". Do not build
  for phonemes now; do not make adding VO later impossible.

## The one thing that would reopen 3D faces

Whether Tripo, or another generator, can produce a head with an actual open mouth
cavity from our turnarounds. That is a question about the generator, not about Godot
or about rigging.
