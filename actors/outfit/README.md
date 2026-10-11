# Character Workshop and outfit compatibility

Use Godot's **Character Workshop** editor dock for new character assembly. The
plugin is enabled in this project. Open an existing assembly or choose a template
in the dock. [The assembly guide](../assembly/README.md) covers the full workflow.

Characters are ordinary editable `.tscn` scenes: freely named parts, native move /
rotate / scale handles, arbitrary parent and bone attachments, and independent
local rigs. There are no mandatory body-part slots or automatic clothing conflicts
in this workflow. The accepted world Captain, Santi and dialogue portrait retain
their existing authored scenes.

## Existing fit resources

**Import legacy outfit / fit** reads an `Outfit` or an individual `OutfitPiece`
`.tres` from any supported project destination. It prepares independent parts,
retains authored transforms and source provenance, and reports conversion limits.
An outfit supplies its own donor body; an individual fit needs an explicitly chosen
target afterward. Conversion does not change the original fit resource.

Legacy skinned fits retain their placement and metadata. Choose the intended donor
and run **Bind / Rebind** explicitly to produce deforming geometry. A face with
blend shapes retains its complete local rig; attach it to a bone. Donor conversion
rejects facial morph geometry rather than dropping its animation data.

`workshop.tscn` is the deprecated runtime slot-picker workflow. It starts empty and
exists for old-data compatibility. New assembly uses the editor dock; fixed slot
constants in `OutfitPiece` and `Dresser` are legacy resource/runtime interfaces.
They do not constrain `AssemblyPart` or the new dock. The legacy authoring scene
and the new editor plugin are excluded from game exports.

## Backend ownership and checks

`dresser.gd`, `skin_copy.gd`, `rig_space.gd` and `retarget.gd` provide the measured
humanoid fitting backend. Weight sampling uses reference/rest data, independent of
the current animation pose. Nearest candidates are checked against an exhaustive
regression fixture; generated legacy meshes use a bounded 16-entry cache.

Binding requires a supported hips/head frame and compatible bone names. Other rigs
can assemble and attach freely; they need an explicit landmark/retarget mapping
before body deformation or borrowed locomotion. Weight transfer is a starting fit,
not a guarantee that loose clothing deforms well in every pose. The dense bare body
and final garment art acceptance remain separate work.

Run `workshop_backend_check`, `dressercheck`, `workshop_integration_check` and
`workshop_legacy_check` through [the check runner](../../tests/README.md).

See [rigging decisions](../../docs/RIGGING.md) and [the local handoff](HANDOFF.md).
