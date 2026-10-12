# Handoff

Current Character Workshop scope: construct and save reusable visual assemblies.
No adapters, gameplay export or legacy import in the plugin. Game identity and
speech use game-owned definitions/wrappers. Rigs, weight copying and facial shapes
remain core construction features. Old adapter records below are superseded; see
`addons/character_workshop/HANDOFF.md` and `docs/CHARACTER_WORKSHOP_PLAN.md`.


**This file is how the people working on this game talk to each other.** Not chat, not
the owner relaying messages. Two sides write here: the art agent, who makes turnarounds
and prop sheets, and the engine side, who puts them in the game.

## Current architecture — 2026-10-11

2026-10-12 Workshop activation correction: Close Workshop and standard 3D/2D
return to normal scene editing. Character selection and remembered scene tabs no
longer reopen it; use the Workshop tab or its New/Open explicitly. Leaving cancels
temporary previews/tools and suspends its viewports without changing fitted content.
Native 239/239 assertions and focused integration/cold/reference checks pass with
unchanged authored hashes. See the Workshop and tests handoffs for evidence.

2026-10-12 owner-fitted portrait restoration: the game portrait again owns its
camera/lights/speech rig, around the preserved six-part fit. The fitted template
and UI assembly use separate binary meshes, keeping text scenes ~1–7 KB.
Open `ui/portraits/captain_live.tscn` for game edits and its Camera for framing;
open `actors/assembly/templates/captain_portrait.tscn` for the starter. Workshop
Save/Save As keeps mesh resources external and rejects bare-assembly overwrites
of portrait renderers. All 24 checks/cold routes, 227 native assertions and actual
GPU dialogue/speech captures pass. Exact fit comparison preserves all 23 assembly
nodes, transforms and geometry. See UI/editor/assembly/test handoffs and fit.json.

2026-10-12 Character Workshop reference images: the small pane now switches between
3D and an image; Images… opens a collapsible thumbnail board sharing the asset
drawer's space. Pointer-anchored zoom, pan, Fit and per-saved-character local editor
preferences are implemented without scene content. Focused backend/integration/cold
checks and 217 native graphical assertions pass; source hashes stay unchanged.
Transparent overlays, pinned cards and design-sheet crops remain future improvements
in `docs/CHARACTER_WORKSHOP_PLAN.md`. See workshop/test handoffs for evidence.
The owner's fitted template/live portrait are preserved; the approved renderer
and binary mesh storage restoration is complete as recorded above. Other local
import/art changes remain outside this portrait integration.

2026-10-12 owner clarification: the reported doubled appearance was traced by the
owner to the Tripo pirate hat, not the head. A handmade tricorn is now delivered
under `art/characters/captain_live/pieces/hat/handmade/`. The owner requested keeping
that hat and reusing the previous Tripo feather; the selected combination is
`hat_with_original_feather.glb`, with separate hat/feather exports and Blender source.
Inspect `ui/portraits/captain_live_handmade_hat.tscn`; it has separate fitted parts
and does not replace the live portrait. See the asset README for provenance and
reproduction. Feather extraction and preview used CPU only; no GPU/game run was
performed for this pass. The earlier normals repair is a separate shading correction,
not a resolution of the hat geometry issue.

2026-10-12 Character Workshop usability follow-up: all ten approved improvements
are implemented on `main`, including same-tab saving, hierarchy editing/visibility,
inline fitting controls, attachment feedback, persistent hierarchy with asset drawer,
filtered discovery, explicit drop placement, overlay/focus controls and advanced
task tabs. All 22 checks/cold routes and 213 native assertions pass headlessly.
Visual acceptance is deferred during GPU training. See the current sections in
`addons/character_workshop/HANDOFF.md`, `tests/HANDOFF.md` and
`docs/CHARACTER_WORKSHOP_PLAN.md` for evidence and remaining acceptance.
The latest remote hat work was pulled before delivery. Its first headless import
supplied missing UIDs for `feather_original.glb` and `hat_with_original_feather.glb`;
only those import metadata additions are included alongside the workshop changes.

2026-10-12 portrait mesh repair: the rigged head had lost its original surface
normals, creating jagged shading/false contours on the left temple and cheek.
The portrait now uses a UI-local derivative restoring those normals, with source
geometry, textures, skin and facial morphs intact. Identical speech/rest GPU
comparisons confirm smoother shading; owner visual acceptance remains pending.
Its renderers also retain scene-local worlds/private deformation resources.
See `ui/HANDOFF.md` and the portrait's `fit.json` for provenance and commands.

Owner UI corrections: response hit regions follow actual text height, choices
open without first-row focus, and the extra response chevron is removed. Ribbon
text fits and is centered. Only one dialogue portrait renders at a time; reported
doubling was not reproduced. See `ui/HANDOFF.md`. The cabin camera is lower/closer
to the art reference, though furniture proportions/layout still prevent an exact
match; see `locations/captains_cabin/HANDOFF.md`. Focused graphical previews were
reviewed; no full suite was run for this pass.

Scene migration is complete and merged into `main`, including clean-checkout
and graphical verification. Read `AGENTS.md` and
`docs/REFACTOR_PLAN.md`. Game owns startup wiring; named `locations/` own placement.
Fixed objects and UI/audio use authored prefabs. Packing flags and batch builders
have been retired. Normal startup/tests must not save scene/model resources.

Detailed implementation handoffs belong in module directories. This file indexes
integration status and preserves historical art decisions. Root integration owns
shared paths and location composition; parallel editing uses assigned file scopes.
Current owner policy keeps work on `main`, with notification before another branch
or worktree is created/used or the checkout is switched.

Module records: `actors/HANDOFF.md`, `props/HANDOFF.md`, `ui/HANDOFF.md` and
`tests/HANDOFF.md`. `docs/migration/README.md` indexes commits, checks and preserved
baseline evidence. Camera framing is completed; unrigged clothing still has the
authoring decisions listed there. The fake-lighting library is indexed in
`materials/stylized_lighting/README.md`; it owns its comparison lab and does not
replace current game materials. Texture exports and rig fitting have separate owners.
Captain's fitted frontal dialogue portrait and its editable assembly rotation are
recorded in `ui/HANDOFF.md` and `ui/portraits/captain_live/fit.json`; body work remains
deferred. Portrait checks and external GPU capture commands are in `tests/README.md`.

Character Workshop is integrated into `main` and enabled in
Godot's editor. Read `actors/assembly/README.md` for the workflow and
`docs/CHARACTER_WORKSHOP_PLAN.md` for priorities, evidence and remaining acceptance.
Freely named parts use native transforms/undo, scene-derived parent/bone targets,
preserved local rigs, reversible mesh exclusion and explicit reusable-scene saves.
Binding and animation borrowing are deliberate and cancellable/transactional.
No fixed slots, automatic conflicts, global asset registry or runtime builders.
Module details: `actors/assembly/HANDOFF.md`, `actors/outfit/HANDOFF.md`,
`addons/character_workshop/HANDOFF.md` and `tests/HANDOFF.md`.
New empty and New from template now open independent unsaved characters immediately,
preserving existing tabs. Open/Save As retain file browsing; creation never writes
a scene. Native editor validation passes 125/125 assertions; focused integration
and cold reopen checks pass. Evidence is indexed in the module handoffs.
The editable `head_swap_demo.tscn` proves fused-head removal and local speaking-rig
preservation; its neck seam/material fit needs art review. Production garment poses,
the replacement body and final owner usability acceptance remain open. Current
game actors and the accepted dialogue portrait are not replaced by tool templates.

