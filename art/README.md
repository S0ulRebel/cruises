# art/

Produced by the art agent, consumed by the engine. The contract is
[`docs/ART_SPEC.md`](../docs/ART_SPEC.md) — read it before adding anything here.

```
characters/<name>/sheet.png      full-resolution design sheet
characters/<name>/views/*.png    the four Tripo inputs
characters/<name>/palette.json   swatches, and what model produced the asset
rooms/<name>/background.png      1920x1080
rooms/<name>/foreground_*.png    1920x1080 with alpha, things walked behind
rooms/<name>/blockout.png        the 3D blockout the painting was made over
```

Folders are already in place for the designed cast. Empty means not delivered yet.
