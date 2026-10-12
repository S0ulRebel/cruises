# Character Workshop implementation plan

Created and approved: 2026-10-11. Status: implemented and integrated into
`main`; integration checks passed; art/owner acceptance below.
The earlier scene migration remains completed in [REFACTOR_PLAN.md](REFACTOR_PLAN.md).
Open checkboxes identify remaining acceptance work, not missing tool foundations.

## Approved viewport workspace — 2026-10-12

The owner approved the revised two-view fitting layout and requested implementation,
commit and push on `main`. The latest remote `main` was pulled first. This approval
supersedes the earlier UI design hold; existing game/portrait art stays untouched.

- [x] **UI01:** Replace the long dock with a main-screen Character Workshop tab.
  Keep a dominant assembly viewport and optional independent detail viewport visible.
  Provide orbit, pan, zoom, framing, view presets and direct part selection.
- [x] **UI02:** Show the actual collapsible character hierarchy, including the root
  and arbitrary nested attachments. Preserve selection and collapsed branches across
  refresh. No fixed body-part categories or duplicate Captain row among its parts.
- [x] **UI03:** Add a searchable visual project asset browser, thumbnail drag/drop,
  and a deliberate disk-import flow with a chosen destination and no overwrites.
- [x] **UI04:** Put Move, Rotate, Scale, Attach, Duplicate and Remove on the bottom
  action bar. Viewport transforms and picked attachments preserve placement and use
  native undo. Fine adjust provides exact local fields; Godot's Inspector stays available.
- [x] **UI05:** Move geometry removal, bone attachment, binding, animation, legacy
  conversion and export into contextual/closed advanced tools. Retain their behavior.
- [x] **UI06:** Check real scene rendering, hierarchy, asset discovery, selection,
  transforms/undo, save/reopen and source preservation; inspect a graphical capture.
  Run module and integration checks, then commit and push the completed change.

Scopes on the shared `main` checkout: viewport widget, asset browser and dock/layout
have separate files; integration owns plugin/commands, checks and documentation.
View cameras, overlays and UI resources belong to the tool, never saved characters.

Delivered: the main-screen workspace renders the actual editable scene in two
independent views. Native undo covers viewport drags, precise transforms and picked
attachments. The sidebar shows the real hierarchy or searchable project thumbnails;
advanced operations open separately through More. GLB disk imports require an
explicit destination and reject overwrites or external texture/buffer dependencies.

Validation on Godot 4.7.2: all 22 default checks and cold reopen routes passed,
including 174 native editor assertions and the engine-error rejection self-test.
After the thumbnail follow-up, the native editor, workshop integration/cold reopen
and authored-scene checks passed again with authored source hashes unchanged.
A separate Compatibility GPU run passed 174/174 with no engine/script errors;
workspace, actual hair/chair thumbnails and Fine adjust captures were inspected.
Evidence: `%TEMP%/cruises-checks-8886df44ee964b44917681864e669c83/`,
`%TEMP%/cruises-checks-c4a8b69c52474907a6455d990aa0c8c2/` and
`%TEMP%/cruises-workshop-final-109c40bcbfd24286b2be2a64d43193f1/`.
Picking uses reference mesh triangles for skinned models; animated-pose picking
and final clothing/neck art acceptance remain separate work.

## Approved usability follow-up — 2026-10-12

The owner approved all ten review points. Implement on `main` without graphical
Godot sessions while GPU training is running. Use static/headless module and
integration checks; defer visual acceptance explicitly.

1. [x] Continue editing the current tab after Save As; add ordinary Save.
2. [x] Put visibility in hierarchy rows and everyday actions in a context menu.
3. [x] Support inline rename and undoable drag-to-parent with placement preserved.
4. [x] Add Local/World controls, adjustable snapping and inline precise fields.
5. [x] Show source/destination attachment feedback, hover highlighting and Cancel.
6. [x] Keep hierarchy visible with a collapsible asset drawer.
7. [x] Add word-aware asset search, folder/type filters and source labels.
8. [x] Make drop placement explicit, with a preview and preserved-transform option.
9. [x] Add subtle selection/overlay controls and reversible editor focus mode.
10. [x] Organize advanced tools into contextual Attachment/Geometry/Animation/Export.

