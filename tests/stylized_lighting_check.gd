extends "res://tests/check.gd"
## Library contracts and imported model reuse; never writes project resources.

const LIBRARY := "res://materials/stylized_lighting/"
const COMMON := ["albedo_texture", "base_tint", "light_position", "light_direction",
	"point_weight", "light_strength", "light_color", "shadow_color", "effect_strength"]

func _run() -> void:
	var catalog := load(LIBRARY + "material_catalog.tres")
	if not check("material catalog loads", catalog != null):
		finish()
		return
	check("catalog contains sixteen techniques and matching descriptions", catalog.ids.size() == 16
		and catalog.labels.size() == 16 and catalog.descriptions.size() == 16)
	if not check("catalog contains sixteen code/graph pairs", catalog.shader_materials.size() == 16
		and catalog.graph_materials.size() == 16):
		finish()
		return
	var ids: Dictionary = {}
	for index in catalog.ids.size():
		var id: String = catalog.ids[index]
		var basename := id.substr(3) if id.length() > 3 and id.substr(0, 2).is_valid_int() else id
		check("technique ID is unique: " + id, not ids.has(id))
		ids[id] = true
		var code := catalog.shader_materials[index] as ShaderMaterial
		var graph := catalog.graph_materials[index] as ShaderMaterial
		if not check("materials load: " + id, code != null and graph != null and code.shader != null and graph.shader != null): continue
		check("explicit material suffixes: " + id, code.resource_path.ends_with(basename + "_shader.tres")
			and graph.resource_path.ends_with(basename + "_graph.tres"))
		check("code shader and editable VisualShader forms: " + id, not code.shader is VisualShader
			and code.shader.resource_path.ends_with(basename + "_shader.gdshader") and graph.shader is VisualShader)
		check("both forms use unshaded rendering: " + id, code.shader.code.contains("unshaded")
			and graph.shader.code.contains("unshaded"))
		var code_uniforms := uniform_schema(code.shader)
		var graph_uniforms := uniform_schema(graph.shader)
		check("code and graph expose the same parameter types: " + id, code_uniforms == graph_uniforms,
			str(code_uniforms) + " / " + str(graph_uniforms) if code_uniforms != graph_uniforms else "")
		var common_present := true
		for parameter in COMMON: common_present = common_present and code_uniforms.has(parameter) and graph_uniforms.has(parameter)
		check("common texture and fake-light controls exist: " + id, common_present)
		if graph.shader is VisualShader: check_editable_graph(id, graph.shader)
	await check_binding_reuse(catalog.shader_materials[0])
	var lab := instantiate_scene(LIBRARY + "gallery/material_lab.tscn")
	if lab != null:
		var before := authored_transforms(lab)
		root.add_child(lab)
		await process_frame
		await process_frame
		check("lab startup preserves all authored transforms", authored_transforms(lab) == before)
		check("fake-light lab creates no engine lights", lab.find_children("*", "Light3D", true, false).is_empty())
		for index in catalog.ids.size():
			lab.select_variant(index)
			await process_frame
			await process_frame
			var left: Array = lab.get_node("ShaderPanel/Sample/Material").get_applied_materials()
			var right: Array = lab.get_node("GraphPanel/Sample/Material").get_applied_materials()
			check("lab switches both authored samples: " + catalog.ids[index], not left.is_empty()
				and left.size() == right.size() and left[0].shader == catalog.shader_materials[index].shader
				and right[0].shader == catalog.graph_materials[index].shader)
		lab.queue_free()
		await process_frame
		await process_frame
	finish()

func uniform_schema(shader: Shader) -> Dictionary:
	var schema: Dictionary = {}
	for property in shader.get_shader_uniform_list(): schema[String(property.name)] = property.type
	return schema

