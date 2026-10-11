# Art specification

The contract between whoever makes the art and the engine that has to load it.

Written for an agent or a person working on the art side, so that assets arrive usable
the first time. Everything here is a requirement with a reason. If a reason stops
applying, change the rule — but change it here, not in one asset.

Target resolution is **1920 × 1080**. Everything is authored at that scale.

---

## 1. Characters

### Pipeline

```
character sheet  ->  cropped views  ->  2x upscale  ->  Tripo  ->  rigged GLB  ->  Godot
```

Tripo, not a local image-to-3D model: better topology, and no territory restriction.
Hunyuan3D excludes the EU, the UK and South Korea, and this game sells into all three.

### Do not crop the views by hand

`tools/crop_views.py` does it. Tripo treats the four views as one object seen from four
angles, so a difference in framing between them is read as a difference in shape. Four
hand-made crops give four framings; the script gives one, measured.

```
python tools/crop_views.py art/characters/captain_live/sheet.png     --row 0.06 0.40 --cols 0.25 0.62     --out art/characters/captain_live/views
```

`--row` and `--cols` bound the turnaround band as fractions of the sheet, because a
design sheet is mostly text and panels and automatic detection finds all of it. Run with
`--dry-run --preview check.png` first and look at the strip.

What it guarantees: every figure cut to its own bounds, composited onto a shared square
canvas in the sheet's own background colour, at a shared foot line, horizontally centred.
Nothing from the surrounding sheet is included — these characters are tall and narrow on
a closely spaced row, so a square window big enough for the height always reaches into
the neighbours. Real height differences between characters are preserved; framing
differences are not.

It writes `views.json` beside the images recording the native crop size, the output size
and whether anything was upscaled, which answers the provenance question before it is
asked.

### What the art side delivers

Per character, a folder named after the character in lower snake case:

```
art/characters/captain_live/
├── sheet.png              the full design sheet, for reference
├── views/
│   ├── front.png
│   ├── three_quarter.png
│   ├── side.png
│   └── back.png
└── palette.json           the swatches off the sheet
```

**The four views are the Tripo input and the only part with hard rules:**

- Square canvas, same size for all four, minimum 1024 × 1024 after the 2× upscale.
- Identical framing between views. The character must be the same height and sit at the
  same vertical position in all four, or the reconstruction skews.
- Whole figure in frame. No cropped feet, no cropped hat, no cropped weapon.
- Flat neutral background, or transparent. No cast shadows, no scenery, no ground plane.
- Lighting: as flat and even as the source allows.

  The rule is "do not bake a key light into the texture", and the reason stands — the
  room lights the character in engine, and a shadow painted onto the coat contradicts
  every room it ever stands in. But the existing sheets were rendered before this spec
  and already carry soft directional light, and no amount of cropping or resampling
  removes it. So, in order of preference:

  1. A new view rendered flat, if the character is being made from scratch.
  2. The existing sheet as-is, where its light is soft and **identical across all four
     views**. Mild baked light is survivable in a stylised look; light that moves
     between views is not, because the reconstruction reads it as geometry.
  3. De-lit in post, only if 2 fails.

  Whichever applies, record it in `palette.json` so the character shader can be told
  how much in-engine light to add rather than double-lighting the figure.
- Arms away from the torso where possible. Limbs touching the body fuse in the mesh.
- Same outfit, same props, same everything across all four. The sheets already solve
  this — crop from one sheet, never regenerate per view.

### Tripo settings that work

Established by testing Captain Livé end to end:

- **Smart Mesh**, not HD Model. HD Model returned triangles and duplicated the hat
  feather into two mirrored feathers; Smart Mesh returned quads and reconstructed the
  tricorn correctly. 6,601 quads against 9,618 triangles for the same character.
- **Give it a text prompt as well as the views** — "pirate character model with tricorn
  hat, red sash, black coat and brown boots". Naming the hat is probably why it stopped
  dissolving into feathers.
