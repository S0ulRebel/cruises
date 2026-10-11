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
