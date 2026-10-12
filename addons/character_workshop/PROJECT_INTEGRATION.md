# Optional project integration

The addon is standalone. Put project-specific integration scripts outside it.
Choose an `@tool` script extending `RefCounted`, with no required constructor
arguments, in Workshop Settings. The adapter is an editor service, never a
character node. Blank adapter path means no integration. Loading must be read-only.

Every method is optional:

- `can_edit(root: Node) -> bool`: support an additional saved scene wrapper.
- `handles(object: Object) -> bool`: let native selection recognize a custom wrapper.
- `protected_root(root: Node) -> bool`: identify a complete protected wrapper.
- `protected_destination(path: String) -> bool`: block saving a bare assembly or
  gameplay export over an existing protected wrapper. Inspect without writing.
- `export_actor(root: Node, output_path: String) -> Dictionary`: show the gameplay
  export action and save only to the user's explicit output. Return `ok` and `error`.
- `prepare_legacy(root: Node, source_path: String) -> Dictionary`: show legacy import
  and prepare the existing import command's `ok/error/parts/warnings` result.
  Parts are off-tree `CWPart` instances; caller inserts them with native undo.

Generic assembly/part/mask classes are `CWAssembly`, `CWPart`, `CWMeshMask`. Core
services use the `CW` prefix, reducing collisions with ordinary game class names.
Runtime metadata is in `runtime/`, authoring services in `core/`, editor UI at the
addon root. Export rules must retain runtime scripts and their core dependencies.
Do not exclude the complete addon directory from a game that uses saved assemblies.
Disabling the editor plugin is supported; deleting its required scripts is not.

Cruises configures `actors/assembly/project_adapter.gd` in its own project descriptor.
That adapter recognizes gameplay actors and complete portrait renderers, protects
portrait destinations, calls Cruises gameplay export and converts old outfits. Its
borrowed library remains `captain`; other projects default to `workshop`. Neither
that adapter nor Cruises templates/art is shipped in the addon ZIP.
