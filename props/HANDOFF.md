# Prop module handoff

2026-10-11: all existing model wrappers retain their authored transforms and real sizes.
The seven interactive props own Hotspot, InteractionShape and ApproachMarker children.
Visual and approach references are local; moving or rotating a prop carries interaction
and collision with it. Solid roots persist in nav_source. The glass/unlit components
also run in the editor and change only materials, never scene placement.

Integration removed the seven former location-level hotspot copies. The corrected
fishbowl approach is in front of its present pedestal, rather than at the old desk.
Location-specific prose and puzzle settings can be overridden on the instance's Hotspot.

Verification: 11 prefabs load; local references, rotated markers and persistent groups
pass. Runtime checks must wait for navigation synchronization before map queries.

Follow-up picking verification: interactive collision volumes are saved from each
Model's transformed bounds, with small click padding. The rapier uses separate blade,
guard and grip boxes so its empty AABB corners cannot cover the compass. The desk's
click volume ends at local y=0.72 below its separate tabletop props. Model, Hotspot
and ApproachMarker transforms are unchanged. All seven visual-center rays and
actual mouse inputs select their own Hotspot in a temporary prefab test scene.
Default camera/placement remains exact: the inkwell is behind the player's collision
body initially, the crate is outside the view, and the fishbowl is partly outside.
These are remaining scene-framing decisions, not runtime placement changes.

Hovered-prefab teardown also retains temporary per-instance material references for
one SceneTree process frame while Godot deletes their mesh RIDs. Original material
settings still restore on exit; no resources or nodes are created for this lifetime
hold. Two-instance highlight isolation/restoration and freeing highlighted bowls
pass in both headless and NVIDIA OpenGL compatibility runs with no engine errors.

## 2026-10-11 — native models and painted bowl adoption

Owner authorized arranging existing completed models in the cabin before more modeling. Added neutral reusable `timber_beam`, `wood_board`, and `chart_roll_01/02/03` prefabs with metre-scale GLBs. The cabin's saved dressing instances own placement and fake-light bindings; these prefabs remain reusable elsewhere. Each roll is one separate 0.60x0.04x0.04m asset.

Supply crate Model now references `art/props/supply_crate/native/supply_crate.glb`, the owner-approved 0.9m Blender trial, at identity scale. Previous Tripo asset remains untouched. Existing crate collider, hotspot, approach, stencil wording, rapier/key combination and flags are preserved.

Fishbowl adds exported `painted_glass` (default true), unshaded water and a local Unlit component explicitly targeting Count Fingers' existing Model. `roughness` remains the physical-glass control when painted_glass is false. Painted glass and all Unlit copies normalize unused roughness to 1 so Godot material duplication preserves exact hover/restoration values. Source models, material geometry, transparent tint and actor motion are unchanged.

All 15 headless checks passed, including independent two-bowl hover restoration and teardown. Real graphical clicks pass for all eight interactions. This delivery adds no new roll inventory pickup, colliders, or animated crate opening.
