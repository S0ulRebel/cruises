# Prop module handoff

2026-10-11: all existing model wrappers retain their authored transforms and real sizes.
The seven interactive props own Hotspot, InteractionShape and ApproachMarker children.
Visual and approach references are local; moving or rotating a prop carries interaction
and collision with it. Solid roots persist in nav_source. The glass/unlit components
also run in the editor and change only materials, never scene placement.

Integration must remove the seven former location-level hotspot copies. The corrected
fishbowl approach is in front of its present pedestal, rather than at the old desk.
Room-specific prose and puzzle settings can be overridden on the instance's Hotspot.

Verification: 11 prefabs load; local references, rotated markers and persistent groups
pass. Runtime checks must wait for navigation synchronization before map queries.
