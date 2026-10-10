# Props and scenery for Scene 1 — Captain Livé's quarters

A brief for the art agent. Same contract as `ART_SPEC.md`: every rule here has a reason,
and the measurements are the ones the engine actually uses.

The room exists and runs. What it has now is **four grey boxes** standing in for a desk,
a chair, a crate and a porthole, plus one real prop (the fishbowl, built from primitives
in code). This brief replaces the boxes with art.

---

## What the room is

A fixed-camera 3D room with a painted backdrop, Grim Fandango's architecture. The camera
never moves within a scene, so the painting and the geometry only have to agree from one
angle.

| | metres |
| --- | --- |
| back wall width | 12.0 |
| depth | 7.0 |
| wall height | 3.2 |
| character height | 1.90 (Livé), 1.70 (Santi) |

Render target 1920x1080. A character stands **250-390 px** tall on screen. That number
decides everything below: a prop the size of a tankard is about 25 px, so detail finer
than roughly 3 cm is invisible and costs only file size.

---

## What to make

### Props — modelled, as turnaround sheets

Each becomes a Tripo model, so each needs its own sheet following `ART_SPEC.md` section
1: four views, shared ground line, clear space between figures, plain flat background.

These are **objects, not characters** — no A-pose or T-pose rules apply, and they do not
get rigged. But the four-view discipline still does, because Tripo reads the four views
as one object seen from four angles.

| prop | size (m, W x H x D) | notes |
| --- | --- | --- |
| captain's desk | 1.8 x 0.76 x 0.9 | charts, compass, dried inkwell. The fishbowl stands on it, so leave a clear flat area ~0.3 m across on the left half |
| captain's chair | 0.5 x 1.0 x 0.5 | high-backed, worn leather, one arm repaired badly |
| sea chest / crate | 0.9 x 0.9 x 0.9 | stencilled LE CHAOS NAVIGUE TOUJOURS PLUS LOIN, nailed shut |
| porthole | 0.9 x 0.9 x 0.08 | brass ring, thick glass, fog behind it. Mounted in the back wall at y 1.55 |
| hanging lantern | 0.25 x 0.40 x 0.25 | the room's warm key light comes from here, so model it as the source |
| rolled charts | 0.6 x 0.08 x 0.08 | a loose bundle, for the desk |
| wine bottle + pewter cup | 0.08 x 0.30 x 0.08 | Livé drinks |

Order matters: desk, chair, crate, porthole first — those four are the grey boxes.

### Scenery — painted, not modelled

The **backdrop** is a single painted image on a quad behind everything. One per scene.

- **1920 x 1080**, painted to the camera described above.
- It must agree with the floor: the horizon and wall base sit where the geometry's do.
  Use `art/rooms/blockout_scene1.png` (rendered from the live camera — ask and I will
  regenerate it) as the underlay and paint over it.
- Everything a character can walk in front of belongs in the backdrop. Anything a
  character can walk **behind** has to be a prop, not paint.
- Lighting: warm lantern from the left, cold fog-light through the porthole behind.
  The 3D props are lit by the engine, so the painting has to match that, not fight it.

---

## Style

Cartoony throughout. Monkey Island, Discworld, goblins — never realism. The characters
are stylised and the room has to sit with them: chunky silhouettes, exaggerated
proportions, visible wear, saturated but dirty colour.

Ship's quarters on a cruise liner that pirates have taken over, so the room is a modern
cruise cabin with 18th-century piracy grafted onto it. That contrast is the joke and it
should be visible in the props: a brass porthole next to a cabin light switch, a sea
chest on fitted carpet.

---

## Deliverables

```
art/props/<id>/sheet.png          four-view turnaround, as ART_SPEC.md section 1
art/props/<id>/asset.json         same shape as the character asset.json files
art/rooms/scene1_backdrop.png     1920x1080
```

Send props one at a time rather than as a batch — the first one through the pipeline
will teach us something that changes the rest, and that is cheaper to learn once.

---

## Things that have already cost a day, so they are rules

1. **Four views, clear space between them.** Figures that touch cannot be cut apart;
   `tools/crop_views.py` separates by empty columns. Santi's sheet overlapped by 25 px
   and had to be redone.
2. **Flat, plain background.** The cutter finds the background from the corner pixel.
3. **Same scale and ground line in all four views.**
4. **No text, labels or callouts inside the turnaround band.** They get cut out with the
   figure and generated into the model.
5. For props with a hollow or a hole (the porthole ring, a mug handle), make sure the
   hole is visible as background in at least two views, or Tripo fills it solid.
