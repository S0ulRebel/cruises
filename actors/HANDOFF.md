# Actor module handoff

2026-10-11: CaptainLive and SantiWong roots are neutral. Location instances retain their
placement. Each prefab has one authored Agent with avoidance enabled and one disabled
Obstacle without carving flags. Santi owns the conversation Hotspot targeting its root.
CharacterDefinition resources preserve screenplay IDs live, santi and count separately
from asset IDs captain_live, santi_wong and count_fingers. Count Fingers animates Motion,
leaving its authored root transform intact. UI owns per-character portrait scenes.

The default world meshes and animation clips remain unchanged. GLB inspection measured
65 joints and 14 clips on captain_live_hands.glb; delivered pieces/body/body.glb and
coat/coat.glb contain no joints. head_face.glb has Head/Jaw, two joints and no clips.
Replacing the world Captain with those pieces requires the donor-fit acceptance check
in docs/RIGGING.md and measured garment fitting. This structural migration does not
claim that art work is complete.

The outfit workshop discovers current delivery paths and uses explicit, isolated
per-character/per-outfit outputs. Role-based pinned fitting/refitting and explicit
assembled-scene export were verified. See outfit/README.md for the authoring workflow.

Integration uses each Mover.definition; old cast placement/fitting tables are retired.
Captain's portrait_scene now points to ui/portraits/captain_live.tscn.