Implemented and headless-verified on Godot 4.7.2: 213/213 native editor assertions,
all 22 default checks, separate cold reopen routes and the engine-error rejection
self-test pass. Authored source hashes are unchanged by checks. Evidence:
`%TEMP%/cruises-checks-3a572b89171f4c5ba843ccc99d2f07f9/`.
The cabin dressing check now stops music and allows the audio thread a mix interval
after scene deletion, fixing a timing-dependent headless shutdown leak.

Drop preview is a wrapper-origin marker, not an instantiated ghost mesh; internal
model transforms remain intact. Local/World controls affect move/rotate; scale
follows local axes. Rename rebases node paths and affected animation tracks in
private libraries; undo restores the original names, paths and libraries.

- [ ] Inspect the revised layout at normal/narrow editor sizes, overlay legibility,
  and physical mouse drag/drop after the owner's GPU training permits rendering.
- [ ] Obtain owner usability acceptance for this follow-up.

The follow-up does not alter source art, production scenes or imported meshes.
Latest remote `main` hat work is integrated; its two missing GLB import UIDs are
versioned after first import, without changing their models or import options.
Normal startup never saves authored resources. Visual approval remains pending.

## Current result and remaining acceptance

The native Character Workshop plugin is enabled. Arbitrary part assembly, native
transforms/undo, free/parent/bone/local-rig attachments, reversible fused-geometry
exclusion, explicit binding, previews, legacy conversion and reusable scene saves
are implemented. Use [the authoring guide](../actors/assembly/README.md).

Owner usability correction: New empty and New from template now open an editable,
independent unsaved scene immediately. Existing scene tabs remain available; browsing
is deferred to Open/Save As. A template is never located again or saved on creation.

Implementation checkpoints: foundation `02cd8c7`, masks `6bf1e37`, integration
services/templates `95e9409`, legacy conversion `941d9c8`, editor `8a8f13f`,
head-swap example `8a2f798`, owner/collision isolation `8eb2d60`, nested source
composition `6bee7b1`, native adoption `3990f68`, graph cloning `d5cf375` and private
binding snapshots `8bd1a01`. Module handoffs record focused validation.

Final integration validation on Godot 4.7.2: all 21 module/integration checks passed,
including 114 assembly assertions, 109 native editor assertions and separate cold
processes for regular/nested/graph assemblies, masks, legacy conversion, editor
output, head swap and the actual gameplay actor. The runner self-test rejected a
deliberate engine-error false-pass. Production checks had no engine/script errors;
tracked authored sources, including binary `.res` meshes, retained their hashes.
Evidence: `%TEMP%/cruises-checks-c672df683e5e4f13966fe5ac8e6f1f52/`.

Template workflow follow-up: 125/125 native editor assertions pass, including
immediate unsaved creation, retained scene tabs, repeated independent copies and
Open/Save As dialogs. Authored-scene and workshop integration checks also pass,
including separate cold reopen, with no engine errors or authored source changes.
Evidence: `%TEMP%/cruises-checks-e4f55424f02b480eb0b0bafc1c525dfc/` and
`%TEMP%/cruises-checks-ac9e3e05b0e144f38b82a54340b443a9/`.

- **CW14:** The saved head-swap demonstration removes the Zombie skull/jaw while
  retaining its skeleton and the Captain's Head/Jaw, three facial shapes and jaw
  accessory motion. Front/three-quarter/open-jaw GPU renders were reviewed. Its
  thin neck, open seam and material mismatch still need art acceptance or an
  explicitly saved modeling asset. It is a tool example, not the final Captain body.
- **CW16:** Nearest-weight search, normalization and real donor input are verified.
  Real production clothing still needs representative-pose art acceptance after
  the replacement body is ready. The placeholder integration garment proves the
  binding/save/playback route; it cannot approve final coat deformation.
- **CW24:** The approved visual workspace is implemented and GPU-checked. Native
  editor commands, hierarchy, transforms/undo, static/rigged reuse and cold reopen
  are covered by automated checks. Final owner usability acceptance remains open.

The explicit disk-import flow copies self-contained GLBs into a chosen project
folder, then waits for Godot's normal import before adding them. Other formats and
external dependencies use Godot's standard import workflow. Generic attachments
use actual scene bones; body fitting/retargeting requires supported measured torso
landmarks. Unsupported rigs fail visibly and need an explicit mapping extension.