func check_editable_graph(id: String, graph: VisualShader) -> void:
	var opaque: Array[String] = []
	var disconnected: Array[String] = []
	var node_count := 0
	for stage in [VisualShader.TYPE_VERTEX, VisualShader.TYPE_FRAGMENT, VisualShader.TYPE_LIGHT]:
		var nodes := graph.get_node_list(stage)
		var edges := graph.get_node_connections(stage)
		var reaches_output: Dictionary = {0: true}
		for node_id in nodes:
			var node := graph.get_node(stage, node_id)
			if node is VisualShaderNodeVaryingSetter: reaches_output[node_id] = true
		var changed := true
		while changed:
			changed = false
			for edge in edges:
				if reaches_output.has(edge.to_node) and not reaches_output.has(edge.from_node):
					reaches_output[edge.from_node] = true
					changed = true
		for node_id in nodes:
			if node_id == 0: continue
			var node := graph.get_node(stage, node_id)
			node_count += 1
			if node is VisualShaderNodeExpression or node is VisualShaderNodeGlobalExpression:
				opaque.append("%s:%d" % [node.get_class(), node_id])
			if not reaches_output.has(node_id) and not node is VisualShaderNodeInput:
				disconnected.append("%s:%d" % [node.get_class(), node_id])
	check("graph is editable math, without Expression blobs: " + id, node_count >= 10 and opaque.is_empty(), str(opaque) if not opaque.is_empty() else "")
	check("graph math and parameters contribute to output: " + id, disconnected.is_empty(), str(disconnected) if not disconnected.is_empty() else "")

