# Character Workshop editor handoff

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
