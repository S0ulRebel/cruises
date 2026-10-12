# Character visual assemblies

Open **Character Workshop** in Godot to assemble a reusable visual character.
This folder contains Cruises templates and their mesh resources. The reusable tool
is entirely under `addons/character_workshop/`; see its README for the full guide.

## Construct and save

1. Choose **New empty**, a template, or **Open** an existing assembly scene.
2. Use **Add part** to browse assets. Parts can contain complete local skeletons,
   skinning, animation players, materials and facial blend shapes.
3. Move, rotate, scale and attach parts freely. Bone attachment keeps a head's local
   facial rig intact. Use explicit **Bind clothing** for donor weight copying.
4. Use reversible mesh exclusion to hide fused source geometry. Source GLBs remain
   untouched; local masks keep original geometry for restore/reset.
5. Save to an explicit `.tscn` path. Private derived meshes save beside it as binary
   `.res` files. Reopen that visual scene to continue editing.

**Settings** configures asset/template/save folders and a generic animation library
name. There are no fixed equipment slots, automatic body replacement or game adapters.
The current project uses `workshop` for newly borrowed clips; existing clips retain
their authored names. Nothing renames existing animation libraries on load.

## Use in Cruises

Instance the saved visual assembly inside an authored game actor or portrait scene.
Movement, collision, navigation, dialogue, camera framing and speech belong there.
Open those containing scenes in Godot's native editor. Workshop opens the separate
assembly component, such as `ui/portraits/captain_live/assembly.tscn`.

`systems/content/character_definition.gd` provides the game's identity/presentation
resource. No mesh-name lookup or global Workshop character registry is involved.

The developer-only game exporter and old outfit converter now live under `tools/`
as `character_actor_export.gd` and `legacy_outfit_import.gd`. They are not part of
the addon or game export. Existing WIP art remains reusable without compatibility
shims or special Workshop portrait behavior.

## Runtime and validation

Saved characters use the addon's three small runtime metadata scripts and native
Godot meshes, skeletons, skins and animation. They do not load Workshop editor/core
authoring code to animate. Keep imported content's own script/resource dependencies.

Regression checks cover whole local rigs, facial shapes, weight copying, independent
duplicates, bound clothing, geometry masks, undo, saved resources and cold reopening.
Binding still needs supported humanoid rig landmarks; neck seam reconstruction is
an art task rather than automatic fitting behavior.
