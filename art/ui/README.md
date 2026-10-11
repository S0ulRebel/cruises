# Captain’s Ledger UI art

## Selected design — rope-edged walnut

The owner selected **variation 3**, shown in
`reference/no_divider_variations/03_rope_edge.png` and the canonical
`reference/layout_concept.png`. The blank production frame is delivered;
**engine integration and runtime verification remain pending**.

The design uses one continuous parchment field inside a rope/walnut perimeter,
with brass at the four outer corners. The live portrait sits directly over the
shared paper. There is no internal divider, portrait aperture or separate backing.
The name/response ribbon sits on the upper rail.

## Layout and active artwork

`dialogue.json` is the exact asset and layout contract for the 1920×1080 logical
canvas. The whole bar is **`(80,720,1760,300)`**. Draw three adjacent regions of
one `dialogue_frame.png` into widths **100/1560/100px**. The outer caps retain their
proportions; only the middle stretches horizontally. Source regions and draw sizes
are explicit in the manifest and `ENGINE_INTEGRATION.md`.

| File | Purpose |
| --- | --- |
| `dialogue_frame.png` | Blank continuous parchment with rope/walnut perimeter and four brass corners. |
| `speaker_ribbon.png` | Blank red ribbon for a live speaker name or response label. |
| `response_highlight.png` | Blank selection background for single or wrapped rows. |
| `controls_atlas.png` | Scroll arrows, chevron, thumb, track and blank number medallion. |

These are native RGBA source PNGs. Use their atlas metadata; do not stretch their
full canvases into the runtime rectangles. `integrated_frame.png` and
`portrait_frame.png` are preserved **legacy, unused** sources.

The ribbon occupies y720–760, the bounded text viewport y764–952, and the footer
y956–984. The 188px viewport fits four complete speech lines or four single-line
response rows; longer or wrapped content scrolls without enlarging the 300px bar.
The transparent live portrait renders **over** the paper at `(144,756,224,224)`.
It has no additional background, frame or aperture mask.

## Live text and integration

Supplied fonts remain Grenze SemiBold 36px for names, Source Sans 3 Regular 32px
for speech, Source Sans 3 Semibold 30px for choices, and Regular 24px for the footer.
Licences, provenance and fallback information are in `fonts/` and the manifest.
Names, dialogue, numbers, hints and portraits remain dynamic. Mockup copy is
layout content, not new screenplay or canon.

`source_validation.json` records image checks; `generation.json` records provenance.
The frame exterior is transparent, the paper has no transparent portrait hole,
and the broad paper sample has median alpha 253/255.

Follow `ENGINE_INTEGRATION.md` for layer order, bounded scrolling and focus.
Scroll-wheel/navigation input must not advance dialogue. No engine code,
animation or screenplay was changed by this art delivery. Room reference images
remain composition guides, not final camera-matched backdrops; simplify the carpet
markings in final scenery.
