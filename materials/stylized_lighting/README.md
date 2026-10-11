# Stylized fake lighting

Open `gallery/material_lab.tscn` and press **F6**. It compares the code material on
the left with its VisualShader equivalent on the right. Choose a technique and a
sample, sweep the light, rotate the objects, or adjust strength, color and shadow.
The existing captain's chair keeps its embedded texture. Effect 0 shows the original
albedo; Effect 1 applies the complete treatment. No engine Light3D is required.

## Files and editing

Each numbered variant has four files:

- `<id>_shader.tres`: ShaderMaterial using `<id>_shader.gdshader`.
- `<id>_graph.tres`: ShaderMaterial using `<id>_graph_shader.tres` (VisualShader).

Assign either **material** to a MeshInstance3D material slot/override and set
`albedo_texture`. Open the nested Shader resource to edit code or the graph.
Both forms expose the same parameters. Graphs use built-in math and texture nodes,
with readable node names and left-to-right dependency columns. There are no
Expression nodes containing hidden copies of the entire shader.

Make a material unique before changing a shared resource across unrelated objects.
For an imported multi-surface model, instance `material_binding.tscn` as a child,
set Target to the model and choose a material. It makes per-surface local
copies and retains each original albedo texture/tint. Texture Override deliberately
uses one texture across those surfaces. Existing geometry, UVs, skinning and placement
are untouched. Original overrides are restored when the component leaves the tree.
Live Inspector/code parameter changes refresh those copies. The binding checks
template parameters because Godot's uniform setter does not emit Resource.changed.
Use one appearance component per target; an existing Unlit component should not
also manage those same meshes.

## Scene controls or direct material controls

Every material exposes `light_direction` (world vector **toward** the source),
`light_position` (world position), `point_weight` (0 directional, 1 point),
`light_strength`, `light_color`, `shadow_color`, `effect_strength`, `base_tint`,
and `albedo_texture`. Directional mode has no distance falloff. Point mode selects
the point-to-surface direction; variants 11/12 additionally implement falloff.

For a scene-driven source, instance `fake_light.tscn`. Assign its Targets explicitly
to material-binding components. Its position supplies point position; Direction
supplies the world direction. Strength, colors and effect are editable in the
Inspector and update both in editor and at runtime. A source only affects its assigned
components. It does not discover or overwrite unrelated materials. Remove the source
or its target assignment to restore the material's own parameters. Assign one source
per binding to give its scene parameters one owner.
Aim Spotlight makes the cone face opposite Direction, from source toward the objects;
disable it to use a material's own `spot_direction`.

The lab uses a source per panel so point positions match relative to each sample.
Both panels have their own authored Occluder Marker3D for variant 16. The two views
share a camera, so view-dependent highlights naturally differ slightly between
left and right; the render validation compares equal geometry/cameras separately.
Select a specific material's Inspector for its extra technique parameters.

## Techniques and useful controls

1. **Soft Lambert:** smooth normal/light response; `diffuse_curve` shapes the falloff.
2. **Half Lambert:** lifts the unlit side; the response curve controls roundness.
3. **Two Tone:** one hard threshold produces flat painted light/shadow regions.
4. **Three Tone:** separate middle color and two thresholds form three values.
5. **Soft Toon:** an adjustable soft transition around a toon threshold.
6. **Texture Ramp:** an editable grayscale GradientTexture1D controls the response.
7. **Hemisphere:** world-up sky/ground tint with a controllable directional key blend.
8. **Wrap Diffuse:** wraps the key past the normal terminator; tune wrap amount.
9. **Rim Light:** view-dependent colored edge light with optional key-side gating.
10. **Toon Specular:** stylized camera/light half-vector highlight with gloss/threshold.
11. **Point Falloff:** adjustable range and power create a local painted light pool.
12. **Spotlight:** editable inner/outer cone angles, direction and distance falloff.
13. **Crosshatch:** two UV diagonal stroke layers accumulate toward the shadow side.
14. **Halftone:** UV ink-dot radius grows with darkness; tune density and softness.
15. **Height Gradient:** a world-height gradient combines with the directional key.
16. **Fake Occlusion:** an explicit sphere blocker controls an analytic soft shadow.
    Set `occluder_position`, radius, softness and strength, or assign a marker on
    the fake-light component. It is an approximation; it does not trace scene meshes.

## Practical limits

These are opaque surface materials. They simulate illumination by multiplying/tinting
the existing texture and sometimes adding a stylized highlight. They do not remove
lighting already painted into a texture; lower Effect if that creates double shading.
They do not receive engine shadows, automatically detect occluders, illuminate another
surface, or provide glass/transparency. The sphere blocker is an explicit artistic
control, not scene-wide shadow casting. The default game materials are not replaced.

Hatching/halftone follow the model UVs. Seams and uneven UV density can distort the
patterns; high density can shimmer when viewed small. Their soft edges are artistic
controls, not full curvature-aligned stroke maps or a complete antialiasing solution.
Height shading uses world height, so choose its origin/span for the location.

The library targets the project's Godot 4.7.2 Compatibility renderer. Fragment view
positions/normals are transformed with INV_VIEW_MATRIX before world-space light
math. No screen/depth texture, custom renderer feature or texture re-export is used.

## Research references

- [Godot spatial shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html):
  unshaded output, fragment coordinate spaces and built-in transforms.
- [Godot VisualShaders](https://docs.godotengine.org/en/stable/tutorials/shaders/visual_shaders.html):
  graph editing, typed math/texture ports and generated shader code.
- [Godot Fresnel node](https://docs.godotengine.org/en/stable/classes/class_visualshadernodefresnel.html):
  the normal/view-angle response underlying the rim variation.
- [Praun et al., Real-Time Hatching (2001)](https://hhoppe.com/hatching.pdf):
  surface-attached strokes and tone-dependent hatching. Our variation uses a simpler
  procedural UV stripe scheme; it does not implement the paper's tonal-art-map pipeline.

The response, falloff, cone and analytic blocker formulas are deliberately small
artist-controlled implementations, with equivalent node and text forms for comparison.

## Verified — 2026-10-11

- Root integration `8d1521b` passed all 13 project checks and the intentional
  engine-error rejection probe. Tracked authored source/asset hashes did not change.
  Logs: `C:/Users/Nikola/AppData/Local/Temp/cruises-checks-72f76ada4f23497aa963bef9f1fc87c8/`.
- All 32 materials compiled on the RTX 4060 Ti / OpenGL Compatibility renderer.
  The GPU harness passed 64 code/graph comparisons (directional, point, mixed and
  original-texture bypass); sampled pixels matched, and all 16 bypass images matched
  the independently rendered original unshaded material. Detailed report/images:
  `C:/Users/Nikola/AppData/Local/cruises-tests/stylized-lighting-parity-28168-863746/`.
- Module checks additionally exercised exact opposite-vector cancellation and a
  moved analytic blocker. Full-resolution module spotlight images differed by at
  most one 8-bit step from graph arithmetic; the integrated GPU check samples every
  second pixel and uses tolerance limits recorded in its report.
- The real 1920×1080 lab was rendered and inspected with primitive, chair, toon,
  rim, spotlight, hatch, halftone and blocker selections. UI and teardown produced
  no engine/script errors. Captures:
  `C:/Users/Nikola/AppData/Local/Temp/cruises-lighting-authoring-20261011/`.
- Forward+ and Mobile have not been validated. Existing game materials and source
  models remain unchanged.
