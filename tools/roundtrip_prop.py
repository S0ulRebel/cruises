"""Import a prop's glTF and write it out again, so Blender rewrites the file.

Same reason as tools/roundtrip.py: a raw Tripo GLB does not survive Godot's importer.
A separate tool because roundtrip.py is for CHARACTERS - it deletes every mesh with no
vertex groups, which for an unrigged prop is the whole prop.

What it does drop is Tripo's reference Icosphere: a 42-vertex ball at the origin that
rides along in the export and would otherwise appear in the room as a small grey blob.
Dropped by shape, not by name, so a renamed one still goes.

    blender --background --factory-startup --python tools/roundtrip_prop.py -- in.glb out.glb
"""

import sys

import bpy

STRAY_VERTS = 64  # Tripo's marker is 42; no real prop in this game is under this.

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
if not meshes:
    raise SystemExit("no mesh in %s" % src)
keeper = max(meshes, key=lambda o: len(o.data.vertices))
for stray in meshes:
    if stray is not keeper and len(stray.data.vertices) <= STRAY_VERTS:
        print("dropping stray '%s' (%d verts)" % (stray.name, len(stray.data.vertices)))
        bpy.data.objects.remove(stray, do_unlink=True)

kept = [o for o in bpy.data.objects if o.type == "MESH"]
tris = sum(len(o.data.loop_triangles) for o in kept) or None
for o in kept:
    o.data.calc_loop_triangles()
tris = sum(len(o.data.loop_triangles) for o in kept)
print("kept %d mesh, %d verts, %d tris" % (len(kept), sum(len(o.data.vertices) for o in kept), tris))

bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB")
print("wrote %s" % dst)
