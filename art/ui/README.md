# Captain’s Ledger UI art

The owner selected the parchment, walnut and brass response-panel direction on
11 October 2026, then requested matching portrait and dialogue-frame heights.
This package supplies the artwork, actual font files and exact layout contract.
Engine integration is still pending.

## Start here

Use `dialogue.json` for regions, patch margins, colours and positions. At the
1920×1080 logical resolution the portrait is `(80,720,300,300)` and the text frame
is `(394,720,1446,300)`. Both start at y720 and end at y1020, with a 14px gap.
The name ribbon stays inside those bounds. Speech and responses scroll inside
the text frame; longer content never increases either frame’s height.

## Delivered artwork

| File | Purpose |
| --- | --- |
| `dialogue_frame.png` | Empty parchment field with walnut rails and fixed brass corners. |
| `portrait_frame.png` | Empty walnut/brass surround with a genuinely transparent opening. |
| `speaker_ribbon.png` | Blank red ribbon for a live name or response-state label. |
| `response_highlight.png` | Blank red/gold selection background for single or wrapped rows. |
| `controls_atlas.png` | Separate up/down arrows, right chevron, scroll thumb, track and empty number medallion. |

These are unchanged high-resolution RGBA source PNGs. Their full canvases have
different transparent margins. **Use the measured `atlas_region_px` values** in
the manifest so those margins cannot create unequal visible heights. Each
control sprite has its own source rectangle; the atlas is never drawn as a whole.

For each stretchable image, the manifest separates source patch margins from
their intended displayed size. One Godot route is a fixed-size plain `Control`
host with a visual `NinePatchRect` child: set its `region_rect`, source-pixel patch
margins, uniform `texture_scale`, and local size to target size divided by that
scale. Keep text and input controls in the unscaled host. The portrait does not
draw the centre patch. Stretch the quiet rails/fields; preserve corner proportions.
Do not put the scaled visual child directly under a `Container`, which can reset
its scale. The [NinePatchRect](https://docs.godotengine.org/en/stable/classes/class_ninepatchrect.html)
and [Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control-property-scale)
documentation describe these properties. This route has not been run in Godot
in the art session.

## Typography and live content

The supplied production type is Grenze SemiBold for names at 36px, Source Sans 3
Regular for speech at 32px, and Source Sans 3 Semibold for choices at 30px. Original
font licences and pinned download provenance are under `fonts/`. Use Source Sans 3
Semibold for speaker-name glyphs missing from Grenze, including Cyrillic and Greek.
The mockup lettering is illustrative; it did not embed these font files.

Names, dialogue, response numbers, hints and the animated portrait remain live.
No such content is baked into the five production PNGs. A muted red backing can
sit behind the portrait as a separate engine element. The manifest and
`ENGINE_INTEGRATION.md` specify the measured aperture and safe face area.

## Integration and review

`ENGINE_INTEGRATION.md` records the remaining scrolling, focus, input and portrait
state work. Scroll-wheel input must be consumed by the UI instead of advancing
dialogue. Only actual story options should be shown; example mockup responses
are layout demonstrations and must not be added to the screenplay.

`source_validation.json` records alpha/geometry checks; `generation.json` records
the built-in image-generation prompts. All five source PNGs were checked as RGBA,
with transparent exterior pixels and a transparent portrait centre. Font files
were checked for family, weight, static format and accented-character coverage.
Runtime rendering, input handling and localisation wrapping remain engine checks.

The images under `reference/` are concept art, not runtime UI textures. The room
is an approved composition/colour guide: pirate cabin, no modern utility fixtures,
Count Fingers in the near foreground. The carpet pattern needs simplification.
It is **not** a camera-matched production backdrop, and foreground props remain
separate scene objects. `layout_concept.png` illustrates the equal-height revision;
the exact geometry is in the manifest.
