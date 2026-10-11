# Captain's cabin camera framing

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
