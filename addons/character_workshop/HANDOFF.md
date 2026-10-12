# Character Workshop editor handoff

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
