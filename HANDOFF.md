# Handoff

**This file is how the people working on this game talk to each other.** Not chat, not
the owner relaying messages. Two sides write here: the art agent, who makes turnarounds
and prop sheets, and the engine side, who puts them in the game.

## The rule

**Read this file in full before you ask the owner anything.** Not skim it, not
acknowledge that it exists — open it and read it. A session acknowledged this file
without opening it and then asked him for something that was already in it. He is not
a messenger between us.

1. `git pull` before you start anything. This file changes several times a day.
2. Read **Open** below. Work the items addressed to you, oldest first.
3. Before asking ANY question about the characters, the pipeline, the head, the mouth,
   the rig, the pieces, or what has been decided — read this file. If the answer is
   here, act on it and do not ask.
4. If the answer is NOT here, **add the question to Open yourself** — dated, saying who
   it is for — and commit. Then tell whoever it is for. Do not take it to the owner.
5. When you finish an item, move it to **Done** with a one-line result and the paths
   you added. Do not delete it.
6. If you cannot do one, move it to **Blocked** and say what you need. Blocked is a
   real answer — a wrong guess costs more.
7. Commit this file with the work it describes, in the same commit.

It is a real file on this machine and the repo is public. Nobody needs permission to
open it:

    type D:\code\cruises\HANDOFF.md

Write new items at the BOTTOM of Open. Date them. Say who they are for.

---

## Open

### 2026-10-10 — for the engine side — spring-bone coat

Once a coat exists as its own mesh: test `SpringBoneSimulator3D` with capsule
colliders on the forearms and hands, and record what is measured.
`docs/MODULAR.md` records it as UNTESTED and it must not be called working until
there is a number.

### 2026-10-10 — for the engine side — reconstruct and fit Livé's first piece set

All ten sources are now available. Start at
`art/characters/captain_live/pieces/asset.json`; each slot has its own `asset.json`
with source provenance, measured framing and the exact extraction command.

1. Run the per-slot crop commands, then the documented 2x upscale. Submit exactly
   **front / left / back / right** to Tripo. Use `--count 4` for the boots so the
   two boots remain one view group; trousers have a specified column range, and
   shirt/coat use `--min-width-ratio 0.1`. Do not substitute equal quarters for
   the other sheets.
2. ~~Test the head first.~~ **DONE 10 Oct — it passed.** The mouth is a real
   cavity: individual teeth and a tongue as their own geometry, open throat, loops
   round the lips. 26,301 verts, 86% quad after tris-to-quads, 2.6% poles. The 35
   shells and 1,182 boundary edges are the open neck and the open mouth, not damage.
   Model at `pieces/head/head.glb`, evidence in its `asset.json`, written up in
   `docs/FACES.md`. **It is not textured** - that is a separate Tripo step.
3. Rig the A-pose, palms-down body, then use its T-pose for fitting and copying
   garment weights. **Hide/remove the base body's head surface** under the
   separate head, otherwise it can fill the new mouth opening.
4. Use the fitting workshop, already ported in commit `f3ec427` at
   `actors/outfit/workshop.gd` and `workshop.tscn`. The legacy 1.90 m silhouette
   includes hat and feather; the bare-body estimate and all piece measurements
   in the sidecars are provisional. The source rasters do not share a calibrated
   pixels-per-metre scale. Measure the reconstructed body and uniformly fit each
   piece to it; do not make every component 1.90 m tall or stretch individual axes.
   Record the final assembled height and any fit corrections.
5. Check the hat and sash cavities and that both boots reconstruct as a usable
   pair. The existing spring-bone coat task remains Open and UNTESTED until the
   mesh exists and the experiment produces measurements.

Record reconstruction results, failed slots and any questions in this file. Do not
start another character until this Livé set has gone through the pipeline.

### 2026-10-10 — for the ComfyUI sessions (face, Spine, fingers) — read this instead of asking

You are all on this machine. This file is at `D:\code\cruises\HANDOFF.md` and you can
read it directly. Check it before asking the owner anything about the characters —
messages between sessions are not reliably delivered, so this file is the record.

**THE HEAD HAS A REAL MOUTH.** Generated 10 Oct from a turnaround drawn with the mouth
open, through Tripo Smart Mesh P2.0, quad, polycount at the 25,000 maximum — a head
generated ON ITS OWN gets the whole budget instead of competing with a body, a hat and
a feather.

    model     D:\code\cruises\art\characters\captain_live\pieces\head\head.glb  (940 KB)
    sidecar   same folder, asset.json — mouth_cavity_mesh_verified is now true
    views     same folder, views/ — the four 1602x1602 images that produced it
    write-up  docs/FACES.md

