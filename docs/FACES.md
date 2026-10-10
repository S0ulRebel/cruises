# Faces

**The characters can talk.** Settled 10 Oct 2026 by generating a head on its own from
an open-mouth turnaround and looking at the result untextured.

## What changed

The two characters built before the modular decision - Livé and Santi, generated as one
fused figure each - have no mouth. Rendered untextured, Livé's lower face is one smooth
surface from nose to chin and the mouth is painted into the basecolor map; Santi has a
sculpted closed lip line and no opening. Neither has teeth, tongue or any interior, so
no jaw bone and no blendshape can open one.

That was taken as a limit of the pipeline. It is not. It is a limit of asking for a
closed mouth.

## The measurement

`pieces/head/sheet.png` drawn with the mouth open mid-word, teeth and tongue visible in
all three face views, the opening going back into the head in profile. Four views at
1602x1602 through Tripo Smart Mesh P2.0, quad topology, polycount at the 25,000 maximum
because a head generated on its own gets the whole budget.

What came back, measured rather than eyeballed:

| | |
| --- | --- |
| faces / vertices | 26,493 quads reported; 51,426 tris on glTF import, 26,301 verts |
| quad recovery | 23,774 quads, 3,878 tris, 0 ngons after tris-to-quads - **86% quad** |
| poles (6+ edges) | 675 of 26,301 verts, **2.6%** |
| shells | 35 |
| boundary edges | 1,182 |

**The shells and boundary edges are the point, not a defect.** The neck is open, so the
head slots onto a body instead of being a capped ball hidden inside one. The mouth
interior is open, so it is a cavity rather than a dent. The separate shells are the
teeth and the tongue, which are modelled as their own geometry.

Topology, looked at rather than counted: concentric loops round both eyes, loops round
the lips, even quad flow across the brow and cheek, individual teeth with their own
loops, a tongue that is its own shell inside an open throat.

## What this unlocks

- **A jaw bone** now has something to open, and the geometry behind it exists.
- **Blendshapes** are back on the table for close-up work.
- **The dialogue portrait can come from the 3D head** after all, rendered into a
  SubViewport, instead of a separate 2D asset chain that would have to be kept in sync.
- **In-game talking**, which the owner called nice-to-have, is reachable.

None of it is built yet, and none of it should be written down as working until it has
been measured the way this was.

## The rule that produced it

Generate the head **on its own**, from a sheet whose mouth is open, with teeth and
tongue drawn, and the side view showing the opening going back into the head. The
generator takes exactly four images and will not accept a mouth close-up, so the profile
is the only thing that tells it how deep the cavity goes.

See `docs/ARTIST_BRIEF_PIECES.md` for the sheet requirements and `docs/MODULAR.md` for
why the head is a separate piece at all.

## Still true

- Godot 4.7.2 ships `VideoStreamTheora` and nothing else - no mp4, webm, mkv or avi.
- Tripo multiview takes exactly four images, front/left/back/right, front required.
- Livé's and Santi's EXISTING fused models still cannot talk. They are superseded by
  the per-piece rebuild, not fixed by it.