## Intended workflow

Open a character scene, add a body or start an empty assembly, add any model or
prefab, select it visually, move/rotate/scale it, attach it where desired, and save
an editable character scene that can be reused in another location or portrait.
The body is an ordinary scene component; static assembly does not require a rig.

The part list follows the authored scene and uses names chosen by the author.
There are no fixed head/shirt/hat sections, mandatory filename conventions,
one-per-category restrictions or automatic clothing conflicts. Each instance has a
stable identity; multiple hats, props or arbitrary objects are allowed. A target
picker may list the actual parts and bones in this scene, without a predefined cast
or body-part registry.

Attachment choices are free placement, parenting to another part, following a
selected bone in any available skeleton, preserving a part's local rig, or explicitly
binding a deforming garment to a compatible body rig. Local-rig preservation can be
combined with parent/bone attachment. Switching an attachment keeps its world
placement; an editable offset remains available afterward. Reject cycles and show
missing targets rather than silently attaching to a different bone.

Example: a speaking head follows the body's head bone while retaining its own
Head/Jaw rig and blend shapes; hat and hair follow the head; chin tuft follows its
jaw. Names and this example are author choices, not enforced categories.

## Authoring and persistence rules

- Godot's native scene tree, selection, transform handles, Inspector and undo/redo
  provide direct editing. The proposed editor plugin supplies focused attachment,
  binding, mesh-exclusion and save tools.
- The authored `.tscn` is the source of composition. Keep reusable source scene/model
  references and save any necessary derived mesh/skin resources explicitly.
- Add, attach, bind, exclude geometry and save are deliberate author actions. Ordinary
  editor opening, game startup and checks do not regenerate or overwrite content.
- Keep source GLBs, rigs, textures, import settings and accepted scenes intact.
  Make working resources independent; derived outputs belong to the chosen character.
- Preserve the existing accepted world actors and Captain portrait while the tool is
  developed. The dense bare body is a separate art task; do not substitute it into
  gameplay or silently decimate it as part of this work.
- Templates are optional ordinary editable scenes. They suggest a starting assembly
  and have no locked slots, mandatory attachments or automatic deletion rules.

## Priority 0: establish the foundation

- [x] **CW01 — Define assembly data and module ownership.** Agree on stable part
  identities, source references, editable transforms, parent/skeleton/bone targets,
  optional local rigs, binding settings and mesh-exclusion metadata. Separate the
  editor UI from authoring operations and the saved/runtime scene. Establish narrow
  interfaces before parallel edits; keep legacy outfit resources readable.
- [x] **CW02 — Make opening the tool reliable.** Start with an empty assembly or an
  explicitly selected valid template. Remove automatic first-body selection and
  random dressing. Allow static/unrigged models to assemble; only rig-dependent
  commands require a validated skeleton. Opening must produce no engine errors.
- [x] **CW03 — Repair resource and operation state.** Clone mutable per-part resources
  explicitly, including external fit resources. Track pending fits by stable part
  identity and resolve them before save/export or target changes. Validate changes
  before committing replacements, synchronize scene and UI state on success, and
  leave a failed operation recoverable. Never report a rejected load as successful.

Completion check: static and rigged starters open cleanly; same-session reload drops
unsaved working changes; two independent saved outfits remain independent; changing
selection during a fit cannot apply it to the wrong part or export stale geometry.

## Priority 1: direct assembly and expanded attachments

- [x] **CW04 — Implement direct editing and recovery.** Use viewport selection,
  translate/rotate/scale handles and Inspector fields with undo/redo and dirty state.
  Preserve authored transforms during preview and animation. Validate finite values
  and nonzero scale; define deliberate mirroring behavior rather than accepting a
  singular transform. Random fitting or guessing, if retained, is explicit and undoable.
- [x] **CW05 — Add arbitrary assets.** Support normal project drag/drop and browsing
  for models/prefabs, refresh the available files and include root MeshInstance3D
  models as well as nested meshes. Source basename, directory and humanoid category
  must not determine eligibility. External files enter through an explicit project
  import/copy destination; show unsupported-format or missing-resource errors.
- [x] **CW06 — Replace fixed slots with independent instances.** Add, rename,
  duplicate and reorder freely named parts using stable IDs. Remove automatic
  category replacement/conflict behavior from the new assembly model. Deleting or
  replacing one instance must leave another instance of the same asset intact.