Repository pull repair: the remote cabin normal-map delivery and local workshop
history were merged without switching the owner's checkout. Local texture-import
edits remain staged; whole-directory `art/` and `ui/` ignore entries were removed
so new assets stay visible. Branch creation/use and checkout switching must be
announced to the owner before acting; see `AGENTS.md`.
Validation: all 21 checks, 125 native editor assertions, cold reopen routes and
the engine-error rejection self-test pass with authored hashes unchanged.
Evidence: `%TEMP%/cruises-checks-ff8993880e4449c8aea84fca57604f3f/`.
The owner approved the revised two-view Character Workshop layout on 2026-10-12.
The implementation is complete on `main`, after pulling remote portrait repairs.
Open the Character Workshop main-screen tab beside 3D for two independent fitting
views, the actual nested hierarchy, searchable thumbnails, bottom transform/attach
actions and exact Fine adjust fields. More keeps advanced tools out of the workspace.
All 22 checks/cold routes and 174 native editor assertions pass; final GPU captures
show the workspace and real thumbnails with no engine errors. Source hashes remain
unchanged. Details and remaining art/owner acceptance are in
`docs/CHARACTER_WORKSHOP_PLAN.md` and the editor/test module handoffs.

Owner-authorized follow-up: the checkout is now `main`. Both stashes contain the
same three texture-import updates; these are versioned on `main` with their existing
UIDs and sources. Neither stash contains unique missing code or art. The blanket
art/UI ignores stay removed; stashes remain available as backups.
Eleven existing Tripo input view sets are now versioned with their crop provenance
and import settings (Captain pieces boots/coat/face/hair/hat/shirt/trousers/waist;
props captain_chair/fishbowl/pirate_chest). `views.json` records the delivered sizes
and crop bounds from tracked source sheets. Embedded texture copies and diagnostic
head previews remain local; no source images were regenerated or replaced.
Validation: all 44 manifest-selected Tripo views match their recorded square output
dimensions (at least 1024 px) and tracked source sheets. Godot import plus authored
scene/portrait checks pass with all newly versioned source hashes unchanged:
`%TEMP%/cruises-checks-e79f24c2eee14f95993a98fe9421d7b1/`.

## The rule

**Read this file in full before you ask the owner anything.** Not skim it, not
acknowledge that it exists — open it and read it. A session acknowledged this file
without opening it and then asked him for something that was already in it. He is not
a messenger between us.

1. Check branch/status and the assigned worktree before editing. Fetch/rebase only
   when coordinated with the integrator; do not pull over active local edits.
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
**Owner override, 11 Oct:** Santi modular source creation is explicitly authorized;
see his delivery and reconstruction task below. Livé's remaining checks still apply.

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

### 2026-10-11 — for the engine side — integrate Captain’s Ledger dialogue UI

**Selected and delivered — variation 3, rope-edged walnut:** use the new blank
`art/ui/dialogue_frame.png` and `art/ui/dialogue.json`. The frame has one continuous
parchment interior, rope/walnut perimeter and four outer brass corners. The portrait
renders over the shared paper with no internal divider, aperture or separate backing.
The approved preview is `art/ui/reference/no_divider_variations/03_rope_edge.png`,
also copied to `art/ui/reference/layout_concept.png`.

At 1920×1080, the whole bar remains `(80,720,1760,300)`. Draw three adjacent regions
of the same source into widths 100/1560/100px, preserving both outer caps. The live
portrait occupies `(144,756,224,224)`. The ribbon sits on the top rail at y720–760;
content scrolls within y764–952 and the footer occupies y956–984. Four complete
speech lines or four single-line response rows fit at the supplied font sizes.
Keep the portrait visible during responses. `integrated_frame.png` and
`portrait_frame.png` are preserved legacy sources and must not be rendered.

Read `art/ui/ENGINE_INTEGRATION.md` for the exact source rectangles, layers and
remaining input work. Implement bounded scrolling, visible keyboard focus and
explicit confirm/continue controls. The audited caption handler accepts any
key/mouse press, so **consume wheel/navigation/scrollbar events before they can
advance dialogue**. Choice buttons currently use `FOCUS_NONE`. Verify frame joins,
the live portrait, long text and input in Godot; engine integration remains open.
Mockup copy is layout content, not new screenplay or canon. No engine code or
animation was changed by this art delivery.

**Scene direction agreed with the owner:** retain the warm dark wood/brass/red
palette and overall cabin layout, remove modern visible fittings (AC, sockets,
electric ceiling lights), and make the room read as a pirate captain’s cabin.
This supersedes the visible cruise-utility-fixture direction in the older brief.
Count Fingers belongs near the camera at the left so his expression is readable
in exploration; the dialogue overlay may cover him. Keep him a scene character
in a separate bowl/foreground prop. The room concept and carpet are an outline,
not a final camera-aligned backdrop; simplify the carpet marks in final scenery.

### 2026-10-11 — for everyone — the owner's target render for this room

`docs/reference/room_target.png`, posted by the owner. This is what the cabin is
meant to look like, and the assets for it are being built now. Read it before you
pick a palette or a prop shape; it answers most of what the older brief left open.

What it settles for the engine side:
- Count Fingers' bowl is a FOREGROUND prop on its own pedestal at the left, big
  enough to read, not a small bowl on the desk. `main.gd` currently puts it on the
  desk at `(-3.3, 0.76, -1.2)`; that moves when the pedestal exists.
- The room is enclosed — beamed ceiling, panelled walls, a porthole with weather
  behind it, bookcase left, chest right. The grey boxes standing in for the chair
  and the crate come out when their turnarounds land.
- Lighting is warm and practical: lanterns, a picture light, the porthole. The
  current single key light is a placeholder.

The dialogue bar itself is DONE and in the engine — the owner supplied the frame art
directly (`art/ui/dialogue_frame.png`). It holds the portrait and the text in one
piece. Nothing further is needed from the art agent for the bar.

---


---

### 2026-10-11 — for the engine side — reconstruct and place the pirate chest

`art/props/pirate_chest/sheet.png` and `asset.json` are ready for the closed chest.
Extract the named front/left/right/back views using the sidecar command, reconstruct
with Tripo at the retained 0.9 × 0.9 × 0.9 m target. The engine queue now distinguishes
this ornamental `pirate_chest` from the nailed puzzle `supply_crate`: place the chest
as its own prop on the right of the cabin, without replacing the supply-crate hotspot.
The skull and crossed bones are flat paint, not a separate skull mesh. The sheet has no contents or open
state; verify mesh proportions, rear hinges and de-lit materials before import.
All view heights and baselines match exactly. Front/back hardware envelopes remain
about 3.5–4.0% wider than their height; the sidecar records this source limitation.

### 2026-10-11 — for the art agent — the prop queue for the captain's cabin

The **chest** and **captain's chair** sheets are delivered at `art/props/pirate_chest/`
and `art/props/captain_chair/`; see their Done entries. This is everything else the room needs, in the order the engine
side wants it. Work down it; you do not need to ask before starting the next one.

The reference for all of it is `docs/reference/room_target.png` — the owner's target
render for this room. Match its palette and its level of detail.

**2026-10-11 — owner requirement for every new asset:** Before generating, visually inspect `docs/reference/room_target.png`, the established character artwork and recent delivered prop sheets (including candle, desk lantern and desk globe). Match their simplified cartoon painted finish, broad colour shapes and restrained wear. Do this for every asset, not just the first asset of a session; record the inspected references in its sidecar.

**Conventions, same as the props already delivered:**
- One folder per prop, `art/props/<id>/`, with `sheet.png` and `asset.json`. The `<id>`
  is lower_snake_case and is load-bearing for anything that goes in the inventory: the
  engine loads `art/props/<id>/<id>.glb` and renders the inventory icon from the model
  itself, so the id below is the folder name, exactly.
- Four orthographic sheet views, **front / left / right / back**, equal heights and
  flat background, no other props or floor shadow. This follows `ART_SPEC.md` section1A
  and the delivered chest/compass sheets. Assign upload slots by filename, not by
  the sheet’s display position; do not swap right and back.
- Polycount, measured off what is already in the game and reading correctly at the room
  camera: hand-held items **2,500–3,500 tris** (compass 2,746, inkwell 3,070), furniture
  **6,000–8,000** (desk 6,051). Nothing needs more.
