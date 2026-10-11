# Stylized lighting ownership

- This library owns its materials, graphs, reusable material/light components and lab.
- Every technique has equivalent `_shader` and `_graph` ShaderMaterial resources.
  Graph resources contain editable VisualShader math nodes, not an opaque shader blob.
- Keep shading unshaded. Fake lights pass parameters; they never create Light3D nodes,
  construct scenery, change mesh geometry, or save resources during startup.
- Scene light controls affect only their explicitly assigned material components.
  Material copies are local to each mesh instance and retain imported albedo textures.
- Gallery content is authored in scenes. Game/cabin adoption requires a separate
  intentional art decision; this library does not replace current game materials.
- Variant contributors own assigned numbered subfolders. Root integration owns the
  common components, catalog, gallery, docs and validation.
