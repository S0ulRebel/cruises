# Character Workshop

Enable **Character Workshop** in Project Settings → Plugins, then click its tab
beside **3D** at the top of the editor. The workspace has an assembly viewport,
an optional detail viewport, a real parts hierarchy and a collapsible asset drawer.
Godot's scene tree, Inspector and undo history remain available.
There are no fixed clothing slots or mandatory filenames.

## Assemble a character

1. Choose **New empty** or **New from template**. The character opens immediately
   as a new, unsaved scene with private editable resources; no file browser appears.
   Existing scene tabs stay open. Choose a destination later through **Save As**
   or the first **Save**, then continue editing that same tab. Later **Save** writes
   to the chosen path; **Save As** deliberately chooses a different destination.
   **Open** browses for another saved assembly. Exported gameplay actors with an
   authored `Body` assembly can also be reopened and edited.
2. **Add part** toggles the asset drawer below the views, keeping the hierarchy visible.
   Search imported project models/prefabs by filename/folder word prefixes, use optional
   type/folder filters, and read each tile's format and source folder. Search `hair`
   matches a hair word, not `chair`.
   Double-click a thumbnail, use **Add selected**, or drag it into a fitting view.
   **Import from disk** copies a self-contained GLB into an explicitly chosen project
   folder and waits for Godot import. Existing filenames are rejected. For formats
   with external dependencies, import the complete asset through Godot first.
   **More → Export → Adopt selected** wraps a model already in the native scene tree.
3. Select a part in either viewport or hierarchy. Nested rows follow real attachment
   parents; names remain arbitrary. Use the bottom **Move**, **Rotate**, **Scale**
   buttons and axis handles. **Fine adjust** opens exact local position, rotation
   and scale fields in the sidebar with Apply/Cancel; the native Inspector also remains
   available. World/Local axes control translation and rotation; scale uses the part's
   own axes. Enable Snap or hold Ctrl; adjust movement metres, rotation degrees and
   scale increments (0.1 means 10% of the initial scale).
4. **Attach** starts target picking: click the destination part in a view or hierarchy.
   A banner names the source and hovered parent; the parent is highlighted before
   clicking. **Cancel attach** or Escape returns to fitting. Alternatively drag a
   hierarchy part onto its desired parent. For an arbitrary node or bone, open
   **More → Attachment** and choose its actual scene target.
   **Attach / Apply** and **Detach** preserve world placement. The entire
   imported Model remains intact, including local rigs and facial blend shapes.
5. Double-click a hierarchy name or press F2 to rename. Renames preserve node and
   animation targets; edited animation tracks use private library copies. Eye buttons
   toggle visibility. Right-click a part for Rename, Hide/Show, Replace, Duplicate,
   Detach and Remove, all using native undo. Dependents require
   an explicit choice: keep them free, remove all, or reconnect matching targets.
   External skinned garments count as dependents too. Keeping one without its donor
   is rejected; reconnecting requires compatible bone names/order/rest poses.
6. Use **Save As** for a validated explicit reusable-scene destination. Derived
   meshes and masks are embedded in that scene; source GLBs are never rewritten.
   **Save gameplay actor** deliberately adds movement/collision components through
   the export service. Static assemblies need no gameplay services.

The second view can be hidden for more space. Each view has independent camera
presets and framing, plus mouse orbit/pan/zoom. Cameras and gizmos are tool controls;
they are never added to saved characters. Viewport drags commit one native undo action.
Use right-drag or Alt-left-drag to orbit, middle-drag to pan, and the wheel to zoom.
W/E/R choose transform tools, F frames selection, Home frames the whole character,
and Ctrl snaps a drag. Leaving the tool or pressing Escape cancels an active drag.
Grid and Bounds controls adjust overlays; subtle corner marks are the default
selection feedback. **Focus** temporarily hides surrounding Godot side docks and
restores the prior editor layout when disabled or when leaving the workshop.
**More** opens four task tabs: Attachment, Geometry, Animation and Export. Selection
controls are enabled only when their required part, mesh or player is available.

The drawer's **Drop** setting defaults to authored placement. Cursor placement shows
an origin marker and places the new part's wrapper on the horizontal plane through
the selection. Front/side rays use a screen-plane fallback when needed. Internal
model offsets/transforms stay intact, so the marker represents the wrapper origin,
not an automatic fit to the visible mesh. Insertion and placement share one undo
action. Double-click/Add selected always preserves authored placement.

Asset thumbnails are loaded lazily. When Godot has no native saved-scene preview,
the browser renders the largest visible mesh from the prefab without instantiating
its scripts. Compound prefabs therefore show a representative part. Thumbnails
stay in memory and never change source models or materials.

After native scene-tree renames/reparenting, the workshop tracks retained target objects
and enables **Repair moved / renamed references** when paths need repair. This is
an explicit undoable action. Use it before the workshop's validated Save As/export.
Opening a scene never silently repairs its paths. Targets already missing on opening
must be selected again; the tool cannot infer a deleted rig.

## Remove fused geometry

Select a part, then its mesh in **Reversible mesh exclusion**. Enable reference-pose
selection and click faces in either workshop view or the native 3D viewport. The Add/Subtract switch edits
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

## Character references

The small pane has **3D** and **Reference** buttons. **Images…** opens a compact
thumbnail board below the views; it shares space with the asset drawer. Choose
**Add images…** to select PNG, JPEG or WebP images from the project or elsewhere
on disk. Project image files can also be dragged onto the board or reference pane.
Select a thumbnail to compare it beside the character. Close hides the board while
keeping the selected reference visible. **Second pane** hides either view.

Use the mouse wheel to zoom under the pointer, drag with the left/middle button to
pan, or use **Fit** / F / Home with the image pane focused. Switching back to 3D
preserves its camera and the image's current zoom/pan.

Image paths, selection and pane mode are local editor preferences per saved character,
not scene resources or game nodes. A first Save or Save As associates the current
choices with that destination. Unsaved characters retain independent session choices;
a new template copy starts with an empty reference workspace. These preferences do
not travel through Git to other computers. Images stay at their chosen paths; moved
files show an unavailable state and can be removed/re-added. Remove never deletes art.
Only the active image uses a full-size texture; board thumbnails are reduced to 96px.

The saved editable assembly is distinct from a game portrait renderer. For the
Captain's workshop default, open `res://actors/assembly/templates/captain_portrait.tscn`.
For the game version, open `res://ui/portraits/captain_live.tscn` in Workshop. That
complete portrait owns its Camera, lights and speaking-rig paths; its fitted parts
are an editable instance of `res://ui/portraits/captain_live/assembly.tscn`. Camera
framing is edited on the portrait's Camera node in the native Inspector. Workshop
view cameras are separate editing tools and never save into the character.

Save/Save As now externalizes private meshes to binary `.res` files under the
explicit scene destination's `<scene_name>/meshes/` folder. Original imported art
is untouched; Save As gives its output a separate resource folder. Subsequent saves
can update only resource files already referenced by that saved scene. Geometry,
facial shapes, materials and per-instance independence are retained. Use project
scene paths for ordinary native editor authoring. Normal opening/game startup has
no save or compaction route. A bare assembly/gameplay export cannot overwrite a
portrait renderer through Workshop; open the complete portrait to save it.

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