- `asset.json` must carry `dimensions_m` and a `dimension_contract`. The engine scales
  every prop from that sidecar, so a wrong number puts a teacup the size of a barrel on
  the desk.

**1 — blocking art sheets: delivered.**

`supply_crate`, `rapier`, `key`, `bowl_stand` and `porthole` now have sheets and
sidecars; see their Done entries. Their reconstruction and engine integration tasks
remain Open below. The porthole sheet supplies its metal surround; transparent glass
and weather are separate engine components.

**2 — current owner scope: practical cabin fixtures — art delivered.**

The owner’s latest request narrows this pass to `wall_lantern`, empty `bookcase`,
`desk_globe` and `painting_frame`, published one at a time. All four requested art
sources and sidecars are delivered; their reconstruction/integration tasks remain
Open below. `painting_frame` replaces the former complete `ship_painting` request:
the frame is empty, with no artwork, canvas, backing, glass or picture light.
Future picture contents are separate and replaceable. Books remain separate from
the shelving.

**Deferred by the owner as too fancy for this pass:**

| id | what |
| --- | --- |
| `curtain_panel` | heavy red curtain panel; deferred |
| `potted_palm` | brass pot and palm; deferred |

`picture_light` has now been delivered as a separate prop; `bookshelf_books` remains
future work in the dressing queue below. See the picture-light Done entry.

**3 — dressing and inventory, once the above are in.**

| id | what |
| --- | --- |
| `rolled_parchment` | a single rolled parchment tied with cord. Asked for by name; distinct from `rolled_charts`, which is a bundle of three |
| `loose_map` | an unrolled map lying flat, curled at the corners. Asked for by name |
| `bookshelf_books` | a run of books for the shelves, as one piece. Asked for by name. Separate from `bookcase` so the shelves can be dressed without regenerating the unit |
| `ladle` | Santi's galley ladle. Already referenced by the puzzle data |
| `quill_stand` | quill in a stand, on the desk |
| `ship_ledger` | the open log book on the desk |
| `pewter_tankard` | the mug on the desk |
| `rum_bottle` | dark glass bottle, as beside the chest in the render |

The owner's words on this list: *"You have the whole night, just play around."* Nothing
below row 1 needs approval before you make it. If you see something in the render that
is not on this list and the room wants it, add the row yourself and make it.

**What happens when you deliver.** Push the sheet and `asset.json` and move the row to
Done. The engine side picks it up from there: Tripo reconstruction, texturing,
Blender fixes, scale from the sidecar, and into the room. You do not run any of that
and you do not need to wait for it — keep going down the list.

The chest's lid is already readable on all four views, so no lid work is needed on it;
the engine side cuts and hinges the lid itself.

---


---

### 2026-10-11 — for the engine side — reconstruct and place the captain’s chair

`art/props/captain_chair/sheet.png` and `asset.json` provide the four orthographic
views. Reconstruct the red-leather/walnut chair, retaining the open spaces beneath
both arm rails and the one outside right-arm repair. The owner’s dimensions are
**0.5 × 1.0 × 0.5 m**; `main.gd::FURNITURE` still has a **1.9 m** chair placeholder.
Correct its height and vertical center/collision together when replacing it; the
proposed ground origin remains `(-3.6,0,-2.1)`. Do not scale this chair to 1.9 m.
Check de-lit materials, repair connectivity and final proportions. The source
height spread is 1 px; slightly broad silhouette ratios are recorded in the sidecar.

---

### 2026-10-11 — for the engine side — use the empty fishbowl construction reference

`art/props/fishbowl/sheet.png` and `asset.json` document the empty bulbous glass bowl
and attached brass base collar. Keep the engine-built transparent glass route from
the queue; Tripo is not required. Water, Count Fingers and `bowl_stand` stay separate.
The upright target is 0.52 × 0.44 × 0.52 m; 0.44 m height is provisional new art,
not the current 0.26 m hemisphere height. Views show the bowl sideways, mouth +Z;
rotate -90° about X to read it upright. Check silhouette, collar and clear visibility
of the fish when fitting the foreground-left stand. The image’s reflections/tint
are illustration, not a transparency texture. No engine code changed.

---

### 2026-10-11 — for the engine side — reconstruct and integrate the supply crate

`art/props/supply_crate/sheet.png` and `asset.json` are delivered. Reconstruct the
closed nailed crate at 0.9 × 0.9 × 0.9 m, keeping the French front stencil as flat
paint. Replace `main.gd::FURNITURE`’s `crate` / `Crate` visual at its current center
`(3.9,0.45,1.9)`; preserve the Crate hotspot, rapier answer, separate key item and
`crate_open` flag. Keep the decorative `pirate_chest` as a different object.
Check the nailed lid seam, lettering/material, bounds and any opening/interior work
in the model; the sheet shows the closed state only. All source heights and final
baselines match exactly; the common painted envelope is 1.54% wider than a square.

---

### 2026-10-11 — for the engine side — reconstruct and integrate the rapier pickup

`art/props/rapier/sheet.png` and `asset.json` are delivered. Use the sidecar’s
`--min-gap 80` extraction command so the open guard is kept in each whole sword view.
Target 2,500–3,500 triangles; verify a connected guard with real openings, blade
thickness and grip clearance. The selected provisional upright art target is
0.25 × 1.05 × 0.14 m; no earlier owner/engine numeric dimensions existed. The initial
narrower guide is preserved in provenance. Choose the scene/held rotation and grip
anchor in engine; the point-up sheet pose is not an already fitted desk placement.
Keep the `rapier` pickup/item ID and the supply-crate combination that gives `key`
and sets `crate_open`. Model target: `art/props/rapier/rapier.glb`.

---

### 2026-10-11 — for the engine side — reconstruct the crate’s brass key reward

`art/props/key/sheet.png` and `asset.json` are delivered. Reconstruct one integral
key with a genuinely open bow and the single notched bit; front/back reverse the bit
correctly and both show the bow opening. Target 2,500–3,500 triangles and the new
provisional upright dimensions 0.045 × 0.10 × 0.015 m. Keep the relatively clean
brass finish, matching the existing inventory description. Export to
`art/props/key/key.glb` and preserve the exact item ID `key`, given by the rapier /
supply-crate combination. No new pickup location or puzzle behavior is introduced.
Check material, hole topology and readability at the inventory icon size.

---

### 2026-10-11 — for the engine side — reconstruct and fit the foreground bowl stand

`art/props/bowl_stand/sheet.png` and `asset.json` are delivered. Reconstruct a solid
turned column with genuinely circular top/foot disks and an empty flat support top;
the four naturally matching elevations must not become a cuboid. Target 6,000–8,000
triangles or fewer if the turned silhouette holds. The stand’s own brass band is
below the wooden top; the bowl’s collar, glass, water and fish remain separate.
New provisional size is 0.60 × 0.65 × 0.60 m. The 0.60 m top accommodates the 0.52 m
bowl; 0.65 m plus its provisional 0.44 m height gives a nominal 1.09 m assembly.
Verify contact, circle geometry, materials and foreground-left placement in engine;
no final scene transform or assembled fit is claimed by this sheet.

---

### 2026-10-11 — for the engine side — reconstruct and glaze the porthole

`art/props/porthole/sheet.png` and `asset.json` provide the metal surround only,
with a clear aperture in front and back. Use the sidecar’s extraction command with
`--min-width-ratio 0.05` so the genuine narrow profiles survive the default span
filter. Keep the authoritative 0.90 × 0.90 × 0.08 m envelope including hardware,
centered at `(0,1.55,-3.4)`, `solid=false`, broad plane XY and room-facing front +Z.
Front hinge-left becomes rear hinge-right; the three front dogs do not duplicate
onto the back. The painted profiles imply about 0.08884 m depth, 8.84 mm / 11.05%
above the target; verify/correct mesh depth rather than changing the dimension
contract or stretching image views. Hinge/latch mechanics remain unverified.
Add a separate transparent glass disk within the inner rim and weather behind it;
do not reconstruct an opaque center disk with Tripo. The guide aperture is about
0.665 m, a proposed secondary measurement. Preserve the existing Porthole hotspot
and approach. Metal reconstruction and glass/weather integration remain Open.

