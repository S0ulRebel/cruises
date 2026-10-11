"""Restore authored glTF normals after rigging, without rebuilding the model.

python tools/restore_mesh_normals.py --reference original.glb --rigged rigged.glb \
    --out corrected.glb

Matches corners by position AND UV, so texture seams stay intact. Only the dense
base NORMAL accessor is patched. Geometry, UVs, skin, morph targets and embedded
textures remain byte-for-byte unchanged. Inputs are never overwritten.
"""

import argparse
import hashlib
import json
import math
import struct
from pathlib import Path


def read_glb(path):
    data = bytearray(path.read_bytes())
    magic, version, size = struct.unpack_from("<III", data)
    if magic != 0x46546C67 or version != 2 or size != len(data):
        raise ValueError("Expected a complete glTF 2 binary")
    length, kind = struct.unpack_from("<II", data, 12)
    if kind != 0x4E4F534A:
        raise ValueError("Expected a JSON chunk")
    doc = json.loads(data[20:20 + length])
    binary_start = 28 + length
    if struct.unpack_from("<I", data, 24 + length)[0] != 0x004E4942:
        raise ValueError("Expected an embedded binary chunk")
    return data, doc, binary_start


def accessor_layout(doc, binary_start, index, components):
    accessor = doc["accessors"][index]
    if accessor["componentType"] != 5126 or "sparse" in accessor:
        raise ValueError("Expected dense float attributes")
    view = doc["bufferViews"][accessor["bufferView"]]
    start = binary_start + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    stride = view.get("byteStride", components * 4)
    return start, stride, accessor["count"]


def floats(data, doc, binary_start, index, components):
    start, stride, count = accessor_layout(doc, binary_start, index, components)
    return [struct.unpack_from("<" + "f" * components, data, start + i * stride)
            for i in range(count)]


def corners(data, doc, binary_start):
    if len(doc["meshes"]) != 1 or len(doc["meshes"][0]["primitives"]) != 1:
        raise ValueError("This repair targets one mesh with one primitive")
    attributes = doc["meshes"][0]["primitives"][0]["attributes"]
    positions = floats(data, doc, binary_start, attributes["POSITION"], 3)
    uvs = floats(data, doc, binary_start, attributes["TEXCOORD_0"], 2)
    normals = floats(data, doc, binary_start, attributes["NORMAL"], 3)
    keys = [tuple(round(value, 6) for value in position + uv)
            for position, uv in zip(positions, uvs)]
    return attributes, keys, normals


def restore(reference, rigged, output):
    if output.resolve() in [reference.resolve(), rigged.resolve()]:
        raise ValueError("Output must be separate from both source assets")
    source_data, source_doc, source_start = read_glb(reference)
    target_data, target_doc, target_start = read_glb(rigged)
    _, source_keys, source_normals = corners(source_data, source_doc, source_start)
    attributes, target_keys, old_normals = corners(target_data, target_doc, target_start)
    candidates = {}
    for key, normal in zip(source_keys, source_normals):
        candidates.setdefault(key, []).append(normal)
    missing = set(target_keys) - candidates.keys()
    if missing:
        raise ValueError("Rigged geometry/UVs do not match the reference")
    # Preserve intentional hard edges when a corner has several authored normals.
    normals = [min(candidates[key], key=lambda normal: sum((a - b) ** 2
               for a, b in zip(normal, old))) for key, old in zip(target_keys, old_normals)]
    start, stride, count = accessor_layout(target_doc, target_start, attributes["NORMAL"], 3)
    if count != len(normals):
        raise ValueError("Normal count differs from the matched corners")
    before = bytes(target_data)
    for i, normal in enumerate(normals):
        struct.pack_into("<fff", target_data, start + i * stride, *normal)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(target_data)
    angles = sorted(math.degrees(math.acos(max(-1, min(1, sum(a * b for a, b in zip(old, normal))))))
                    for old, normal in zip(old_normals, normals))
    report = {"matched_corners": count, "changed_normals": sum(old != normal for old, normal in zip(old_normals, normals)),
              "normal_angle_p90_degrees": angles[int(count * .9)],
              "reference_sha256": hashlib.sha256(source_data).hexdigest(),
              "rigged_sha256": hashlib.sha256(before).hexdigest(),
              "output_sha256": hashlib.sha256(target_data).hexdigest(),
              "changed_attribute": "base NORMAL only"}
    print(json.dumps(report, indent=2))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", required=True, type=Path)
    parser.add_argument("--rigged", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    restore(args.reference, args.rigged, args.out)