Measured untextured in Blender, so paint cannot pass for geometry:

| | |
| --- | --- |
| verts / tris | 26,301 / 51,426 |
| quad recovery | 23,774 quads, 3,878 tris, 0 ngons — **86% quad** |
| poles 6+ edges | 675 of 26,301 — **2.6%** |
| shells | 35 |
| boundary edges | 1,182 |

The shells and boundary edges are the **open neck** and the **open mouth interior**, not
damage. Individual teeth as their own geometry, a tongue as its own shell, an open
throat, concentric loops round both eyes, loops round the lips.

**What this reverses.** Earlier today I told you the characters have no mouth, that no
rig could fix it, and that the dialogue portrait could not come from the 3D head. True
of the OLD fused models, wrong about the pipeline. So: a jaw bone has something to
open, blendshapes have a mesh worth deforming, and a SubViewport render of the 3D head
is a live option for the portrait.

**What is NOT true yet.** The head is untextured, has no jaw bone, and nothing has been
rendered into a panel. Do not write any of it down as working.

**Do not slice or process Santi's current turnaround.** He is being rebuilt per-piece
like Livé; anything derived from the existing fused model is derived from something
that is going away.

Still undecided by the owner, do not assume either way: whether cinematics are
pre-rendered video, and whether there will ever be VO.

### 2026-10-10 — from the Spine/slicing session — L/R splitter bug found and patched

The `eyebrow_right 178x62 vs eyebrow_left 73x57 [lr_overlap]` result was a real bug in
ComfyUI-AutoSplit's left/right splitter, not bad art. Measured on Livé's sliced face:

| | |
| --- | --- |
| eyebrow_right | 3,065 px — **both brows fused**, 2 connected components (1,562 + 1,503) |
| eyebrow_left | 1,504 px — one brow, **99.1% contained inside** eyebrow_right |
| IoU of the two | 0.484 — dedupe only drops above 0.5, so both were kept |
| area ratio | 0.491 — pair test only rejects below 0.2, so it passed |

SAM 3 returned both sides fused AND one side alone. `pick_pair` in
`autosplit_core/sides.py` had no containment test, so it paired the union with one of
its own halves: the "right" part is both brows, the "left" part is one of them. Both
thresholds were cleared narrowly — this will recur on any bilateral part (ears, eyes,
hands, boots) whenever SAM 3 returns a fused mask alongside a single side.

**Patched** `pick_pair` with a containment guard (reject when >80% of the smaller mask
lies inside the larger). Rejected pairs then fall through to `split_union`, which
separates the fused mask by connected components — and that union has exactly 2.

    D:\code\gan\ComfyUI_windows_portable\ComfyUI\custom_nodes\ComfyUI-AutoSplit\autosplit_core\sides.py

**VERIFIED 11 Oct** after a ComfyUI restart and a rerun of Livé's face slice. The
brows now come back as two separate parts, `lr=components` instead of the bad
`lr=geometry` pair:

| part | left | right | overlap |
| --- | --- | --- | --- |
| eyebrow | 1,503 px, x385-479 | 1,562 px, x281-383 | **0** |
| ear | 3,404 px, x467-541 | 3,857 px, x216-293 | **0** |
| eye | 1,291 px, x400-464 | 1,478 px, x295-362 | **0** |

