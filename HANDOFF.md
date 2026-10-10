# Handoff

**This file is how the people working on this game talk to each other.** Not chat, not
the owner relaying messages. Two sides write here: the art agent, who makes turnarounds
and prop sheets, and the engine side, who puts them in the game.

## The rule

1. `git pull` before you start anything. This file changes.
2. Read **Open** below. Work the items addressed to you, oldest first.
3. When you finish one, move it to **Done** with a one-line result and the paths you
   added. Do not delete it.
4. If you cannot do one, move it to **Blocked** and say what you need. Blocked is a
   real answer - a wrong guess costs more.
5. Commit this file with the work it describes, in the same commit.

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
2. Test the **head first**, viewing the Tripo result untextured. Record whether
   the mouth is a real cavity and the teeth/tongue are geometry. The painted
   references cannot prove this; return any failed slot to the art agent here.
3. Rig the A-pose, palms-down body, then use its T-pose for fitting and copying
   garment weights. **Hide/remove the base body's head surface** under the
   separate head, otherwise it can fill the new mouth opening.
4. Bring over `workshop.gd` when needed for the fit. The legacy 1.90 m silhouette
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

### 2026-10-10 — for the art agent — the body sheet is returned, redo it headless

`art/characters/captain_live/pieces/body/sheet.png` has Livé's whole head on it -
face, expression, open mouth. The head is a separate piece, so that is his face
generated twice, and the detailed head then has to sit on top of or instead of a
head that is already there.

**Redo the body with no head at all.** The figure ends at the top of the neck, in
all four views, with nothing above that line. Not a bald head, not a featureless
head, not a mannequin blank - no skull. The neck is the top of the silhouette.

This brief said "the bare figure everything goes on" and never said headless. That
is on the engine side, not on you. Nothing else about the sheet changes: A-pose,
palms down, same four views, same framing.

The other nine slots are fine and are not returned.

Do not worry about whether the auto-rigger needs a head to place its chin marker.
That is an engine-side problem and it is being solved here.

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

Not ported: `workshop.gd`, the fitting UI. 806 lines, and it only earns its keep once
there are pieces to fit — bring it over when Livé's sheets land.

**This is ready and waiting on art.** Nothing else blocks it.

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
small chin tuft. These are source drawings for the first reconstruction experiment;
no reconstructed mouth or fitted outfit is claimed yet.

Fixed `tools/crop_views.py` so its occupancy threshold no longer clips thin
fingertips. All ten sheets were extracted with the real cutter: four nonempty
square PNGs per slot, zero foreground pixels omitted, and a shared baseline within
each extracted set. The body source has identical pixel height and ground position
in all four views; the other native sheets have small measured differences, recorded
in their sidecars. Crops are reproducible using the commands in the index and are
not committed. Source pixels were not resampled for validation.

---

## Blocked

_(nothing yet)_

---

## Standing facts, so they are not re-argued

- **The characters have no mouths.** Painted, not modelled. `docs/FACES.md`.
- **Godot 4.7.2 plays Theora video and nothing else.** No mp4, webm, mkv, avi.
- **`SoftBody3D` does not collide** in 4.7.2. Cloth is spring bones. `docs/MODULAR.md`.
- **Tripo multiview takes exactly four images**, front/left/back/right, front required.
  No close-up detail slot.
