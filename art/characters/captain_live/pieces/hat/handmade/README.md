# Handmade tricorn with original feather

The owner selected the new hat and requested reusing only the feather from the
previous Tripo hat. The preferred combination is `hat_with_original_feather.glb`.
It contains two separately selectable meshes. `hat.glb` and
`feather_original.glb` are the individual reusable parts in the same coordinate
system; instance both at identity under one parent to assemble them.

Editable source: `source/captain_hat_original_feather.blend`. The source folder
has `.gdignore` so Godot does not need Blender installed to import the GLBs.

The offline Blender authoring commands are:

```
blender -b --factory-startup --python tools/build_captain_hat.py -- --out art/characters/captain_live/pieces/hat/handmade
blender -b --factory-startup --python tools/reuse_captain_feather.py -- --source art/characters/captain_live/pieces/hat/hat.glb --hat art/characters/captain_live/pieces/hat/handmade/hat.glb --out art/characters/captain_live/pieces/hat/handmade
```

Optional `--preview <image.png>` on the second command renders with Cycles CPU
only. The first command still uses Eevee for its original previews; do not run
that command on the owner's machine while GPU use is prohibited. Reusing the
existing `hat.glb` requires only the second command.

The hat is authored with a hollow crown, a folded brim and ochre piping. Its
1024px albedo is emission-baked colour only; no light or AO was baked. The reused
feather retains the previous model's original 2048px texture, including any
preexisting colour/shading. No new lighting is baked into either texture by
the extraction command.

The previous hat and plume were fused in one mesh, so extraction selects the
scarlet faces and discards isolated hat-edge fragments. UVs/materials and source
shape are retained; a uniform scale and translation fit it to the new hat.
`feather_original.json` records the source checksum, exact extraction criteria,
triangle count, bounds and fitting transform. The source hat is unchanged.

Godot inspection scene: `res://ui/portraits/captain_live_handmade_hat.tscn`.
Its `HeadAttachment/Hat` has separate `Model` and `Feather` children, and follows
the existing Head bone. This is a separate candidate portrait; the live character
definition still uses `captain_live.tscn`. The head, hair and facial animation
were not rebuilt. Final fitting to the body and game-camera acceptance remain
for engine inspection. No game or GPU was started for the feather reuse pass.

The rejected handmade-feather trial remains local for comparison. The delivered
models and editable source use the selected original Tripo feather.
