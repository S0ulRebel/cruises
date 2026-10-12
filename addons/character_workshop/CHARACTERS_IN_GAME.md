# Use a constructed character in a game

Workshop saves a visual assembly: editable parts, meshes, materials, skeletons,
skin weights, attachments, facial shapes and animations. It does not decide who a
character is or supply movement, dialogue, voice selection or portrait behavior.
There is no adapter API or game script field in Workshop Settings.

## Authoring and game scenes

1. Build and save the visual assembly in Workshop.
2. Instance that scene inside an authored game actor scene. Add your movement,
   collision, interaction and animation-control components there.
3. Instance the same visual assembly, or a deliberately authored head-only assembly,
   in a portrait scene. The game owns its camera, lights and speech behavior.
4. Open the visual assembly in Workshop when changing its parts. Open the containing
   actor or portrait in Godot's native editor when changing its gameplay behavior.

A game-owned character definition can associate an ID, name, visual/gameplay scene,
portrait and voice. Assign identity explicitly; never infer it from a mesh filename
or a list of parts. A game can build an ID lookup from these resources when needed.
Workshop requires no registry and reads none of those identity resources.

Cruises already has `systems/content/character_definition.gd`, used by game dialogue
and character presentation. Its definitions and speech systems stay outside this
addon. The game decides which clip, bone or blend shape drives speech.

## Runtime dependencies

Saved assemblies require only `runtime/assembly.gd`, `runtime/part.gd` and, when
using exclusion masks, `runtime/mesh_mask.gd`, plus their `.gd.uid` files. These
scripts contain metadata and read-only editor validation; they never construct,
rebind or save a character. Bones, Skin, ArrayMesh, AnimationPlayer and
BoneAttachment3D use Godot's native behavior. Keep the files referenced by the
character, including any scripts that were already part of imported source scenes.

The addon `core/` directory and editor UI can be excluded from a game export.
The test suite installs the addon in a clean project, saves an assembly and plays
the exported scene with all core/editor code excluded. Disabling the editor plugin
does not disable the saved character's rig or animation.

## Scope and limitations

Local facial rigs and facial shapes survive import, attachment, duplicate and save.
Weight copying and binding are explicit authoring operations. The humanoid fitting
backend still requires suitable hips/head landmarks and compatible bone names;
it does not automatically convert arbitrary facial rigs to another skeleton.

Legacy game conversion/export helpers are outside the addon and are not available
as Workshop buttons. Earlier path compatibility shims and adapter hooks were removed
during the construction-only cleanup; update old script references to the canonical
addon paths if reopening older WIP content.