- **Texture with Remove Lighting ON**, generated at 8K. Author high and downscale at
  export; the export dialog has its own resolution.
- **Rigging: Humanoid, Mixamo preset.** Comes back with all 65 bones Mixamo-named, so
  Mixamo animation retargets directly. A relaxed stance rigs fine - the T/A-pose
  warning did not matter.

### The turnaround must be in an A-pose

Not a character pose. This is the single most expensive thing learned so far.

Tripo rigs the model in whatever pose the views show, and that pose becomes the
skeleton's **rest pose**. Mixamo animation - and anything generated against a Mixamo
rig, including HY-Motion - stores rotations *relative to a T-pose rest*. Feed those to
a rig whose rest is a relaxed stance and every clip shears the character into a heap.

Captain Livé's turnaround has him standing naturally, so he cannot be animated by any
borrowed clip. Five separate routes were tried - a hand-written retargeter, a direct
track copy, the same with position tracks stripped, Godot's own humanoid bone-map
retargeting, and clips generated onto the Mixamo Y Bot - and all five deform him. The
model itself is correct and stands fine; it simply cannot accept animation.

**So: arms out at roughly 45 degrees, legs slightly apart, palms facing DOWN,
fingers relaxed and separated.** Tripo says the same at its rigging step ("Use a T- or
A-pose for best results"), and it means it.

#### Palms DOWN, not forward. This line used to say forward, and it cost a day.

Mixamo's own rigs are built palms down, and its clips store wrist and forearm rotations
relative to that. Captain Livé was modelled palms forward, so Mixamo's auto-rigger built
his hand bones a quarter turn out of convention and every clip started its wrist rotation
from the wrong angle: his arms hung at his sides with the palms facing the camera and the
thumbs pointing at the floor.

Measured on the same frame of the same Mixamo idle, as the vertical component of the
pinky-to-thumb vector:

| rig | thumb above (+) or below (-) the pinky |
| --- | --- |
| Mixamo's own skeleton | **+0.47** |
| Captain Livé | **-0.42** |

A clean flip. Four fixes were tried on the rig and none of them can work, for one reason
worth remembering: **retargeting carries over how far a bone has TURNED from its rest, so
a rest that is itself rolled stays rolled.** Aligning all 58 arm and hand bone rolls to
the Mixamo skeleton changed the measurement by nothing; a full rest-frame retarget made it
worse (-0.48). The rest pose comes from the art, and only the art can fix it.

Checked with `tools/from_mixamo.py`, which refuses to write a character who is upside
down, and by posing the merged clip and measuring the hand - never by eye, because a
90 degree twist down a forearm is invisible at the size the character appears on screen.

The character's personality lives in the animation, not in the turnaround pose.

### Then run it through Blender. This step is not optional.

A raw Tripo GLB **collapses to a crumpled mass in Godot**. The file is valid - 65
inverse bind matrices, sane joints and weights - but Godot's importer cannot resolve
its skin and the mesh implodes toward the origin.

The fix is a Blender import/export round-trip, which rewrites the skin:

```
blender --background --factory-startup --python tools/roundtrip.py -- in.glb out.glb
```

`--factory-startup` matters: installed add-ons crash Blender in background mode.

How to tell a file has been through it: its `asset.generator` reads
`Khronos glTF Blender I/O`, not `Tripo`. That one string is the difference between a
character that works and one that does not.

### What comes back

A rigged **GLB**, Mixamo-compatible skeleton, under ~50k triangles.

- **Origin at the feet**, centred left-to-right. The engine places characters by their
  feet because that is what stands on the floor and what depth-sorts correctly. A model
  with its origin at the hips floats or sinks in every room.
- Facing **+Z** in the bind pose.
- Bake measured dimensions into the exported model and use `nodes/root_scale=1.0`.
  Version `.glb.import` settings. Do not rescale or guess orientation at startup.
- Export Y-up glTF and preserve measured prefab-child orientation. New modular parts
  use the pinned donor and fitting rules in `RIGGING.md`.
- One metre in the model equals **one metre**. Scale is on the sheets — Livé 1.9 m,
  Mehmet 1.8 m, Santi 1.7 m, Al 1.7 m, Count Fingers 6–8 cm.

  **Measured, not estimated.** With the blockout camera (42° FOV, 2.6 m high, 9 m back,
  pitched −14°), a 1.9 m character on a 1920×1080 screen renders:

  | position | height on screen |
  |---|---|
  | downstage, front of room | **392 px** |
  | upstage, back wall | **246 px** |

  So a character occupies between 23% and 36% of screen height. Texture detail finer
  than that is invisible — 2048² is generous, and 1024² is honestly enough for anyone
  who is not Livé. These are historical blockout-camera measurements. The current
  authored cabin camera is at (0, 3.4, 6.2), pitch -17 degrees, FOV 62 degrees.
  This framing follow-up keeps every prop visible and preserves object placement;
  the original camera is recorded in docs/migration/baseline_layout.json.
  Use a dedicated render harness to re-measure after changing the camera.
- Textures no larger than 2048 × 2048, one material per character where possible.

---

## 1A. Props — static object turnarounds

This contract applies to props. It overrides the character section's view selection
and background options; character pose and rigging rules do not apply. A prop goes
from its sheet through cropped views to Tripo as one static object, without a rig.

### What the art side delivers

```
art/props/<id>/
├── sheet.png              one object in four views, in a single horizontal row
└── asset.json             dimensions, provenance and pipeline status
```

Use the character `asset.json` files as the sidecar pattern. Record the prop's actual
width, height and depth in metres in `dimensions_m`, together with the view order and
the tool that produced the sheet. The engine uses these measurements to scale the
model; the apparent size of the object on the sheet is not its game-world size.

### Sheet rules

- **Model the object only, never a dressed arrangement.** A desk is bare. Charts,
  an inkwell and a compass each get their own sheet and asset, because the player can
  pick them up and use them separately. Apply this to every future prop.
- **Choose one fixed reconstruction orientation that exposes the working parts.**
  It may differ from the object's resting orientation in the game. Keep that same
  orientation in all four views and rotate only the viewing direction. The images
  must reveal the features needed to reconstruct and recognise the object; four
  repeated views of a casing that hide its functional face are insufficient.
- **Four views, left to right: front, left side, right side, back.** These are strict
  orthographic elevations, with the camera level at the middle of the object, looking
  straight at each face. No perspective, camera tilt or three-quarter angles. The back
  must show the actual back, not another angle on the front.
- **One camera scale for all four views of a prop.** Keep camera distance and
  orthographic scale unchanged. Measure the object's height in every view: the pixel
  heights must match, allowing at most 1 px of raster rounding. A different rendered
  height becomes a different shape in reconstruction. Do not enlarge narrow side
  views to fill their frames; their widths must follow the object's depth, while the
  front and back widths follow its width.
- **Use the frame for the individual asset.** A small inventory object can fill its
  own sheet as much as a large piece of furniture does. There is no shared pixel scale
  between different assets; there is a shared pixel scale between the four views of
  the same asset. Scale in the engine from the sidecar's measurements.
- **Whole object, same ground line and clear space.** Every view must be complete,
  at the same vertical position, with its lowest point on a common baseline (within
  1 px). Leave a clear vertical band of empty background between each view so the
  cutter can separate them. The baseline is an alignment, not a drawn line.
- **Plain flat white background.** No scenery, floor plane, cast shadows, borders,
  labels, dimensions or callouts in the turnaround band. The background must stay
  uniform, including the corners and the gaps between views.
- **Same design and finish in all four views.** Keep construction, fittings, colour,
  wear and lighting consistent. Generate one coherent sheet, not four unrelated
  images. Use broad, readable forms and soft, even form shading; record any baked
  lighting in the sidecar so it is not doubled in the engine.
- **Show genuine openings.** Where an object has a through-hole, make the background
  visible through it in at least two views. Do not change the required camera angles
  to suggest a hole that the geometry does not have.

### Reconstruction orientation and engine placement

A compass that lies flat in the room can stand upright on its edge for reconstruction.
The front then shows its dial, glass and needle; the left and right show the casing's
true edge profiles; the back shows the underside. For the 0.09 m diameter, 0.03 m thick
compass, the front and back project to 9 × 9 cm and the edge views to 3 × 9 cm. All
four have a 9 cm height at one orthographic scale. Keep the edge views narrow.

Record both the reconstruction orientation and its dimensions in `asset.json`, along
with the corrective rotation and axis convention needed for engine placement. For
this compass the reconstruction dimensions are 0.09 × 0.09 × 0.03 m (W × H × D).
Rotate the reconstructed mesh 90° into its flat, dial-up resting orientation before
checking and applying the engine dimensions, 0.09 × 0.03 × 0.09 m. `dimensions_m`
continues to describe that engine resting orientation. Do not compensate for a pose
difference by stretching the model or independently resizing its reference views.

### Extract and check the views

Use `tools/crop_views.py`, with the prop names explicitly supplied:

```
python tools/crop_views.py art/props/<id>/sheet.png --names front left right back --out art/props/<id>/views --dry-run --preview check.png
```

During upload, assign each crop to its matching named view; do not assume the sheet's
display order is the upload slot order.

The cutter aligns the bottoms and centres each view on one common square canvas.
**It does not normalize object heights or correct perspective.** Check the source
sheet's heights and projection before accepting it; a shared baseline alone does not
prove that the four views have the same scale.

For a sheet deliberately laid out in four equal-width cells, add `--count 4` to use
those cells. For a sheet with unequal spacing and genuine narrow end views, use
automatic gap detection with a lower `--min-width-ratio`, for example `0.08` for
rolled charts. The default is `0.25`: it rejects spans at or below a quarter of the
longest view's width as stray marks. A chart end 0.08 m wide beside a 0.6 m long
elevation is only about 13.3% as wide and would be discarded by that default. This
option only changes which spans are retained; it does not resize them or correct
their scale. Confirm four complete views, their measured scale and clear separation
in the source and preview before writing the views. Keep one common square output
size, with the same minimum 1024 × 1024 after the 2× upscale as the character inputs.

---

## 2. Rooms

### What the art side delivers

```
art/rooms/captain_live_quarters/
├── background.png         1920 x 1080, the painted room
├── foreground_01.png      1920 x 1080, alpha, things he walks BEHIND
├── blockout.png           the 3D blockout this was painted over
└── palette.json
```

### Rules

- **Paint over a 3D blockout.** Block the room out roughly in 3D, render it, paint over
  that. Perspective and the walkable floor then agree by construction instead of by eye,
  and the blockout doubles as the depth reference for placing characters.
- **Foreground strips are separate files with alpha**, full canvas size, same origin as
  the background. A crate he passes behind is a foreground strip; a crate he walks
  around is part of the background plus a hole in the floor polygon.
- **Leave the floor readable.** Something must tell the player where they can walk —
  a rug edge, floorboards, a change of tone. The floor polygon is invisible, so the
  picture has to imply it.
- **One key light per room, stated in `palette.json`** as a direction and a colour. The
  character shader reads it so figures are lit by the room they are standing in. This is
  the single thing that stops 3D characters looking pasted onto a painting.
- **Headroom at the top.** Stage directions and dialogue sit over the picture; keep the
  top ~120 px and bottom ~260 px free of anything that must be read.

---

## 2A. Reusable surface textures and construction parts

The owner also requested materials and individual textured parts for building rooms
whose final dimensions are unknown. These are reusable sources, separate from a
camera-matched painted backdrop. The cabin kit index is
`art/kits/captains_cabin/asset.json`.

Surface colour textures live at
`art/materials/captains_cabin/<material_id>/albedo.png`, with an `asset.json` recording
the actual generated size, full prompt, inspected references, colour space, repeat
directions, suggested tile span in metres and seam-review limits. Supply flat,
neutral colour without room lighting. Normal, roughness and height maps are separate
data; do not call painted grain a measured normal or displacement map.

Map UVs by material density, not by stretching one image across a room. For surface
dimensions `S_u` and `S_v` metres and tile spans `T_u` and `T_v`, the UV extent is
`(S_u / T_u, S_v / T_v)`. Enable repeat and mipmaps, and align wood grain with the
piece's long axis. The initial spans are provisional: floorboards 2.4m square
(eight rows, about0.30m board width), wall planks 2m square (about0.25m row height),
beam grain 1m square, carpet field 0.8m square. These do not define the room size.
The carpet field has no finite rug border or fringe; edging is a separate strip.

Inspect a repeated preview and record edge measurements. The delivered generated
textures have approximate matching edges, not pixel-identical opposite edge rows.
Live camera, mipmap and scene-light checks must precede any claim of seamless
in-engine results. The original1254px images are retained without image correction.

Individual construction parts follow section1A: one textured object per four-view
sheet, front/left/right/back, with common height and baseline. `timber_beam` and
`wood_board` include extracted views and sidecars. Their finished provisional sizes
adopt the revised hand-hewn proportions: beam2.10x0.38x0.375m;
floor board0.305x0.107x1.65m. The owner requested visibly stylized geometry,
so bowed outlines, taper, broad carved bevels and worn corner cuts replace the
initial straight boxes. Board height alignment passes; beam's2px (~1.27%) source
height spread exceeds the1px requirement and remains an explicit modeling limit.
The board stands on end in its source for useful elevations; rotateX-90 degrees to
make its broad front face face upward, after exporter axes agree. Both sources have
central end contact patches and no attached hardware. Curved side edges can leave
gaps; make suitable contact lands and check floor flatness on the model. Cap/joint fitting
and snap markers are not verified until the mesh exists. Keep grain density fixed
when adapting a module's length: cut/extrude and adjust UVs instead of stretching
the painted texture with the mesh. These sources do not replace the live cabin or
define its final layout.

---

## 3. Naming

Lower snake case, everywhere, no spaces. The folder names the thing; the file names the
role. `captain_live/views/front.png`, not `Captain Livé Front View (2).png`.

Character ids in `screenplay/*.json` must match the folder name exactly — that is how a
line of dialogue finds a face.

---

## 4. Licensing

This ships commercially, so every asset must come from a tool that allows it.

- **Tripo** — paid tiers grant commercial rights. Confirm the plan covers it.
- **Never** in a delivered asset: Flux dev, Flux Klein 9B, MMAudio, Qwen Image 2.1,
  4x-UltraSharp, Anima, the Product Image LoRA, or anything InstantID / InsightFace.
- **Never** for this project: Hunyuan3D, HY-Motion, FramePack. Territory-restricted,
  and the game sells into the EU and UK.
- Clear to use: Qwen Image 2512, Qwen Image Edit 2511, Wan, Z-Image Turbo, FLUX.2 klein
  4B, BiRefNet, ACE-Step 1.5.
- **Tag every delivered asset with the model that made it**, in `palette.json` or a
  sidecar. When someone asks in two years, there is an answer.

---

## 5. What the engine does with all this

So the art side knows what the rules are for.

| Engine behaviour | What it needs from the art |
|---|---|
| Character shrinks upstage | Origin at the feet; real-world scale |
| Character passes behind a crate | Crate supplied as a foreground strip with alpha |
| Character lit by the room | Neutral character texture + room key light |
| Click a thing, he walks to it | Hotspot readable in the painting |
| Dialogue over the picture | Headroom top and bottom |

The engine is finished and tested against placeholder blocks. Anything delivered to this
spec drops into a slot that already works.
