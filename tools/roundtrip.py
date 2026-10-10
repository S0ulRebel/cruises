"""Import a glTF and export it again, so Blender rewrites the skin.

Tripo's rigged export omits the skin's `skeleton` root reference. The file is valid
glTF and other tools cope, but Godot uses that field to resolve the bone hierarchy and
without it the skinned mesh collapses to the origin. Blender rebuilds the armature on
import and writes a complete skin on export.
"""
import bpy, sys

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

# Blender's startup scene can leave a primitive behind, and it would be exported into
# the character as stray geometry. Anything with no vertex groups is not part of a
# skinned character.
for stray in [o for o in bpy.data.objects if o.type == "MESH" and not o.vertex_groups]:
    print(f"dropping stray mesh '{stray.name}' ({len(stray.data.vertices)} verts)")
    bpy.data.objects.remove(stray, do_unlink=True)

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
print(f"imported: {len(meshes)} mesh, {len(arms)} armature")
for a in arms:
    print(f"  armature '{a.name}' bones={len(a.data.bones)}")
for m in meshes:
    print(f"  mesh '{m.name}' verts={len(m.data.vertices)} groups={len(m.vertex_groups)}")

bpy.ops.export_scene.gltf(
    filepath=dst,
    export_format="GLB",
    export_skins=True,
    export_yup=True,
    export_apply=False,
)
print("exported", dst)
