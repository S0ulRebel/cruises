extends SceneTree
func _init():
	var p := SkeletonProfileHumanoid.new()
	var names := []
	for i in p.bone_size: names.append(p.get_bone_name(i))
	print(p.bone_size, " bones: ", ", ".join(names))
	var ok := p.bone_size > 30 and "Head" in names and "Hips" in names
	print("ALL CHECKS PASSED" if ok else "FAIL humanoid profile has no expected bones")
	quit(0 if ok else 1)
