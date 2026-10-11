# Lighting variants 09–16 handoff

Implemented 2026-10-11 in `codex/lighting-variants-b`. Scope is the eight
variant directories numbered 09 through 16. Gameplay scenes, source art,
project settings and startup code were not changed.

Each directory has a code material (`*_shader.tres`), its editable
`*_shader.gdshader` source and UID, a graph material (`*_graph.tres`), and an
editable VisualShader resource (`*_graph_shader.tres`). Materials reference
their source resources rather than embedding a second copy. The graph resources
use built-in nodes only, with no Expression, GlobalExpression or custom node
scripts. Disconnected helper branches have been removed.

## Contract

All variants are opaque, unshaded and texture based. The common parameters are
`albedo_texture`, `base_tint`, `shadow_color`, `light_color`, `light_direction`,
`light_position`, `point_weight`, `light_strength` and `effect_strength`.
`effect_strength = 0` returns the tinted original texture.

`light_direction` points toward the light. `light_position` and occluder/height
positions are in world units. Normals and positions are converted from view
space in the fragment stage; rotating and scaling a mesh changes the shading
without reauthoring a texture. The final directional/point blend divides by
`max(length(blended_light), 0.00001)` so opposing inputs have a defined result.
These materials do not use Light3D illumination or Godot shadow maps.

## Techniques and editable controls

- **09 Rim light:** normal/view Fresnel-like silhouette highlight, optionally
  restricted to light-facing surfaces. `rim_power = 3`, `rim_strength = 0.75`,
  `rim_directionality = 0.8`, `rim_color = (1, 0.84, 0.52)`.
- **10 Toon specular:** thresholded Blinn half-vector highlight added to the
  textured diffuse result. `specular_gloss = 24`, `specular_threshold = 0.35`,
  `specular_softness = 0.04`, `specular_strength = 0.65`,
  `specular_color = (1, 0.97, 0.82)`.
- **11 Point falloff:** normal-facing illumination with bounded distance fade.
  Material preset `point_weight = 1`; `light_range = 7`, `falloff_power = 1.5`.
- **12 Spotlight:** bounded distance fade multiplied by an adjustable cone.
  Material preset `point_weight = 1`; `light_range = 8`, `falloff_power = 1`,
  `spot_direction = (0.4, -0.8, -0.5)`, `spot_inner_angle = 22`,
  `spot_outer_angle = 45`. Spot direction points from the light; cone angles
  are degrees. Reversed angle inputs are sorted and equal edges have a minimum gap.
- **13 Crosshatch:** two diagonal UV stripe layers, each enabled at a different
  shadow level. `hatch_density = 35`, `hatch_width = 0.13`,
  `hatch_softness = 0.035`, `hatch_strength = 0.7`.
- **14 Halftone:** UV cell dots whose radius grows with shadow darkness.
  `dot_density = 24`, `dot_radius = 0.52`, `dot_softness = 0.04`,
  `dot_strength = 0.8`. UV seams and stretching follow the supplied mesh UVs.
- **15 Height gradient:** world-height tint gradient blended with normal-facing
  light. `height_origin = 0`, `height_span = 2`, `height_influence = 0.65`.
- **16 Fake occlusion:** analytic sphere blocker projected along the fake light
  ray. `occluder_position = (0, 0.7, 1)`, `occluder_radius = 0.6`,
  `occluder_softness = 0.25`, `occlusion_strength = 0.85`. Blockers behind the
  surface are ignored; for a point light, blocker centers beyond the light are
  ignored. This is an artistic sphere approximation rather than geometry-derived
  occlusion. Place the authored occluder marker roughly 1.5 units toward the
  light from the sample center for a clear example. It can be moved independently.

## Validation

Godot 4.7.2 resource creation/loading and fresh editor import succeeded.
GPU validation used Compatibility/OpenGL on an RTX 4060 Ti, 256-square paired
views, a checker/gradient texture, and a rotated sphere with nonuniform scale.
All eight pairs matched at defaults, with moved lights, with texture-only bypass,
and with almost opposing light inputs at `point_weight = 0.5`. Seven default
pairs were pixel-identical; spotlight differed by at most one 8-bit color step
(RMSE 0.00000885). All moved-light and opposing-input pairs were pixel-identical.
The explicit sphere blocker produced matching visible darkening (RMSE 0.07356
against occlusion disabled). No engine or script errors occurred.

The temporary authoring helper and module probe are outside the repository and
are never loaded by the game. Root integration owns the persistent catalog,
comparison scene, controller, GPU regression checks and complete suite.
Visual evidence is in
`C:/Users/Nikola/AppData/Local/Temp/cruises-lighting-b-render-20261011/`.

## Primary references

The [Godot spatial shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)
documents unshaded rendering, the coordinate spaces of `VERTEX`, `NORMAL` and
`VIEW`, and the inverse view matrix. The
[VisualShader input reference](https://docs.godotengine.org/en/stable/classes/class_visualshadernodeinput.html),
[float operation reference](https://docs.godotengine.org/en/stable/classes/class_visualshadernodefloatop.html)
and [vector operation reference](https://docs.godotengine.org/en/stable/classes/class_visualshadernodevectorop.html)
describe the editable built-in nodes used here. Local 4.7.2 ClassDB introspection
confirmed the operator enums and property names before authoring the resources.
