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

Every `head` sheet is drawn with the mouth **open**, roughly as if mid-word - not a
yawn, not a grin. The opening must read as a hole in the head, not as a crease.

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

**Captain Livé first, and only him.** Body, head, hat, hair, face, shirt, coat,
trousers, waist, boots.

We put that one set through the whole pipeline before anyone draws a second character.
The head is the risk: nobody yet knows whether the generator will build a real mouth
cavity from a drawn one, or seal it over. That answer changes the brief, and it is
much cheaper to learn it once.
