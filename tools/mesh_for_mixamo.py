"""Write a plain mesh OBJ for Mixamo's auto-rigger.

Deliberately minimal. An earlier version applied the armature modifier, cleared vertex
groups and rotated the result, and the mesh arrived at Mixamo shredded - every extra
operation on a skinned mesh is a chance to corrupt it. OBJ carries geometry and UVs and
nothing else: no skin, no modifiers, no armature, so there is nothing to corrupt.

    blender --background --factory-startup --python mesh_for_mixamo.py -- in.glb out.obj
"""
import sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

for stray in [o for o in bpy.data.objects if o.type == "MESH" and not o.vertex_groups]:
    bpy.data.objects.remove(stray, do_unlink=True)

bpy.ops.object.select_all(action="DESELECT")
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for mesh in meshes:
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    print(f"{mesh.name}: {len(mesh.data.vertices)} verts")

def extent():
    lo = [min((v.co[i] for m in meshes for v in m.data.vertices)) for i in range(3)]
    hi = [max((v.co[i] for m in meshes for v in m.data.vertices)) for i in range(3)]
    return [hi[i] - lo[i] for i in range(3)]

size = extent()
print("extent in Blender (Z should be tallest): X %.2f Y %.2f Z %.2f" % tuple(size))
if size.index(max(size)) != 2:
    print("  WARNING: still not upright")

bpy.ops.wm.obj_export(filepath=dst, export_selected_objects=True,
                      export_materials=False, forward_axis="NEGATIVE_Z", up_axis="Y")
print("wrote", dst)
