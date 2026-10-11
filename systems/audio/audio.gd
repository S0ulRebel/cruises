class_name Audio
extends Node
## What the room sounds like.
##
## Its own node so that adding ambience, footsteps or a door later touches this file
## and nothing else - main.gd decides WHEN a room is entered, not what it sounds like.

## Each track: the file, the node name, and how loud. A dictionary rather than four
## parallel constants, because a fifth track should be one line.
const TRACKS := [
	{ "path": "res://art/audio/music/quarters_theme.ogg", "name": "Music", "db": -14.0 },
]


func _ready() -> void:
	for track in TRACKS:
		_play(String(track["path"]), String(track["name"]), float(track["db"]))


func _play(path: String, who: String, db: float) -> void:
	if not ResourceLoader.exists(path):
		push_warning("audio: nothing at %s" % path)
		return
	var player := AudioStreamPlayer.new()
	player.name = who
	var stream := load(path) as AudioStream
	# Looping is set on the STREAM, not by restarting on finished: a restart leaves a
	# gap of at least one frame, which is audible on a quiet room tone.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	player.stream = stream
	player.volume_db = db
	add_child(player)
	player.play()
