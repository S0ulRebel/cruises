# Audio

Music and ambience, from a generated track to a loop the game can play.

    Suno (or a local model)  ->  make_loop.py  ->  WAV  ->  encode_ogg.py  ->  OGG  ->  Godot

**Two steps, never one.** `make_loop.py` can write an `.ogg` directly and it must not be
used that way. See below — it cost an afternoon.


## 1. Cut the loop

    python tools/make_loop.py "<generated>.wav" --out art/audio/music/<name>.wav --min 40

Generators write songs, not loops: an intro that happens once, a fade at the end, and no
guarantee the last bar leads back to the first. The tool finds the pair of points that
actually join, nudges them onto a shared zero crossing and crossfades the seam.

It reports the seam as a measurement, not a claim:

    seam step 0.00198 against a typical sample step of 0.00618 (0.3x)

Below 1.0x means the join is smaller than the track's own average sample-to-sample
movement, so it cannot be heard. Anything approaching or above 1.0x needs a different
`--min` so it can find a better pair.

`--min` is the shortest acceptable loop in seconds. Too high and it refuses; too low and
you get a short cycle that announces itself.


## 2. Encode with Blender, not with PyAV

    "C:\Program Files\Blender Foundation\Blender 4.3\blender.exe" --background --factory-startup ^
        --python tools/encode_ogg.py -- art/audio/music/<name>.wav art/audio/music/<name>.ogg

**This is the step that matters and the one that is easy to skip**, because `make_loop.py`
will happily write an `.ogg` itself if you give it one as `--out`. Its own docstring and
`tools/README.md` both say not to: `encode_ogg.py` exists for exactly this reason.

PyAV's vorbis encoder — which is what `make_loop.py` falls back to — produces a file that
plays but crackles. Measured on the captain's quarters theme, counting sample-to-sample
jumps above 0.2 over the same 107 seconds of audio:

| file | jumps > 0.2 | jumps > 0.4 |
| --- | --- | --- |
| lossless WAV, the reference | **1** | 0 |
| Blender's libvorbis | **5** | 0 |
| PyAV | **11,360** | 65 |

Eleven thousand against five. That is the stuttering, and it is in the file, not in Godot.

Note that `av.Codec("libvorbis", "w")` succeeds in this environment, so `make_loop.py`
believes it has the good encoder and takes no fallback path. It is still wrong. Do not
trust that check — use Blender.

Delete the intermediate WAV once the OGG is written; it is 10x the size and nothing reads
it.


## 3. Godot

Looping is authored on the stream in `systems/audio/audio.tscn`. The saved Music
AudioStreamPlayer exposes stream, volume, bus and autoplay in the Inspector.
Scripts control playback without creating players or changing shared streams.

A restart-on-finished leaves a gap of at least one frame, which is inaudible under music
and very audible under a quiet room tone.

Each layer gets its own `AudioStreamPlayer` so they can be mixed against each other — the
score can duck or stop for a dramatic beat while the room keeps breathing. Current levels:
music -14 dB.


## What is in the game

| file | what | loop | seam |
| --- | --- | --- | --- |
| `art/audio/music/quarters_theme.ogg` | Captain's quarters, calypso-ish, low-key | 107.1 s | 0.3x |
| `art/audio/music/pirate_shanty.ogg` | Instrumental sea shanty, for the pirate side | 80.9 s | 0.4x |

Only the theme is wired in; the shanty is for a scene that does not exist yet.

**There is no ambience bed.** Suno's Sounds tab caps a loop at 14 seconds and what it
produced for a ship's cabin was closer to noise than room tone — a 10 second cycle of
distinctive creaks that announces itself on every repeat. Silence under the score is
better than that.


## Writing the prompts

The owner writes the Suno prompts. Earlier attempts from this side missed: a Caribbean
calypso read as a cruise ship rather than a pirate ship, and asking for "room tone" with a
list of instruments got music back instead of atmosphere.