---

### 2026-10-11 — for the engine side — reconstruct and complete the wall lantern

`art/props/wall_lantern/sheet.png` and `asset.json` deliver the opaque metal housing,
rear wallplate, two brackets and empty candle holder. Reconstruct these connected
parts while keeping the lifting eye and cage open. The center strip visible through
the front is the rear plate, not a candle. Adopt the declared 0.25 × 0.40 × 0.25 m
complete fixture target, adapted from the old hanging-lantern brief; no wall-mounted
transform existed. Side outlines imply 0.25745 m depth at H0.40, about 2.98% above
target, so check/correct mesh depth without rescaling individual source views.
Add separate transparent panes, candle and wick, flame effect and actual warm light.
The sidecar gives guide-only cage/holder fitting cues; verify clearances on the mesh.
Keep it upright with front +Z and rear -Z toward its selected wall. Exact left-wall /
door-area placement, component fitting and lighting remain engine work.

---

### 2026-10-11 — for the engine side — reconstruct and fit the empty bookcase

`art/props/bookcase/sheet.png` and `asset.json` provide the complete empty unit at
provisional 0.90 × 2.20 × 0.35 m. Reconstruct three fixed shelves making four actual
recessed bays, solid side panels and an opaque boarded back; do not flatten the
front into painted panels or turn the bays into through-holes. Books and globe are
separate. All four source heights are 837 px. At H2.20 the painted envelope implies
W0.90681 (+0.76%) and D0.36272 (+3.64%) m; inspect/correct mesh proportions against
the sidecar target without independently resizing the views.
The guide uses 45 mm shelves and 0.46125 m clear bay height, giving 0.08125 m nominal
vertical allowance for the separate 0.38 m globe. These are fitting cues only:
verify real shelf depth and globe base support, accounting for the back and front
setback, before dressing. Place upright, open face +Z, left of the desk; exact
coordinates, wall contact and final materials remain engine work.

---

### 2026-10-11 — for the engine side — reconstruct and place the separate desk globe

`art/props/desk_globe/sheet.png` and `asset.json` provide the complete globe alone:
mapped sphere, brass meridian and horizon ring, pole axle and short walnut pedestal.
Use provisional 0.30 × 0.38 × 0.30 m dimensions; the sphere guide is 0.24 m diameter.
Front/back show real air gaps around the sphere; side views show the same meridian
edge-on, with the horizon ring keeping full width. Reconstruct circular geometry
and connected pole supports rather than a flat disk. Target 2,500–3,500 triangles.
All source heights are 506 px. At H0.38 the painted widths/depths imply
0.301146 / 0.300395 / 0.299644 / 0.301146 m; retain the target and check mesh bounds.
The decorative fictional map uses one guide orientation: front 0°, left -90°/270°,
right +90°, back 180°. Preserve broad coastline continuity; exact texture seams,
UVs and globe mechanics remain unverified. Place the base on the separate bookcase;
its 0.46125 m guide bay gives 0.08125 m nominal vertical clearance, not a verified
assembled fit. Check real shelf depth, front lip/setback and pedestal support.
No exact scene transform, interaction or navigation-accurate chart is supplied.

---

### 2026-10-11 — for the engine side — reconstruct and place the empty painting frame

`art/props/painting_frame/sheet.png` and `asset.json` supply the connected wooden
frame with modest brass inner trim and four front corner plates. The back is plain
wood with an inner bevel/rebate; both broad views show the empty opening. Use the
named crop command with `--min-width-ratio 0.05` to retain the actual thin profiles.
Reconstruct the frame only: no painting, blank canvas, backing, glass or picture
light. Future image content is a separate changeable surface.

The complete **1.40 × 0.90 × 0.10 m** envelope is provisional new art, not an
existing scene measurement. All source heights are 456/456/456/457 px. At H0.90 m,
the front/back widths imply 1.395395/1.390372 m and the side profiles imply
**0.1125 m depth**, 12.5 mm above the 0.10 m target. Retain the target and verify
mesh construction; do not independently rescale the reference profiles.

The guide’s **1.20 × 0.70 m aperture (12:7)** is a fitting target, not verified
output geometry. The visible front/back background envelopes are 590×337 and
585×334 px, about 1.751 in aspect. Check the real through-opening and rebate depth
after reconstruction, then fit the separate image plane with appropriate hidden
edge overlap and a non-coplanar seat behind the inner lip. Set its final texture fit
from that measured aperture rather than assuming the guide dimensions survived.
The frame is upright in XY with front +Z. No exact wall transform or image-plane Z
offset is supplied. Reconstruction, final material lighting and engine placement
remain untested by this art delivery.

---

### 2026-10-11 — for the engine side — reconstruct and place the picture light

`art/props/picture_light/sheet.png` and `asset.json` supply the connected brass
hood, closed endcaps, central bent arm and rear mounting plate. The front shows a
blind reflector recess; the back is the actual exterior hood and plate rear.
Use the sidecar's named front/left/right/back extraction command and uniform 2x
output at 1630 px. The final provisional complete target is **0.40 × 0.17 × 0.19 m**;
the original 0.40 × 0.18 × 0.18 m guide and sizing revision are preserved in provenance.
At H0.17, painted widths imply 0.40825/0.40676 m and profiles 0.19040/0.19164 m.
Verify bounds, connected geometry and the shallow hood cavity. Rear fasteners are
proud of the plate, so inspect wall seating rather than assuming a flush contact.
Fit above the separate painting frame; the emitter and actual warm light remain
engine components. No exact placement or illumination has been tested by this sheet.

---

### 2026-10-11 — for the engine side — reconstruct and complete the desk lantern

`art/props/desk_lantern/sheet.png` and `asset.json` supply the standalone brass
housing: flat circular foot, four-post cage and closed front-door frame, hinges and
latch, empty holder, domed cap, vent gap and lifting eye. Keep the cage open and the
eye as a real through-hole; its opening is visible in front/back and edge-on in both
profiles. There is no rear brace or wall hardware. Target **0.18 × 0.32 × 0.18 m**
is provisional new art, not the larger wall-lantern size. Painted widths/depths at
H0.32 imply 0.18068–0.18122 m, within 0.7% of target.

Use the sidecar's named front/left/right/back extraction at native 729 px or uniform
2x at 1458 px. Reconstruct the connected metal frame, inspect/form the actual holder
cavity (its interior depth is not established by level views), verify pane seats,
door details and vent openings, then add separate glass and use the standalone
`candle` asset for the removable wax/wick insert; see its engine task below.
Fit the flame effect and warm light as separate runtime components. Set the origin
at the flat foot and fit on the desk's left side; no exact
scene transform or fitted assembly has been tested by this source delivery.

---

### 2026-10-11 — for the engine side — reconstruct and reuse the standalone candle

`art/props/candle/sheet.png` and `asset.json` provide one unlit ivory wax candle
with its embedded dark wick, a softly rolled uneven rim, restrained wax drips and
a flat supporting base. The owner explicitly wants a **separate reusable object**
that can be removed from a lantern or placed elsewhere. Reconstruct this as its own
`candle` asset/prefab at `art/props/candle/candle.glb`; keep fixture attachment at the
instance level. Set its root to the flat base center, +Y up. Flame and warm light are
optional separate runtime components attached near the measured wick tip.

The final provisional envelope is **0.033 × 0.080 × 0.033 m**, including wick
and wax relief. This adopts the finished projected width/depth of 0.03255–0.03332m
at H0.080m. The measured lower stem projects to about Ø0.0301–0.0310m; its lowest
0.025m is straight and undripped. The original Ø0.030m envelope / Ø0.028m stem
guide targets remain recorded in the sidecar. The intended wick tip is local Y0.080m.
Named front/left/right/back crops are native 720px square, or uniform 2x at 1440px.
Use the sidecar's commands and measure the reconstructed envelope, flat base,
upper rim and actual wick before import.

