# Brief: characters come as pieces from now on

This replaces "one turnaround per character". A character is now a **body** plus
separate **pieces** that are swapped onto it, so one body can wear many heads and many
outfits, and a head can be remade without rebuilding the character.

Why, in one line each:
- Our characters cannot talk. Their mouths are painted on, not modelled. A separate
  head can be regenerated with a real open mouth without redoing the whole character.
- Polygons go where they are seen. Captain Livé spends 47% of his mesh on his head -
  and that figure includes his hat, hair and feather. A head generated on its own gets
  the whole budget for the face.
- A cruise ship is full of background people. One body, many heads and outfits.

---

## One sheet per piece

Each piece is its own four-view turnaround and becomes its own model. The slots:

| slot | what it is |
| --- | --- |
| `body` | the figure everything goes on. It KEEPS a head, as a rigging scaffold - the auto-rigger needs a chin to place its marker. That head is deleted in Blender after rigging and never ships, so it needs a skull, a jaw and a chin and nothing else: no likeness, no expression, no open mouth. The real head is its own piece |
| `head` | head and neck. **Mouth open** - see below |
| `hair` | hair alone |
| `hat` | hat alone |
| `face` | moustache, beard, eyepatch, mask |
| `shirt` | |
| `corset` | goes over a shirt, under a coat |
| `coat` | |
| `trousers` | |
| `skirt` | instead of trousers, never both |
| `dress` | instead of shirt AND trousers together - one garment, shoulder to hem |
| `waist` | sash, belt |
| `boots` | |
| `accessory` | pendant, pistol, bottle - anything hung on the figure |

A character only needs the slots it uses. Livé has no corset.

---

## The pose rule, and it is the one that breaks things

**The body sheet stays as it is: A-pose, palms DOWN**, exactly as `ART_SPEC.md`
already says. That has not changed.

**Every other piece is drawn in T-POSE: arms straight out sideways, horizontal,
palms down.** Not the A-pose.

The reason is not cosmetic. The body goes through the auto-rigger and comes back out
in a T-pose, and a piece is bent by copying the weights of the body underneath it. A
sleeve drawn hanging down gets weighted to the ribs instead of the arm, and then the
arm moves and the sleeve stays behind. A coat drawn in A-pose will do this. A coat
drawn in T-pose will not.

Pieces that do not reach the arms (hat, hair, boots, waist) have no pose to get wrong,
but draw them at the same scale as the body anyway.

---

## Heads: the mouth must be open

Every `head` sheet is drawn with the lips **slightly parted**, aiming for a gap of
**2-3% of head height**, per the 11 Oct mouth findings in `HANDOFF.md`. Livé's
wide-open source reconstructed a cavity but cannot close cleanly with the jaw alone.
The small opening must still read as depth into the head, not as a painted crease.

- **Teeth and tongue drawn and visible.** They are not in the current art and cannot
  be added afterwards. If they are not on the sheet they will not exist.
- Inside of the mouth dark but readable - suggest the back of the throat rather than
  filling it flat black.

**The side view is the one that decides whether this works.** The generator takes
exactly four images - front, left, back, right - and will not accept a close-up of the
mouth, so depth can only come from the profile. Draw the side view with the mouth
clearly open in profile, the gap between the lips readable, and the opening going back
into the head rather than looking like a notch on the outline. If a straight 90-degree
profile hides the mouth behind the nose, angle that view slightly toward the camera.
An imperfect side view is much better than a hidden mouth.

---

## Everything these have in common

- Four views: front, left, back, right. Same scale, same ground line, in that order.
- Clear empty space between the figures. Figures that touch cannot be cut apart.
- Plain flat background - the cutter reads the background from the corner pixel.
- No text, labels or callouts inside the turnaround band. They get cut out with the
  figure and generated into the model.
- For a piece with a hole - a belt buckle, a mug handle, a hat band - the hole must
  read as background in at least two views or it comes back solid.
- One piece per sheet. Not a coat and a hat on the same sheet.

---

## Women

A female body is a different build and needs its **own `body` sheet**. Clothing is
fitted in metres on the body it was drawn for, so a coat cut for Livé will not sit on
her. Her pieces are drawn on her body, in her T-pose.

---

## Order of work

**Initial scope: Captain Livé first.** His separate head passed the mouth-cavity
reconstruction check on 10 Oct; full body, garment fitting and jaw closure are
separate checks recorded in `HANDOFF.md`.

**Owner update, 11 Oct: create Santi Wong the same way.** This explicit request
supersedes the earlier Livé-only source-art gate for Santi. Inspect the approved
Santi artwork and corresponding Livé modular sheets before every new piece. Keep
Santi's short, stocky build, tall chef toque, curls, moustache/goatee, stained ivory
shirt/apron, striped breeches, leather harness, boots and red neckerchief.

Santi's sources are at `art/characters/santi_wong/pieces/asset.json`: the ten Livé
slots plus `accessory` for the neckerchief. The apron occupies the existing `coat`
slot. The neckerchief requires a SKINNED hold override; goatee follows Jaw while
moustache follows Head. Cookware stays separate. His assembled 1.70m silhouette
includes the toque; per-piece dimensions are provisional fitting guides. The source
rasters are not calibrated to common pixels per metre. Measure and fit the
reconstructed Santi body before applying clothing. Follow the current single-donor
armature procedure in `RIGGING.md`, rather than auto-rigging each component.

Source delivery does not establish Santi's mouth cavity, donor fit, garment
clearance or animation. These remain Open in the handoff.
