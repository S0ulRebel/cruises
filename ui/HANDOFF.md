# UI, cold-open stage and audio handoff

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
