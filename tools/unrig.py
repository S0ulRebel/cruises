r"""Drop a useless skeleton off a model and keep the mesh exactly where it is.

    blender --background --factory-startup --python unrig.py -- in.glb out.glb

For models that do not need bones, or whose generated rig is unusable. Tripo's
non-humanoid auto-rigger gave Count Fingers a skeleton with every bone at the origin;
tools/repair_rig.py measured the best possible placement at 81 mm from the vertices it
should sit inside, against a 20 mm tolerance, and refused to write. A second attempt
came back worse. The mesh and the texture are fine, so the skeleton goes and the fish
is animated by moving the whole node instead.

Not tools/strip_rig.py: that one writes FBX for Mixamo and stands the model upright,
which is right for a character and wrong for a fish - a fish's longest axis is its
length, so "stand it up" would put it on its tail.

The armature modifier is REMOVED, not applied. Applying it bakes the deformation the
skeleton is currently producing into the vertices - and when the skeleton is the broken
one, that bakes the tearing in permanently: the fish came out 1.90 x 2.00 x 2.00 m of
shredded fins instead of a fish. The undeformed mesh is the good one, so the modifier
is simply dropped.
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

# A mesh with no vertex groups was never part of the skin - generators ship stray
# primitives, and an Icosphere rode along with one of these before.
for stray in [o for o in bpy.data.objects if o.type == "MESH" and not o.vertex_groups]:
    print(f"dropping stray mesh '{stray.name}'")
    bpy.data.objects.remove(stray, do_unlink=True)

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for mesh in meshes:
    bpy.context.view_layer.objects.active = mesh
    for modifier in list(mesh.modifiers):
        if modifier.type == "ARMATURE":
            mesh.modifiers.remove(modifier)
    while mesh.vertex_groups:
        mesh.vertex_groups.remove(mesh.vertex_groups[0])
    mesh.parent = None

for armature in [o for o in bpy.data.objects if o.type == "ARMATURE"]:
    bpy.data.objects.remove(armature, do_unlink=True)

corners = [m.matrix_world @ v.co for m in meshes for v in m.data.vertices]
lo = [min(c[i] for c in corners) for i in range(3)]
hi = [max(c[i] for c in corners) for i in range(3)]
print("meshes %d, extent X %.3f Y %.3f Z %.3f"
      % (len(meshes), hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]))

bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB",
                          export_animations=False, export_skins=False,
                          export_yup=True)
print("wrote", dst)
