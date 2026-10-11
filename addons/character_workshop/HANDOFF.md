# Character Workshop editor handoff

2026-10-11. Editor scope only; integration enables the plugin and owns services/templates.

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

Native Godot 4.7.2 plugin-enabled fixture checks pass 109/109 with engine errors treated as failure;
separate cold process checks saved mask, rig, materials, collision and clip independence.
Logs are external under the agent's Temp diagnostic paths. Production source art, scenes,
project settings and global docs are not part of this module commit. Imported resources
in this isolated worktree generated their normal cache/embedded previews; none are staged.

Integration should complete native visual acceptance, real clothing worker/cancel/close,
legacy conversion dialog checks, gameplay exports and the complete multi-scene reuse.
Mesh selection is practical reference-space clicking/region intersection, not modeling;
seam reconstruction remains an explicitly authored external art operation.
