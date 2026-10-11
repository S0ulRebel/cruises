# Captain's Ledger — engine integration

Art handoff, 11 October 2026. This specifies the approved layout and proposed
interaction behavior; it does not implement engine or animation changes. UI sources
were inspected at `6a93595a15d50cb5f2b4f94cb035acdf52f1c50b`.

## Exact outer alignment

Use the project's **1920 × 1080 logical canvas**. Coordinates below are
`(x, y, width, height)`; right and bottom are exclusive bounds.

| Element | Rectangle | Right / bottom |
| --- | --- | --- |
| Portrait outer frame | `(80, 720, 300, 300)` | `380 / 1020` |
| Empty gap | `(380, 720, 14, 300)` | `394 / 1020` |
| Dialogue / response outer frame | `(394, 720, 1446, 300)` | `1840 / 1020` |

**Both visible frames are exactly 300 px high, with the same top and bottom.**
Keep ribbons, tabs, corner flourishes and shadows within those outer rectangles.
Transparent padding must not disguise unequal visible frame heights. Retain the
80 px side margins and 60 px bottom margin. Longer content scrolls; it never makes
one frame taller. Setting only a 300 px minimum height is insufficient if a child
can still enlarge its `PanelContainer`.

## Interior layout

| Element | Suggested screen rectangle |
| --- | --- |
| Name / state label ribbon, inside the text frame | `(418, 732, 1398, 44)` |
| Speech or response scroll region | `(418, 784, 1398, 188)` |
| Text / choice content, reserving scrollbar space | `(418, 784, 1366, 188)` |
| Visible scrollbar track | `(1800, 784, 16, 188)` |
| Continue / navigation hint footer | `(418, 978, 1398, 28)` |

The name ribbon's rectangle is its safe layout area; its ornament may occupy less
width. Keep it inside the frame rather than perched above the top edge.

Use the bundled fonts at these logical canvas sizes:

| Role | Font | Size / line advance |
| --- | --- | --- |
| Speaker / state label | `fonts/grenze/Grenze-SemiBold.ttf` | `36 / 44 px` |
| Speech | `fonts/source_sans_3/SourceSans3-Regular.ttf` | `32 / 40 px` |
| Response | `fonts/source_sans_3/SourceSans3-Semibold.ttf` | `30 / 36 px` |
| Footer | `fonts/source_sans_3/SourceSans3-Regular.ttf` | `24 / 28 px` |

The scroll region holds four complete speech lines at this spacing. Start with
four 44 px response rows and 4 px gaps (`4 × 44 + 3 × 4 = 188`). Wrapped responses
grow their own rows and reduce the number visible; the outer panel stays fixed.
Larger text settings also use scrolling rather than shrinking the type.

## Production frame mapping and portrait aperture

Keep the native RGBA PNGs unchanged and select these atlas regions. Source margins
are measured relative to the atlas region, not the full PNG. Source and destination
margins are distinct units; the mapping must preserve both rather than interpreting
them as a single margin setting. All four corners scale uniformly within each frame.

| Frame | Native PNG size | Atlas `(x, y, w, h)` | Source margins, all sides | Destination margins, all sides |
| --- | --- | --- | --- | --- |
| Portrait | `1254 × 1254` | `(37, 65, 1180, 1116)` | `300 px` | `72 px` |
| Dialogue | `2172 × 724` | `(28, 99, 2116, 523)` | `160 px` | `48 px` |

These atlas bounds enclose every source pixel with alpha greater than 16. They omit
only faint outer fringe pixels from the rendered region; those pixels remain in
the untouched source files. Render the atlas regions into the exact outer boxes
above using the stated nine-patch mapping, preserving the brass corners.

The portrait's main enclosed opening, measured at alpha at most 16, has native
source bounds `(177, 195, 898, 847)`. After the portrait nine-patch mapping, its
bounding rectangle is approximately `(33.60, 31.20, 232.32, 235.44)` relative to
the 300 × 300 frame. **Its corners are curved: this bounding rectangle is not a
fully clear rectangle.**

Use a safe live-portrait rectangle of **`(44, 44, 212, 212)` within the frame**, or
**`(124, 764, 212, 212)` on screen**. It is centered, preserves a square viewport,
and keeps the eyes, mouth and moving chin clear of the brass-corner clipping.
A larger viewport may occupy the opening's bounding rectangle only if the frame
or a matching alpha mask clips its corners. Do not reuse the old 6 px inset or the
earlier suggested 268 px aperture; neither fits this production frame. Keep any
portrait backing separate and fit the live head to this usable area. Do not bake a
character, name, dialogue or control hint into the UI bitmaps.

Alpha checks on the unmodified sources: all four canvas corners of both images
are `(0, 0, 0, 0)`. The portrait center is `(0, 0, 0, 0)`. Within the safe portrait
area, the sampled source pixels are 97.39% alpha 0 and 2.61% alpha 1; the opening is
visually clear but is not mathematically alpha 0 everywhere. The dialogue center
is RGBA `(248, 223, 183, 253)`; a broad parchment sample has alpha 251–254, median
253. It is almost opaque, not fully opaque. Neither image contains a baked portrait
or checkerboard background.

## Two content states, one geometry

Speech shows the speaking character, a dynamic name and one multiline passage.
Responses replace the passage with selectable numbered rows; preserve the same
portrait and text-frame bounds. The portrait can show the player making the
response, as in the approved preview. Keep the portrait/state decision separate
from the character animation implementation.

Both states use a real vertical scroll control when their content overflows.
Keep the label, portrait and footer stationary. Show a clear thumb and a visible
focus treatment; colour alone should not identify the selected response. Support
pointer scrolling, keyboard navigation and confirmation. Start each new passage
at its top. During reveal, follow the newest line only while the reader is at the
bottom; manual scrolling back must preserve their position.

**A scroll-wheel event must never advance dialogue.** Consume wheel, scrollbar
drag and navigation events in the UI. Keep Continue/confirm distinct from scrolling
and use deliberate activation actions rather than any key or mouse button. First
Continue may finish the reveal; a subsequent Continue advances. Noninteractive
ornament and full-screen containers should continue to ignore mouse input.

## Mapping to the current engine

- `ui/caption.gd` already supplies the 80/80/60 margins, 14 px gap, dynamic name and
  typewriter text. Replace its content-driven panel sizing with the bounded region:
  it currently has `fit_content = true`, `scroll_active = false`, and advances on
  any key or mouse-button press. That last condition also catches unhandled wheel
  events.
- `ui/portrait.gd` already uses a 300 × 300 outer control and a separate live head.
  Replace its generic frame and existing 6 px inset with the delivered frame's
  opening; keep portrait animation and lighting with their existing owner.
- `ui/choices.gd` currently builds an unbounded list and sets each response button
  to `FOCUS_NONE`. Add the bounded scrolling list, keyboard focus/navigation and
  visible focus treatment. Keep numbered shortcuts mapped to displayed choices.
- `dialogue/dialogue.gd` currently calls `hide_box()` before asking for responses,
  which also dismisses the portrait. The approved response layout needs its own
  visible portrait state while preserving the existing conversation flags.

**Mockup dialogue is layout copy, not new screenplay or canon.** Do not add options
or alter story flags to reproduce a preview. The existing Santi file has four
authored topics, but its `once` and recipe-unlock conditions mean they are not all
simultaneously available. Test overflow with temporary fixtures, not story edits.
