@tool
extends StylizedMaterialBinding
## Cabin adoption retains each imported surface's separate normal map as well as colour.
func apply() -> void:
	super.apply()
	for mesh in _originals:
		if not is_instance_valid(mesh): continue
		var record: Dictionary = _originals[mesh]
		for surface in mesh.mesh.get_surface_count():
			var source: Material = record.override
			if source == null: source = record.surfaces[surface]
			if source == null: source = mesh.mesh.surface_get_material(surface)
			var copy := mesh.get_surface_override_material(surface) as ShaderMaterial
			if copy == null: continue
			var normal_source := source as BaseMaterial3D
			var has_normal := normal_source != null and normal_source.normal_enabled and normal_source.normal_texture != null
			copy.set_shader_parameter("use_normal", has_normal)
			if has_normal:
				copy.set_shader_parameter("normal_texture", normal_source.normal_texture)
				copy.set_shader_parameter("normal_depth", normal_source.normal_scale)