func check_binding_reuse(material: ShaderMaterial) -> void:
	var binding_script := load(LIBRARY + "material_binding.gd") as Script
	var light_script := load(LIBRARY + "fake_light.gd") as Script
	var imported := load("res://art/props/captain_chair/captain_chair.glb") as PackedScene
	if not check("imported textured model and components load", imported != null and binding_script != null and light_script != null): return
	var fixture := Node3D.new()
	fixture.name = "LightingReuseFixture"
	var chairs: Array[Node3D] = []
	var records: Dictionary = {}
	for index in 2:
		var chair := imported.instantiate() as Node3D
		chair.name = "Chair%d" % index
		chair.position = Vector3(index * 2.0, 0.3, -0.5)
		chair.rotation = Vector3(0.15, index * 0.4, 0.0)
		fixture.add_child(chair)
		chairs.append(chair)
		for mesh in chair.find_children("*", "MeshInstance3D", true, false):
			# Exercise both designer override forms, not only bare import defaults.
			var original := mesh.get_active_material(0) as BaseMaterial3D
			if original != null:
				var painted := original.duplicate() as BaseMaterial3D
				painted.albedo_color = Color(0.8, 0.7, 0.6) if index == 0 else Color(0.9, 1.0, 0.8)
				if index == 0: mesh.material_override = painted
				else: mesh.set_surface_override_material(0, painted)
			var surfaces: Array = []
			var active: Array[Material] = []
			for surface in mesh.mesh.get_surface_count():
				surfaces.append(mesh.get_surface_override_material(surface))
				active.append(mesh.get_active_material(surface))
			records[mesh] = {"override": mesh.material_override, "surfaces": surfaces, "active": active}
	var bindings: Array[Node3D] = []
	for index in 2:
		var binding := Node3D.new()
		binding.name = "Binding%d" % index
		binding.set_script(binding_script)
		binding.set("target", NodePath("../Chair%d" % index))
		binding.set("material", material)
		fixture.add_child(binding)
		bindings.append(binding)
	var fake := Marker3D.new()
	fake.name = "FakeLight"
	fake.set_script(light_script)
	fake.position = Vector3(1, 2, 3)
	fake.set("light_mode", 1)
	fake.set("strength", 0.65)
	var targets: Array[NodePath] = [NodePath("../Binding0")]
	fake.set("targets", targets)
	fixture.add_child(fake)
	var transforms := authored_transforms(fixture)
	root.add_child(fixture)
	await process_frame
	await process_frame
	check("binding preserves imported geometry placement", authored_transforms(fixture) == transforms)
	var first: Array = bindings[0].get_applied_materials()
	var second: Array = bindings[1].get_applied_materials()
	check("each imported surface receives an instance-local material", not first.is_empty() and first.size() == second.size()
		and first[0] != second[0] and first[0] != material)
	var texture_preserved := true
	var tint_preserved := true
	var textured_surfaces := 0
	for mesh in records:
		var active: Array = records[mesh].active
		for index in active.size():
			var source := active[index] as BaseMaterial3D
			var applied := mesh.get_surface_override_material(index) as ShaderMaterial
			if source != null and source.albedo_texture != null:
				textured_surfaces += 1
				texture_preserved = texture_preserved and applied != null and applied.get_shader_parameter("albedo_texture") == source.albedo_texture
				var template_tint: Variant = material.get_shader_parameter("base_tint")
				var expected_tint: Color = source.albedo_color * (template_tint if template_tint is Color else Color.WHITE)
				tint_preserved = tint_preserved and applied != null and applied.get_shader_parameter("base_tint") == expected_tint
	check("original embedded albedo textures survive binding", textured_surfaces > 0 and texture_preserved)
	check("designer whole-mesh and surface tint overrides survive binding", textured_surfaces > 0 and tint_preserved)
	if not first.is_empty() and not second.is_empty():
		var untouched_position: Variant = second[0].get_shader_parameter("light_position")
		var untouched_strength: Variant = second[0].get_shader_parameter("light_strength")
		fixture.position = Vector3(3.2, -0.7, 1.1)
		fixture.rotation.y = 0.6
		fake.position = Vector3(-2, 2.5, 0.8)
		fake.set("strength", 1.7)
		fake.apply(true)
		check("moving a fake light sends its world position to assigned materials", first[0].get_shader_parameter("light_position").is_equal_approx(fake.global_position))
		check("fake-light strength reaches assigned materials", is_equal_approx(float(first[0].get_shader_parameter("light_strength")), 1.7))
		check("unassigned prefab remains independent", second[0].get_shader_parameter("light_position") == untouched_position
			and second[0].get_shader_parameter("light_strength") == untouched_strength)
		first[0].set_shader_parameter("effect_strength", 0.2)
		check("editing a material copy preserves the other prefab and source", second[0].get_shader_parameter("effect_strength") != 0.2
			and material.get_shader_parameter("effect_strength") != 0.2)
		bindings[0].apply()
		first = bindings[0].get_applied_materials()
		check("reapplying binding retains its assigned fake-light parameters", not first.is_empty()
			and first[0].get_shader_parameter("light_position").is_equal_approx(fake.global_position))
		var old_tint: Variant = material.get_shader_parameter("base_tint")
		var before_tint: Variant = first[0].get_shader_parameter("base_tint")
		material.set_shader_parameter("base_tint", Color(0.7, 0.8, 0.9))
		await process_frame
		await process_frame
		first = bindings[0].get_applied_materials()
		check("editing source-template parameters refreshes bound instances", not first.is_empty()
			and first[0].get_shader_parameter("base_tint") != before_tint)
		material.set_shader_parameter("base_tint", old_tint)
		await process_frame
		await process_frame
		var no_targets: Array[NodePath] = []
		fake.set("targets", no_targets)
		fake.apply(true)
		first = bindings[0].get_applied_materials()
		check("removing a fake-light target restores material defaults", not first.is_empty()
			and first[0].get_shader_parameter("light_position") == material.get_shader_parameter("light_position")
			and first[0].get_shader_parameter("light_strength") == material.get_shader_parameter("light_strength"))
		fake.set("targets", targets)
		fake.apply(true)
		fake.queue_free()
		await process_frame
		await process_frame
		first = bindings[0].get_applied_materials()
		check("removing fake light clears its transient parameters", not first.is_empty()
			and first[0].get_shader_parameter("light_position") == material.get_shader_parameter("light_position")
			and first[0].get_shader_parameter("light_strength") == material.get_shader_parameter("light_strength"))
	for binding in bindings: binding.queue_free()
	await process_frame
	await process_frame
	var restored := true
	for mesh in records:
		restored = restored and mesh.material_override == records[mesh].override
		for index in records[mesh].surfaces.size():
			restored = restored and mesh.get_surface_override_material(index) == records[mesh].surfaces[index]
	check("removing bindings restores original imported materials", restored)
	fixture.queue_free()
	await process_frame
	await process_frame

func authored_transforms(node: Node) -> Dictionary:
	var result: Dictionary = {}
	for child in node.find_children("*", "Node3D", true, false):
		result[String(node.get_path_to(child))] = child.transform
	return result
