# Scene migration evidence

`baseline.png` and `baseline_layout.json` were captured before deleting the old
runtime construction. The JSON records the saved and runtime tree, transforms and
component types. The migrated cabin preserves all 18 saved object/environment/camera
transforms and its original framing. Default actors retain their original model and
animation sources.

## Implementation and checks

- Required GLBs, import settings and script UIDs preserved: `783d603`.
- Module contracts and owned location components: `033585d`.
- Game/location migration and builder removal: `b41e030`, `6b4e1d2`, `412e19b`.
- Reusable actor/prop/item resources and isolated materials: `c62de5b`, `9ed8920`.
- Authored UI, portraits, cold-open stage and audio: `6c4ed03`, `0c3a66b`.
- Saved picking shapes and renderer-safe hover teardown: `5d141c5`, `8a4e804`.
- Synchronized navigation and reliable transitions: `aacd113`, `82b2e48`, `6549bc7`.
- Strict runner, baseline/outdoor checks and failed-transition coverage: `9d68935`,
  `f34ec9e`; see `tests/README.md` for commands and current test coverage.

Checks exercise successful/unreachable/stuck/cancelled movement; interactions stay
busy through responses; choices clear shared flags; props retain local visual and
approach references; duplicate materials remain independent; location transitions
preserve session state and roll back on invalid navigation. A deliberately broken
test that prints success and exits zero is rejected by the runner.

Graphical Compatibility checks at 1920×1080 verified real Captain portrait animation,
scrollable long speech, wrapped keyboard-selectable responses, four inventory icons,
audio autoplay/looping and the complete cold-open return to gameplay. Baseline and
default-startup images differ by mean RGB 0.399/255, with 1.585% of pixels differing
by more than 5; shell, chest and sampled lower-floor areas are pixel-identical.
The small differences are actor animation timing; authored placement is checked
directly as well. Graphical logs/screenshots are preserved outside the project at
`C:/Users/Nikola/AppData/Local/cruises-tests/final-graphical-1300-730676/` and
`C:/Users/Nikola/AppData/Local/cruises-tests/cold-open-finish-17812-739989/`.

The first local full run exposed an old cached zombie scene depending on a removed
extracted JPEG. Removing only that imported `.scn`/`.md5` forced regeneration from
the versioned embedded-texture GLB; its dresser check then passed. Clean-checkout
verification must confirm that no extracted preview or stale cache is required.

## Final validation — 2026-10-11

Root HEAD `1ac5738` passed all 12 checks, the deliberately false-pass runner probe,
and exact authored source/asset/settings checks. Logs:
`C:/Users/Nikola/AppData/Local/Temp/cruises-checks-edaf726e6e9a44048c254ea16e5b66ab/`.

A managed worktree created from `8a4e804` had no `.godot` cache or local extracted
previews. Its first import and full 12-check suite passed, including dresser/rig,
navigation and baseline/outdoor composition. Logs:
`C:/Users/Nikola/AppData/Local/Temp/cruises-checks-455162bee080468380f05633f847e5e1/`.
The final test commit `61d663f` was then integrated there and its expanded
hover/rollback/teardown and asset/settings hash checks passed after editor import.
Logs: `C:/Users/Nikola/AppData/Local/Temp/cruises-checks-1cbcfded8ea74f0c8bfe70d21e39818d/`.

Module editing worktrees are archived with recoverable snapshots after integration.
Graphical evidence and prefab review records remain outside the archived checkouts.

## Remaining authoring decisions

The subsequent camera-only follow-up is complete: the authored camera is at
(0, 3.4, 6.2), pitch -17 degrees and FOV 62. All props are fully in frame and their
visual-centre clicks reach the correct hotspot. All 17 noncamera baseline transforms
remain unchanged. The original camera/baseline remains recorded; current framing
and picking checks cover this deliberate improvement. See
`locations/captains_cabin/HANDOFF.md` for measurements and graphical evidence.

1. Delivered modular body and coat GLBs have no joints. Bind and fit them to the
   measured donor before replacing the current animated world Captain. The workshop
   now supports isolated explicit outfit and assembled-scene outputs; this art
   acceptance work remains described in `docs/RIGGING.md` and `actors/HANDOFF.md`.
2. Moving static furniture requires an explicit editor navigation bake and save.
   Locations without navigation regions are deliberately nonwalkable; supplied
   regions must have usable baked geometry.
