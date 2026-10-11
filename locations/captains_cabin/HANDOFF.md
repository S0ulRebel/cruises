# Captain's cabin camera framing

## Current view — 2026-10-11 reference correction

Owner rejected the elevated all-props view against `docs/reference/room_target.png`.
Saved Camera now uses `cabin_reference_eye_level_v1`: `(0, 1.8, 5.5)`, pitch `-6°`,
vertical FOV `62°`. This lowers/closes the view and enlarges the actors. Foreground
crate extends past the right edge; its center is still visible and clickable.
All original noncamera root transforms, colliders and navigation remain unchanged.
Startup never resets the view. The artwork still differs in room width, furniture
proportions and character placement: exact composition needs a separate layout/art
pass and a navigation bake if static furniture moves.

Focused Compatibility preview: Captain bounds 418px high, Santi 296px; all eight
visual-center rays reach their own hotspot and the floor covers all three sampled
bottom points. Captures/measurements are outside the project in the current task's
`outputs/dialogue_fixes/after/` directory. Framing expectations were updated for the
larger actors and deliberate partial crate crop. Full suite not run at owner request.
Earlier measurements and validation below are historical.

## Previous all-props view

2026-10-11: the authored Camera uses `cabin_all_props_v1`: perspective at
`(0, 3.4, 6.2)`, pitch `-17°`, unchanged vertical FOV `62°`, at 1920×1080.
Only Camera properties changed. All 17 original actor/prop/environment root
transforms, navigation and UI composition remain exactly as recorded in the migration
baseline. Original camera and screenshots remain in `docs/migration/` as history.

The complete crate is now visible with approximately 75 pixels to the right edge.
The whole fishbowl and pedestal are in frame. Initial Captain placement no longer
blocks the inkwell: its visual-centre ray and actual mouse click hit its own Hotspot.
All seven prop interactions and Santi's interaction pass the same checks.
Camera height and pitch also keep the authored floor filling the lower view; lower
camera candidates exposed the grey space beyond its finite front edge.

Measured projected bounds: Captain 329 pixels high, Santi 254 pixels; both fall
within the art brief's 250–390-pixel gameplay target. The inkwell remains a small
13×10-pixel model and the compass approximately 16×7 pixels. Their click shapes
include the existing authored padding. Showing the complete location makes world
characters smaller than the original close view; the full-size dialogue portrait
and 1760×300 ledger retain their existing layout. The ledger overlays lower scenery
while speaking, as before. Fishbowl glass remains the existing dark material; this
camera-only change does not alter prop appearance or fitting.

`tests/authored_scene_check.gd` continues checking every noncamera baseline transform.
It separately checks the named camera profile, all prop/actor projected bounds with
24-pixel frame margins, actor readability, unoccluded visual-centre interaction rays
and lower-floor coverage. Ordinary startup/tests never reposition or save the camera.

Full import, all 12 checks and the deliberate false-pass runner probe passed. Authored
source/asset/settings hashes remained unchanged during validation. Logs:
`C:/Users/Nikola/AppData/Local/Temp/cruises-checks-f94ef279b68a4e6394936bcb8e79ef74/`.

Manual graphical evidence can be regenerated from the saved Game without changing it:

```powershell
& 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe' --path . --resolution 1920x1080 --script res://tests/cabin_framing_capture.gd
```

The harness verifies real mouse clicks for all eight interactions, then saves default,
inkwell highlight, speech and response screenshots plus picking coordinates to its
printed unique cache directory. It never saves under `res://`. Re-run it after any
default actor replacement to check the fitted model against the same composition.

Final NVIDIA Compatibility capture passed without engine/script errors. Evidence:
`C:/Users/Nikola/AppData/Local/cruises-tests/cabin-framing-23108-6279561/`.
Graphical log:
`C:/Users/Nikola/AppData/Local/Temp/cruises-framing-graphical-a652bc7ebd3b4ea6a5641fc3a94af796.log`.
Inkwell highlight uses its public mouse-entered signal after the real click assertion;
the input simulation avoids moving the user's OS cursor. Speech/responses retain the
existing animated Captain portrait and ledger. Camera measurements use
[Godot's projection and ray APIs](https://docs.godotengine.org/en/stable/classes/class_camera3d.html).

## 2026-10-11 — first cabin dressing pass

Owner requested arranging the finished objects and assigning scene textures before any further modeling. The saved cabin now has metre-density floorboards, walnut walls, textured ceiling, a finite burgundy rug with a shader-drawn gold edge, reused timber beams/posts/baseboards, and three independent chart rolls on the back of the desk. Additions are authored in `dressing.tscn`; nothing is built or positioned by startup code.

`materials/cabin_surface.gdshader` is a cabin-owned adoption of soft painted fake lighting, with linear OpenGL +Y tangent normals used in its actual illumination calculation. Existing shared library variants and VisualShader graphs are unchanged. Colour and normal share UV transforms: floor 2.4m per tile, wall 2m, carpet 0.8m. The finite rug border is shader colour, outside the unchanged repeating colour texture. Imported timber/roll surfaces use `dressing_material_binding.gd`, extending the library binding to preserve each original normal map in addition to its albedo and tint. No scene lights or texture light baking were added.

The native crate visual is adopted in its existing prefab, at its measured 0.9m envelope and identity child transform. The prior Tripo GLB remains available. Existing furniture/actor/camera roots, gameplay hotspots, colliders and navigation polygons are unchanged. New timber/rug/charts are visual dressing with no new blockers or gameplay behaviour; parsed navigation collision geometry is unchanged, so the existing bake is retained. The individual rolls remain separately reusable, not a fused bundle or new inventory rule.

Glass, water and Count Fingers now use painted/unshaded materials so the bowl is readable without engine lights. Model geometry, motion and placement are unchanged. Unshaded roughness is normalized to its unused default of 1 because Godot otherwise drops that property during material duplication, causing hover restoration values to differ.

Validation: all 15 headless checks passed, including original transform/framing, navigation, movement, puzzle combinations, two-instance hover restoration, portrait and material library checks. The graphical framing harness passed all eight actual hotspot clicks and saved default/hover/speech/response images. GPU normal on/off validation changed 4,323 sampled foreground-floor pixels, confirming shader consumption of the supplied normal data. No engine/script errors in successful final import, checks or graphical runs.

Generated colour tiles still have approximate edge continuity. Render was reviewed at the authored 1920x1080 camera; no pixel-perfect seamless claim is made. Fake lighting provides painted shading and a soft local colour pool, not geometry-aware cast shadows. This is the first dressing pass: future lantern/bookcase/globe/painting assets remain at their prior pipeline status. Blender editing sources are retained in `.gdignore` folders so importing the game does not require a local Blender installation.
