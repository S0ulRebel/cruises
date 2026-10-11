# Captain’s Ledger UI art

The current UI uses **one continuous walnut/brass frame with one shared divider**.
The owner requested this correction because the earlier independent portrait and
speech frames had mismatched joins. The current correction removes both rejected internal metal connectors: a straight
wood divider meets both rails in clean T-junctions. Brass remains only at the four
outer corners. Engine integration is still pending.

## Start here

`dialogue.json` is the current layout and asset contract. At the 1920×1080 logical
resolution, the whole bar is `(80,720,1760,300)`: top 720, bottom 1020. Render three
adjacent regions of **the same `integrated_frame.png`**, with destination widths
375, 1235 and 150px. Scale the left assembly and right cap uniformly by 75/97; stretch
only the middle region horizontally. Source and destination rectangles are explicit
in the manifest. This preserves the plain wooden divider and outer brass corners.

There is no gap or second frame underneath the shared divider. The old
`dialogue_frame.png` and `portrait_frame.png` remain in the repository as **legacy,
unused sources**; their old rendering geometry has been removed from the active
contract.

The label ribbon now sits wholly inside the parchment at y756–796. Speech and
responses use a bounded 156px-high viewport at y800–956; the footer occupies
960–988. At the default sizes, three complete speech lines or three single-line
responses fit. More content scrolls instead of enlarging the 300px bar.

## Active artwork

| File | Purpose |
| --- | --- |
| `integrated_frame.png` | Continuous rails, one shared divider, transparent portrait aperture and parchment field. |
| `speaker_ribbon.png` | Blank red ribbon for a dynamic name or response-state label. |
| `response_highlight.png` | Blank red/gold selection background for single or wrapped rows. |
| `controls_atlas.png` | Up/down arrows, right chevron, thumb, track and blank number medallion. |

These are unchanged native RGBA PNGs. Use the measured source regions, not the full
canvases or independently cropped/resampled copies. The ribbon, highlight and
controls retain their own stretch or atlas metadata. Keep all live text and hit
targets separate from the visual source layers.

## Portrait and typography

The live portrait belongs behind the master’s transparent opening. Its safe face
rectangle is **`(142,764,212,212)`** on screen. A larger viewport may fill the curved
opening when masked/clipped to it; keep the eyes, mouth and moving chin in that
safe area. A muted red backing remains a separate engine element.

The supplied fonts remain Grenze SemiBold 36px for names, Source Sans 3 Regular 32px
for speech, Source Sans 3 Semibold 30px for choices, and Regular 24px for the footer.
Original licences, pinned provenance and fallback information are under `fonts/`
and in the manifest. Names, dialogue, numbers, hints and portraits remain dynamic.
Mockup lettering and responses are illustrative, not new screenplay or canon.

## Verification and integration

`source_validation.json` records the native-image and alpha checks;
`generation.json` records provenance. The master’s safe portrait sample contains
only alpha 0–1, with 99.972332% exactly zero. Parchment is almost opaque, median alpha 253.
The source PNG is not flattened or repainted to change those values.

`ENGINE_INTEGRATION.md` gives the current mapping and remaining engine work. Verify
slice joins, scrolling, keyboard focus, long text and portrait states in Godot.
Scroll-wheel/navigation input must not advance dialogue. No engine code, animation
or screenplay was changed by this art correction.

`reference/layout_concept.png` illustrates the unified frame and internal label;
the manifest supplies exact runtime dimensions. Reference room images remain
composition guides, not camera-matched production backdrops. The earlier caveat
about simplifying the carpet markings still applies.
