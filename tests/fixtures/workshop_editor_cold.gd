extends SceneTree
## Separate runtime process verifies saved authoring output without the plugin.

func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()
	if paths.size() != 1:
		printerr("Supply the explicit output path printed by workshop_editor_check.")
		quit(1)
		return
	var packed: PackedScene = load(paths[0]) as PackedScene
	if packed == null:
		quit(1)
		return
	var assembly := packed.instantiate()
	var body: Node = assembly.get_node_or_null("MyBody")
	if body == null or body.get("geometry_masks").size() != 1:
		printerr("Cold reload lost body or exclusion metadata.")
		assembly.free()
		quit(1)
		return
	var mesh: MeshInstance3D = body.get_node("Model/Geometry")
	var mask: Resource = body.get("geometry_masks")[0]
	var skeleton: Skeleton3D = body.get_node("Model/Skeleton")
	var ok: bool = mesh.mesh != mask.source_mesh and mask.excluded_faces[0] == PackedInt32Array([0, 1]) and skeleton.get_bone_count() == 2
	ok = ok and mesh.get_surface_override_material(0) != null and body.get_node("Model/CollisionBody/Shape").disabled
	ok = ok and body.get_node("Model/AnimationPlayer").get_animation("talk").loop_mode == Animation.LOOP_NONE
	assembly.free()
	print("WORKSHOP_EDITOR_COLD: ", "passed" if ok else "failed")
	quit(0 if ok else 1)
