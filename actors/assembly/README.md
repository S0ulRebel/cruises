# Character Workshop

Open the project in Godot 4.7.2. The **Character Workshop** dock sits beside the
native scene tree and Inspector. If hidden, enable **Character Workshop** under
Project Settings → Plugins. This is an editor workflow; F6 is not needed.

## Start and add parts

1. Choose **New empty** for a static composition, or choose **Rigged starter** or
   **Captain portrait** under **New from template**. The character opens immediately
   as an independent unsaved scene, with existing tabs preserved. Templates are
   ordinary scenes under `actors/assembly/templates/`.
2. Start editing, then choose **Save As** when ready to select your character folder.
   Starting from a template never asks for a file or writes a scene to disk.
3. **Add model / prefab** accepts imported models and 3D prefabs anywhere in the project.
   Each instance gets a separate stable identity. Names and directories do not
   determine eligibility. Add multiple copies, rename and reorder them freely.
4. You can also drag a model into the native scene and **Adopt selected** to make
   it a managed part. External files need a chosen project import destination;
   Godot must finish importing them before they can become parts.
5. Select the Part node, then use native handles or Inspector transforms. The
   nested `Model` retains its imported hierarchy, materials, skins and local rigs.
   Transform units are metres and degrees in the editor. Zero scale is rejected
   by validated authoring operations; negative scale is deliberate mirroring.

## Attach, replace and animate

Choose a real target in the scene, then **Free**, **Parent** or **Bone** attachment.
Bone choices come from the selected skeleton, including a skeleton inside another
attachment. Switching attachment preserves world placement; edit the resulting
offset afterward. Cycles and missing bones produce an error before changing it.

A complete speaking head can follow a body bone while its own Head/Jaw rig remains
intact. Attach hair or a hat to its Head and a chin accessory to its Jaw. Importing
or attaching a part never automatically transfers donor weights.

**Hide**, **Remove**, **Replace** and **Duplicate** affect the chosen instance.
Removal/replacement with dependents asks whether to keep them free, remove them
together, or reconnect them. Godot undo restores the operation and its attachments.

For a deforming garment, first fit it visually, choose its donor and run
**Bind clothing**. This explicit conversion prepares independent geometry, retains
the original model for later refitting and has progress/cancellation. It does not
rebind on each transform nudge. A changed donor/part during a job invalidates its
result. Morph-bearing faces and unsupported torso frames return an actionable
error; keep those local rigs and use parent/bone attachment.

**Borrow clips** explicitly retargets a compatible source's body clips to the donor.
Use the preview player and clip controls to review rest, idle, walk and gestures.
Only deliberately requested preview looping changes; source clips stay untouched.
Original materials are the default. Neutral preview shading is temporary.

## Exclude part of a fused mesh

Select the Part and its mesh. Enter **Face selection** to work on the immutable
source geometry in reference pose; disable it to return to native transforms.
Click faces or select a box region, use add/subtract, then **Exclude selected**.
Whole surfaces can also be excluded. **Restore / Reset** and Undo recover geometry.

The mask keeps the original mesh, source face IDs and a content fingerprint. The
derived mesh retains remaining UVs, skin weights, facial shapes and materials.
Stale LOD/shadow meshes are dropped, and affected collision is deliberately removed
or rebuilt. If reimport changes the source, review/reset the stale mask instead of
applying old triangle indices. Normal game startup only loads the saved mesh.

`head_swap_demo.tscn` is a removable, editable demonstration: the Zombie head is
excluded while its neck and skeleton remain; the Captain head retains its local
rig and accessories. It does not replace a game actor. Inspect the neck in motion
before using any head swap in gameplay. Triangle exclusion cannot sculpt, cap or
retopologize a neck seam; that art requires an explicitly saved modeling asset.

## Save and reuse

Use native Save for ordinary editing and the dock's **Save As** for a validated
explicit destination. Save As expands an independent editable scene snapshot and
checks identities, transforms, skin targets and attachment metadata. Choose an
existing destination folder; source model overwrite is rejected. Derived meshes
and skin resources save with that scene, so one character does not overwrite another.

Native scene-tree reparenting/renaming can invalidate metadata paths. The dock
reports it and offers **Repair moved / renamed references**, an explicit undoable
action using the targets retained in this editor session. Use it before Save As or
gameplay export. If a previously saved broken reference is reopened without that
session history, choose its target again explicitly. Native Ctrl+S remains Godot's
own save route; use validated Save As for a checked prefab.

**Save gameplay actor** is optional and writes a separate `.tscn` with editable
Mover, collision capsule, NavigationAgent and Obstacle nodes. It selects a player
with idle/walk clips and saves their names and player path for the real controller.
Review collision size and add your CharacterDefinition/hotspot where gameplay needs
them. A static prop, composition or portrait does not need movement components.

Instance the saved prefab in any location or another scene. Placement belongs to
that location. No global registry, pack flag or startup builder is involved.

**Import saved legacy fit / outfit** converts old `.tres` data explicitly. See
[compatibility limits](../outfit/README.md). Godot's dirty state/undo history manages
unsaved edits; discard/reload when you want the saved version.

Implementation contract: [interfaces](../../docs/CHARACTER_WORKSHOP_INTERFACES.md).
Progress and acceptance: [plan](../../docs/CHARACTER_WORKSHOP_PLAN.md) and
[module handoff](HANDOFF.md).
