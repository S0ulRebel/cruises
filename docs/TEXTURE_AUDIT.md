# Texture resolution audit

2026-10-11. Read-only inspection of tracked source assets, current Game dependencies,
embedded model images, existing untracked art and Godot texture import/cache settings.
No model, image or import setting was changed by this audit. Full asset inventory is
in [texture_resolution_2026_10_11.json](audits/texture_resolution_2026_10_11.json).

## Findings

- All 33 GLBs contain one embedded material-used image each: **9 at 8192×8192,
  6 at 4096×4096 and 18 at 2048×2048**. Identical embedded bytes reduce this to
  26 distinct maps: 4 at 8K, 4 at 4K and 18 at 2K.
- The current Game dependency tree uses 18 of those model maps: **4 at 8K,
  1 at 4K and 13 at 2K**. The 8K models are the current Captain, Santi, Count
  Fingers and chair. Portrait head_face is 4K. Other referenced props and portrait
  accessories are 2K.
- Delivered modular body/body.glb is 4K; coat/coat.glb is 2K. These are source
  candidates and do not replace the current 8K world Captain.
- All 15 binary FBXs were inspected. Two character Mixamo donors embed 512×512
  images, matching the documented upload workflow; 13 animation files have no
  image/texture records. No formats or images remain uninspected.
- Standalone inspection covered 145 tracked art rasters and three documentation
  images, plus 108 untracked art rasters: 28 extracted/source JPGs, 76 cropped
  views and four facial diagnostics. Twenty-six JPGs duplicate GLB images exactly;
  two are alternate 2K bowl-stand/chair exports. Caches, build/test output and
  1,265 root recording/scratch images were excluded from asset totals.
  The final count includes 11 Santi source sheets added by remote commit f8e9391:
  nine at 2172×724, face at 1882×836 and head at 1881×836. They add reference art,
  with no change to model texture counts or the current Game dependency tree.
- Referenced UI images use their authored atlas dimensions: controls 1536×1024;
  dialogue frame, ribbon and response highlight 2172×724 each. Reference artwork,
  UI and vector fonts have independent dimensions and purposes.
- All inspected texture imports set size_limit to 0; no platform override or
  global downscale was found. All 242 existing art texture-cache headers preserve
  source dimensions, including copies corresponding to every embedded GLB image.
  All 18 active model maps have mipmaps; 14 use VRAM compression and four lossless
  compression. Compression and mipmaps do not increase source resolution.

## Policy to resolve

[PIPELINE.md](PIPELINE.md) requires 8K keeper maps. [ART_SPEC.md](ART_SPEC.md)
also recommends runtime character maps no larger than 2048×2048. These require
separate source-master and runtime-budget decisions. No separate 8K master was
found for any of the 24 lower-resolution GLBs in this checkout. Recover or export
the original high-resolution maps if that keeper requirement remains; resizing a
lower-resolution image alone does not recover missing detail. UI/reference files
should retain dimensions appropriate to their authored layout.

Import semantics were checked against [Godot image import documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html)
and cache-header interpretation against [Godot's compressed texture loader](https://raw.githubusercontent.com/godotengine/godot/master/scene/resources/compressed_texture.cpp).