- [x] **CW07 — Provide all attachment modes.** Select an actual scene part or bone,
  including bones inside an attached head or another local rig. Support free parts,
  parent attachments, bone attachments and explicit garment binding. Reparent,
  attach and detach without jumping position; detect cycles, stale targets and
  unsupported rigs. Avoid hardcoded Mixamo names in the generic assembly interface.
- [x] **CW08 — Remove, hide and replace selected parts.** Support reversible removal
  and visibility changes, and replacement with an option to reuse the attachment
  target and transform. When dependents exist, present explicit choices for moving,
  removing or reconnecting them; never silently discard or orphan them. Validate a
  replacement before removing the current part.
- [x] **CW09 — Preserve local rigs and facial features.** Attach a complete speaking
  head with its skeleton, skins, materials, blend shapes and animation references
  intact. Donor weight transfer must be a separate requested conversion, never an
  automatic consequence of importing or attaching a head.
- [x] **CW10 — Save editable, reusable character scenes.** Provide explicit Save/Save
  As destinations and retain part identities, targets, binding settings, draft/source
  references and exclusion metadata so authors can reopen and refit a saved assembly.
  Save derived resources alongside that character without cross-character collisions.
  Gameplay movement/collision/hotspot components are explicit reusable components;
  a static assembly or portrait must not require movement services.

Completion check: add an arbitrarily named prefab and two copies of one accessory;
position them visually; attach head to body, hat to head and tuft to local Jaw;
detach/reattach without a jump; remove/replace/undo; save, close and reopen. Continue
editing both pinned and skinned parts during animation. Verify independent instances
and speaking-head blend shapes, not only counts in the exported scene.

## Priority 2: reversible mesh exclusion and head replacement

Current donor bodies contain their heads in a single mesh primitive. Remove-part
handles a separate attachment; it cannot remove only the head of a fused body.

- [x] **CW11 — Add geometry selection and exclusion.** Support whole mesh/surface
  exclusion where possible and manual face/region selection on fused meshes, with
  selection preview, clear add/subtract controls, hide/exclude, restore/reset and
  undo/redo. Work against the source mesh in a stable reference pose. Start with
  practical region selection rather than implementing a complete modeling package.
- [x] **CW12 — Persist reversible masks safely.** Store the selected source mesh,
  surface/face identities and a topology fingerprint with the assembly. Keep the
  original geometry recoverable. If a reimport changes topology, mark the mask stale
  and require review/remapping; never apply old indices to unrelated faces.
- [x] **CW13 — Create faithful derived mesh resources.** Exclude selected triangles
  from an independent output and keep remaining UVs, normals/tangents, materials,
  custom attributes, skin/bone data and synchronized blend-shape data intact.
  Update or invalidate affected LOD, shadow and collision data deliberately; excluded
  geometry must not remain in shadows or picking. Keep required skeleton bones even
  when their visible geometry disappears. Preview is temporary; persistence requires
  an explicit output path and authoring save. No runtime mesh reconstruction.
- [ ] **CW14 — Demonstrate a complete head swap.** Exclude the old head, retain the
  appropriate neck geometry and attach the replacement speaking-head prefab. Verify
  the mouth cavity is clear, jaw-driven accessories follow, and neck fit/weights hold
  during relevant body/head poses. Do not infer removal solely from Head-bone weights.
  Complex neck reshaping, capping or retopology uses an explicitly saved Blender-derived
  asset. A mask does not promise an automatic watertight seam.

Completion check: hide a fused head, restore it, undo/redo, save and cold-reopen the
result without changing its source GLB. Verify UVs, skinning, facial shapes, shadow
and picking behavior. Reimport a topology-changed fixture and confirm the stale mask
is reported. Review the assembled neck and mouth visually in more than one pose.

## Priority 3: explicit clothing binding and animation reliability

- [x] **CW15 — Generalize fitting and binding.** Keep the measured outfit backend,
  adapting it to independent parts and explicitly selected donor rigs. Resolve
  landmarks through declared roles/mappings and validate unsupported rigs. Offer
  explicit fit/rebind actions and retain the saved fit instead of guessing again
  after save, reload or a body change without author intent.
