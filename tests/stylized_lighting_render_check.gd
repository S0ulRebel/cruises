extends "res://tests/check.gd"
## GPU compilation and parity on identical authored geometry in separate worlds.
## Run graphically with --rendering-method gl_compatibility. Evidence is external.

const LIBRARY := "res://materials/stylized_lighting/"
const ArtOutput := preload("res://tests/art_output.gd")
const SIZE := Vector2i(512, 512)
var worlds: Array[SubViewport] = []
var samples: Array[Node3D] = []
var evidence: Array[Dictionary] = []

func _run() -> void:
	if not check("GPU parity requires a rendering window", DisplayServer.get_name() != "headless"):
		finish()
		return
	check("GPU parity uses Compatibility renderer", RenderingServer.get_current_rendering_method() == "gl_compatibility")
	root.size = Vector2i(1056, 544)
	var catalog := load(LIBRARY + "material_catalog.tres")
	var prefab := load(LIBRARY + "gallery/lighting_sample.tscn") as PackedScene
	if not check("catalog and authored textured sample load", catalog != null and prefab != null):
		finish()
		return
	if not check("sixteen shader/graph pairs are available", catalog.ids.size() == 16 and catalog.shader_materials.size() == 16 and catalog.graph_materials.size() == 16):
		finish()
		return
	var output := ArtOutput.new_run("stylized-lighting-parity")
	print("Lighting GPU evidence: " + output)
	for index in 2: create_world(prefab, index)
	# Original sample materials are authored as unshaded, providing an independent
	# texture reference rather than comparing two potentially identical mistakes.
	for sample in samples:
		sample.get_node("Material").set("material", null)
		sample.get_node("Material").apply()
	await frames(4)
	var original_albedo := worlds[0].get_texture().get_image()
	original_albedo.convert(Image.FORMAT_RGBA8)
	check("original unshaded albedo reference saves", original_albedo.save_png(output.path_join("original_albedo.png")) == OK)
	for index in catalog.ids.size():
		var id: String = catalog.ids[index]
		for form in 2:
			var binding := samples[form].get_node("Material")
			binding.set("material", catalog.shader_materials[index] if form == 0 else catalog.graph_materials[index])
			binding.apply()
		for scenario in ["directional", "point", "mixed", "texture_only"]:
			var direction := Vector3(-0.4, 0.8, 0.5).normalized()
			var parameters := {
				"light_direction": direction,
				"light_position": Vector3(2.0, -3.0, -3.0) if scenario == "mixed" else Vector3(-2.0, 3.0, 3.0),
				"point_weight": 1.0 if scenario == "point" else (0.5 if scenario == "mixed" else 0.0),
				"light_strength": 1.15, "light_color": Color(1.0, 0.91, 0.74),
				"shadow_color": Color(0.30, 0.36, 0.52),
				"effect_strength": 0.0 if scenario == "texture_only" else 1.0,
				"spot_direction": Vector3(2.0, -2.4, -3.0).normalized(),
				"occluder_position": Vector3(0.0, 0.9, 0.6),
			}
			for sample in samples: sample.get_node("Material").set_light_parameters(parameters)
			await frames(4)
			var images: Array[Image] = []
			for form in 2:
				var image := worlds[form].get_texture().get_image()
				image.convert(Image.FORMAT_RGBA8)
				images.append(image)
				var suffix := "shader" if form == 0 else "graph"
				check("GPU image saves: %s %s %s" % [id, scenario, suffix], image.save_png(output.path_join("%s_%s_%s.png" % [id, scenario, suffix])) == OK)
			var result := compare(images[0], images[1])
			result["id"] = id
			result["scenario"] = scenario
			evidence.append(result)
			check("visible textured geometry: %s %s" % [id, scenario], result.coverage > 2000 and result.range > 0.08,
				"coverage=%d range=%.4f" % [result.coverage, result.range])
			check("GPU code/graph parity: %s %s" % [id, scenario], result.mean_difference <= 0.008 and result.large_difference_fraction <= 0.01,
				"mean=%.6f large_fraction=%.6f max=%.6f" % [result.mean_difference, result.large_difference_fraction, result.max_difference])
			if scenario == "texture_only":
				var reference := compare(images[0], original_albedo)
				result["texture_reference_mean_difference"] = reference.mean_difference
				check("Effect zero preserves original painted albedo: " + id, reference.mean_difference <= 0.008
					and reference.large_difference_fraction <= 0.01, "mean=%.6f" % reference.mean_difference)
	var report := {"renderer": RenderingServer.get_current_rendering_method(), "size": str(SIZE), "results": evidence,
		"mean_limit": 0.008, "fraction_over_0_05_limit": 0.01, "sample_stride": 2}
	var file := FileAccess.open(output.path_join("parity.json"), FileAccess.WRITE)
	check("GPU report saves", file != null)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	for world in worlds: world.queue_free()
	await frames(3)
	finish()

func create_world(prefab: PackedScene, index: int) -> void:
	var world := SubViewport.new()
	world.name = "CodeWorld" if index == 0 else "GraphWorld"
	world.size = SIZE
	world.own_world_3d = true
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world.msaa_3d = Viewport.MSAA_DISABLED
	world.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	root.add_child(world)
	worlds.append(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.04, 0.04, 0.04)
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.add_child(environment)
	var camera := Camera3D.new()
	camera.position = Vector3(2.8, 2.2, 4.0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.1
	world.add_child(camera)
	camera.look_at(Vector3(0, 0.6, 0))
	camera.current = true
	var sample := prefab.instantiate() as Node3D
	world.add_child(sample)
	samples.append(sample)
	var view := TextureRect.new()
	view.position = Vector2(16 + index * 528, 16)
	view.size = SIZE
	view.texture = world.get_texture()
	root.add_child(view)

func frames(count: int) -> void:
	for index in count:
		await process_frame
		await RenderingServer.frame_post_draw

func compare(code: Image, graph: Image) -> Dictionary:
	var left := code.get_data()
	var right := graph.get_data()
	var samples_count := 0
	var coverage := 0
	var total := 0.0
	var maximum := 0.0
	var large := 0
	var minimum_value := 1.0
	var maximum_value := 0.0
	for y in range(0, SIZE.y, 2):
		for x in range(0, SIZE.x, 2):
			var offset := (y * SIZE.x + x) * 4
			var difference := 0.0
			var value := 0.0
			for channel in 3:
				var delta := absf(float(left[offset + channel]) - float(right[offset + channel])) / 255.0
				total += delta
				difference = maxf(difference, delta)
				value = maxf(value, float(left[offset + channel]) / 255.0)
			maximum = maxf(maximum, difference)
			if difference > 0.05: large += 1
			if value > 0.09: coverage += 1
			minimum_value = minf(minimum_value, value)
			maximum_value = maxf(maximum_value, value)
			samples_count += 1
	return {"mean_difference": total / float(samples_count * 3), "max_difference": maximum,
		"large_difference_fraction": float(large) / samples_count, "coverage": coverage,
		"range": maximum_value - minimum_value}
