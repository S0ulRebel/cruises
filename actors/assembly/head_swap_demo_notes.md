# Editable head-swap example

Open `templates/head_swap_demo.tscn` in Godot. The ordinary authored scene contains
Body, SpeakingHead, Hair, Hat, Moustache and ChinTuft parts. Select their part roots
to move/rotate/scale or reattach them through Character Workshop. The complete
speaking head keeps its local Head/Jaw skeleton, skin, materials and three facial
blend shapes. Hair, hat and moustache follow local Head; the chin tuft follows Jaw.
The complete assembly can be saved and reused in another scene.

The body is the existing 52-bone Zombie donor, used as a functional starter because
its fused skull and elongated lower jaw make the difference between removing a part
and excluding faces visible. It is not replacement body art for the accepted Captain
or a gameplay placement. The accepted portrait and all original assets remain intact.

## Authored exclusion and restoration

`Body.geometry_masks[0]` records the original mesh, topology fingerprint, exact source
triangle ordinals, source node path, GLB SHA-256 and both manually selected regions.
The derived body mesh is saved under `templates/head_swap_demo/`. There is no runtime
generator, bone-weight head detection, startup conversion or source GLB rewrite.

Reference-space boxes in metres (the Zombie mesh is upright, Y up, at rest):

- Upper skull: `AABB(-0.30, 1.52, -0.30, 0.60, 0.40, 0.60)`.
- Long front jaw/teeth: `AABB(-0.10, 1.28, 0.07, 0.20, 0.32, 0.26)`.

Their union excludes 1,269 of the source's 4,630 triangles; 3,361 remain. Selecting only
the upper box left the Zombie's lower jaw visible, so GPU review drove the second
front-region selection. The upper/rear neck below Y 1.519492 remains. UVs, all bone
indices and skin weights remain unchanged, and the complete skeleton is retained.
Unused source vertices stay in the derived array to preserve attribute correspondence;
excluded faces have no draw/picking indices. Stale shadow/LOD geometry is discarded.

Select Body and use Restore geometry in the workshop to recover the original fused
head. Undo/redo keeps both authored meshes intact. Reapplying the stored source-face
mask yields the saved derived mesh. Save only to your explicit character destination.
Source topology must be checked again if the donor GLB is replaced/reimported.

## Measured attachment and fit

Zombie source bounds are approximately `(-0.765462, 0, -0.180703)` to
`(0.765462, 1.8, 0.180703)`. Its Head rest origin is
`(0.002651, 1.590358, 0.003003)`; Neck rest origin is
`(0.002651, 1.428560, -0.074379)`.

The Captain head mesh is approximately 0.9995 m tall before fitting. The complete
portrait assembly is scaled uniformly by 0.30, with its own authored accessory fits
preserved. Its pivot is the donor Head origin shifted down 0.015 m, cancelling the
donor bone's rest orientation while retaining the portrait's 3-degree frontal tilt.
The Captain neck base sits near Y 1.484 and overlaps the retained donor neck rather
than floating above it. This offset is authored on SpeakingHead and remains editable.

The Jaw rest rotation must be retained when posing the local rig. The verified test
uses the same composition as `ui/talking_head.gd`: Jaw rest orientation multiplied
by a 12-degree local X rotation. Replacing that orientation with an identity-axis
quaternion flips/distorts this imported rig; attachment does not cause the distortion.

## Validation and visual limits

Godot 4.7.2 checks pass: 59 initial/same-session authoring assertions and 31 assertions
in a separate process reopening the explicitly saved character. Checks cover absent
skull/jaw triangles, recoverable source, restore/undo/redo, retained neck, UV/skin
attributes, materials, six identities, local rigs/shapes, body-head pose following,
Jaw/chin-tuft motion, explicit saves, cold reopening and source SHA-256 preservation.

```powershell
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/workshop_head_swap_check.gd
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/workshop_head_swap_check.gd -- cold <printed-COLD_SCENE_PATH>
```

Compatibility GPU renders were reviewed from front, three-quarter and an 18-degree
body-head/12-degree jaw pose. Evidence is outside the source project at
`C:/Users/Nikola/AppData/Local/Temp/cruises-headswap-c1b8c029abfe4509a3c2b11064eb7872/`
(`front_full.png`, `front_head.png`, `three_quarter_head.png`,
`turned_head_open_jaw.png`, plus original-Zombie comparison images). Rendering scripts
and the one-off explicit authoring script are external and are not shipped.

This proves editable head replacement and pose following, not final neck art
acceptance. The two donors have different skin colors, neck proportions and topology;
the visible color seam and open/jagged cut still need art review. Masks do not cap or
retopologize the neck. A matching body or an explicitly saved Blender-derived seam is
needed for production artwork; broad pose/animation acceptance remains separate.