- [ ] **CW16 — Correct and validate weight transfer.** Repair the nearest-neighbor
  search so it cannot accept farther candidates while missing nearer ones. Verify
  normalization, supported influence counts and unweighted vertices. Evaluate real
  garments in representative poses; proximity alone is not art acceptance.
- [x] **CW17 — Make expensive fitting usable.** Bound/invalidate generated-mesh
  caches, expose useful mesh statistics and show progress for expensive binding.
  Avoid full rebinds on every transform nudge; use explicit/deferred work with correct
  part identities and cancellation. Use background work where engine operations
  permit it, and prevent stale results from replacing a newer fit.
- [x] **CW18 — Preserve correct animation behavior.** Align saved idle/walk mappings
  with the movement component, including borrowed/retargeted clip library names.
  Duplicate preview animation resources before changing them; keep one-shot gestures
  distinct from deliberate loops. Preview T/rest pose, idle, walk and facial motion
  and verify exported playback through the actual gameplay controller.

Completion check: bind a measured garment, edit/save/reopen its fit and verify real
deformation while walking; both native and borrowed locomotion reach the controller.
Two previews cannot mutate each other's clips. Measure binding/caching behavior and
verify cancellation, rapid edits and the nearest-neighbor regression fixture.

## Priority 4: usability, templates and final acceptance

- [x] **CW19 — Improve labels, saves and preview controls.** Show readable labels
  plus paths for duplicate basenames, clear units and destinations, Save/Save As
  dialogs, and actionable validation errors. Offer original-material preview and
  optional preview shading without silently rewriting source materials.
- [x] **CW20 — Make reopening predictable.** Synchronize the part list, selection,
  destination fields and fit status to saved identities rather than cached object
  equality. Allow opening a saved character, outfit or individual fit from arbitrary
  supported destinations. Document legacy conversion limits and dirty-state recovery.
- [x] **CW21 — Add editable templates.** Provide an empty/static starter, a validated
  rigged starter and a reviewed character example. Templates use ordinary scenes;
  every part, target and transform is editable and deletable. No categories or
  automatic conflicts become mandatory when a template is used.
- [x] **CW22 — Finish migration and documentation.** Add safe, explicit conversion
  for useful legacy outfit data and document its limitations. Retire or clearly
  deprecate the runtime slot-picker authoring workflow when its replacement passes.
  Rewrite actors/outfit/README.md, relevant module handoffs and user instructions to
  match free assembly, local rigs, masks and explicit outputs. Keep packing flags and
  batch builders retired; exclude editor-only tools from gameplay exports.
- [x] **CW23 — Add focused checks alongside each phase.** Cover real editor commands,
  undo/redo, failure rollback, same-session and cold reload, multiple independent
  instances, local-rig facial motion, masks and real exported gameplay animation.
  Engine errors fail checks even with exit code zero. Authoring-save tests use a
  separate temporary project or explicit isolated fixture/output paths.
- [ ] **CW24 — Verify the complete authoring and reuse workflow.** Assemble a character
  visually, replace its head, attach arbitrary parts, save, cold-reopen and reuse it
  in a second scene. Include a static assembly and a rigged actor. Ordinary startup
  and checks must leave tracked source scenes/models/resources unchanged. Record
  visual acceptance and update completion checks with commit and evidence references.

Completion check: the owner can perform the intended workflow without editing code,
using fixed slot filenames or typing bone names guessed from a specific donor.
Per-phase checks and integration pass; imported art and the accepted gameplay/portrait
scenes remain intact unless a separately reviewed replacement is deliberately placed.

## Parallel implementation boundaries

These module boundaries were established before delegated editing.

- Integration owns the assembly contract, compatibility/migration decisions,
  project/plugin wiring, any actors/mover animation interface and final merges.
- Editor owner: addons/character_workshop/ for docks, commands and native editor
  integration. UI depends on the agreed authoring API; it does not own mesh binding.
- Assembly owner: actors/assembly/ for per-part identity/attachment resources and
  scene operations. Coordinate any shared API changes with integration and consumers.
- Binding owner: actors/outfit/ for donor fitting, weight transfer and caches.
  New generic assembly uses explicit instance identities; legacy slot compatibility
  must not constrain the new UI or cause automatic part removal.
- Mesh owner: a separately assigned actors/assembly/mesh_exclusion/ scope for masks
  and derived geometry; any shared resource changes go through the assembly owner.
