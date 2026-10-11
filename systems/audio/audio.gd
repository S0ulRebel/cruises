class_name Audio
extends Node
## Playback behavior; streams, players and volumes live in audio.tscn.
@onready var music: AudioStreamPlayer = $Music

func play() -> void:
	if music.stream and not music.playing:
		music.play()

func stop() -> void:
	music.stop()

func _exit_tree() -> void:
	if is_instance_valid(music):
		music.stop()
