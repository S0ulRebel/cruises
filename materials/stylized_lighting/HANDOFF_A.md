# Fake lighting variants 01–08

Authoring completed 2026-10-11 in the isolated `lighting-variants-a` worktree.
Scope is the eight variant folders listed below. Existing models, materials,
locations, startup and scripts are unchanged.

Each folder contains an opaque, unshaded ShaderMaterial ending `_shader.tres`
that references its readable `_shader.gdshader`, and an equivalent ShaderMaterial
ending `_graph.tres` that references a real VisualShader `_graph_shader.tres`.
The graphs use connected built-in math, sampling and parameter nodes. No Expression
nodes, custom-code graph nodes or runtime authoring scripts are required.
Materials are local to scene instances; shader resources remain reusable.

## Common controls

- `albedo_texture`: source-color Texture2D sampled using the mesh's existing UV.
- `base_tint`: white; multiplies the source texture before fake lighting.
- `shadow_color`: `(0.30, 0.36, 0.52)`.
- `light_color`: `(1.0, 0.91, 0.74)`.
- `light_direction`: `(-0.4, 0.8, 0.5)` in world space, pointing toward the light.
- `light_position`: `(-3, 4, 3)` in world space.
- `point_weight`: `0`; blend directional light with positional light, up to `1`.
- `light_strength`: `1`, range `0`–`3`.
- `effect_strength`: `1`, range `0`–`1`; `0` returns the texture and base tint.

Fragment position and normal are transformed from view space using
`INV_VIEW_MATRIX`. Authored mesh transforms therefore remain meaningful when the
object or camera moves. No actual Godot light, shadow map, material alpha or geometry
change is involved. These variants color surfaces according to their orientation;
they do not determine whether a different object blocks the fake light.

## Variants and exact extra controls

- **01 Soft Lambert:** `diffuse_curve = 0.65`, range `0.1`–`4`.
  Response is `pow(clamp(N·L, 0, 1), diffuse_curve)`; lower values spread the bright
  part without illuminating the back-facing side. Graph has 35 nodes including output.
- **02 Half Lambert:** `half_curve = 2`, range `0.1`–`4`.
  Response is `pow(clamp(0.5 * N·L + 0.5, 0, 1), half_curve)`. The back-facing side
  remains readable. Graph has 39 nodes including output.
- **03 Two Tone:** `band_threshold = 0.15`, range `-1`–`1`.
  A step divides shadow and light into two hard bands. Graph has 34 nodes including output.
- **04 Three Tone:** `lower_threshold = -0.15`, `upper_threshold = 0.45`, both
  range `-1`–`1`; `midtone_color = (0.64, 0.69, 0.75)`.
  Two automatically ordered steps select shadow, an independent middle tint and the
  light tint. Graph has 40 nodes including output.
- **05 Soft Toon:** `band_threshold = 0.10`, range `-1`–`1`;
  `band_softness = 0.14`, range `0.001`–`0.75`.
  Smoothstep joins two broad tones around an adjustable boundary. Graph has 39 nodes
  including output.
- **06 Texture Ramp:** `ramp_bias = 0`, range `-0.9`–`0.9`; `shading_ramp` is an
  editable 256-pixel grayscale GradientTexture1D embedded in each material.
  The red channel maps remapped `N·L` to the shadow/light blend; edit gradient stop
  positions and grayscale values to draw the response. Sampling clamps at the ends
  with linear filtering. Graph has 45 nodes including output.
- **07 Hemisphere:** `ground_tint = (0.68, 0.52, 0.42)`;
  `sky_tint = (0.80, 0.92, 1.0)`; `ambient_mix = 0.55`, range `0`–`1`.
  World-normal height blends ground and sky fill, while `ambient_mix` combines that
  fill with the common directional/positional key tint. Graph has 44 nodes including output.
- **08 Wrap Diffuse:** `wrap_amount = 0.5`, range `0`–`1`.
  Response is `clamp((N·L + wrap_amount) / (1 + wrap_amount), 0, 1)` and spreads the
  key light around curved silhouettes. Graph has 38 nodes including output.

## Validation

- Inspected Godot 4.7.2's local ClassDB and generated VisualShader code to verify
  input names, ports, source-color sampling, transform modes and parameter defaults.
- Compiled and rendered every code and graph material using the actual NVIDIA
  OpenGL Compatibility renderer. Eight pairs across four configurations yielded
  **32 successful image comparisons with zero differing pixels** at 256 × 256.
  Configurations covered texture-only, directional, positional and blended light,
  modified direction, strength and effect amount. Center pixels were checked to be
  nonblack and changed across configurations, avoiding a vacuous comparison.
- Removed disconnected helper nodes before final saving; every shipped math/input
  node belongs to the output's input ancestry. Graphs contain zero Expression nodes.
- Clean Godot editor import creates and versions all eight `.gdshader.uid` files.
  Temporary authoring and render-check scripts live outside the repository and are
  excluded from shipping. Generation requires explicit output paths and is never
  part of startup or tests.

Official references: [spatial shader inputs and unshaded rendering](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html),
[VisualShader resource API](https://docs.godotengine.org/en/stable/classes/class_visualshader.html),
[built-in vector operation nodes](https://docs.godotengine.org/en/stable/classes/class_visualshadernodevectorop.html),
and [Texture2D graph parameters](https://docs.godotengine.org/en/stable/classes/class_visualshadernodetexture2dparameter.html).
