# Captain’s Ledger — engine integration

11 October 2026. The owner selected **variation 3: rope-edged walnut**. Final blank
source art is delivered; engine integration and Godot runtime verification remain
pending. The UI source audit was performed at
`6a93595a15d50cb5f2b4f94cb035acdf52f1c50b`.

## Frame and layer order

All rectangles are `(x,y,width,height)` on the 1920×1080 logical canvas unless
marked native source. Right and bottom are exclusive. The whole bar is
**`(80,720,1760,300)`**.

`dialogue_frame.png` is the unchanged 2172×724 RGBA production master. Its atlas
region is `(39,176,2094,387)`. Draw these three adjacent regions of the same texture:

| Section | Native source rectangle | Screen rectangle |
| --- | --- | --- |
| Left cap | `(39,176,129,387)` | `(80,720,100,300)` |
| Middle span | `(168,176,1836,387)` | `(180,720,1560,300)` |
| Right cap | `(2004,176,129,387)` | `(1740,720,100,300)` |

Both caps use uniform scale **100/129**. The middle uses the same vertical scale
and horizontal scale 1560/1836. This preserves the outer fittings while applying
modest horizontal extension to the long rails. Sections meet at x180 and x1740;
no tiling algorithm is required. At other widths, keep both 100px caps fixed and
resize the middle. Scale the logical canvas uniformly for other display sizes.

Use one fixed, unscaled host for layout and hit targets. Draw the shared frame and
parchment first, then the transparent live portrait, then ribbon/highlight/control
sprites and live text/focus. The portrait rectangle is **`(144,756,224,224)`**.
Render the head over the paper without a backing colour, separate frame or aperture
mask. Clip only the portrait viewport and scrolling content to their own bounds.
Keep `integrated_frame.png` and `portrait_frame.png` unused.

The paper has no transparent portrait hole; its sampled alpha is 252–254, median
253. Preserve source alpha. Exact measurements and hashes are in
`source_validation.json` and `dialogue.json`.

## Title, content and controls

The title is raised onto the top rail. Content and footer stay within the measured
paper inset, approximately y753.33–984.34 in the middle of the panel.

| Element | Screen rectangle |
| --- | --- |
| Name/state ribbon | `(418,720,420,40)` |
| Name text safe area | `(461,720,342,40)` |
| Speech/response scroll region | `(418,764,1382,188)` |
| Content, reserving scrollbar space | `(418,764,1350,188)` |
| Scrollbar region | `(1784,764,16,188)` |
| Up arrow / track / down arrow | `(1784,766,16,12)` / `(1784,788,16,140)` / `(1784,938,16,12)` |
| Footer | `(418,956,1382,28)` |
| Continue chevron | `(1782,958,18,24)` |

Keep at least 24×24px hit targets around scroll buttons. Those hit areas must not
advance dialogue. The ribbon may widen up to 1382px for longer names/localisation.

| Role | Supplied font | Size / line advance |
| --- | --- | --- |
| Name/state | Grenze SemiBold | 26px / 39px font height |
| Speech | Source Sans 3 Regular | 32/40px |
| Response | Source Sans 3 Semibold | 30px / 40px font height |
| Footer | Source Sans 3 Regular | 24/28px |

Runtime correction, 11 October 2026: center the name horizontally and vertically
inside its 40px safe area. Grenze at size 36 actually needs 54px in Godot; size 26
fits. Response rows use the label's measured minimum height plus 4px padding,
with a 44px minimum. Highlight the hovered row without an extra left chevron;
start keyboard focus on the first navigation key, rather than when opening choices.

The 188px viewport holds **four complete speech lines**, or exactly four 44px
single-line response rows plus three 4px gaps. Wrapped choices grow their rows;
fewer complete rows are then visible. Additional content scrolls. A minimum height
alone is insufficient: prevent content from making the 300px bar taller.

## Behavior and remaining engine changes

Speech shows the current speaker; responses show the responding player portrait.
The portrait, label and footer stay fixed while only the passage/list scrolls.
Start each new passage at the top. During typewriter reveal, follow the newest
line only while the reader is at the bottom; preserve manual scroll-back. Names,
dialogue, numbers and hints remain live text.

**Wheel, scrollbar dragging and navigation must never advance dialogue.** Consume
scrolling events and use explicit Continue/confirm actions. Provide visible
keyboard focus and numbered choice shortcuts. First Continue may finish reveal;
the next advances. Decorative/full-screen controls remain mouse-ignoring.

The audited `ui/caption.gd` uses content-driven height, `fit_content = true`,
`scroll_active = false`, and any key/mouse-button press for advancement. It needs
bounded scrolling and explicit activation. `ui/choices.gd` builds an unbounded list
with `FOCUS_NONE`; add focus/navigation and scrolling. `ui/portrait.gd` should render
its transparent live head over the shared paper without its old frame/backing.
`dialogue/dialogue.gd` dismisses the portrait before choices; retain the appropriate
portrait for the selected response state. Animation remains with its existing owner.

**Mockup copy is not new screenplay or canon.** Do not change story flags or add
responses to reproduce the preview. Verify the frame joins, live portrait, overflow
and input in Godot before marking this handoff complete.