For the desk lantern, guide-only fitting cues are a Ø0.034m holder bore, 0.023m
interior depth and seat Y0.049m. A candidate base translation (0,0.049,0) puts this
candle's wick tip at lantern Y0.129m, 0.101m below the guide hood. The revised Ø0.031m
stem gives 1.5mm nominal radial clearance. The existing holder's actual cavity is
unverified: check/form the bore and seat, then check door, glass
and roof clearance before making a final socket. Recheck other holders separately.

---


### 2026-10-11 — for the engine side — reconstruct and fit Santi Wong's modular set

Start at `art/characters/santi_wong/pieces/asset.json`. Eleven separate sheets and
sidecars are delivered: body, head, hat, hair, face, shirt, coat (apron), trousers,
waist (harness/belt), boots pair and accessory (red neckerchief). The owner explicitly
requested this rebuild using Livé's modular references, superseding the old Livé-only
source-art gate; this does not certify the remaining Livé pipeline checks.

1. Use the recorded per-slot crop command, then a common 2x upscale of all four
   views. Order is front / left / back / right. Boots need `--count 4` to preserve
   paired boots. Other sheets use detection and `--min-width-ratio 0.1`.
2. Check Santi's A-pose, palms-down stocky body against the current one-donor
   armature workflow in `docs/RIGGING.md` before fitting clothing. His proportions
   have not passed donor fit. Retain the scaffold head for this check, then hide or
   remove its surface beneath the detailed head. Shirt sleeves are T-pose.
3. Reconstruct the slightly parted-mouth head; verify actual cavity, upper/lower
   teeth and tongue, then jaw closure without tearing. Mouth depiction is source
   artwork only. Moustache follows Head; chin goatee follows Jaw.
4. Fit each piece uniformly in metres to the reconstructed Santi body. The legacy
   assembled height is 1.70m INCLUDING the chef hat. Bare body 1.40m and all sidecar
   dimensions are provisional. No shared pixels-per-metre calibration is claimed.
   Native height differences are 0.66-4.46%; cropping aligns baselines without
   correcting source scale or projection. Do not stretch axes to conceal them.
5. Use `coat` for the cloth apron; `accessory` neckerchief requires a SKINNED hold
   override. Check garment openings, hat cavity, harness loops, both boots and
   scarf clearance. Cookware/ladle remain separate props. No engine code or fused
   Santi files were replaced by this source delivery.

Record reconstruction, body fit, mouth closure, garment clearance and engine-import
results here. All of these checks remain unverified.

---

### 2026-10-11 — for the engine side — cabin textures and reusable construction parts

The owner requested repeating material textures without fixing room dimensions,
then requested a textured beam and board from multiple angles for modeling; keep
both kinds of source. Index: `art/kits/captains_cabin/asset.json`.

Four original colour textures with sidecars are under
`art/materials/captains_cabin/`: `floorboards`, `wall_planks`, `beam_wood` and
`carpet_burgundy`. Map by metres per tile, with repeat/mipmaps enabled, rather than
stretching one image across the room. Suggested spans and grain axes are in each
sidecar and `docs/ART_SPEC.md` section2A. Carpet is the inner repeating field only;
any gold border belongs on a separate finite edge strip.

The original textures are1254px square, neutral painted cartoon colour sources.
Companion normal/height trials for boards, beam grain and carpet are now delivered
in the task below; wall planks remain colour-only and roughness remains constant.
Simple2x2 colour repeats were inspected.
Opposite edge rows are approximately matched, not identical; numeric edge jumps
are recorded. Check visible seams, repetition and brightness at the actual camera
under the current toon lights before certifying the live material.

Modeling sources are `art/props/timber_beam/` and `art/props/wood_board/`, each with
`sheet.png`, `asset.json` and `views/`. Submit the four crops by their named slots.
The owner rejected the initial box-like geometry. Selected revisions use bowed
edges, taper, oversized carved bevels and worn corner cuts, matched to the crate
and desk. The beam shows long front/back faces and opposite cut ends with end grain.
Board source is upright, showing broad faces and thin edges. Board heights match;
beam's155/157px heights differ2px (~1.27%), beyond the strict1px allowance. Resolve
that source limit or check measured model projections before certifying reconstruction.
All baselines match. Crops preserve complete native foreground, then use one
common2x upscale. Provisional sizes adopt finished ratios rather than the initial
prompt estimates: beam2.10x0.38x0.375m, board0.305x0.107x1.65m laid flat. The board is
a substantial solid plank, not thin veneer. Rotation and source ratio limits are
recorded. Check actual contact patches, side gaps, floor flatness, UV density and endpoint markers after
reconstruction. Keep width/thickness and grain density fixed when adapting length.

**Owner-authorized adoption, 2026-10-11:** Native beam/board models and live material assignment are now delivered in the first cabin dressing pass; see Done and `locations/captains_cabin/HANDOFF.md`. The earlier source-only statement is superseded. Snap-grid/contact-land certification and any future construction expansion remain open; do not infer those from decorative scene placement.

---


## Done

### 2026-10-11 — for the engine side — scene authoring and agent collaboration plan

The owner requested a prioritized plan covering editable reusable scene objects,
removal of scene regeneration flags/tools, and modular ownership for parallel agents.
The full checklist and completion checks are in
[docs/REFACTOR_PLAN.md](docs/REFACTOR_PLAN.md). Follow its priority order: preserve
the baseline, establish module ownership, migrate fixed content and remove builders,
repair behavior, then validate integration and update documentation.

Implemented naming: `game/game.tscn` is the startup wrapper, root Game;
`locations/captains_cabin/captains_cabin.tscn`, root CaptainsCabin, is the initial
playable place. Indoor and outdoor locations reuse the same authored components.

Fixed content and default UI/audio are now reusable scenes. Both batch builders and
custom game/packing switches are removed. Module agents used separate worktrees;
integration includes navigation, movement/interaction completion, dialogue scrolling,
portrait/item resources and isolated explicit outfit saves. All 24 plan tasks passed
their checks, including the strict 12-check suite, fresh import and renderer lifecycle.
See `docs/migration/README.md` for evidence and remaining art/composition decisions.

---

## 2026-10-11 — for the art agent — the dialogue bar, with the portrait frame in it

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

**Result — 2026-10-11, art side:** Delivered Captain’s Ledger UI sources under
`art/ui/`: `dialogue_frame.png`, `portrait_frame.png`, `speaker_ribbon.png`,
`response_highlight.png`, `controls_atlas.png`, and the exact `dialogue.json`
layout/atlas/9-slice contract. Actual Grenze and Source Sans 3 fonts, original
licences and provenance are in `art/ui/fonts/`. `README.md`,
`ENGINE_INTEGRATION.md`, `source_validation.json` and `generation.json` accompany
the art; selected/revised concept images are in `art/ui/reference/`.

The owner approved the second ledger/response direction, then asked that the
portrait and dialogue box have **the same height and aligned top/bottom edges**.
The exact delivered target is 300px high for both: portrait `(80,720,300,300)`,
text box `(394,720,1446,300)` at 1920×1080. Use the measured atlas regions so native
transparent gutters do not change their visible heights. Longer speech and
wrapped responses scroll; they do not enlarge either frame. All five runtime
PNG sources are blank RGBA art, with no baked names, dialogue or portrait. The
portrait centre has alpha0; its measured safe face area is documented.

Source rasters and font/manifest properties were verified. **Engine integration
and Godot runtime verification remain in Open.** No animation or screenplay
was changed. The cabin images are composition guides; the owner specifically
flagged the carpet markings as rough. They are not a final room backdrop.

---

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

### 2026-10-11 — art side — Captain’s Ledger frame join corrected

**Result:** Delivered `art/ui/integrated_frame.png`, one unchanged 1644×957 RGBA
source with continuous rails and a straight wooden divider reaching both rails.
The owner rejected the preceding internal-connector attempt; both decorative
connectors are now removed. Brass remains only at the four outer corners.
This supersedes the two-frame/14px-gap geometry in the earlier UI delivery above.
The existing standalone frame files are preserved as legacy/unused.

