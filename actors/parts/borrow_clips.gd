class_name BorrowClips
extends RefCounted
## Copies animation clips from one Mixamo rig straight onto another.
##
## Pillage People needs a full retargeter because its rigs genuinely disagree - different
## units, different rest poses, bones that turn about different axes. Ours do not. Every
## character here comes out of the same generator with the same Mixamo skeleton, and the
## donor clips are Mixamo too, so the bone names, the axes and the rest poses already
## match. Nothing needs converting; the tracks only need to point at the new skeleton.
##
## That matters beyond simplicity: a retarget recomputes every bone on every frame and
## any error in the conversion shows up as a character folded inside out. Copying tracks
## verbatim cannot distort anything, because it changes no values.
##
## Bones the donor animates that the target lacks are skipped, and bones the target has
## that the donor never animates simply stay at rest - which is why Livé's extra pinky
## bones cost nothing.

## Clips that represent a continuing state. Mixamo exports everything as a one-shot, so
## without this the character plays its walk once and then stands frozen mid-stride.
const LOOPING := ["idle", "walk", "run", "swim"]


## Build a library of `donor`'s clips, aimed at `skeleton`, with paths resolved from
## `player_root` - the node the AnimationPlayer will live under.
static func library(donor_path: String, skeleton: Skeleton3D, player_root: Node) -> AnimationLibrary:
	var out := AnimationLibrary.new()

	var scene := load(donor_path) as PackedScene
	if scene == null:
		push_error("BorrowClips: '%s' is not a model" % donor_path)
		return out

	var donor := scene.instantiate() as Node3D
	var players := donor.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("BorrowClips: '%s' carries no clips" % donor_path)
		donor.free()
		return out

	var target_path := String(player_root.get_path_to(skeleton))
	var player := players[0] as AnimationPlayer

	for name in player.get_animation_list():
		var copy := _aim(player.get_animation(name), skeleton, target_path)
		if copy.get_track_count() > 0:
			if name in LOOPING:
				copy.loop_mode = Animation.LOOP_LINEAR
			out.add_animation(name, copy)

	donor.free()
	return out


## One clip, with every track repointed at the target skeleton and tracks for bones it
## does not have dropped.
static func _aim(source: Animation, skeleton: Skeleton3D, skeleton_path: String) -> Animation:
	var clip: Animation = source.duplicate(true)
	for track in range(clip.get_track_count() - 1, -1, -1):
		var bone := clip.track_get_path(track).get_concatenated_subnames()
		if bone.is_empty() or skeleton.find_bone(bone) == -1:
			clip.remove_track(track)
			continue

		# Position tracks are dropped, and both reasons matter.
		#
		# They are authored in the donor's units. The donor rig works in centimetres
		# and ours in metres, so a hip track copied verbatim throws the character a
		# hundred times too far - straight off the top of the screen, as it did.
		#
		# And they are not wanted regardless: this is a point-and-click, where the
		# code decides where someone stands and the clip only moves their limbs. A
		# clip that also travels fights the walk code and makes the character drift.
		# Rotation is what carries the performance; it is also what stands these rigs
		# up, since they rest lying face down.
		if clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
			clip.remove_track(track)
			continue

		clip.track_set_path(track, NodePath("%s:%s" % [skeleton_path, bone]))
	return clip
