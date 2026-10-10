extends Node3D
func _ready() -> void:
	var m := (load("res://art/animations/hymotion/walk.fbx") as PackedScene).instantiate()
	add_child(m)
	var sk := m.find_children("*", "Skeleton3D", true, false)
	var ap := m.find_children("*", "AnimationPlayer", true, false)
	print("skeletons=%d players=%d" % [sk.size(), ap.size()])
	if not sk.is_empty():
		var s := sk[0] as Skeleton3D
		var names := []
		for i in min(8, s.get_bone_count()): names.append(s.get_bone_name(i))
		print("bones=%d first: %s" % [s.get_bone_count(), ", ".join(names)])
	if not ap.is_empty():
		print("clips: %s" % ", ".join((ap[0] as AnimationPlayer).get_animation_list()))
	get_tree().quit()
