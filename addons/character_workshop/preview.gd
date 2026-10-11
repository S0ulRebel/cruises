@tool
extends RefCounted
## Independent temporary animation/material state, never written into authored scenes.

var player: AnimationPlayer
var libraries: Dictionary = {}
var properties: Array = []
var poses: Array = []
var materials: Array = []
var original_process: int
var original_active: bool

func _nodes(node: Node) -> Array:
	var result: Array = [node]
	for child: Node in node.get_children():
		result.append_array(_nodes(child))
	return result

func play(value: AnimationPlayer, clip: String, loop: bool) -> String:
	stop()
	if value == null or not value.has_animation(clip):
		return "Select an available animation player and clip."
	player = value
	original_process = player.callback_mode_process
	original_active = player.active
	var animation_root: Node = player.get_node_or_null(player.root_node)
	var captured: Dictionary = {}
	if animation_root != null:
		for node: Node in _nodes(animation_root):
			if node is Skeleton3D:
				var bones: Array[Transform3D] = []
				for index: int in node.get_bone_count():
					bones.append(node.get_bone_pose(index))
				poses.append({"node": node, "bones": bones})
		for library_name: StringName in player.get_animation_library_list():
			var original: AnimationLibrary = player.get_animation_library(library_name)
			libraries[library_name] = original
			for animation_name: StringName in original.get_animation_list():
				var animation: Animation = original.get_animation(animation_name)
				for track: int in animation.get_track_count():
					var path: NodePath = animation.track_get_path(track)
					var node: Node = animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))
					if node == null or (node is Skeleton3D and path.get_subname_count() > 0):
						continue
					var property: NodePath
					match animation.track_get_type(track):
						Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D:
							property = NodePath("transform")
						Animation.TYPE_VALUE, Animation.TYPE_BLEND_SHAPE:
							property = NodePath(path.get_concatenated_subnames())
						_:
							continue
					var key := str(node.get_instance_id()) + ":" + str(property)
					if not captured.has(key) and not str(property).is_empty():
						captured[key] = true
						properties.append({"node": node, "property": property, "value": node.get_indexed(property)})
	# Duplicate every mutable animation resource before toggling loop or previewing.
	for library_name: StringName in libraries:
		var copy: AnimationLibrary = libraries[library_name].duplicate(true)
		for animation_name: StringName in copy.get_animation_list():
			var animation: Animation = copy.get_animation(animation_name)
			# Preview must not execute gameplay methods or audio events.
			for track: int in range(animation.get_track_count() - 1, -1, -1):
				if animation.track_get_type(track) in [Animation.TYPE_METHOD, Animation.TYPE_AUDIO]:
					animation.remove_track(track)
		player.remove_animation_library(library_name)
		player.add_animation_library(library_name, copy)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.active = true
	player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	player.play(clip)
	player.advance(0.0)
	return ""

func advance(delta: float) -> void:
	if is_instance_valid(player) and player.is_playing():
		player.advance(delta)

func set_loop(clip: String, value: bool) -> void:
	if is_instance_valid(player) and player.has_animation(clip):
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if value else Animation.LOOP_NONE

func stop() -> void:
	if is_instance_valid(player):
		player.stop()
		for library_name: StringName in libraries:
			if player.has_animation_library(library_name):
				player.remove_animation_library(library_name)
			player.add_animation_library(library_name, libraries[library_name])
		player.callback_mode_process = original_process
		player.active = original_active
	for entry: Dictionary in properties:
		if is_instance_valid(entry.node):
			entry.node.set_indexed(entry.property, entry.value)
	for entry: Dictionary in poses:
		if is_instance_valid(entry.node):
			for index: int in mini(entry.bones.size(), entry.node.get_bone_count()):
				entry.node.set_bone_pose(index, entry.bones[index])
	player = null
	libraries.clear()
	properties.clear()
	poses.clear()

func neutral_shading(root: Node, enabled: bool) -> void:
	restore_materials()
	if not enabled or root == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.75, 0.82)
	material.roughness = 0.8
	for node: Node in _nodes(root):
		if node is MeshInstance3D:
			materials.append({"node": node, "material": node.material_override})
			node.material_override = material

func restore_materials() -> void:
	for entry: Dictionary in materials:
		if is_instance_valid(entry.node):
			entry.node.material_override = entry.material
	materials.clear()
