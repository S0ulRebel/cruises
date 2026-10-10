r"""Bake a library of hand poses onto a rigged character as single-pose clips.

    blender --background --factory-startup --python add_hand_poses.py -- ^
        <character.glb> <poses.json> <bend_axes.json> <out.glb>

Why these are clips and not part of the body animation: actors/parts/animator.gd blends
them on an Add2 layer filtered to the finger bones, so a hand pose plays OVER whatever
the arms are doing. A walk with a pointing hand is then two clips, not a third clip that
has to be authored for that combination.

WHICH NUMBER TO USE. The pose file gives three forms per bone and only one of them is
safe here:

  raw            the quaternion as three.js stores it - bone.quaternion REPLACES the rest
                 rotation, so the value already contains VNCCS's own rest pose. Writing it
                 into Blender's pose_bone.rotation_quaternion, which is an offset FROM
                 rest, bakes a foreign rest onto this rig.
  delta          inverse(open_palm) * pose, so VNCCS's rest cancels. Correct in principle,
                 but still assumes our finger bones' local axes line up with theirs.
  bend_degrees   the same movement as one angle about one axis. A finger bends about a
                 single axis, so this cannot be twisted by an axis-convention mismatch.

This uses bend_degrees, with the axis read from the measured file rather than assumed:
the finger bones on this rig were measured bending about local X for most joints and Z
for some, with per-bone signs. Guessing X everywhere would silently splay the thumbs.

Quaternion order is another trap worth naming: the pose file is three.js [x, y, z, w] and
Blender is [w, x, y, z]. Only the delta path would hit it, and that path is not used.

Bones that are absent are skipped, not treated as an error. Tripo fuses middle, ring and
pinky on some meshes and Mixamo then rigs 41 bones instead of 65; such a character picks
up six finger bones and ignores the other twenty-four. The count is printed so a silently
half-applied pose cannot pass for a working one.
"""
import json
import math
import sys

import bpy
from mathutils import Matrix, Quaternion

FINGERS = ("Thumb", "Index", "Middle", "Ring", "Pinky")


# How much of the measured bend this mesh can actually take. The poses were measured
# on a human-proportioned reference hand; Tripo's hand has no interior volume at the
# knuckles, so past roughly 40 degrees on a single joint the finger passes through the
# palm and the fist renders as a smooth crumpled lump with no knuckles at all. Rendered
# at 900px from above, the knuckle ridges are countable at a 40 degree cap and gone by
# 55. The deepest joint in the library is the fist's ring MCP at 87.6 degrees, so the
# whole library is scaled by 40/87.6 rather than clamped - clamping flattens fist and
# grip into the same shape, scaling keeps them apart.
BEND_SCALE = 0.45

# Poses in the library that are not baked. "chop" is flexion-only like the rest, and a
# chop needs the fingers brought TOGETHER - abduction, which the measured data has no
# channel for. Without it the pose is open_palm with a tucked thumb, so it shipped as a
# duplicate. Dropped 10 Oct 2026.
SKIP = {"chop"}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    character, poses_path, axes_path, out = argv[0], argv[1], argv[2], argv[3]

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30
    bpy.ops.import_scene.gltf(filepath=character)

    rig = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
    if rig is None:
        print("REFUSED: no armature")
        return 1

    poses = json.load(open(poses_path, encoding="utf-8"))["poses"]
    axes = json.load(open(axes_path, encoding="utf-8"))
    present = {b.name for b in rig.data.bones}
    finger_bones = [n for n in present if any(f in n for f in FINGERS)]
    print(f"rig       {len(present)} bones, {len(finger_bones)} of them fingers")

    kept = [a for a in (rig.animation_data.nla_tracks if rig.animation_data else [])]
    print(f"existing  {len(kept)} clips kept")

    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")

    made = []
    for name, bones in poses.items():
        if name in SKIP:
            continue
        bpy.ops.pose.select_all(action="SELECT")
        bpy.ops.pose.rot_clear()

        action = bpy.data.actions.new(f"hand_{name}")
        action.use_fake_user = True
        rig.animation_data.action = action

        applied, skipped = 0, 0
        for bone_name, data in bones.items():
            bone = rig.pose.bones.get(bone_name)
            if bone is None:
                skipped += 1
                continue
            spec = axes.get(bone_name, {})
            axis = spec.get("axis", "X")
            sign = spec.get("sign", 1.0)
            degrees = data.get("bend_degrees", 0.0) * BEND_SCALE
            bone.rotation_mode = "QUATERNION"
            vector = {"X": (1, 0, 0), "Y": (0, 1, 0), "Z": (0, 0, 1)}[axis]
            bone.rotation_quaternion = Quaternion(vector, math.radians(degrees) * sign)
            # Two keys, a second apart. A single-key action has zero length, and a zero
            # length clip cannot be blended on a weight - it reads as absent.
            for frame in (1, 31):
                bone.keyframe_insert("rotation_quaternion", frame=frame)
            applied += 1
        made.append((name, applied, skipped))

    bpy.ops.object.mode_set(mode="OBJECT")

    rig.animation_data.action = None
    for name, _, _ in made:
        track = rig.animation_data.nla_tracks.new()
        track.name = f"hand_{name}"
        track.strips.new(f"hand_{name}", 1, bpy.data.actions[f"hand_{name}"])

    for name, applied, skipped in made:
        print(f"  hand_{name:<10} {applied} bones posed, {skipped} absent")

    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB",
                              export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_skins=True, export_yup=True)
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