Updated `art/ui/dialogue.json`, `README.md` and `ENGINE_INTEGRATION.md` for three
adjacent regions of the same master, rendered into `(80,720,1760,300)` with fixed
375px/150px caps and only the 1235px middle stretched horizontally. Moved the label
fully below the upper rail at y756; the 156px scrolling viewport honestly fits three full
speech lines or three single-line response rows. Fonts, helper controls and live
text/portrait responsibilities are retained. The confirmed safe face rectangle is
`(142,764,212,212)`; its source sample contains only alpha 0–1.

`art/ui/source_validation.json` and `generation.json` record the new source and
checks; `reference/layout_concept.png` shows the corrected composition. Engine
integration and runtime verification remain in the existing Open item. No engine
code, animation or screenplay was changed.

---

### 2026-10-11 — art side — selected rope-edged dialogue frame delivered

The owner selected **variation 3** from the five divider-free previews. Delivered
the final blank `art/ui/dialogue_frame.png`: 2172×724 RGBA, continuous parchment,
rope/walnut perimeter and four outer brass corners. It replaces the divider and
portrait-aperture construction above; `integrated_frame.png` and
`portrait_frame.png` are preserved unused.

Updated `art/ui/dialogue.json`, `README.md` and `ENGINE_INTEGRATION.md` for the
`(80,720,1760,300)` bar with 100/1560/100px sections of the same source. The portrait
renders over the shared paper at `(144,756,224,224)`. The raised title at y720 and
188px scrolling viewport recover four full speech lines or four single-line choices.
Fonts, helper assets and live text/portrait responsibilities remain unchanged.

`source_validation.json` and `generation.json` record the final source checks and
provenance. `reference/layout_concept.png` now shows the selected rope-edged option.
Engine integration and runtime verification remain in the existing Open item;
no engine code, animation or screenplay was changed.

---

### 2026-10-11 — art side — pirate skull chest sheet delivered

Delivered `art/props/pirate_chest/sheet.png` and `asset.json`: one closed warm-wood
chest, flat white skull/crossbones at the front, plain sides and two rear hinges.
Four level orthographic views in a 2176×544 white sheet; every silhouette is 374 px
high, all baselines are y435, and empty separators are 163/169/163 px. The unchanged
cutter only translated native source crops; no resampling. Full prompts, source
hashes and measured proportion limits are in the sidecar. Reconstruction and engine
integration remain Open; no engine code was changed.

---

### 2026-10-11 — art side — captain’s chair sheet delivered

Delivered `art/props/captain_chair/sheet.png` and `asset.json`: tufted red-leather
front, plain red rear, walnut/brass structure and one horizontal right-arm splint.
Four opposite orthographic views in a 3392×848 white sheet; heights are
683/684/684/684 px, all baselines are y746, and separators are
489/484/489 px. Native source crops were translated only, with no resampling.
The sidecar contains all five prompts, hashes, measured ratios and the 1.0 m owner
height versus 1.9 m engine-placeholder discrepancy. Reconstruction and engine fit
remain Open; no engine code was changed. The current queue’s `dimension_contract`
field and 6,000–8,000 triangle target are recorded for both furniture assets. The
chest’s earlier crate-slot mapping is corrected: `pirate_chest` and `supply_crate`
are separate props.

---

### 2026-10-11 — art side — empty fishbowl reference sheet delivered

Delivered `art/props/fishbowl/sheet.png` and `asset.json`: four level orthographic
views of the empty glass bowl and its brass base collar, with no water, fish or stand.
The final cel-shaded sheet is 2404×601; all four silhouettes are 485 px high and share
baseline y528, with 145/175/145 px separators. The unchanged cutter only translated
native crops; their pixels are identical to the generated source. Full recorded
prompts, hashes, measured profile limits and the sideways-to-upright convention are
in the sidecar. Upright dimensions are 0.52 × 0.44 × 0.52 m; height is a new provisional
art target. This remains a construction reference for engine-built transparent glass,
not a required Tripo job. The separate `bowl_stand` queue item remains open.

---

### 2026-10-11 — art side — supply crate sheet delivered

Moved `supply_crate` from the blocking queue to Done. Delivered
`art/props/supply_crate/sheet.png` and `asset.json`: plain nailed wood, a readable
closed lid seam and the exact front stencil `LE CHAOS NAVIGUE TOUJOURS PLUS LOIN`.
Four flat orthographic views; final sheet 2296×574, each object 463×456 px, shared
baseline y505, separators 111/111/111 px. Native source crops were translated only;
all four object rectangles remain pixel-identical. Full prompt, references, hashes
and measured proportion limits are in the sidecar. Reconstruction and puzzle
integration remain Open. Rapier, key, bowl stand and porthole remain queued.

---

### 2026-10-11 — art side — rapier sheet delivered

Moved `rapier` from the blocking queue to Done. Delivered `art/props/rapier/sheet.png`
and `asset.json`: silver blade, open brass guard and pommel, worn brown grip, point up
in four orthographic views. The final sheet is 4164×1041; every sword is 840 px high,
all baselines are y916, and separators are 885/932/886 px. Native own-bounds crops
were translated only, using the unchanged cutter’s `--min-gap 80` to bridge internal
guard gaps. All source object pixels are unchanged. Background is visible through
the guard in front and back. Full prompt, hashes, initial/final dimensional choices
and measured envelopes are in the sidecar. Engine reconstruction/pickup fit remain
Open; key, bowl stand and porthole remain queued.

---

### 2026-10-11 — art side — brass key sheet delivered

Moved `key` from the blocking queue to Done. Delivered `art/props/key/sheet.png`
and `asset.json`: clean brass bow/shaft/bit as one object, bow hole visible in front
and back, thin opposite profiles. Final sheet 3400×850; all heights 686 px, baseline
y747, gaps 643/746/642 px. The unchanged cutter translated native own-bounds crops
without resampling; all source object pixels are identical. Full prompt, guide,
hashes, provisional dimensions and measured ratios are recorded in the sidecar.
Reconstruction/inventory integration remain Open; bowl stand and porthole remain
queued.

---

### 2026-10-11 — art side — fishbowl stand sheet delivered

Moved `bowl_stand` from the blocking queue to Done. Delivered
`art/props/bowl_stand/sheet.png` and `asset.json`: a solid walnut turned pedestal,
flat circular support disk, stepped circular foot and brass band below the top.
The stand is alone. Final sheet 2472×618; all heights 499 px, baseline y543,
gaps 152/153/153 px. Full PNG decode passed; the unchanged cutter only translated
native crops, and all four source object rectangles remain pixel-identical.
Full prompt, guide/reference hashes, provisional dimensions and measured ratios
are recorded. Reconstruction and foreground bowl fit remain Open; porthole is
still queued.

---

### 2026-10-11 — art side — porthole metal-surround sheet delivered

Moved `porthole` from the blocking art queue to Done; all five priority sheets are
now delivered. `art/props/porthole/sheet.png` and `asset.json` show the brass ring
and attached hardware, with open white apertures in front/back and true narrow
opposite profiles. Final sheet 2308×577; heights 466/466/466/465 px, baseline
y507, gaps 321/531/322 px. Full PNG decode passed. The unchanged cutter used
`--min-width-ratio 0.05` and translated native own-bounds crops only; every source
object rectangle remains pixel-identical. Three full prompts, guide/reference
hashes, the authoritative dimensions and the measured depth discrepancy are in the
sidecar. Metal reconstruction and separate engine glass/weather remain Open.
The furnishing and dressing queues remain unchanged.

---

### 2026-10-11 — art side — wall lantern housing sheet delivered