- Validation owner: tests/ with explicit fixture/output ownership and no source saves.
  Character/portrait art and template placements retain their respective owners.

Each editing agent receives an exact file scope. Current owner policy keeps work
on `main`; notify the owner before using another branch/worktree or switching.
CW01–CW03 establish interfaces and safe state first. Independent editor, binding and
mesh work can then proceed within assigned scopes; shared scenes and APIs have one
owner. Record detailed handoffs locally and keep HANDOFF.md as the current index.

## Coverage of the 20 audit findings

- A01 broken default startup: CW02.
- A02 no viewport picking/handles: CW04.
- A03 rig requirement blocks static assembly: CW02, CW07.
- A04 fixed scan roots/filenames: CW05.
- A05 one item per category: CW06.
- A06 restricted modes and body-only bone targets: CW07.
- A07 speaking-head blend shapes/local rig lost: CW09, CW13–CW14.
- A08 mutable external fit resources shared after load: CW03.
- A09 deferred refit uses the selected rather than edited part: CW03, CW17.
- A10 rejected loads/replacements leave inconsistent state: CW03, CW08.
- A11 borrowed locomotion names mismatch exported controller: CW18.
- A12 missing undo/dirty-state recovery: CW04, CW20.
- A13 zero scale accepted: CW04.
- A14 loaded selectors and saved fit status inconsistent: CW15, CW20.
- A15 ambiguous labels/paths and missing individual-fit load: CW19–CW20.
- A16 slow fitting and unbounded generated-mesh cache: CW17.
- A17 nearest-neighbor lookup can miss nearer samples: CW16.
- A18 shared preview loops and forced preview materials: CW18–CW19.
- A19 generic-rig assumptions and root-mesh omission: CW05, CW15.
- A20 export lacks editable fit metadata/gameplay authoring options: CW10, CW20.

Validated foundation to retain: numerical fitting, resolved bone attachments,
native-donor export and editable exported pinned/skinned transforms that survive
animation and cold reopening. The audit did not find skinned transform editing
broken; do not replace working skinning to fix a disproved suspicion.

## Reference images — approved 2026-10-12

- [x] Add a simple Reference/3D switch to the small pane while preserving the main
  assembly view, hierarchy and camera settings.
- [x] Add a collapsible thumbnail board with multiple images, Add/Remove and project
  image drops. External images use a file chooser; originals are never copied/deleted.
- [x] Provide pointer-anchored wheel zoom, drag pan and Fit, with recoverable missing
  files and stale-dialog protection when changing the edited character.
- [x] Remember image paths, active image and mode in project-local editor preferences
  per saved scene. Unsaved characters remain separate; Save As carries current choices.
  Reference UI/images never become game-scene nodes or resources.
- [ ] Future: adjustable transparent viewport overlay with opacity/position/scale.
- [ ] Future: movable/pinnable reference cards around the main view.
- [ ] Future: crop a design sheet into front/side/back reference views.
- [ ] Future: portable reference bundles for sharing reference choices with teammates.
- [ ] Follow-up: reduce inline mesh serialization through deliberate binary `.res`
  outputs while retaining independent editable resources and exclusion provenance.
  Do not disable warnings or silently rewrite fitted character scenes.

Implementation uses authored editor-only controls and retains exactly two 3D viewports.
References/Assets share drawer space. The regular Save label is corrected. Native
template checks use the actual authored part count, allowing the owner's new hat and
feather without forcing an older composition. Visual and integration evidence is
recorded in the workshop/test handoffs after checks complete.

## Technical references

- [Godot EditorPlugin](https://docs.godotengine.org/en/4.7/classes/class_editorplugin.html)
  and [EditorUndoRedoManager](https://docs.godotengine.org/en/4.7/classes/class_editorundoredomanager.html).
- [BoneAttachment3D](https://docs.godotengine.org/en/4.7/classes/class_boneattachment3d.html)
  and [ArrayMesh](https://docs.godotengine.org/en/4.7/classes/class_arraymesh.html).
- Project evidence: actors/outfit/workshop.gd, dresser.gd, outfit_piece.gd and
  skin_copy.gd; [actor handoff](../actors/HANDOFF.md),
  [rigging decisions](RIGGING.md) and the Captain/Santi pieces' asset.json records.
