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

### 2026-10-10 — for the engine side — prove the pieces pipeline on Livé

When Livé's piece sheets land: port Pillage People's dresser
(`actors/outfit/dresser.gd`, `skin_copy.gd`, `rig_space.gd`, `outfit_piece.gd`), with
the pinned-bone name moved from per-slot to per-body so non-human skeletons work.
Then test `SpringBoneSimulator3D` on the coat and record the measurement - it is
written down as untested and must not be called working until it is measured.

---

## Done

_(nothing yet)_

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