Delivered `art/props/wall_lantern/sheet.png` and `asset.json`, and moved the lantern
from the pending art table to Done. The sheet is metal housing/brackets/plate and
empty holder only; engine glass, candle/wick/flame and light remain separate.
Final 2800×700, native 700 px cells; source/final heights 565/564/564/564 px,
shared final baseline y615 and empty gaps 342/337/342 px. Full PNG decode and IEND
passed. Unchanged cutter, no resampling, all four source object rectangles remain
pixel-identical. Full prompt, guide/reference hashes, size adaptation and measured
width/depth differences are recorded. Reconstruction and mounting remain Open.
The latest owner scope is also recorded above: empty bookcase, desk globe and empty
painting frame next; curtains/palm deferred, books and picture light separate future work.

---

### 2026-10-11 — art side — empty bookcase sheet delivered

Delivered `art/props/bookcase/sheet.png` and `asset.json`; removed only the bookcase
from the pending art table. Three shelves form four empty wood-backed bays, with
plain narrow side panels and a real boarded rear. Final 4148×1037, native 1037 px
cells; all source/final heights 837 px, final baseline y912, gaps 795/899/796 px.
Full PNG decode and IEND passed. Unchanged cutter, no resampling; all four source
rectangles remain pixel-identical. Both full prompts, guide/reference hashes,
provisional dimensions, measured proportions and clearance limits are in the
sidecar. Reconstruction/dressing remain Open. Desk globe and empty painting frame
remain the current art queue; the deferred items and separate future tasks are unchanged.

---

### 2026-10-11 — art side — separate desk globe sheet delivered

Delivered `art/props/desk_globe/sheet.png` and `asset.json`; removed only the globe
row from the current scope. Final sheet 2508×627; all four heights are 506 px,
baseline y551 and gaps 226/228/227 px. Full PNG decode passed. The unchanged cutter
translated native own-bounds crops only; all source object rectangles remain
pixel-identical. Broad front/back meridian gaps stay open, and the four map faces
follow the same fictional spherical-map guide. Two full prompts, guide/code/map
provenance, hashes and measured proportional limits are in the sidecar.
Reconstruction, texture seams/topology and bookcase fit remain Open. The empty
painting frame remains current; deferred curtains/palm and future dressing are
unchanged.

---

### 2026-10-11 — art side — empty painting frame sheet delivered

Delivered `art/props/painting_frame/sheet.png` and `asset.json`; removed the last
pending row in the current four-prop scope. Final sheet 3504×876, native 876 px
cells; heights 456/456/456/457 px, shared baseline y770 and gaps 494/819/495 px.
Source and final PNG decode/IEND passed. The unchanged cutter translated native
own-bounds rectangles only; all four remain pixel-identical. Front and rear
openings are enclosed background regions, with no image, backing, glass or light.
The sidecar records the provisional dimensions, measured profile/aperture limits,
tool/model provenance, source/guide hashes and actual selected-source evidence.
The exact full prompt was lost from transient state; it is explicitly null, with
the retained opening and a labeled instruction summary instead of invented text.
All four requested art sources are delivered. Reconstruction and changeable-image
fit remain Open; curtains/palm stay deferred and later dressing remains queued.

---

### 2026-10-11 — art side — separate picture-light sheet delivered

Delivered `art/props/picture_light/sheet.png` and `asset.json`; moved only the
picture light from the dressing art queue. One connected practical brass fixture,
with an empty blind hood recess, true opposing profiles and actual rear mounting
plate. Final 3260×815; heights 274/275/275/275 px, shared baseline y717, clear uniform
gaps 332/506/331 px. Full PNG decode and IEND passed. The unchanged cutter translated
native own-bounds rectangles only; every rectangle remains pixel-identical.
All three prompts, guide source/geometry, reference hashes, proportional limits,
and the final provisional 0.40 × 0.17 × 0.19 m dimensions are in the sidecar.
Reconstruction, wall seating and actual lighting remain Open. Other queued props
and the owner's deferred curtains/palm are unchanged.

---

### 2026-10-11 — art side — desk-lantern sheet delivered

Delivered the separately requested `art/props/desk_lantern/sheet.png` and
`asset.json`; moved only this lantern from the pending dressing queue. The fixture
matches the reference's tabletop lantern and keeps all nonmetal components for the
engine. Final 2916×729; all four heights are exactly 588 px, common baseline y641,
and clear uniform gaps are 397/396/397 px. The lifting-eye openings are enclosed
background regions in front/back (1154/1155 px). Full PNG decode/IEND and named
crop checks passed. The unchanged cutter translated native source rectangles only;
every rectangle remains pixel-identical. Full prompt, guide source/geometry,
reference hashes, provisional dimensions and measured limits are in the sidecar.
Metal reconstruction, holder depth and all component fitting remain Open.

---

### 2026-10-11 — art side — reusable candle sheet delivered

Delivered the separately requested `art/props/candle/sheet.png` and `asset.json`:
one unlit ivory wax candle with embedded wick, ready as a source for a removable,
reusable prop. The candle is separate from all holders, lanterns and flame/light
effects. Complete dimensions 0.033 × 0.080 × 0.033m are provisional art targets
adopted from the final painting; original guide dimensions remain in the sidecar.

Final sheet 2880×720px; native source heights 580/581/581/581px; final last-ink
baselines 633/633/633/633px and clear separator widths 482/479/479px. The unchanged
repository cutter placed each source rectangle on a shared native 720px square canvas;
all four rectangles retain identical source pixels with no resampling. The sidecar
records the full imagegen prompt, guide source/geometry, reference hashes, measured
proportions and provisional lantern-fit cues. Reconstruction, material review and
the standalone prefab/optional effects remain Open above.

---

### 2026-10-11 — art side — rolled charts redo delivered

Moved the requested redo from the art queue to Done. Delivered
`art/props/rolled_charts/sheet.png`, `asset.json` and refreshed `views/`: three
long cylindrical parchment rolls with layered recessed ends in every elevation,
simplified cartoon painted finish matched against established props. This replaces
the first rejected flat-slab source. Fixed diagonal reconstruction yaw exposes the
ends while preserving level front/left/right/back cameras and one shared scale.
Final sheet 2420 × 605 px; native heights 79/80/79/79 px, baseline 532 px for all four,
clear separator bands 122/123/122 px. Unchanged cutter translates native pixels only;
view crops use one common 2x upscale. Full prompts, reference hashes, dimension
contract and measured limitations are in the sidecar. Reconstruction remains Open.
The owner also requires inspecting other artwork before EVERY new asset; recorded
in the art conventions above. Show this prop to the owner before starting the next.

---

### 2026-10-11 — art side — Santi Wong modular source set delivered

Delivered eleven four-view sheets with per-piece metadata and the index at
`art/characters/santi_wong/pieces/asset.json`. Inspected approved Santi identity
artwork, room style reference and corresponding Livé modular pieces before
generation; preserved the stocky cook and separated all wearables. Full selected
and revision prompts, reference hashes, provisional sizes, slot mapping and source
limits are recorded. Body is A-pose with scaffold head; shirt is T-pose; detailed
head uses the current slightly parted-mouth guidance. Apron maps to `coat`, red
neckerchief to `accessory`; moustache and chin goatee are separate islands.

All eleven original generated PNGs are copied unchanged. The existing cutter
extracts 44 nonempty native views on shared per-piece square canvases/baselines;
pixel comparisons verify complete foreground coverage with no clipping or
resampling in native extraction. Source height spreads range from 4 to 16px
(0.66-4.46%); exact equal-scale projections are not claimed. Common 2x input sizes
range from 1140 to 1712px. Reconstruction, cavities, rigging and fitting remain
Open above. This is source artwork, not an assembled animation-ready character.

---

### 2026-10-11 — engine — editable fake-lighting material library

Delivered 16 techniques with equivalent `_shader` and built-in-node `_graph`
materials, plus authored reusable samples and a comparison lab at
`materials/stylized_lighting/gallery/material_lab.tscn`. Scene fake-light controls
target explicitly assigned components; source textures, independent instance settings
and authored transforms are preserved. No game look or source mesh was replaced.
Usage, researched references, limits and measurements are recorded in
`materials/stylized_lighting/README.md`. All 13 project checks and 64 GPU pair
comparisons pass; Compatibility is validated, Forward+/Mobile remain untested.
---

