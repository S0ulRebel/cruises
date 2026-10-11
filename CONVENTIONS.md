# Conventions

Where things go in this project, and why. Written now because the game is about to stop
being small, and because the alternative is deciding it once per file and getting a
different answer each time.

Three sources, in this order of authority:

1. **The owner's rule** (below, Part 0). It overrides anything else here.
2. **Godot's own documentation** — [project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html).
3. **`D:\code\pillage_people\CONVENTIONS.md`** — the sister project. Where that document
   and this one cover the same ground, they say the same thing on purpose.

Community practice ([abmarnie](https://github.com/abmarnie/godot-architecture-organization-advice),
[Simon Dalvai](https://simondalvai.org/blog/godot-best-practices/)) agrees with both and is
followed where it adds something; it is not an authority on its own.

---

## Part 0 — Placement lives in the scene, not in code

**Every prop, every character and every light is a node in a scene file, placed where it
goes, and movable by dragging it in the editor.** Nothing that has a position in the world
is created by a script at startup.

This is the rule the project currently breaks worst: `main.tscn` is a single empty
`Node3D` and all 1,183 lines of `main.gd` run at `_ready` to build the cabin — desk, chair,
crate, chest, porthole, fishbowl, the fish, both characters, every hotspot. The owner
cannot move the chair without editing a `Vector3` in GDScript, rendering a screenshot, and
looking at it. That is not a workflow; it is a guessing game, and this document exists
because of it.

What follows from it:

- **A room is an authored scene.** `rooms/captains_cabin/captains_cabin.tscn` contains the
  floor, the walls, the navigation region and an instance of every prop and actor in it,
  each with its own transform. Opening it shows the room.
- **Scripts find nodes; they do not make them.** A script reaches what it needs through an
  `@export` node slot or a group, never by instancing a `PackedScene` and positioning it.
- **Code may still spawn what has no fixed place** — an item the player drops, a particle,
  a piece of UI. The test is: *would a human ever want to drag it?* If yes, it is in the
  scene.
- **A number that only exists to correct an asset is not placement, it is a bug.** See
  Part 4.

## Part 1 — Where files go

**Organise by thing, not by file type.** A `scenes/` folder beside a `scripts/` folder is
tidy with nine files and unusable with two hundred: every edit means finding the same name
in two places and keeping them in step. A thing owns a folder, and everything belonging
only to that thing lives in it. This is Godot's own advice — "group files around scenes" —
and pillage_people's.

```
res://
├── main.tscn  main.gd           the entry point, and the orchestrator only
├── rooms/                       authored places
│   └── captains_cabin/          captains_cabin.tscn  captains_cabin.gd
├── props/                       things placed in a room
│   ├── captain_desk/            captain_desk.tscn
│   ├── supply_crate/  pirate_chest/  fishbowl/  bowl_stand/  porthole/
│   ├── rapier/  key/  compass/  brass_inkwell/  captain_chair/
│   └── parts/                   hotspot.gd, approach.gd - shared by every prop
├── actors/                      things that act
│   ├── captain_live/            captain_live.tscn  captain_live.gd
│   ├── santi/  count_fingers/
│   └── parts/                   mover.gd, animator.gd, fish.gd
├── ui/                          caption/  portrait/  inventory/  pointer/  choices/
├── systems/                     dialogue/  speech/  audio/
├── art/                         models, textures, sheets - DATA ONLY
├── data/                        .json and .tres the game reads
├── tests/                       flat, named after what they check
├── tools/                       python and blender, not shipped
└── docs/
```

### The rules

**1. A thing owns a folder.** Its scene, its script and any resource only it uses sit
together. Never `scenes/rapier.tscn` paired with `scripts/rapier.gd`.

**2. Files are named after their folder.** `rapier/rapier.tscn`, not `rapier/prop.tscn`. A
folder whose files are named something else is a folder you have to open to identify.

**3. `art/` is data. If it has a `.gd`, it is not art.** Imported models, textures and
reference sheets go there and nothing in it is loaded as code. A prop's *scene* lives in
`props/`, even though its *mesh* came from `art/`.

**4. snake_case for files and folders, PascalCase for node names.** Godot's own rule. The
PCK filesystem is case-sensitive even when Windows is not, so a capital letter that works
here breaks the export.

**5. Name a thing for what it is, not the role it plays.** `supply_crate`, not `crate_2`.

**6. Third-party code goes in `addons/`**, with its licence.

**7. `tests/` is flat**, named after what it checks — `combocheck.gd`, `navcheck.gd` —
because tests cut across folders and mirroring the tree means picking one owner for a test
that has several.

## Part 2 — How scenes are built

**One controller script per scene, on the root, named after the scene.** `captains_cabin.gd`
sits on the root of `captains_cabin.tscn` and on nothing else.

**A scene is self-contained and must run on its own.** If it only works under one
particular parent, it is a fragment, not a scene. Anything it needs from outside arrives
as an `@export`, which is also what lets the owner wire it in the editor.

**A controller touches its own children and no one else's.** No `get_node("../Sibling")`,
no walking the tree for a cousin. Call down, signal up.

**Don't make a scene out of two nodes with no script.** A `MeshInstance3D` with a
`StaticBody3D` under it is three clicks; a scene file for it is a file to keep in step.

## Part 3 — Where behaviour goes

**One component, one noun.** `Mover`. `Animator`. `Hotspot`. If the name needs "and" or
falls back on "Manager", it is two.

**Components never reference each other; the owner wires them.** A component that connects
to a sibling's signal knows that sibling exists, which is the coupling you were removing,
moved sideways.

**Extract on the THIRD user, or on a bug — never in advance.** One user is a feature, two
is a coincidence. The strong signal is the same idea existing twice and having drifted,
because that has already cost you something.

**A component that cannot work says so once, loudly** — `push_error` and a flag, never a
silent `return` that does nothing every frame forever.

**Static typing everywhere.** Typed GDScript is checked at parse time and runs faster.

## Part 4 — Assets

**Models point -Z.** Godot points a node's `-Z` forward, so a model faces `-Z` in the file.
When it does not, **fix the file** with `tools/reorient_model.py` — never with a
compensating rotation in code.

This project has three of those compensating rotations right now: `spin` on the chest,
`lie_flat` on the compass and the rapier, and `FISH_REST` on Count Fingers. Each exists
because a Tripo export landed on its back or its face, and each has to be rediscovered by
rendering the game and squinting. They come out as the assets are reoriented.

**Measure which end is which; do not infer it from shape.** Count Fingers cost an hour of
pitching and yawing because a render that looked like a level fish in Blender said nothing
about where he lands in Godot — Blender's glTF importer turns the file to its own Z-up on
the way in. The reliable test is in the engine, at full resolution.

**Every generated prop carries an `asset.json`** with `dimensions_m`, so the engine scales
it from its real size rather than from whatever Tripo normalised it to.

## Comments

Explain **why**, not what. The code says what. A comment earns its place by recording
something the next reader cannot recover: a measurement, a constraint, or a thing that was
tried and did not work.
