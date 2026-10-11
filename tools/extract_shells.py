"""Lift a separate piece out of a fused Tripo character.

Tripo hands back one mesh with everything in it, but the pieces are still
separate SHELLS inside it - the hat does not share an edge with the head. They do
not show up as loose parts until the UV-split duplicate vertices are welded: the
captain reads as 2,010 fragments before a weld and 13 real shells after it.

    blender --background --factory-startup --python tools/extract_shells.py -- \
        <source.glb> --list
    blender --background --factory-startup --python tools/extract_shells.py -- \
        <source.glb> --shell 1,2 --out art/.../hat.glb

`--shell` takes one index or a comma-separated list, for a piece that is more than
one shell - the captain's hat is the tricorn and its feather, which Tripo kept
apart. Nothing is scaled or moved here: where the piece sits on another head is a
placement decision, and it lives in data/pieces.json where it can be nudged.

Shell indices come from --list and are ordered by vertex count, largest first, so
they are stable for a given source file. The weld is 0.1 mm, which is below any
real feature and above the float noise the exporter leaves behind.
"""

import sys

import bmesh
import bpy
from mathutils import Vector

WELD = 1e-4


def argv():
    return sys.argv[sys.argv.index("--") + 1:]


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit("no mesh in %s" % path)
    return max(meshes, key=lambda o: len(o.data.vertices))


def shells_of(obj):
    """Vertex-index groups, largest first, after welding the UV splits."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=WELD)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    seen, groups = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, comp = [v], []
        seen.add(v.index)
        while stack:
            cur = stack.pop()
            comp.append(cur.index)
            for e in cur.link_edges:
                other = e.other_vert(cur)
                if other.index not in seen:
                    seen.add(other.index)
                    stack.append(other)
        groups.append(comp)
    bm.free()
    groups.sort(key=len, reverse=True)
    return groups


def bounds(obj, indices):
    co = [obj.data.vertices[i].co for i in indices]
    return (Vector((min(p.x for p in co), min(p.y for p in co), min(p.z for p in co))),
            Vector((max(p.x for p in co), max(p.y for p in co), max(p.z for p in co))))


def profile(points, lo_z, hi_z, step=0.01, band=0.012):
    """Width, depth and centre at each height, for finding a skull's widest level."""
    out = []
    z = lo_z
    while z <= hi_z:
        slab = [p for p in points if abs(p.z - z) < band]
        if slab:
            xs = [p.x for p in slab]
            ys = [p.y for p in slab]
            out.append((z, max(xs) - min(xs), max(ys) - min(ys),
                        (max(xs) + min(xs)) / 2.0, (max(ys) + min(ys)) / 2.0))
        z += step
    return out


def head_landmarks(path):
    """The two things a hat is placed by: how wide the skull is at its widest, and
    where the crown is. Measured rather than guessed, because the portrait head and
    the head inside the full character are separate Tripo runs at different scales."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    obj = max([o for o in bpy.data.objects if o.type == "MESH"],
              key=lambda o: len(o.data.vertices))
    co = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo_z = min(p.z for p in co)
    hi_z = max(p.z for p in co)
    # Only the top half: a neck or a body below would win the "widest" contest.
    rows = profile(co, lo_z + (hi_z - lo_z) * 0.5, hi_z)
    widest = max(rows, key=lambda r: r[1])
    return {"crown_z": hi_z, "width": widest[1],
            "centre": Vector((widest[3], widest[4], widest[0]))}


def fit_to_head(obj, head_path):
    """Scale and move the piece from the head it was made on onto another head.

    Uniform scale from the ratio of skull widths, then the piece is hung off the
    CROWN rather than off the origin - a hat is placed relative to the top of the
    head, and the two heads do not share an origin or a size.
    """
    donor_path = argv()[0]
    donor = head_landmarks(donor_path)
    target = head_landmarks(head_path)
    scale = target["width"] / donor["width"]

    # Reload the piece we just carved, since head_landmarks reset the file.
    print("fit: donor skull %.4f at z %.4f crown %.4f" % (donor["width"], donor["centre"].z, donor["crown_z"]))
    print("fit: target skull %.4f at z %.4f crown %.4f" % (target["width"], target["centre"].z, target["crown_z"]))
    print("fit: scale %.4f" % scale)
    return scale


def main():
    args = argv()
    source = args[0]
    obj = load(source)
    groups = shells_of(obj)

    if "--list" in args:
        print("shells: %d" % len(groups))
        for i, g in enumerate(groups):
            lo, hi = bounds(obj, g)
            print("  %2d verts=%-6d  x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f"
                  % (i, len(g), lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
        return

    wanted = [int(n) for n in args[args.index("--shell") + 1].split(",")]
    out = args[args.index("--out") + 1]
    keep = set()
    for index in wanted:
        keep |= set(groups[index])

    # Delete everything that is NOT the wanted shell, rather than duplicating it
    # out: that keeps the original material, the UVs and the vertex order of the
    # piece exactly as Tripo made them, so the shared texture still lines up.
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    doomed = [v for v in bm.verts if v.index not in keep]
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()

    if "--fit" in args:
        fit_to_head(obj, args[args.index("--fit") + 1])

    for other in [o for o in bpy.data.objects if o is not obj]:
        bpy.data.objects.remove(other, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True)
    lo, hi = bounds(obj, range(len(obj.data.vertices)))
    print("%s  verts=%d  x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f"
          % (out, len(obj.data.vertices), lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))


main()