### 2026-10-11 — art side — cabin material textures and construction kit delivered

Delivered four reusable colour tiles at `art/materials/captains_cabin/`, plus
standalone textured `timber_beam` and `wood_board` four-view sources and their
eight extracted reconstruction inputs at `art/props/`. The kit index is
`art/kits/captains_cabin/asset.json`; surface-density guidance is in
`docs/ART_SPEC.md` section2A. Inspected the cabin, established captain and relevant
recent props before each asset; used built-in image generation with complete
prompts and reference hashes recorded. All six selected PNG sources are unchanged.

After owner feedback, revised both parts' silhouettes to hand-hewn cartoon timber
with broad carved facets, curved edges, taper and corner wear. Original straight
drafts are unselected; actual edit/alignment prompts are retained in provenance.
Beam source2172x724px: heights155/157/157/155px, common baseline415px; strict1px
height alignment NOT met, remaining2px difference (~1.27%) recorded. Board source
1536x1024px: all heights990px, baseline1003px. Unmodified cutter gives native squares
1067/1227px; pixel comparison verifies all eight native rectangles intact and zero
detected foreground lost. Reconstruction inputs are2134/2454px with one common2x
LANCZOS upscale per part. Initial dimension prompts differed from finished ratios;
the sidecars preserve both and use explicit provisional final guides.

Each texture is1254px square and was reviewed as a2x2 repeat. Approximate edge
matching and residual transitions are recorded; no pixel-exact seamless guarantee
or in-engine material test is claimed. Carpet has no outer border. User explicitly
asked to retain textures while adding modeled-part references. Reconstruction,
caps/joints, scene assignment and live seam/light checks remain Open above.

---

### 2026-10-11 — art side — stylized normal-map trials delivered

Delivered six1254px normal maps (gentle/stronger for boards, beams and carpet),
three unchanged generated height sources, full prompts/derivation sidecars and
Godot import settings alongside the existing cabin albedos. Original colour PNGs
are unchanged. Updated material/kit metadata and documented engine setup at
`art/materials/captains_cabin/NORMAL_MAPS.md`. Normal-vector/data checks and scoped
Godot4.7.2 import/load/material binding passed; evidence is `normal_validation.json`.
Owner saw the lighting comparison and actual purple normal map and authorized
commit/push for engine use. Live assignment, seams and toon-light acceptance remain Open.

---

### 2026-10-11 — scene side — first cabin dressing pass delivered

Owner requested scene arrangement/texturing before further modeling. Adopted the four existing cabin colour sources, gentle floor/beam/carpet normals, native timber/board parts, three separate reusable roll models and the native crate visual. Saved scene layout, fake-light material controls, painted bowl and verification are indexed in `locations/captains_cabin/HANDOFF.md`, `props/HANDOFF.md` and `tests/HANDOFF.md`. Existing actors, furniture roots, camera, navigation collision geometry and puzzle interactions are preserved. All 15 checks, eight real GPU hotspot clicks and actual normal-map render comparison passed. New modeling is paused in favour of scene review; no character replacement was made. Changes are saved locally; no commit or push is claimed.

The old three-roll Tripo reconstruction request is superseded by the owner's direct-modeling and separate-reuse instructions. Runtime assets are `art/props/chart_roll_01/02/03/` and neutral `props/chart_roll_01/02/03/` prefabs. Each is 0.60x0.04x0.04m and 3,056 triangles. The original source sheet/metadata are retained; gameplay inventory remains unchanged. Historical task follows for provenance:

### 2026-10-11 — for the engine side — reconstruct the revised three-roll charts

`art/props/rolled_charts/sheet.png` and `asset.json` replace the rejected slab source;
`views/` is refreshed at 1210 px square. Three rolls now match the latest queue;
the former source sidecar had four. Use Tripo and assign named front/left/right/back
slots explicitly. The object is fixed at 45-degree horizontal yaw, so level cardinal
views all expose layered roll ends at one scale; no end view was magnified.
Undo the yaw to long-axis +X before measuring the retained 0.60 × 0.08 × 0.08 m
engine envelope. Check real cylindrical volumes, three hollow bores, connectivity,
de-lit materials and the recorded 4–6% painted proportion deviation. Target 2,500–3,500
triangles. The 2D redo is delivered; successful reconstruction is NOT yet verified.


**Completion note:** Its original Tripo-only and fused-bundle instructions describe the older art handoff, not the current owner-authorized delivery. Native roll geometry, open bores, individual bounds and Godot imports are verified.

---

### 2026-10-11 — for the engine side — use the stylized cabin normal maps

The owner approved committing the three trials for engine use. Start at
`art/materials/captains_cabin/NORMAL_MAPS.md` and the kit index. `floorboards`,
`beam_wood` and `carpet_burgundy` each have `normal_gentle_opengl.png`,
`normal_stronger_opengl.png`, `height_source.png` and `normal_trials.json`.
All six normals are actual normalized tangent-space OpenGL +Y data, not grayscale
height images. Start with gentle. Import settings enable normal data and mipmaps;
leave Y inversion off, enable sampler repeat and share colour/normal UV transforms.

Assign/test through each material/prefab owner. Custom fake-light/toon shaders must
use the perturbed normal in their light calculation. Check final mesh tangents,
UV density, colour/relief alignment, seams and strength at the game camera. Source
registration/repeats are approximate; CPU comparison previews are not scene renders.
Wall planks have no normal trial. Scene assignment and final visual acceptance
remain Open; delivery does not rebuild scenery or modify shared shaders.


**Completed live adoption:** Gentle normals now drive the unshaded cabin shader on floor, carpet and imported timber. Original PNGs are unchanged, UV transforms are shared, and an actual GPU normal on/off comparison confirms visible lighting changes. Tile motifs and colour/height registration remain artistic approximations; this does not certify perfect seams. Further visual tuning can use the editable local materials.

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

## 2026-10-11 — cabin integration with latest main

Owner requested pulling and reviewing latest main before combining the scene work. Pulled `9003da4` on main and reapplied only the cabin dressing, reusable native assets and their material/prop support. All upstream Character Workshop code, source views and texture import settings are retained. The camera node is exactly the latest-main version, including position, rotation, FOV and framing profile; navigation and existing placement are unchanged. Shared documentation and runner conflicts are resolved by retaining the upstream checks and adding cabin_dressing_check, for 22 checks. Owner requested immediate handover and no further test runs. Owner authorized committing and pushing this integrated cabin pass to main. No further tests are requested.

## 2026-10-11 — owner-selected modular Captain body

`art/characters/captain_live/pieces/body/body.glb` is now the owner-supplied lower-polygon body for modular assembly, using the corrected texture version provided after the owner removed lighting. The supplied GLB is copied unchanged. It contains 22,032 mesh triangles, 0 skins, 0 joints and 0 animation clips. The previous source had 50,270 mesh triangles and remains recoverable from commit `0c2ae59`. Existing import UID/settings are retained. Delivery provenance, checksums and measured file counts are in the body asset.json. Use this canonical body for future modular fitting; the separate head/clothing still require fitting. The current world Captain, portrait and scene/camera are unchanged. Engine import, rig fitting and tests were not run for this delivery.

## 2026-10-12 — project-agnostic Character Workshop

Workshop is now self-contained under `addons/character_workshop/`. One Settings
button selects project assets, optional templates, preferred save folder and
integration script; setup is optional. Cruises keeps its own adapter/templates and
borrowed captain namespace outside the addon. Copy the addon alone to another
project. Installation/adapter docs and current status are in the addon README,
PROJECT_INTEGRATION.md and HANDOFF.md. All 25 checks/cold routes pass, including
a fresh-project ZIP install and exported PCK run. The owner's Captain fits, meshes,
skins and bone poses remain unchanged. No runtime authoring or branch change.