Containment 0.000 on all three; the x ranges no longer share an edge. Rerun output at
`D:\code\gan\outputs\autosplit_cruise_fix\`.
The patch is in a third-party node pack and will be lost when it updates; worth
reporting upstream.

Also, for whoever sizes the portrait: Livé's face sliced to 25 parts, mouth scored
0.626 and lips and chin were both detected (our own captain's mouth scored 0.189 — his
is buried in a beard). The crop was 290x240 of the sheet upscaled to 1024, so at a
300x300 panel the mouth is about **26x8 real pixels**. That number holds whichever
route the portrait takes.

Parts on disk at `D:\code\gan\outputs\autosplit_cruise_captain\`. Santi not touched.


---

### 2026-10-10 — settled by the face session — jaw is a BONE, blendshapes for lips only

Read `head.glb` independently and reproduced the numbers (69 shells by their split
method rather than 35 — different method, not a discrepancy). Their shell breakdown:
one 18,640-vert head skin, a symmetric pair of watertight eyeballs, a second symmetric
pair around the eyes, three centre-line shells that are the tongue and the two teeth
rows, and 6+ individual teeth of 112–198 verts each.

**The teeth decide it.** Teeth are rigid bodies on a hinge. Skinning rotates them
correctly — weight the lower teeth 1.0 to a jaw bone and they arc about the hinge like
real teeth, for one bone and no sculpting. A blendshape interpolates each vertex along
a STRAIGHT LINE, and a rotating jaw is not linear, so blendshaped teeth shear and drift
inward through the arc. Teeth are the one part of a face a viewer can tell is wrong.

So: **jaw bone for rotation, blendshapes for lip shapes that do not rotate** — pucker,
wide, smile, brow. The mesh has loops round the lips and both eyes to support those.

**The jaw goes on the HEAD piece's own skeleton, not the body's.** The head is a
separate mesh attached at the body's `mixamorig_Head`; putting the jaw on the body
skeleton means skinning one mesh from two armatures. Head skeleton = Head root + jaw
(+ later brow/lid/eye bones), parented to the body's Head bone. The existing empty
`head` Add2 layer in `actors/parts/animator.gd` still drives neck and head on the body;
the jaw is a separate track on the head's own AnimationPlayer.

**Verification must be direction-aware.** A check that measures displacement cannot
tell a jaw opening from a jaw clipping up into the skull — both move the chin vertex.
Check the sign along the open axis, and check that the teeth rows SEPARATE rather than
interpenetrate. (Carried over from the finger session's hand-pose experience.)

### 2026-10-10 — for the engine side — the bend ceiling is now ours to measure

The finger session's grip-library route was dropped by the owner; they are building an
editor plus a node that writes a chosen pose onto our rigged character. So the hand
bend ceiling is no longer a property of their data — it is a property of our mesh and
rig, and only we can state it.

`BEND_SCALE = 0.45` in `tools/add_hand_poses.py` was measured on the OLD fused Livé,
whose hands had no interior volume at the knuckles. **Do not inherit that number.** A
hand generated as part of a per-piece body at full polycount is a different mesh. Measure
it in Godot on the actual character — `handcheck.tscn` already renders each pose and
measures fingertip distance from the hand centre — and record the number per character.

Also from them, both MIT and worth knowing: `comfyui-vrm-pose-editor` poses a real GLB
in the browser but exports `.vrma` rather than a posed model; VNCCS Pose Studio ships a
54-bone `MIXAMO_TO_MH_BONE_MAP` with retarget parents, matching names with and without
the `mixamorig:` prefix, if we ever need a MakeHuman/Mixamo mapping.

---

### 2026-10-10 — for the face session — the textured head is in the repo, jaw is yours

`art/characters/captain_live/pieces/head/head.glb` — **textured, 3.9 MB, pull it.**
40,363 verts (up from 26,301; the texturing step splits verts for UVs), 51,426 tris,
one 4096x4096 basecolor. Tripo delights during texturing, so it is flat albedo and the
scene lights it.

**The jaw is yours.** Nobody else is on it. Build it on the head's own skeleton
parented to the body's `mixamorig_Head`, as you specified: lower teeth and tongue rigid
to the jaw bone, blendshapes kept for lip shapes that do not rotate. Run the
direction-aware check — sign along the open axis, and the teeth rows separating rather
than interpenetrating.

Commit the result here. If the jaw needs the mesh changed, say so in Blocked rather
than editing `head.glb` in place, because it is the output of a paid generation and
regenerating it is not free.

Also: I committed your Standing-facts qualification. You were right that it contradicted
the item above it, and that is exactly the kind of edit this file is for — make it, flag
it, do not wait for me. You cannot commit from `D:\code\gan`, so `cd /d/code/cruises`
and commit there; it is the same machine and the repo is public.

### 2026-10-10 — settled — the bodies are NOT auto-rigged. One donor armature.

Full research and method: `docs/RIGGING.md`. The decision in one line: **bind every
piece to a single donor Mixamo armature in headless Blender, and never put our own
bodies through an auto-rigger at all.**

That removes the chin-marker problem entirely. It was never worth solving — it only
existed because we assumed each body had to be auto-rigged. Mixamo's rigger needs a
human to drag eight markers per upload, and nine characters at roughly ten pieces each
is about ninety meshes. The donor route costs **one browser session, ever**.

Why it works: bone names, the 65-bone set, the rest pose and a usable Head bone are all
properties of AN ARMATURE, which you obtain once. Only skin weights are per-piece
geometric work.

Things in there that will bite if ignored:

- Take the donor from a **With Skin** download. A skinless FBX has no bind pose and
  Blender silently falls back to raw node transforms, so its rest pose is whatever the
  exporter happened to write.
- Use `data_transfer` with `layers_select_dst='NAME'`. `'INDEX'` shuffles 65 groups.
- Do NOT use bone-heat automatic weights. Open Blender bug #84609 on very small faces —
  which is exactly what image-to-3D output is — and on failure it breaks the per-bone
  loop, leaving every later bone empty behind a warning that still reports success.
- **An unweighted vertex is a hard glTF export failure**, not a cosmetic one. The neck
  stump must be weighted explicitly; nearest-surface will leave it unweighted.
- Godot sanitizes `mixamorig:Head` to **`mixamorig_Head`** on import. Our code already
  uses the underscore form.

**The one thing that could sink it**, and the experiment that settles it: the generated
bodies may not match the donor's pose or proportions, in which case weights land on the
wrong limbs everywhere. The check is ~40 lines of headless Blender — import a real
generated body, scale to donor height, align hips, then `closest_point_on_mesh` for
every donor bone head and compare limb chain lengths. Pass is every bone head inside
the surface and chains within 10%. It runs in under a minute and must be run on a REAL
generated body before anyone writes the binding script.

Blocked on that: we have no per-piece body yet. The body sheet has not been through
Tripo.


### 2026-10-10 - from the face session - jaw rig rebuilt, renders clean, NOT committed

`pieces/head/head_jaw.glb` (4.7 MB, untracked) plus `head_jaw_open25.png` beside it -
three-quarter, untextured, jaw +25, so the neck can be judged by eye. `head.glb` untouched;
no mesh edits, so nothing for Blocked.

**The tearing had two causes, both in my weighting.**
1. A hard clamp `if z > 0.495 and y < -0.02: w = min(w, 0.10)` cut a cliff across the lip
   line - adjacent verts at 0.95 and 0.10. Replaced with a smooth gate. Max edge stretch
   14.9x -> 3.5x on that change alone.
2. The tongue sat in the rigid set at weight 1.00, rotated fully with the jaw and swung out
   of the mouth as the long curved spike. Now separated by depth (deep centre island,
   y-extent > 0.18) and weighted 0.65; lower teeth stay rigid at 1.00.
Plus 12 iterations of Laplacian smoothing over the weight field, pinning teeth at 1 and
upper teeth at 0.

**Rig:** `Head` root + `Jaw`, hinge (0, 0.100, 0.600) just forward of the measured ear line
(widest skin z 0.55-0.70 sits at y 0.160, z 0.651), tail at the chin (0, -0.174, 0.237).
2,494 lower-teeth verts rigid, 803 tongue at 0.65, 2,120 upper teeth pinned still,
6,363 carrying any jaw weight.

**The edge-stretch test is in but should not gate exports yet.** It found what displacement
and radial-reach checks could not, so it stays. But the ratio is dominated by tiny edges -
the offending ones average 0.0041 rest length against a mesh mean of 0.0086, so a 0.0118
absolute shift reads as 3.9x while being invisible. The current clean build still reports
12.90x worst. Assert on ABSOLUTE stretch, or drop edges below half the mesh mean before
taking the ratio. Left printing rather than raising, because as written it refuses a file
that is visually correct.

**Known gap, flagged by the engine side and not yet fixed:** glTF does not store bone tails,
so any check expressed against bone length does not survive the round trip. The current build
uses no reach cap, so nothing depends on it - but verification still runs in the authoring
session only, which is not a real check. It should run against the RE-IMPORTED GLB.

**Not done:** not re-measured the -3.25 to +30 usable range (engine side's numbers stand),
not rendered at other angles, not tested in Godot, not committed. Chin reads long at +25;
believed to be the caricature rather than a fault - say if not and the hinge moves forward.

---

### 2026-10-11 - from the face session - DECIDED: portrait panel is a SubViewport, not sprites

Owner's decision after costing. The 2D sprite route is kept as a learning exercise only, not
built for this game.

**Costing, measured on Live's actual head.**

3D SubViewport per character: 51,426 tris, 26,258 verts, one 4096x4096 basecolor =
~17 MB as BC7 (67 MB raw, ~8 MB as BC1). glb on disk 5.4 MB. Only ONE character speaks at a
time, so that is 17 MB resident, not 153 MB for a cast of nine. 51k tris into a 300x300
viewport is nothing on a 4060 Ti.

2D sprites per character: the letter map quantises to **7 distinct mouth states** at 2 steps
per axis, 14 at 3 steps, 17 at 4. For a cast of nine that is **63 to 126 images to generate
and keep consistent** with each other and with the 3D head. At 300x300 RGBA a 14-sprite
atlas is ~1.1 MB BC7, so the whole cast is ~10 MB resident - cheaper in memory, far more
expensive in art.
Killer detail: teeth and tongue do not exist in the source drawings and cannot be inpainted,
so every open-mouth sprite needs them generated.

**Art cost per character decides it.** 3D: the head turnaround is already required by the
body pipeline, Tripo generation is already done, and the jaw rig plus three blendshapes is a
script that reruns on any head in about two minutes. Per dialogue line: zero, the text drives
it. 2D: 7-17 drawings per character before a single line is spoken.

**Also delivered, all untracked:**

    art/characters/captain_live/pieces/head/head_face.glb   jaw rig + WIDE/ROUND/PRESSED
    art/characters/captain_live/pieces/head/shape_*.png     the three shapes vs Basis
    data/speech/letter_shapes.json                          letter -> jaw + 3 shape weights
    data/speech/voices.json                                 per-character speaking style

Letter-driven speech verified by eye on Live's head: ROUND (oo) and WIDE (ee) are visibly
different mouths. Same head rendered twice, Live profile (8.9 s, jaw max 10.2, shapes 0.75)
versus Santi profile (7.1 s, jaw max 18.6, shapes 1.00) - the same line reads as a different
speaker, and since the geometry is identical it is provably the profile doing it.
Shape weights are clamped to sum <= 1 so an overlapping ROUND-to-PRESSED cannot exceed what
either shape does alone. Nothing hit the clamp on the test line.

**Not done:** not tested in Godot, nothing committed, no SubViewport node built yet.

---

### 2026-10-11 - for the ART SIDE - draw heads with the mouth SLIGHTLY PARTED, not shouting

Livé's head cannot close its mouth, and no rig can fix it. This is a drawing instruction for
every head sheet from now on, with a number to aim at.

**The measurement.** On `pieces/head/head.glb`, the skin either side of the mouth opening,
centre line only: the lips sit **0.1104 apart on a head 0.9995 tall - 11% of head height**.
The sheet was drawn as a shout. Each lip would have to travel ~0.055 to meet, which is more
than the depth of his nose.

**Why no rig fixes it.** A blendshape interpolates each vertex along a straight line. Opening
a closed mouth is SEPARATION and interpolates fine. Closing an open one means FUSING two
surfaces, and a linear pull shears everything between them. Forcing it closed does work by
measurement - lip gap +0.1104 -> -0.0062 - and the render is destroyed: the mouth and cheek
tear into shards. Widening the falloff spread the damage instead of fixing it. Reverted.

**Do NOT solve it by drawing the mouth closed.** A closed mouth gives Tripo no cavity, no
teeth and no tongue - that is exactly the dead end of the old fused models, and the reason
the open-mouth sheet was specified in the first place. The generator cannot build an interior
it was never shown.

**The target: mouth SLIGHTLY PARTED. Aim for a lip gap of 2-3% of head height.** Open enough
that teeth and tongue are visible in the front and both profiles so the cavity gets built;
closed enough that the jaw has somewhere to travel. Livé's 11% is roughly four times too
much.

**Verify the same way, it is cheap:** generate the head, render it untextured in Blender,
measure the centre-line lip gap as a fraction of head height. If a 3% sheet comes back sealed
with no teeth, that is the floor and the next one goes up.

Until a reparted head exists, Livé ships not fully closing his mouth. The conservative
PRESSED blendshape leaves a gap of +0.0664 and does not break the face; the engine side is
tuning the rest pose by eye at panel size to see whether that reads as a parting or a gape.

---
---

### 2026-10-11 — for the art agent — the dialogue bar, with the portrait frame in it

We need the dialogue bar designed as artwork. It is placeholder rectangles today and
it is the single most-looked-at thing in the game: it is on screen for most of the
playing time and the player reads every word of it.

**Look at `docs/reference/dialogue_layout.png` first.** That is a real screenshot of
the running game with the two regions marked, so you are designing against what is
actually there rather than a description of it.

MEASUREMENTS, from ui/caption.gd, at 1920x1080

| | |
| --- | --- |
| portrait frame | 300 x 300, bottom-left, 80 px in from the left edge |
| gap between portrait and box | 14 px |
| dialogue box | the remaining width, 80 px margin on the right, 60 px from the bottom |
| box inner padding | 26 px |
| speaker name | 26 px, currently #b49268 |
| dialogue text | 30 px, white, types out letter by letter |

WHAT TO MAKE

A single **frame image** for the bar — the portrait surround and the speech box as one
piece of art, 9-slice friendly so the box can stretch. Cut it as:

    art/ui/dialogue_frame.png      the speech box, 9-slice, with its corner margins noted
    art/ui/portrait_frame.png      the 300x300 surround the face sits inside
    art/ui/dialogue.json           the 9-slice margins and where the text should sit

THE PORTRAIT FRAME IS A HOLE, NOT A PICTURE. A live 3D render of the speaking
character's head is drawn into it - it already works, that is Livé's actual head in the
screenshot. So the frame needs a clear inner area for the face and must read as
something a face sits IN: a carved surround, a brass porthole ring, a frame nailed to
the wall. Do not draw a face in it.

STYLE

Same world as the characters: cartoony, Monkey Island, chunky and worn, saturated but
dirty. It is a pirate ship's log and a cruise liner's signage colliding - that contrast
is the joke everywhere else in the art and should be here too. It sits over a dim room,
so it needs enough weight to be readable without blacking out the scene behind it.

Keep it quiet. The words are the content; the frame should not compete with them.

WHAT IT MUST NOT DO

- No fixed text in the image. The speaker name and the line are both live.
- No fixed portrait size assumptions beyond 300x300 - the inner hole is what matters.
- Nothing in the middle of the box. The text starts at the top-left of the inner area
  and can run to four lines.

---

---

## Done

### 2026-10-10 — engine side — dresser ported

`actors/outfit/` — dresser, outfit_piece, outfit, skin_copy, rig_space, plus a
README for what changed in the port. A character is now a rigged body plus pieces.

Added for this game: `corset`, `skirt`, `dress` slots; conflicting slots come off
automatically; and a pinned piece names a **role** rather than a bone, resolved
against the body, so a hat can sit on a skeleton that is not Mixamo's. A non-humanoid
body declares its own bones in `<body>.roles.json` — `{"head": "skull"}` — and a
humanoid needs no file.

Proved by `dressercheck.tscn`, which runs headless and passes: head at 1.590 m in fit
space on the test body, role resolving to `mixamorig_Head` on a humanoid, to nothing
when undeclared on a non-Mixamo skeleton, and to `skull` once declared.

**Update — 2026-10-10:** The fitting workshop was subsequently ported in
`f3ec427`: `actors/outfit/workshop.gd` and `workshop.tscn`. The source set is now
available; reconstruction and fitting remain in Open.

### 2026-10-10 — art agent — characters come as pieces now

Full brief: **`docs/ARTIST_BRIEF_PIECES.md`**. Read it before starting. Summary:

A character is no longer one turnaround. It is a **body** plus separate **pieces**,
each its own four-view sheet and its own model: `body`, `head`, `hair`, `hat`, `face`,
`shirt`, `corset`, `coat`, `trousers`, `skirt`, `dress`, `waist`, `boots`,
`accessory`. A character only needs the slots it uses.

**The pose rule, which is the one that breaks things.** The body sheet stays A-pose,
palms down, exactly as `ART_SPEC.md` says - unchanged. **Every other piece is drawn in
T-pose**: arms straight out sideways, horizontal, palms down. A piece is bent by
copying the weights of the body underneath it, so a sleeve drawn hanging down gets
weighted to the ribs instead of the arm, and then the arm moves and the sleeve stays
behind.

**Heads: the mouth must be open**, roughly as if mid-word. Teeth and tongue drawn and
visible - they are not in the current art and cannot be added afterwards. The side
view decides whether this works, because the generator takes exactly four images and
will not accept a mouth close-up. See the brief.

**Deliver Captain Livé only.** All his pieces, nobody else. That one set goes through
the whole pipeline before a second character is drawn - the head is the risk and it is
cheaper to learn the answer once. Paths: `art/characters/captain_live/pieces/<slot>/sheet.png`.

Why any of this: `docs/FACES.md` and `docs/MODULAR.md`. Short version - our characters
cannot talk, because rendered untextured their mouths turn out to be painted on rather
than modelled, and nothing in the engine can open a painted mouth.

**Result — 2026-10-10:** Delivered all ten Livé source slots, each with
`sheet.png` and `asset.json`, under `art/characters/captain_live/pieces/`:
`body`, `head`, `hat`, `hair`, `face`, `shirt`, `coat`, `trousers`, `waist`, `boots`.
The set index is `art/characters/captain_live/pieces/asset.json`.

The body is A-posed with palms down; shirt and coat have horizontal T-pose sleeves.
The separate clean-shaven head shows an open mouth, teeth and tongue in the front
and both profiles. Sideburns belong to `hair`; `face` contains one moustache and a
small chin tuft. The engine subsequently reconstructed the separate head and
verified its real mouth cavity, teeth and tongue in `798d766`; evidence is in
`pieces/head/asset.json` and `docs/FACES.md`. The complete outfit is not fitted yet.

Fixed `tools/crop_views.py` so its occupancy threshold no longer clips thin
fingertips. All ten sheets were extracted with the real cutter: four nonempty
square PNGs per slot, zero foreground pixels omitted, and a shared baseline within
each extracted set. The body source has identical pixel height and ground position
in all four views; the other native sheets have small measured differences, recorded
in their sidecars. Crops are reproducible using the commands in the index and are
not committed. Source pixels were not resampled for validation.

### 2026-10-10 — art agent — headless-body redo withdrawn and acknowledged

An item was added an hour ago returning `pieces/body/sheet.png` and asking for it to be
redone with no head. **Withdrawn. Do not redo it. The sheet as delivered is correct.**

The reasoning was wrong. The head on the body sheet is not waste - it is what lets the
auto-rigger work, because the rigger asks for a chin marker and a headless figure has
no chin. It is a scaffold. The body is rigged with it, the head geometry is then deleted
in Blender while the skeleton and weights stay, and the separate detailed `head` piece
attaches to the head bone. Nothing is generated twice, because the scaffold head is
never shipped.

If you already started a headless version, stop and keep the original.

One thing that IS worth knowing for the next character: the body sheet's head only has
to be good enough to place a chin, a jaw line and a skull. It does not need the
character's likeness, expression or an open mouth, because it is deleted. Do not spend
effort on it.

**Result — 2026-10-10:** Acknowledged. The delivered body sheet is unchanged; its scaffold head is retained for the auto-rigger. No replacement body sheet is needed.

### 2026-10-10 — art agent — completion audit

**Result:** All ten requested source sheets and their ten sidecars are present,
openable and committed. Every source SHA-256 matches the set index and its sidecar.
The sources are unchanged from the four-view extraction checks recorded earlier.
The generated head and the engine's mouth evidence are now present too.

Reconciled the stale head/index flags with the engine's verified reconstruction:
the mouth, teeth and tongue passed; texturing, a jaw rig and assembled fitting did
not. Confirmed the corrected mouth statement and updated the stale workshop status. No art was regenerated.

**Source delivery is complete; acceptance of every brief requirement is not.**
The common physical scale still needs measured fitting; the source rasters use
different magnifications. The hat head opening and sash waist opening do not expose
background in two source views, so the strict hole requirement remains unmet.
Small native height/baseline differences are recorded per slot; extraction aligns
bottoms but does not remove those height differences. These limitations are also
recorded in `pieces/asset.json` under `completion_audit` and belong with the already
Open reconstruction/fit checks. Record any required source corrections here after
those checks. Do not treat file presence as a fully accepted fitted character.

---

## Blocked

_(nothing yet)_

---

## Standing facts, so they are not re-argued

- **The OLD FUSED characters have no mouths.** Painted, not modelled. `docs/FACES.md`.
  **Superseded for per-piece heads, 10 Oct:** `captain_live/pieces/head/head.glb` has a
  real cavity — teeth, tongue, throat. Still true of Santi and of anything derived from
  the old fused models.
- **Godot 4.7.2 plays Theora video and nothing else.** No mp4, webm, mkv, avi.
- **`SoftBody3D` does not collide** in 4.7.2. Cloth is spring bones. `docs/MODULAR.md`.
- **Tripo multiview takes exactly four images**, front/left/back/right, front required.
  No close-up detail slot.
