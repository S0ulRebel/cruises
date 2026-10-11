# Captain’s Ledger — engine integration

11 October 2026. The current source uses **one continuous frame and a plain wooden
divider**, replacing the two independently rendered frames. This document and
`dialogue.json` describe art integration; Godot runtime verification remains open.
The UI source audit was performed at `6a93595a15d50cb5f2b4f94cb035acdf52f1c50b`.

## Render one source in three sections

The logical canvas is 1920×1080. All rectangles below are `(x,y,width,height)`;
right and bottom are exclusive. The whole bar is **`(80,720,1760,300)`**.

`integrated_frame.png` is the unchanged 1644×957 RGBA master. Its visible source
region is `(18,275,1608,388)`. Draw these adjacent regions from that same texture:

| Section | Native source rectangle | Screen rectangle |
| --- | --- | --- |
| Left assembly | `(18,275,485,388)` | `(80,720,375,300)` |
| Middle span | `(503,275,929,388)` | `(455,720,1235,300)` |
| Right cap | `(1432,275,194,388)` | `(1690,720,150,300)` |

The caps use uniform scale **75/97** in both axes. The middle uses that same
vertical scale and stretches only horizontally. Cuts fall beyond complete
fittings in quiet rails/parchment. Regions meet exactly at screen x455 and x1690;
The divider meets the upper/lower rails directly in wood; there are no internal
metal connectors. Brass remains only at the four outer corners.
Do not render `dialogue_frame.png` or `portrait_frame.png`: both are legacy/unused.

Use one fixed, unscaled host for layout and hit targets, with the three visual
regions and the live portrait/text layers inside it. Preserve alpha, including the
parchment field. Keep all ornaments within y720–1020. A minimum height alone is
insufficient if content can still force a container taller; bound the text region.
For width adaptation at 300px height, preserve the 375px left and 150px right sections
and resize only the middle. Check the two joins with the engine’s texture filtering.

## Portrait aperture

The native opening is approximately `(72,317,323,300)`. Mapped into the bar, its
bounding rectangle is `(41.75,32.47,249.74,231.96)`; its corners are curved.
The safe live-face rectangle is **`(62,44,212,212)` relative to the whole bar**, or
**`(142,764,212,212)` on screen**. Keep the eyes, mouth and moving chin inside it.
A larger viewport may fill the opening if clipped/masked to that curved aperture.
Render the portrait backing separately; no face or backing is baked into the frame.

The confirmed safe sample has alpha 0–1 and 99.972332% exactly zero. The full measured
hole has mean alpha 0.15438761145/255, with 93.733771% exactly zero. A broad parchment sample has
alpha 252–254, median 253; its center is RGBA `(245,225,192,253)`. These are native
source measurements, not a claim of perfectly binary alpha. Details are in
`source_validation.json`.

## Label, text and controls inside the parchment

The usable parchment height is approximately y752–988. The ribbon now sits below
the upper rail, including its tails. Keep the fonts and existing control assets;
the smaller content height is handled by scrolling.

| Element | Screen rectangle |
| --- | --- |
| Name/state ribbon | `(418,756,420,40)` |
| Name text safe area | `(461,756,342,40)` |
| Speech/response scroll region | `(418,800,1382,156)` |
| Content, reserving scrollbar space | `(418,800,1350,156)` |
| Scrollbar region | `(1784,800,16,156)` |
| Up arrow / track / down arrow | `(1784,802,16,12)` / `(1784,824,16,108)` / `(1784,942,16,12)` |
| Footer | `(418,960,1382,28)` |
| Continue chevron | `(1782,962,18,24)` |

Move the right controls 16px inward from the previous contract to clear the thicker
right cap. Keep at least 24×24px hit targets around scroll buttons; those hit areas
must not activate dialogue. The ribbon may widen up to 1382px while remaining inside
the parchment.

| Role | Supplied font | Size / line advance |
| --- | --- | --- |
| Name/state | Grenze SemiBold | 36/40px |
| Speech | Source Sans 3 Regular | 32/40px |
| Response | Source Sans 3 Semibold | 30/36px |
| Footer | Source Sans 3 Regular | 24/28px |

The 156px content viewport holds **three complete speech lines**, or three 44px
single-line response rows plus two 4px gaps (140px). Wrapped choices grow their own
rows; fewer complete rows are then visible. Additional content scrolls. Keep text
readable rather than shrinking it to reproduce the old four-row preview.

## Behavior and remaining engine changes

Speech shows the current speaker. Responses replace the passage with choices and
show the responding player portrait. The portrait, label and footer stay fixed;
only the passage/list scrolls. Start each new passage at the top. During typewriter
reveal, follow the newest line only while the reader is at the bottom; preserve
manual scroll-back. Names, dialogue, numbers and hints remain live text.

**Wheel, scrollbar dragging and navigation must never advance dialogue.** Use
explicit Continue/confirm actions, consume scrolling events, and provide visible
keyboard focus as well as numbered choice shortcuts. First Continue may finish
reveal; the next advances. Keep decorative/full-screen controls mouse-ignoring.

The audited `ui/caption.gd` uses content-driven height, `fit_content = true`,
`scroll_active = false`, and accepts any key/mouse-button press for advancement.
It needs bounded scrolling and explicit activation. `ui/choices.gd` currently
builds an unbounded list with `FOCUS_NONE`; add focus/navigation and scrolling.
`ui/portrait.gd` must use the new aperture instead of its old generic frame/inset.
`dialogue/dialogue.gd` dismisses the portrait before choices; retain the appropriate
portrait for the approved response state. Animation/lighting remain with their
existing owner.

**Mockup copy is not new screenplay or canon.** Do not change story flags or add
responses to reproduce a concept image. Test overflow with temporary fixtures.
Verify the integrated frame, masking, long text and input in Godot before marking
this handoff complete.
