"""Strip the skeleton off a character and write a plain mesh FBX for Mixamo.

Mixamo does its own auto-rigging and wants an unrigged mesh. A model that arrives with
someone else's skeleton already in it is the whole problem this avoids: Mixamo clips are
authored against Mixamo's rest pose and bone axes, so the rig has to be Mixamo's, not a
generator's approximation of it.

    blender --background --factory-startup --python strip_rig.py -- in.glb out.fbx
"""
import sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
if src.lower().endswith((".glb", ".gltf")):
    bpy.ops.import_scene.gltf(filepath=src)
else:
    bpy.ops.import_scene.fbx(filepath=src)

# Anything with no vertex groups is stray geometry, not part of the character.
for stray in [o for o in bpy.data.objects if o.type == "MESH" and not o.vertex_groups]:
    print(f"dropping stray mesh '{stray.name}'")
    bpy.data.objects.remove(stray, do_unlink=True)

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
print(f"meshes: {len(meshes)}")

for mesh in meshes:
    # The armature holds the character upright and at scale; baking that into the mesh
    # before the armature goes keeps the pose and the size.
    for mod in list(mesh.modifiers):
        if mod.type == "ARMATURE":
            bpy.context.view_layer.objects.active = mesh
            bpy.ops.object.modifier_apply(modifier=mod.name)
    while mesh.vertex_groups:
        mesh.vertex_groups.remove(mesh.vertex_groups[0])
    mesh.parent = None
    print(f"  {mesh.name}: {len(mesh.data.vertices)} verts, groups cleared")

for arm in [o for o in bpy.data.objects if o.type == "ARMATURE"]:
    print(f"removing armature '{arm.name}'")
    bpy.data.objects.remove(arm, do_unlink=True)

# Stand the character up, measured rather than assumed.
#
# In Blender a standing figure is tallest in Z, and the FBX exporter converts to Y-up
# on the way out. Generated models arrive on their back, so a rotation is needed - but
# guessing its sign puts the character upside down, which is how the last two attempts
# went. Measuring which axis is longest, and which way the head points, settles both
# the axis and the sign.
import math

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for mesh in meshes:
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)

def extent():
    lo = [min(( (m.matrix_world @ v.co)[i] for m in meshes for v in m.data.vertices)) for i in range(3)]
    hi = [max(( (m.matrix_world @ v.co)[i] for m in meshes for v in m.data.vertices)) for i in range(3)]
    return [hi[i] - lo[i] for i in range(3)]

size = extent()
longest = size.index(max(size))
print(f"extent before: {['%.2f' % v for v in size]}, longest axis {'XYZ'[longest]}")

if longest == 1:            # tall in Y: lying on its back or front
    for mesh in meshes:
        mesh.rotation_euler = (math.radians(90), 0.0, 0.0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
elif longest == 0:          # tall in X: on its side
    for mesh in meshes:
        mesh.rotation_euler = (0.0, math.radians(90), 0.0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

size = extent()
print(f"extent after:  {['%.2f' % v for v in size]}, longest axis {'XYZ'[size.index(max(size))]}")

# Upright but possibly inverted. The head is the end with less material around it -
# a pair of boots is bulkier in plan than a hat - so compare the spread of the top
# tenth against the bottom tenth and flip if the bulk is at the top.
zs = [(m.matrix_world @ v.co).z for m in meshes for v in m.data.vertices]
lo, hi = min(zs), max(zs)
band = (hi - lo) * 0.12
def spread(at_top):
    pts = []
    for m in meshes:
        for v in m.data.vertices:
            w = m.matrix_world @ v.co
            inside = (w.z > hi - band) if at_top else (w.z < lo + band)
            if inside:
                pts.append(w)
    if not pts:
        return 0.0
    return max(p.x for p in pts) - min(p.x for p in pts)

top, bottom = spread(True), spread(False)
print(f"width at top {top:.2f}, at bottom {bottom:.2f}")
if top > bottom * 1.25:
    print("  upside down - flipping")
    for mesh in meshes:
        mesh.rotation_euler = (math.radians(180), 0.0, 0.0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.fbx(filepath=dst, use_selection=True, path_mode="COPY",
                         embed_textures=True, add_leaf_bones=False,
                         mesh_smooth_type="FACE")
print("wrote", dst)
