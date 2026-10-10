r"""Bake a character and a folder of Mixamo clips into one GLB with all its animations.

Run through Blender, not the ComfyUI python:

    "C:\Program Files\Blender Foundation\Blender 4.3\blender.exe" --background --factory-startup ^
        --python merge_animations.py -- <character.glb> <animations folder> <out.glb>

The alternative is doing it in the Godot editor: import each clip, build a BoneMap against
SkeletonProfileHumanoid, set the Bone Renamer's skeleton name, reimport, then collect the
results into an AnimationLibrary on the character. Six clips of that is an hour of clicking
that has to be repeated for every character and cannot be checked into the repo.

This works because a Blender action addresses bones by name, and Mixamo's clips and Tripo's
rig use the same mixamorig names - so an action imported with one armature applies to another
without retargeting. Bone names are compared before anything is written, and the export is
refused if they do not line up, because an action that silently matches nothing produces a
character that simply stands still.
"""
import os
import sys
from pathlib import Path

import bpy
import math
from mathutils import Matrix

# Blender's factory scene runs at 24 fps and the FBX importer OVERWRITES the scene rate from
# whatever file it is reading. So the character arrived keyed at 24 fps and left exported at
# 30, and every clip it already had came out 20% shorter - a captain whose idle, walk and
# slash all silently ran 25% fast, in a file that was otherwise correct. Import and export
# only round-trip when the rate is the same at both ends, so it is pinned here and checked
# again before the write.
FPS = 30

# A point-and-click moves the character from code: the walk clip only has to move the
# legs. Left in, the clip's hip track carries him across the room on top of whatever
# the game is doing - 4.5 m per cycle, straight out of the scene - and the two fight.
PIN_ROOT = True


HIPS_NAMES = ("mixamorig:Hips", "mixamorig_Hips", "Hips")


def stand_up(clip_rig):
    """Turn a clip's armature upright, the same way from_mixamo.py turns the character.

    Mixamo hands out Y-up FBX. tools/from_mixamo.py rotates the character -90 about X so
    he stands in Blender's Z-up world; a clip left Y-up then describes its hips rotation
    in a frame a quarter turn away from his, and he folds in half on the first frame.

    The same turn applied to both keeps bone-local rotations meaning the same thing, which
    is the whole reason the action can be copied across at all.
    """
    bones = clip_rig.data.bones
    if not bones:
        return False
    # Bake the object transform in FIRST. Blender's FBX importer puts the Y-up to Z-up
    # turn on the armature OBJECT for some Mixamo exports and leaves it in the data for
    # others, so testing the data alone answers the wrong question and the clip silently
    # stays a quarter turn out - which lands the captain flat on his back.
    # ROTATION ONLY. The object also carries Mixamo's 0.01 centimetre scale, and
    # unit_ratio() below reads that scale to shrink the hips' translation to the
    # character's metres. Bake the scale away here and that ratio becomes 1, the hips
    # travel a hundred times too far, and he leaves the room on the first frame.
    turn = clip_rig.matrix_world.to_quaternion().to_matrix().to_4x4()
    clip_rig.data.transform(turn)
    keep = clip_rig.matrix_basis.to_scale()
    clip_rig.matrix_basis = Matrix.Diagonal(keep.to_4d())
    bpy.context.view_layer.update()

    span = [max(b.head_local[i] for b in bones) - min(b.head_local[i] for b in bones)
            for i in range(3)]
    if span.index(max(span)) != 1:
        return False
    clip_rig.data.transform(Matrix.Rotation(math.radians(-90), 4, "X"))
    bpy.context.view_layer.update()
    return True


def rest_world(rig, bone_name):
    """A bone's rest ORIENTATION in world space, as a quaternion."""
    bone = rig.data.bones.get(bone_name)
    if bone is None:
        return None
    return (rig.matrix_world.to_3x3() @ bone.matrix_local.to_3x3()).to_quaternion()


