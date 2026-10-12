@tool
class_name CWRigSpace
extends RefCounted
## Reusable rig-space normalization.
## Y up, +Z forward, reference pose in metres. Sources remain unchanged.

## Skeleton space to fit space. See above.
static func frame_of(skeleton: Skeleton3D, model: Node) -> Transform3D:
	var hips := find_any(skeleton, ["mixamorig_Hips", "Hips"])
	if hips == -1:
		hips = 0
	var head := find_any(skeleton, ["mixamorig_HeadTop_End", "mixamorig_Head", "Head"])
	var at_hips := skeleton.get_bone_global_rest(hips).origin
	var up := Vector3.UP
	if head != -1:
		up = nearest_axis(skeleton.get_bone_global_rest(head).origin - at_hips)
	# Both feet, added. Each one splays outwards - the grunt's by 21 degrees - and the two
	# splays cancel, where either foot alone would turn the whole of fit space by that much.
	var step := Vector3.ZERO
	for foot in ["Left", "Right"]:
		var heel := find_any(skeleton, ["mixamorig_%sFoot" % foot, "%sFoot" % foot])
		var toe := find_any(skeleton, ["mixamorig_%sToe_End" % foot,
				"mixamorig_%sToeBase" % foot, "%sToes" % foot])
		if heel != -1 and toe != -1:
			step += skeleton.get_bone_global_rest(toe).origin \
					- skeleton.get_bone_global_rest(heel).origin
	# Only the level part: feet point down as well as forward.
	step -= up * step.dot(up)
	var forward := nearest_axis(step) if step.length() > 0.0001 else Vector3.BACK
	if absf(forward.dot(up)) > 0.5:
		forward = Vector3.BACK if absf(up.z) < 0.5 else Vector3.UP
	var side := up.cross(forward).normalized()
	# Columns are where fit space's axes point in the skeleton's space; inverting turns the
	# skeleton's space into fit space.
	var turn := Basis(side, up, forward).inverse()
	var metres := chain(skeleton, model).basis.get_scale().x
	var frame := Transform3D(turn.scaled(Vector3.ONE * metres), Vector3.ZERO)
	# Centred over the hips, left where the rig puts the floor - the skeleton's origin is on the
	# ground between the feet on every rig here, which is the Mixamo convention.
	var centre := frame * at_hips
	frame.origin = Vector3(-centre.x, 0.0, -centre.z)
	return frame


## Authoring preflight. A local facial rig is valid for attachments but has no
## torso frame for this measured humanoid fitting/retargeting backend.
static func validate_frame(skeleton: Skeleton3D, model: Node) -> String:
	if skeleton == null or model == null:
		return "Choose a complete donor skeleton and model."
	var hips := find_any(skeleton, ["mixamorig_Hips", "Hips"])
	var head := find_any(skeleton, ["mixamorig_HeadTop_End", "mixamorig_Head", "Head"])
	if hips < 0 or head < 0 or hips == head:
		return "This rig needs an explicit hips/head landmark mapping for garment binding or borrowed body animation. Keep its local rig for attachments."
	if skeleton.get_bone_global_rest(head).origin.distance_to(skeleton.get_bone_global_rest(hips).origin) < 0.00001:
		return "The hips/head reference positions coincide; correct the donor rest pose first."
	var placement := chain(skeleton, model)
	if not placement.is_finite() or absf(placement.basis.determinant()) < 0.000001:
		return "The donor transform is invalid or has zero scale."
	return ""


## The transform from `node`'s space to `top`'s, by walking up the parents. Works before
## anything is in the tree, which global_transform does not.
static func chain(node: Node, top: Node) -> Transform3D:
	var out := Transform3D.IDENTITY
	var walk := node
	while walk != null and walk != top:
		if walk is Node3D:
			out = (walk as Node3D).transform * out
		walk = walk.get_parent()
	return out


## The skeleton axis `direction` is closest to. Up and forward are snapped to one, because a
## rig's space is always square to the world it was built in: the grunt's head sits 2.4 cm in
## front of his hips, and taking that literally would lean all of fit space back 1.6 degrees.
static func nearest_axis(direction: Vector3) -> Vector3:
	var axis := direction.abs().max_axis_index()
	var out := Vector3.ZERO
	out[axis] = signf(direction[axis])
	return out


static func find_any(skeleton: Skeleton3D, names: Array) -> int:
	for bone_name in names:
		var bone := skeleton.find_bone(bone_name)
		if bone != -1:
			return bone
	return -1
