extends "res://tests/check.gd"
const ArtOutput := preload("res://tests/art_output.gd")

func _run() -> void:
	root.size = Vector2i(1920,1080)
	var game := instantiate_scene("res://game/game.tscn")
	if game == null: finish(); return
	game.set("skip_cold_open",true)
	root.add_child(game)
	check("dressed cabin starts",await wait_for(func() -> bool: return game.get("initialized") == true,8))
	await process_frame
	var cabin := game.get("location") as Location
	var dressing := cabin.get_node("Dressing")
	check("dressing is authored as a reusable scene",dressing.scene_file_path.ends_with("dressing.tscn"))
	check("dressing adds no navigation or click blockers",dressing.find_children("*","CollisionObject3D",true,false).is_empty())
	check("fake lighting adds no engine lights",cabin.find_children("*","Light3D",true,false).is_empty())
	var floor := cabin.get_node("Floor/FloorVisual") as MeshInstance3D
	var floor_mat := floor.get_active_material(0) as ShaderMaterial
	check("floor has real colour and gentle normal textures",has_textures(floor_mat,"floorboards"))
	check("floor preserves 2.4m texture density",floor_mat.get_shader_parameter("uv_scale").is_equal_approx(Vector2(5,7.0/2.4)))
	var rug := dressing.get_node("Rug") as MeshInstance3D
	check("rug has colour and gentle normal textures",has_textures(rug.material_override as ShaderMaterial,"carpet_burgundy"))
	check("rug is a thin visual layer above the existing floor",is_equal_approx(rug.position.y,.008))
	var ids: Array[String] = []
	for k in range(1,4):
		var roll := dressing.get_node("DeskCharts/ChartRoll%02d" % k) as Node3D
		ids.append(roll.scene_file_path)
		var model := roll.get_node("Model") as Node3D
		var bounds := AABB()
		var first := true
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			bounds = mesh.get_aabb() if first else bounds.merge(mesh.get_aabb())
			first = false
		check("individual roll retains dimensions and underside origin %d" % k,bounds.size.is_equal_approx(Vector3(.6,.04,.04)) and is_zero_approx(bounds.position.y))
		check("roll sits on the tabletop rather than the floor %d" % k,is_equal_approx(roll.position.y,.77))
	check("three rolls have independent prefab paths",ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2])
	var beam_binding := dressing.get_node("CeilingTimbers/Beam1_1Paint") as StylizedMaterialBinding
	var normal_surfaces := 0
	for material in beam_binding.get_applied_materials():
		if material.get_shader_parameter("use_normal") == true and material.get_shader_parameter("normal_texture") != null: normal_surfaces += 1
	check("beam paint retains imported normal maps",normal_surfaces > 0)
	var crate := cabin.get_node("Crate/Model") as Node3D
	check("native crate visual keeps existing prefab hotspot",crate.scene_file_path.ends_with("native/supply_crate.glb") and cabin.get_node("Crate/Hotspot") is Hotspot)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var before := root.get_texture().get_image()
		var off := floor_mat.duplicate() as ShaderMaterial
		off.set_shader_parameter("use_normal",false)
		floor.set_surface_override_material(0,off)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var after := root.get_texture().get_image()
		# Foreground wood pixels are clear of the moving actors, rug and UI.
		var changed := 0
		for y in range(995,1060,3):
			for x in range(180,1740,3):
				if before.get_pixel(x,y) != after.get_pixel(x,y): changed += 1
		check("normal data visibly changes rendered floor lighting",changed > 50,str(changed)+" sampled pixels")
		floor.set_surface_override_material(0,floor_mat)
		var evidence := ArtOutput.new_run("cabin-normal-acceptance")
		before.save_png(evidence.path_join("normal_on.png"))
		after.save_png(evidence.path_join("normal_off.png"))
		FileAccess.open(evidence.path_join("normal_check.json"),FileAccess.WRITE).store_string(JSON.stringify({"changed_foreground_samples":changed,"shader":"cabin_surface.gdshader"},"  "))
		print("Normal-map evidence: "+evidence)
	# Stop playback while its owner is alive, then allow the audio thread to
	# release playback after scene deletion before immediately quitting.
	# Headless process frames are unthrottled and do not provide a mix interval.
	game.get("audio").stop()
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	finish()

func has_textures(material: ShaderMaterial,id: String) -> bool:
	if material == null or material.get_shader_parameter("use_normal") != true: return false
	var colour := material.get_shader_parameter("albedo_texture") as Texture2D
	var normal := material.get_shader_parameter("normal_texture") as Texture2D
	return colour != null and normal != null and colour.resource_path.ends_with(id+"/albedo.png") and normal.resource_path.ends_with(id+"/normal_gentle_opengl.png")
