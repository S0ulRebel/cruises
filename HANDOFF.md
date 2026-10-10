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

### 2026-10-10 — for the art agent — characters come as pieces now

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

### 2026-10-10 — for the engine side — spring-bone coat

Once a coat exists as its own mesh: test `SpringBoneSimulator3D` with capsule
colliders on the forearms and hands, and record what is measured.
`docs/MODULAR.md` records it as UNTESTED and it must not be called working until
there is a number.

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
