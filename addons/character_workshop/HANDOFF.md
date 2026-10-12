# Character Workshop editor handoff

## 2026-10-12 — Workshop can be closed

Close Workshop returns to native 3D (2D for CanvasItem roots); the scene stays open.
Native 3D/2D tabs also leave. `_handles` only claims characters while the workspace
is already visible, preventing selection from reopening it. Scene changes defer a
root-ID-guarded close until after Godot restores per-tab main-screen state. Explicit
New/Open queue a guarded reentry afterward; the Workshop tab remains available.
Leaving restores temporary preview materials/poses and Focus mode, cancels fitting
and attachment/face tools, and suspends viewports. Authored fitting is unchanged.
Native fixture passes 239/239; integration plus cold reopen and references checks
pass with unchanged authored source hashes. Evidence:
`%TEMP%/cruises-checks-7908d030e25646359f128e5c099f2fe5/`.

## 2026-10-12 — complete portrait saves and binary meshes

The Workshop accepts a complete PortraitRig scene, keeping its camera/lights and
speech bindings. Open `ui/portraits/captain_live.tscn` for the game portrait;
`actors/assembly/templates/captain_portrait.tscn` remains the independent fitted
starter. A bare assembly/gameplay export cannot overwrite an existing portrait
renderer. Workshop view cameras remain editor-only.
Explicit Save/Save As uses mesh_storage.store before the native same-tab save.
Meshes, including shadow/mask source meshes, go to <scene basename>/meshes/*.res.
Source models/textures and PackedScene provenance definitions remain intact.
Existing outputs can only be overwritten when already referenced by the chosen
saved scene. ResourceSaver's temporary path is followed by take_over_path so native
scene saving keeps external references. Mutable mesh/material instance isolation
and edited material persistence survive cold reopen. No startup authoring writes.

All 24 checks/cold routes pass, with 227/227 native assertions and unchanged source
hashes. Evidence: `%TEMP%/cruises-checks-120bd94b08b34a43b6ab2bf251e6ea16/`.
Owner-fitted production template/game assembly are preserved exactly; their meshes
are independently stored as binary resources and their text scenes are ~7 KB.

Final staged-resource checks and native reopen also pass with unchanged hashes:
`%TEMP%/cruises-checks-0588cdbe45894802b33e03b3cf62a4b9/`.

## Reference images — 2026-10-12

The approved simple reference workflow is implemented. The second pane switches
between its original 3D camera and a 2D image with Fit, pointer-anchored zoom and
drag pan. Images… toggles a thumbnail board sharing the asset drawer's space.
PNG/JPEG/WebP references accept external file selection and project image drops.
Remove detaches the reference only. Per-character paths, selection and mode use
local EditorSettings project preferences; saved actor Body assemblies use their
owner's scene path. Pending dialogs verify the actual edited root. Templates and
game scenes receive no reference nodes/resources. Save is now labeled correctly.

Focused backend/integration checks and all cold-reopen routes pass, with authored
source hashes preserved: `%TEMP%/cruises-checks-1b43997c8be446a2832e7227ab7e68c1/`.
Latest owner-Body reference coverage is in
`%TEMP%/cruises-checks-7824f2ced1c244a9af6105b8d1c7b162/`.
Graphical native editor assertions pass 217/217; screenshots including references
are in `%TEMP%/cruises-reference-visual-ae0492e2c8354428b0b69313bf366f93/`.
Final graphical run after the exported-Body/packed-drop coverage also passes 217/217:
`%TEMP%/cruises-reference-visual-d6d16398c8f1491b936a73b79853672f/`.
`references.png` shows the owner-fitted Captain beside its design sheet, with the
save toast expired and all fitting controls visible.

At the reference feature handoff the owner's fitted template/live portrait were
large inline assemblies. The subsequently approved renderer/storage restoration
is complete; see the current section above.
Future overlays/pinned cards/design-sheet crops/portable bundles are in the plan.

## Approved usability follow-up — 2026-10-12

Implemented all ten approved points on `main`, with no graphical Godot session.
Native Save As retains the current tab, ordinary Save uses its destination, and a
stale dialog cannot save a different character. Shared read-only save validation
rejects source-path aliases. Hierarchy rows have eyes, inline rename/F2, a context
menu and drag-to-parent; placement, identities and native undo are preserved.
Rename rebases node paths and affected animation tracks in private libraries.

Fine adjust is an inline sidebar panel. World/Local move/rotate axes and adjustable
snapping are exposed; scale uses local axes. Attachment picking names source and
hovered destination, highlights candidates and provides Cancel. The hierarchy stays
visible while the asset drawer opens below the views. Asset search uses word prefixes,
with type/folder filters and source labels. Drops choose authored or cursor placement;
the preview marks the wrapper origin without instantiating a model. Internal model
transforms remain intact, and placement shares insertion's undo action.

Selection uses subtle corner marks; Grid/Bounds are optional. Focus restores the
prior native distraction-free setting on exit. More groups retained advanced tools
into Attachment/Geometry/Animation/Export tabs with contextual disabled states.

Validation: 213/213 native assertions, all 22 default checks, cold reopen routes and
runner false-pass rejection succeed with unchanged authored hashes. Evidence:
`%TEMP%/cruises-checks-3a572b89171f4c5ba843ccc99d2f07f9/`.
Visual layout/overlay/mouse usability acceptance is deferred while the owner trains
on the GPU. Existing body/clothing/neck art acceptance remains separate.

## Approved visual workspace — 2026-10-12

Delivered on the owner's `main` checkout after pulling `origin/main` to `6eda968`.
The old long dock is now a Character Workshop main-screen tab. The authored UI
keeps a dominant assembly view and optional independent detail view, actual nested
character hierarchy, searchable project thumbnails, top file controls and bottom
Move/Rotate/Scale/Attach/Duplicate/Remove actions. More opens the existing advanced
tools separately. Fine adjust applies exact local transforms with native undo.

`workshop_view.gd/.tscn` renders the current scene world with tool-owned cameras;
picking, gizmos and face overlays stay outside the assembly. Live drags restore
their initial transform before committing one native undo action and cancel on
scene/tool/selection/focus changes. Attach picks actual parts and preserves world
placement. Root selection transforms the whole character. Skinned picking uses
reference mesh triangles, so posed animation picking remains a separate feature.

`asset_browser.gd/.tscn` discovers project assets from EditorFileSystem without
a registry. Native previews or lazy representative-mesh previews stay in memory;
no source scene is instantiated for thumbnails and material overrides use private
mesh copies. Compound prefabs show their largest visible mesh. Explicit disk import
accepts self-contained GLBs, requires a chosen destination, rejects filename
collisions/external dependencies and waits for Godot import before adding a part.

Native editor checks pass 174/174, including two real scene views, nested/collapsed
hierarchy, root selection, drag/precise-transform undo, picked attachment undo,
asset search, import validation and existing save/cold-reopen routes. All 22 default
checks and the engine-error rejection self-test pass. After the thumbnail fixes,
editor/integration/cold reopen/authored checks pass again with source hashes intact.
Final GPU capture passes 174/174 with no engine/script errors; workspace, hair/chair
thumbnails and Fine adjust images were reviewed.
Evidence: `%TEMP%/cruises-checks-8886df44ee964b44917681864e669c83/`,
`%TEMP%/cruises-checks-c4a8b69c52474907a6455d990aa0c8c2/` and
`%TEMP%/cruises-workshop-final-109c40bcbfd24286b2be2a64d43193f1/`.
Production art and the accepted dialogue portrait remain independent. Final body,
garment deformation and neck-seam art acceptance remain in the shared plan.

## Earlier foundations

2026-10-11. Editor scope only; integration enables the plugin and owns services/templates.

Template workflow correction: New empty and New from template open independent,
unsaved native editor scenes immediately, preserving existing tabs. No upfront
destination dialog or authoring save. Godot's configured native New Scene shortcut
creates an empty tab before public EditorInterface.add_root_node installs the copy.
Save As and Open retain their respective explicit destination/source dialogs.
The template chooser resets after creation so the same starter can be used again.

- Authored `dock.tscn`; native scene tree, Inspector, transform tools and UndoRedoManager.
- Arbitrary file add/drop/adoption, independent duplication, hide/remove/replace, actual
  node/bone targets, whole local rigs, free detach and preserved world placement.
- Native adoption initializes the core's imported-composition boundary once. Undo restores
  original nested identities/group metadata; redo reuses the same initialized values.
  Duplicates retain that authored nested composition and independently identify its parts.
- Dependency graph includes external skins/provenance. Remove-all includes external
  parts; keep-free cannot orphan a donor. Reconnect validates existing rig correspondence.
- Source-space face click/region/surface preview, reversible masks, faithful surface
  overrides, explicit collision invalidation and reset/undo restoration.
- Mesh selectors, statistics and collision changes stay within the selected part;
  attached parts retain their own geometry/collision. Multiple masks share the original
  collision baseline, so restoring the final mask restores pre-exclusion collision.
- Explicit path dialogs, template discovery, reopen regular assemblies/exported actors,
  independent preview animation/materials, legacy fit conversion and prepared clip install.
- Async binding progress/cancel; shutdown calls the service's explicit cancel/join API.
- Native hierarchy changes expose an explicit undoable reference repair; no startup fixes.
- Root core reference snapshots remain opaque and include mask correspondence; duplicates
  rebase after insertion. Carriers are retained only in the proper do/undo history direction.

Native Godot 4.7.2 plugin-enabled fixture checks pass 125/125 with engine errors treated as failure;
separate cold process checks saved mask, rig, materials, collision and clip independence.
The 16 creation-flow assertions cover immediate unsaved characters, existing tabs,
repeated independent copies, source preservation and the retained Open/Save As dialogs.
Workflow evidence: `%TEMP%/cruises-checks-e4f55424f02b480eb0b0bafc1c525dfc/`.
Authored-scene and workshop integration/cold-reopen checks also pass:
`%TEMP%/cruises-checks-ac9e3e05b0e144f38b82a54340b443a9/`.
Logs are external under the agent's Temp diagnostic paths. Production source art, scenes,
project settings and global docs are not part of this module commit. Imported resources
in this isolated worktree generated their normal cache/embedded previews; none are staged.

Integration should complete native visual acceptance, real clothing worker/cancel/close,
legacy conversion dialog checks, gameplay exports and the complete multi-scene reuse.
Mesh selection is practical reference-space clicking/region intersection, not modeling;
seam reconstruction remains an explicitly authored external art operation.

## 2026-10-12 — portable plugin

Canonical generic implementations and original UIDs now reside in runtime/core.
Old actor helper paths are compatibility shims; tracked consumers use CW classes.
Settings configures per-project folders and an optional adapter without writing on
load. Cruises retains its own templates, portrait handling and captain animation
namespace through an external adapter. ZIP installation in a fresh project passes
19 native assertions and six separate-process runtime assertions with the editor
plugin disabled. Logs: `%TEMP%/workshop-portability-060e02ebec404ad1a387049c81530cbb/`.
All 25 checks, native editor assertions, cold routes and source hashes pass:
`C:/Users/Nikola/AppData/Local/Temp/cruises-checks-86994ffc6c6b4e3cbfc5306f3b8b66ab`. Exported fresh-project PCK also passes the six cold runtime checks.
Captain template and portrait assembly preserve all 23 nodes, transforms, mesh
arrays/shapes, skins and bone poses; binary resources retain their pre-migration hashes.
Cruises export exclusions retain runtime/core while excluding editor UI.
