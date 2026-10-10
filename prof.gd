extends SceneTree
func _init():
	var p := SkeletonProfileHumanoid.new()
	var names := []
	for i in p.bone_size: names.append(p.get_bone_name(i))
	print(p.bone_size, " bones: ", ", ".join(names))
	quit()
