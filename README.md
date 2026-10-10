# Cruises (working title)

A point-and-click comedy adventure. Pirates come through a crack in space and time and
take possession of a cruise ship; the game is the three-way collision between the
pirates, the ship's crew, and the guests.

The folder name is deliberately neutral. The working title on the art board uses a
phrase Disney owns, and that cannot go on a store page — so nothing here depends on
what the game ends up being called.

## What runs today

The cold open, played from a data file, with placeholder art.

```
godot --path .                      # the cold open. Space or click, Esc to quit
godot --path . -- --auto            # plays itself, prints a timed running order
godot --path . -- --room            # room blocking: click the floor to walk
godot --path . -- --talk            # one conversation, on its own
godot --path . -- --talk --auto     # walks every branch, prints a transcript
```

`--auto` is how you judge the scene. It prints each beat with the second it started, so
the question "is the silence before the pop too long" has an answer you can read:

```
[ 20.13s] Captain Choi: "Satisfaction of our guests is our utmost destination."
[ 24.80s]   [sfx]            <- the pop
[ 26.91s]   [shake]
[ 34.64s]   [end]
```

## The shape of it

```
main.gd                 the entry points, and what each one builds
screenplay/*.json       scenes and conversations. Data, not code
cutscene/cutscene.gd    plays a screenplay, one beat at a time
dialogue/dialogue.gd    plays a branching conversation
room/room.gd            a place: floor polygon, perspective markers, hotspots
actors/walker/walker.gd someone who can cross a room
stage/stage.gd          cutscene backdrop. Coloured blocks until there is art
ui/caption.gd           spoken lines and stage directions
ui/choices.gd           what the player could say
art/                    delivered by the art side, to docs/ART_SPEC.md
```

## Conversations

Most of a comedy adventure is talking, so conversations are a data format the writer
owns. See `screenplay/santi_galley.json` - it is a worked example that uses every
feature, so it doubles as the reference.

A conversation is a bag of nodes. A node says some lines, then offers choices, jumps,
or ends.

| field | on | does |
|---|---|---|
| `lines` | node | spoken, in order |
| `choices` | node | what the player may say |
| `set` / `clear` | node, choice | remember something |
| `goto` | node, choice | jump |
| `exit` | node, choice | end the conversation |
| `once` | choice | hide it after it has been used |
| `if` / `unless` | choice | show only when flags match |
| `say` | choice | the player's own line before the jump |

`--talk --auto` picks the first available option every time. With `once` on the content
branches that walks the whole conversation and falls out of the exit, so it doubles as
a coverage check: anything that does not appear in the transcript is unreachable.

### Why the screenplay is a file

The writer is not the programmer, and the joke depends on how long the silence runs.
Reordering beats, cutting a line or stretching a pause has to be possible without
touching the engine or waiting for anyone.

Beats understood today:

| beat | fields | does |
|---|---|---|
| `location` | `id` | switch backdrop, clear the stage |
| `enter` | `who: [ids]` | put people on stage |
| `say` | `who`, `text` | a line; waits for the reader |
| `action` | `text` | a stage direction, shown over the picture |
| `wait` | `secs` | hold — this is where the comic timing lives |
| `sfx` | `id`, `caption` | a sound; captioned until there is audio |
| `shake` | `secs`, `power` | the ship convulses |
| `flicker` | `secs` | the lights go |
| `end` | | stop |

An unknown beat is skipped with a warning, so a newer screenplay still runs on an older
build rather than crashing.

### Why the art is blocks

This build exists to find out whether the *scene* works — the running order, the length
of the pause, whether the two cooks rhyme. Blocks answer that as well as paintings do,
and art made before the timing is settled is art that gets redrawn. Every placeholder is
keyed by an id from the screenplay, so a real backdrop or character drops into the same
slot with nothing else changing.

Stage directions are printed over the picture for the same reason: the picture cannot
show them yet. They switch off in one place (`show_stage_directions` on Main) the moment
it can.

## Next

- A real room instead of two bands, and a character who can cross it. The gap between a
  character sheet and a character who walks is the biggest production risk in the
  project.
- The cruise-side cast. The premise's comedy is pirates against crew against guests, and
  only the pirates are designed.
- Audio: the pop is the first sound the game needs, and currently it is a caption.
