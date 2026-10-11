# Offline authoring tools

These commands target one owned asset with an explicit output. Game startup never
imports them. Scene packing flags and batch scene/prefab builders are removed.

- `retexture_model.py model.glb image.jpg --out output.glb`: replace one embedded
  texture; `--extract output.jpg` reads the current texture without changing the model.
- `crop_views.py sheet.png --out owned/views`: crop source-reference views.
- `trim_dialogue_frame.py --out output.png`: derive the documented UI bar region.
- `repair_rig.py model.glb --check`: read-only rig report; supplying an output path
  explicitly writes the repaired model.
- `inspect_clips.py`: inspect exported animation clips without authoring a scene.
- Blender converters (`from_mixamo`, `roundtrip`, `roundtrip_prop`, `strip_rig`,
  `unrig`, `extract_shells`, `merge_animations`, `add_hand_poses`) require source and
  destination arguments. Follow `docs/RIGGING.md` for new modular parts and the
  legacy full-character guide in `docs/PIPELINE.md` for existing imports.
- `make_loop.py source.wav --out output.wav`: cut a lossless audio loop; encode its
  final OGG with `encode_ogg.py` through Blender as described in `docs/AUDIO.md`.

Keep source models and import settings versioned. Do not delete local art or caches
to conceal validation failures. Diagnostic output belongs in a unique run directory.
The outfit workshop's explicit per-character scene export is documented in
`actors/outfit/README.md`; it does not run when opening the game.
