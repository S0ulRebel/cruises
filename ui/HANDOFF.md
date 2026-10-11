# UI, cold-open stage and audio handoff

## 2026-10-12 — portrait mesh shading repair

Inspected the assembled portrait and the original/rigged head GLBs, rather than
inferring correctness from renderer instance counts. The head is one mesh;
hair/hat/moustache/chin are separate accessories. Hair contains a solid brown
fill behind the face opening, but part-color isolation shows no second visible
skin face. The moustache/chin extracts do not contain another head.

The concrete defect is in the rigged head's base normals: all 40,395 rigged
corners match the original position and UV, but 29,895 normals differ (90th
percentile angle 22.91 degrees). The rigging derivative lost the original smooth
shading, creating jagged ridges on the left temple/cheek and neck. Restoring the
authored normals removes those shading ridges in direct GPU comparisons.

The portrait now references `portraits/captain_live/head_face_normals.glb`, a
UI-local derivative made with `tools/restore_mesh_normals.py`. Only base NORMAL
bytes change: topology, vertex positions, UVs, skin weights/binds, three facial
morph targets and embedded texture bytes remain unchanged. Both original head
assets remain intact, as do authored fitting and world actors. `fit.json` records
the sources, hash and reproducible command.

Focused Compatibility captures compared identical speech poses (0/35/65/100%)
and resting pose, with and without the correction. The live caption shows the
smoother face and speech remains functional. No full suite run. Owner review of
the reported appearance is still the visual acceptance step. Evidence is in this
task's external `outputs/portrait_mesh_trace/` directory.

## 2026-10-12 — head renderer resource isolation

Owner clarified the doubled outline is on the small dialogue head and requested
checking the earlier room/portrait sharing issue. Each TalkingHead now has a
scene-local World3D/Environment, used directly instead of cloning a shared saved
World3D through `own_world_3d`. Captain portrait environment is scene-local too.
The viewport explicitly clears every render. On character load, its animated face
Mesh and Skin are copied for that portrait instance; source geometry/materials,
authored fitting, and the room actor are unchanged. Cached reuse retains the copies.

Focused runtime inspection confirms separate world scenario RIDs from the room
and each other, separate World3D sources, and separate face Mesh/Skin resources
for speech and response heads, without engine errors. The old effective worlds
were already separate, although their source World3D and head resources were
shared. This removes that sharing path; it is not proof that the reported visible
outline has disappeared. No full suite run. The earlier active-portrait guard
alone did not resolve the owner's visual report; don't mark that report accepted
solely from resource counts. Diagnostic log is outside the project in the current
task's `work/portrait_worlds_after.log`.

## 2026-10-11 — response hover and ribbon corrections

Choices open without automatic first-row focus: deferred focus had scrolled the
first response above the clip region before layout settled, and kept it highlighted
alongside hovered rows. Mouse motion releases row focus; Up/Down/Tab deliberately
begins keyboard navigation. Number shortcuts/native confirmation remain available.
Rows now fit the label's measured minimum height plus 4px padding (44px minimum),
including wrapped text. Removed the redundant left chevron/native focus outline.
Ribbon text is centered at size 26, whose 39px height fits its 40px safe area;
the former size 36 needed 54px and extended below the ribbon.

Only one `dialogue_portraits` group member stays active. Dismissal hides its cached
rig and suspends rendering; reopening restores it. Both portraits already have
independent World3D instances. The reported doubled Captain was not reproduced in
isolated speech, animated poses or transitions; this prevents active overlap but
does not establish the original cause. Authored portrait fitting is unchanged.

Focused Compatibility previews at 1920x1080 verified visible text-center hover,
no default focus/scroll jump, wrapped row fitting, keyboard entry, ribbon metrics,
suspended speech portrait during responses and successful reuse. No engine/script
errors. The full suite was not run at owner request. Captures/observations are
outside the project in the current task's `outputs/dialogue_fixes/after/` directory.

Fixed presentation nodes live in saved scenes. Runtime instancing is limited to variable inventory/response entries, selected item models, and whole character portrait scenes. Scripts preserve edited layout, camera and accessory transforms.

## Integration
- Instance `ui/caption.tscn`, `ui/choices.tscn`, `ui/inventory.tscn`, `ui/pointer.tscn`, `stage/stage.tscn`, `cutscene/cutscene.tscn`, and `systems/audio/audio.tscn`.
- Call Caption and Choices `set_characters(Array[CharacterDefinition])` before use. Assign each definition's `portrait_scene`; Captain Live uses `ui/portraits/captain_live.tscn`.
- Call Choices `set_player(person: Dictionary)` before `ask`. The dictionary has `assets`, `name` and `colour`, matching `CharacterDefinition.cast_entry()`.
- Call Inventory `setup(GameState)`; state owns held items and selection. Item definitions own names, descriptions and `model_scene`. `ItemIcon.of(id, host, definition)` requires that definition.
- InputMap actions: `dialogue_continue` (Space/Enter) and `inventory_toggle` (I). Native response buttons support keyboard focus/confirm; number keys choose responses.
- Existing Caption/Pointer/Stage/Cutscene public behavior APIs remain. Cutscene now passes the location ID to Stage; cold-open figure placement and speaking animation are serialized.
- Audio `Music.autoplay`, stream and volume are authored in the prefab. Music looping is authored as `loop=true` in the existing quarters-theme import settings; `play()` and `stop()` remain.

## Authoring
The ledger uses the unchanged supplied frame atlas, native fonts, transparent live portrait, fixed 1760x300 panel, scrollable speech/choices, native atlas scrollbar/controls, proportionate ribbon/highlight nine-patches, and explicit Continue. Other characters require authored portrait prefabs using `ui/portraits/portrait_rig.gd` and exported skeleton/face/jaw paths. Missing portrait content shows the saved name placeholder.

## Validation
Godot 4.7.2 headless scene smoke instantiated twelve module scenes and checked authored face rig, camera transform, shared inventory state, response completion and two/three actor stage layouts. Input checks verified scroll never advances, Continue reveals before advancing, manual scroll-back is preserved, keyboard response selection and row cleanup. Graphical Compatibility checks rendered long speech and wrapped responses at 1920x1080, and repeated normal deferred portrait swaps without renderer errors.

## Captain frontal portrait — 2026-10-11
`portraits/captain_live.tscn` now fits the separate delivered head, hair, hat and face
parts against the approved turnaround. Hair sits behind the eyebrows; the moustache
sits below the nose. UI-local extracts split the original face source into moustache
and chin tuft. Native Head/Jaw attachments keep the moustache fixed and move the tuft
with speech. The assembly pivots at the Head joint with a small 3-degree chin-up tilt;
yaw/roll remain frontal. Select Assembly to adjust the connected portrait orientation,
or the individual authored part to adjust its fit. The full hat and feather fit the
224-pixel viewport. Sources, exact fit and explicit extraction commands are recorded
in [fit.json](portraits/captain_live/fit.json). No runtime fitting or source regeneration
was added. Original art and the world actor/body remain unchanged.

`portrait_check` covers the actual Caption/Choices interfaces, independent/reused rigs,
local-transform preservation, jaw/tuft movement, settling, framing and teardown.
Compatibility GPU captures verify visible speech motion in the actual dialogue panel.
The existing source head is modelled with an open mouth; fitting cannot make it fully
close without replacing the source art. Body topology work remains deferred by the owner.
