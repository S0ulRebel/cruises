# Character Workshop

Enable **Character Workshop** in Project Settings → Plugins. Its authored dock
uses the ordinary Godot scene tree, 3D transform handles, Inspector and undo history.
There are no fixed clothing slots or mandatory filenames.

## Assemble a character

1. Choose **New** or an editable template, then choose a new `.tscn` destination.
   **Open** accepts another saved assembly. Exported gameplay actors with an authored
   `Body` assembly can also be reopened and edited.
2. **Add model / prefab** accepts imported 3D models and ordinary scenes anywhere in
   the project. Drop files on the dock, or drag a model into the native scene tree
   and use **Adopt selected**. Every instance has an independent stable identity.
3. Select its part in the dock/scene tree and rename it freely. Use the native move,
   rotate and scale tools or Inspector. Expand `Model` to edit individual descendants.
4. Choose free placement, parenting to any actual node, or any bone in any actual
   skeleton. **Attach / Apply** and **Detach** preserve world placement. The entire
   imported Model remains intact, including local rigs and facial blend shapes.
5. Duplicate, hide, remove or replace parts with native undo/redo. Dependents require
   an explicit choice: keep them free, remove all, or reconnect matching targets.
   External skinned garments count as dependents too. Keeping one without its donor
   is rejected; reconnecting requires compatible bone names/order/rest poses.
6. Use **Save As** for a validated explicit reusable-scene destination. Derived
   meshes and masks are embedded in that scene; source GLBs are never rewritten.
   **Save gameplay actor** deliberately adds movement/collision components through
   the export service. Static assemblies need no gameplay services.

After native scene-tree renames/reparenting, the dock tracks retained target objects
and enables **Repair moved / renamed references** when paths need repair. This is
an explicit undoable action. Use it before the dock's validated Save As/export.
Opening a scene never silently repairs its paths. Targets already missing on opening
must be selected again; the tool cannot infer a deleted rig.

## Remove fused geometry

Select a part, then its mesh in **Reversible mesh exclusion**. Enable reference-pose
selection and click faces in the native 3D viewport. The Add/Subtract switch edits
the selection. Alternatively choose a mesh-space centre/size region or whole surface.
Orange overlays preview selected faces, including excluded source faces for restoration.
**Exclude**, **Restore** and **Reset mesh** are undoable and retain the original mesh.
Disable face mode to resume ordinary transform handling; viewport input is otherwise
untouched. Existing collision in a changed part is disabled deliberately, with its
original state retained for reset/undo. Author suitable replacement collision explicitly.
Geometry controls list only meshes owned by the selected part. Select an attached part
separately to change its mesh; exclusion does not disable that attachment's collision.

Masks identify source faces and retain a fingerprint. Stale masks fail validation;
old face indices are never applied to an unrelated mesh. UVs, materials, skin weights
and facial shapes are preserved by the mesh service; source surface overrides follow
the returned surface mapping. Exclusion does not cap holes or guarantee a neck seam.

## Clothing and preview

**Bind clothing** is a requested conversion to the chosen donor. Progress and Cancel
are available. The original whole Model is retained by undo and binding provenance.
Binding rejects facial conversion, unresolved dependencies and existing exclusions;
reset exclusions before binding and reapply them to the resulting mesh.

Animation players and clips are discovered from actual nodes. Preview libraries are
independent copies; loop is deliberate, and gameplay method/audio tracks are suppressed.
Stop, save and scene changes restore original poses/libraries/materials. Fitting a part
can continue during animation. Original materials are the default; neutral shading is
temporary. Borrow compatible clips explicitly from a chosen model. Import saved legacy
fits/outfits from arbitrary paths; conversion warnings identify required donor rebinding.

## Verification

Run the real editor with `CRUISES_WORKSHOP_EDITOR_CHECK=1`, plugin enabled and
`res://tests/fixtures/workshop_editor_check.tscn`. The fixture owns no production saves.
It tests native commands/history, real dock routes and face clicks, dependency rollback,
animation independence, masks/material/collision restoration and separate-process reopen.
The environment variable is consumed only by the test fixture; ordinary editor/game
startup never runs it. Treat every engine `ERROR`/`SCRIPT ERROR` as failure.

Do not run this harness as `--editor --script SceneTree`: that creates an unsupported
second editor main loop and leaks editor resources. The test runner launches the native
fixture instead. The cold fixture script accepts its one explicit output path.
