# Cabin stylized normal maps

The owner approved these sources for engine use on 2026-10-11. Each of
`floorboards`, `beam_wood` and `carpet_burgundy` now contains two actual
tangent-space normal maps: `normal_gentle_opengl.png` and
`normal_stronger_opengl.png`. All six are 1254 x 1254 RGB8 data textures.
`height_source.png` is the separate artistic grayscale relief source, not a
normal map or calibrated displacement map. The original albedo PNGs are unchanged.
Wall planks do not yet have a companion normal map.

## Engine setup

1. Start with **gentle**, with normal scale/depth 1.0. Stronger is an alternative
   file, not an extra layer to stack on top.
2. In `StandardMaterial3D`, enable Normal Map and assign the chosen normal texture;
   assign the existing `albedo.png` as the colour texture. Keep metallic 0 and
   matte roughness (about 0.9 wood, 1.0 carpet) as starting art settings.
3. These maps use **OpenGL +Y**. Leave **Normal Map Invert Y off**. Import as normal
   data, without sRGB conversion; the six versioned import sidecars enable normal
   import and mipmaps. UV repeat is a material/sampler setting, not an image setting.
4. Use the same UV transform for colour and normals, and a mesh with valid tangents.
   Preserve density: floorboards 2.4 x 2.4 m per tile, beam grain 1 x 1 m,
   carpet 0.8 x 0.8 m. Rotate both maps together to match grain orientation.
5. Custom toon/fake-light shaders need to sample the normal texture as linear
   normal data and use the resulting perturbed normal in their lighting calculation.
   Merely assigning a texture to a shader that ignores normals will not add relief.
   Keep this work with the relevant material/prefab owner; do not rebuild scenery.

[Godot's normal-map convention](https://docs.godotengine.org/en/4.6/tutorials/3d/standard_material_3d.html#normal-map)
specifies OpenGL +Y.

## Provenance and validation

Built-in image generation produced each simplified height source from its existing
colour tile after inspection of the cabin target and the stylized wood-board sheet.
Full prompts, source hashes and actual numerical settings are in each
`normal_trials.json`; the parent `asset.json` and kit index point to these files.

The maps were calculated from Gaussian-filtered height gradients, with periodic
sampling at the boundaries, normalized vectors and RGB8 encoding. For a height
image whose rows point down, the encoded vector is
`normalize(-strength * dH/dx, strength * dH/drow, 1)`.
Gaussian sigma is 3.5 px for boards, 4.0 px for beams, 4.5 px for carpet.
The stronger scale targets a 99th-percentile slope of 0.48 / 0.42 / 0.20 respectively;
slopes are capped at 0.85 before multiplying by 0.45 for gentle. Actual gradient
multipliers and quantization errors are recorded in the sidecars.

PNG decoding, dimensions, positive Z, near-unit decoded vectors and analytic ramp
checks for X/Y orientation passed. A scoped Godot 4.7.2 import/load and material
binding check is recorded in `normal_validation.json`. Preview PNGs under
`normal_previews/` show CPU matte Lambert lighting using decoded delivered maps;
they are excluded from Godot import with `.gdignore`.

## Engine acceptance still open

No scene material or shader was changed by this source delivery. Check the final
UVs, tangents, colour/relief registration, repeat seams, mipmaps and strength at the
game camera under actual toon lighting before adopting a variant. Generated
height patterns follow the colour features visually; exact registration and
perfect seam continuity are not guaranteed. Periodic numerical filtering does
not prove that the drawn motifs tile exactly. Broad grooves and soft carpet
motifs are intentional; these maps do not change silhouettes or mesh joints.