def retarget(action, source_rig, target_rig):
    """Re-express a clip's rotations in the TARGET rig's rest frame.

    Matching bone names is not enough. A pose rotation is stored in the bone's own local
    space, so the same numbers mean different things on two rigs whose bones rest at
    different angles. Copying them raw worked on Pillage People only because the captain's
    rig and Mixamo's clips happened to share a rest pose; here they do not, and the
    difference came out as a 90 degree twist down both forearms - thumbs pointing down,
    palms to camera - on a character who was otherwise perfect.

    So copy how far each bone has TURNED FROM ITS OWN REST, which is what
    actors/outfit/retarget.gd does in Pillage People. With C = rest_target^-1 * rest_source,
    the same world-space turn is written on the target as

        q_target = C * q_source * C^-1

    and the hips' translation, being a vector in bone space, turns by C as well. Bones
    whose rests already agree get C = identity and are copied untouched.
    """
    import re
    from mathutils import Quaternion, Vector

    channels = {}
    for curve in action.fcurves:
        hit = re.match(r'pose\.bones\["([^"]+)"\]\.(rotation_quaternion|location)$',
                       curve.data_path)
        if hit:
            channels.setdefault((hit.group(1), hit.group(2)), {})[curve.array_index] = curve

    turned = 0
    for (bone, prop), parts in channels.items():
        source, target = rest_world(source_rig, bone), rest_world(target_rig, bone)
        if source is None or target is None:
            continue
        correction = target.inverted() @ source
        if abs(correction.angle) < 1e-4:
            continue

        width = 4 if prop == "rotation_quaternion" else 3
        for index in range(width):
            if index not in parts:
                parts[index] = action.fcurves.new(
                    f'pose.bones["{bone}"].{prop}', index=index,
                    action_group=bone)
        frames = sorted({key.co[0] for curve in parts.values()
                         for key in curve.keyframe_points})
        if not frames:
            continue

        fixed = []
        for frame in frames:
            values = [parts[i].evaluate(frame) for i in range(width)]
            if prop == "rotation_quaternion":
                moved = correction @ Quaternion(values) @ correction.inverted()
            else:
                moved = correction @ Vector(values)
            fixed.append((frame, list(moved)))

        for index in range(width):
            curve = parts[index]
            for key in reversed(curve.keyframe_points):
                curve.keyframe_points.remove(key, fast=True)
            for frame, values in fixed:
                curve.keyframe_points.insert(frame, values[index], options={"FAST"})
            curve.update()
        turned += 1
    return turned


def vertical_index(rig, hips_names=HIPS_NAMES):
    """Which of the hips bone's three LOCAL axes points up in the world.

    A pose bone's location is in bone space, and which index is vertical is a fact about
    the rig rather than a convention. This used to be hard-coded to 1, which is right for
    a Mixamo clip downloaded from Mixamo and wrong for HY-Motion's export of the same
    skeleton: it kept a horizontal axis and deleted the real one, so every clip came out
    with 0.8-1.9 m of hip drift and a dead flat vertical - a walk that slides sideways out
    of the room without ever shifting its weight.

    Read off the rest matrix instead: bone space -> armature space -> world, then take the
    axis whose world direction is most vertical.
    """
    for name in hips_names:
        bone = rig.data.bones.get(name)
        if bone is None:
            continue
        to_world = rig.matrix_world.to_3x3() @ bone.matrix_local.to_3x3()
        return max(range(3), key=lambda i: abs(to_world.col[i].z))
    return 1


def unit_ratio(clip_rig, character_rig):
    """How much to shrink the clip's hip TRANSLATION to fit the character's rig.

    A pose bone's location is in Blender units, and the FBX importer leaves a Mixamo clip
    on an armature OBJECT scaled 0.01 - so its hips translate by values around 100 while
    the character, whose scale is baked into his bones at 1.0, needs values around 1.
    Copying the action across without this makes a 1.9 m captain bob SIX METRES. Rotation
    is unaffected: an angle is an angle on any rig.
    """
    mine = abs(character_rig.matrix_world.to_scale()[2]) or 1.0
    theirs = abs(clip_rig.matrix_world.to_scale()[2]) or 1.0
    return theirs / mine


def pin_root_motion(action, up=1, hips_names=HIPS_NAMES, ratio=1.0):
    """Keep rotation everywhere, and of position keep only the hips' vertical bob.

    Two separate problems, both of which stretch or displace the character:

    POSITION ON LIMB BONES. A generated clip keys location and scale on every bone,
    not just the root. A bone's position is its length on the rig it was authored
    for, so replaying those on a differently proportioned character pulls the
    skeleton apart - arms and legs stretched away from the body. Bone lengths must
    come from the target rig, which means rotation is the only thing worth copying.

    HIP TRAVEL. The walk's hips carry the character 4.5 m forward. In a point-and-
    click the code decides where someone stands, so the clip animating the legs and
    the game moving the body fight each other and he drifts out of the room. The
    vertical bob is kept: that is the weight shift, and it reads as walking rather
    than gliding.
    """
    removed = 0
    for curve in list(action.fcurves):
        path = curve.data_path
        is_hips = any(f'["{n}"]' in path for n in hips_names)
        if path.endswith("scale"):
            action.fcurves.remove(curve)
            removed += 1
        elif path.endswith("location"):
            # The hips keep their vertical axis only. Everything else goes.
            if not (is_hips and curve.array_index == up):
                action.fcurves.remove(curve)
                removed += 1
            elif ratio != 1.0:
                for key in curve.keyframe_points:
                    key.co[1] *= ratio
                    key.handle_left[1] *= ratio
                    key.handle_right[1] *= ratio
                curve.update()
    return removed


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    pin_fps()


def pin_fps():
    """Returns the rate it displaced, or 0 if it was already right."""
    was = bpy.context.scene.render.fps
    bpy.context.scene.render.fps = FPS
    bpy.context.scene.render.fps_base = 1.0
    return 0 if was == FPS else was


def armature_in(objects):
    for obj in objects:
        if obj.type == "ARMATURE":
            return obj
    return None


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    character = Path(argv[0])
    folder = Path(argv[1])
    out = Path(argv[2])

    clear()
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(character))
    rig = armature_in(set(bpy.data.objects) - before)
    if rig is None:
        raise SystemExit("no armature in the character file")
    bones = {b.name for b in rig.data.bones}
    print(f"character: {character.name}, {len(bones)} bones")

    clips = sorted(p for p in folder.iterdir() if p.suffix.lower() in (".fbx", ".glb", ".gltf"))
    if not clips:
        raise SystemExit(f"no clips in {folder}")

    added = []
    for clip in clips:
        existing = set(bpy.data.objects)
        existing_actions = set(bpy.data.actions)
        if clip.suffix.lower() == ".fbx":
            # automatic_bone_orientation MUST stay off. On it, Blender recomputes each
            # bone's roll, so the action's rotations stop meaning the same thing on the
            # character's original bones and the mesh tears apart - while every bone name
            # still matches, so a name check passes and the file looks fine until drawn.
            bpy.ops.import_scene.fbx(filepath=str(clip), ignore_leaf_bones=False,
                                     automatic_bone_orientation=False)
        else:
            bpy.ops.import_scene.gltf(filepath=str(clip))
        fresh = set(bpy.data.objects) - existing
        new_actions = list(set(bpy.data.actions) - existing_actions)

        imported_rig = armature_in(fresh)
        if (os.environ.get("MATCH_CLIP_FRAME") == "1"
                and imported_rig is not None and stand_up(imported_rig)):
            print(f"  {clip.name}: stood upright to match the character")
        their_bones = {b.name for b in imported_rig.data.bones} if imported_rig else set()
        shared = bones & their_bones
        if not new_actions:
            print(f"  {clip.name}: no animation in this file, skipped")
        elif len(shared) < len(bones) * 0.8:
            # Coverage of the CHARACTER's bones, not the clip's. A Mixamo clip carries the
            # full 65-bone skeleton; a character Mixamo rigged at a lower LOD has fewer,
            # because Tripo's mesh only resolved two digits per hand. 41 of the clip's 65
            # is not a mismatch - it is 41 of the character's 41, and the clip's spare
            # finger bones simply go unused. Measuring the wrong way round skipped every
            # clip and produced a character with no animation at all.
            print(f"  {clip.name}: only {len(shared)} of the character's {len(bones)} "
                  f"bones match, skipped")
        else:
            action = new_actions[0]
            action.name = clip.stem
            # A fake user keeps the action alive after the armature it arrived on is deleted;
            # without it Blender drops unused actions and the export comes out empty.
            action.use_fake_user = True
            # Rest frames first: pinning and unit scaling below both assume the curves
            # already mean what they will mean on the character.
            # Both of these are off by default. Each was written to chase the rolled
            # hands and each made it worse on its own: retarget() reproduces the clip's
            # turn faithfully on top of a rest that is itself rolled, and stand_up() is
            # only right for a clip exported in the character's frame. Kept, because the
            # fix needs them once the rest pose is sorted out, but not in the path.
            moved = (retarget(action, imported_rig, rig)
                     if os.environ.get("RETARGET") == "1" else 0)
            up = vertical_index(rig)
            ratio = unit_ratio(imported_rig, rig)
            pinned = pin_root_motion(action, up, ratio=ratio) if PIN_ROOT else 0
            added.append((clip.stem, action, len(shared), len(their_bones), pinned, moved))

        # The clip's own skeleton and mesh are not wanted - only its motion.
        for obj in fresh:
            bpy.data.objects.remove(obj, do_unlink=True)

    if not added:
        raise SystemExit("nothing matched the character's bones - refusing to write a file "
                         "whose animations would do nothing")

    # Each action goes on its own NLA track so the glTF exporter emits them as separate,
    # named animations rather than one merged timeline.
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = None
    for name, action, _, _, _, _ in added:
        track = rig.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, int(action.frame_range[0]), action)

    for name, _, shared, total, pinned, moved in added:
        print(f"  {name}: {shared}/{total} bones matched, {moved} retargeted")

    moved = pin_fps()
    if moved:
        print(f"  note: an import moved the scene to {moved} fps; exporting at {FPS}")

    bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB",
                              export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_skins=True, export_yup=True)
    print(f"\n{len(added)} animations -> {out}")


if __name__ == "__main__":
    main()
