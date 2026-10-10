r"""Turn a Mixamo auto-rigged FBX into a textured GLB the game can load.

Run through Blender, not the ComfyUI python:

    "C:\Program Files\Blender Foundation\Blender 4.3\blender.exe" --background --factory-startup ^
        --python from_mixamo.py -- <mixamo.fbx> <basecolor.jpg> <out.glb>

WHY MIXAMO RIGS THE CHARACTER AND NOT TRIPO. Pillage People's tools/reorient_model.py says
it: a skinned mesh carries inverse-bind matrices and they do not follow a transform written
on the glTF root, so a rigged file that is turned the wrong way cannot be turned the right
way afterwards - the skeleton and the skin end up in different spaces and the mesh tears.
Blender fixes that by rotating armature and mesh together and recomputing the bind poses on
export, "and that is also, implicitly, what a round trip through Mixamo does - which is why
the Tripo characters that went through Mixamo for their animations came out upright and the
ones that did not, did not."

So the orientation fix is not a Blender pass BEFORE Mixamo, it is the Mixamo round trip
itself. The mesh goes up as a plain OBJ (tools/mesh_for_mixamo.py), comes back rigged and
upright, and this tool only has to put the texture back and write a GLB.

IMPORT SETTINGS ARE NOT NEGOTIABLE. ignore_leaf_bones=False and automatic_bone_orientation
=False, exactly as tools/merge_animations.py imports the clips. automatic_bone_orientation
recomputes every bone's rest orientation from its children, so a character imported with it
on and clips imported with it off describe rotations in different frames, and every joint
bends somewhere other than where the clip meant.

THE TEXTURE COMES BACK BY HAND because Mixamo is given an OBJ with no materials - UVs only.
The UVs survive the round trip untouched, so the 8K basecolor from Tripo still lines up; it
just needs a material to hang on.

THE SIZE IS BAKED INTO THE DATA, not left on a node. Mixamo exports in centimetres, so the
character arrives 1 cm tall with a 0.01 scale on the armature OBJECT. The FBX importer's
global_scale does not help: at global_scale=190 the bones still sit where they were (hips at
0.4646) and the 1.9 goes onto the armature's object scale - which is exactly the scale above
a Skeleton3D that tears a skinned mesh. So both the armature data and the mesh data are
scaled directly, through .transform(), and the object scale is reset to 1. After that the
file carries its own size and nothing downstream has to know.

Scaling the DATA rather than calling transform_apply() is deliberate: transform_apply on a
parented mesh in a --background Blender silently did nothing, twice, and a silent no-op here
looks identical to a model that was simply the wrong size to begin with.
"""
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

FPS = 30

# Whether to turn the character upright in Blender. Mixamo's FBX, glTF and Godot are all
# Y-up; Blender is Z-up and its FBX importer leaves this file's data Y-up. Turning him
# upright here also turns his bone REST, which then disagrees with a clip whose rest is
# still Y-up - and the hips rotation lands 90 degrees out, folding him in half. Set by
# the 5th argument.
STAND_UP = True


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


def bounds(obj, world=True):
    """Extent of a mesh, in world space or in its own data space.

    The difference is the whole bug this function was written around: straight off the
    importer the armature carries a 0.01 object scale, so the world extent says 1 cm while
    the vertices themselves are a metre apart. Sizing against the world extent therefore
    asks for a 190x scale on data that only needs 1.9x.
    """
    corners = [(obj.matrix_world @ v.co) if world else v.co for v in obj.data.vertices]
    lo = [min(c[i] for c in corners) for i in range(3)]
    hi = [max(c[i] for c in corners) for i in range(3)]
    return lo, hi


def texture(mesh, image_path):
    """One material, one image, straight into Base Color. No node graph worth the name."""
    material = bpy.data.materials.new("captain")
    material.use_nodes = True
    tree = material.node_tree
    principled = tree.nodes["Principled BSDF"]
    node = tree.nodes.new("ShaderNodeTexImage")
    node.image = bpy.data.images.load(str(image_path))
    node.location = (-400, 200)
    tree.links.new(node.outputs["Color"], principled.inputs["Base Color"])
    # Tripo bakes the lighting out, so the map is albedo: no specular highlight on top of it.
    principled.inputs["Roughness"].default_value = 0.85
    principled.inputs["Metallic"].default_value = 0.0
    mesh.data.materials.clear()
    mesh.data.materials.append(material)


YBOT = "D:/code/gan/ComfyUI_windows_portable/ComfyUI/input/3d/T-Pose_ybot.fbx"


def align_rolls(rig, reference=YBOT):
    """Give every bone the ROLL Mixamo's own skeleton uses.

    Mixamo's auto-rigger reads the roll off the mesh it is given. Captain Livé is modelled
    in an A-pose with his palms facing FORWARD, while Mixamo's rigs are built palms DOWN,
    so his hand and forearm bones came back rolled about 180 degrees from the convention
    its clips are authored in. Measured at the same frame of the same idle: Mixamo's rig
    puts the thumb 0.47 ABOVE the pinky, his put it 0.48 BELOW.

    No retargeting can fix that. Retargeting carries over how far a bone has TURNED from
    its rest; if the rest itself is rolled, the turn is faithfully reproduced on top of a
    wrong starting frame. The roll has to be corrected on the skeleton.

    Doing it in edit mode is safe for the mesh: a bone's roll defines its local axes, and
    at REST the armature deforms by identity whatever those axes are. Nothing moves. Only
    the meaning of a pose rotation changes - which is exactly what is wrong.

    Bone directions differ (he rests in an A-pose, the Y Bot in a T-pose), so this copies
    only the twist about each bone's own axis, via align_roll, and leaves head and tail
    exactly where Mixamo put them.
    """
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=reference, ignore_leaf_bones=False,
                             automatic_bone_orientation=False)
    fresh = set(bpy.data.objects) - before
    ref = next((o for o in fresh if o.type == "ARMATURE"), None)
    if ref is None:
        print("roll      reference skeleton has no armature; left alone")
        return 0

    # The Y Bot's own up-axis handling can differ from his, so compare in each rig's own
    # standing frame rather than in world space.
    want = {}
    rm = ref.matrix_world.to_3x3()
    for bone in ref.data.bones:
        want[bone.name] = (rm @ bone.matrix_local.to_3x3()).col[2].normalized()
    for obj in fresh:
        bpy.data.objects.remove(obj, do_unlink=True)

    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    turned = 0
    for edit in rig.data.edit_bones:
        target = want.get(edit.name)
        if target is None:
            continue
        was = edit.roll
        edit.align_roll(target)
        if abs(edit.roll - was) > 1e-4:
            turned += 1
    bpy.ops.object.mode_set(mode="OBJECT")
    print(f"roll      aligned {turned} of {len(rig.data.bones)} bones to the Mixamo skeleton")
    return turned


def bake_world(rig, meshes):
    """Stand the character up, by baking each object's world transform into its data.

    Tripo's Mixamo-preset FBX is authored Y-up, and it comes out of Mixamo the same way, so
    in Blender's Z-up world the captain arrives lying on his back - 1.90 m along Y and
    0.60 m along Z. The glTF exporter's Y-up conversion then turns a character who is
    already on his back into one who is on his back in Godot too.

    This is the axis fix, and it belongs HERE, after Mixamo, not before it. Rotating the
    mesh on the way IN is pointless: Mixamo orients the character itself, and anything done
    to the mesh beforehand is a conversion the pipeline does not ask for.

    Done by transforming the DATA and resetting the objects to identity, for the same
    reason the size is: transform_apply() depends on selection state and silently did
    nothing twice in a --background Blender.
    """
    for obj in [rig] + meshes:
        obj.data.transform(obj.matrix_world)
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.matrix_basis = Matrix.Identity(4)
        if obj.type == "MESH":
            obj.data.update()
    bpy.context.view_layer.update()

    # The object transforms turn out to be identity: it is the DATA that is Y-up, and
    # Blender's FBX importer leaves it that way. Measure which axis he is longest along
    # and stand him up if it is not Z. Measured rather than assumed, because the same
    # 90 degrees applied to a character who is ALREADY upright lays him down, and the
    # exported file looks fine until something draws it.
    lo, hi = bounds(meshes[0], world=False)
    span = [hi[i] - lo[i] for i in range(3)]
    if span.index(max(span)) == 1 and STAND_UP:
        # MINUS 90, not plus. Both stand him up and both pass a "Z is the tallest axis"
        # check; +90 stands him on his head. The owner remembered this as "one of the
        # axes was wrongly signed" and it is the only part of the turn that measuring the
        # extents cannot catch - which is why the head-above-feet check below exists.
        stand = Matrix.Rotation(math.radians(-90), 4, "X")
        for obj in [rig] + meshes:
            obj.data.transform(stand)
            if obj.type == "MESH":
                obj.data.update()
        bpy.context.view_layer.update()
        print(f"axis      was Y-up {[round(v, 3) for v in span]}, rotated -90 X")


def to_tpose(rig, meshes):
    """Turn the character's REST POSE into a true T-pose, arms horizontal.

    Mixamo's clips store every rotation relative to a rest pose whose arms are straight
    out - 0 degrees below horizontal, measured. Captain Livé is modelled in an A-pose and
    Mixamo's auto-rigger uses the uploaded mesh as the bind pose, so his rest sits 50
    degrees down. Choosing "T-pose" on the Mixamo download does NOT change this: the
    dropdown reads t-pose and the file still comes back at 50. Playing Mixamo's idle on
    that rig left his arms stuck out at 45 degrees where the clip means 82, which reads
    as a man who cannot lower his arms.

    So the rest is converted here. Three steps, and the middle one is the one people miss:

      1. pose the upper arms until shoulder-to-hand is horizontal,
      2. APPLY the armature modifier to a copy of the mesh, which bakes that deformation
         into the vertices - without this the mesh keeps its A-pose shape while the
         skeleton moves to T, and the two disagree,
      3. make the pose the new rest.

    Rotating only the upper arm is deliberate: its children follow rigidly, so the elbow
    and hand keep exactly the angles they were modelled with.
    """
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    print(f"t-pose    {len(rig.pose.bones)} pose bones, "
          f"arm={'mixamorig:LeftArm' in rig.pose.bones}")

    to_world = rig.matrix_world.to_3x3()
    head = rig.data.bones.get("mixamorig:Head")
    foot = rig.data.bones.get("mixamorig:LeftFoot")
    up = Vector((0.0, 0.0, 0.0))
    axis = max(range(3), key=lambda i: abs((to_world @ head.head_local)[i]
                                           - (to_world @ foot.head_local)[i]))
    up[axis] = 1.0 if (to_world @ head.head_local)[axis] > (to_world @ foot.head_local)[axis] else -1.0

    turned = []
    for side in ("Left", "Right"):
        arm = rig.pose.bones.get(f"mixamorig:{side}Arm")
        hand = rig.pose.bones.get(f"mixamorig:{side}Hand")
        if arm is None or hand is None:
            continue
        start = (rig.matrix_world @ arm.head)
        direction = ((rig.matrix_world @ hand.head) - start).normalized()
        flat = (direction - up * direction.dot(up)).normalized()
        correction = direction.rotation_difference(flat)
        before = math.degrees(math.asin(max(-1.0, min(1.0, -direction.dot(up)))))

        arm.rotation_mode = "QUATERNION"
        basis = (rig.matrix_world.to_3x3() @ arm.matrix.to_3x3()).to_quaternion()
        arm.rotation_quaternion = (basis.inverted() @ correction @ basis) @ arm.rotation_quaternion
        bpy.context.view_layer.update()
        after_dir = ((rig.matrix_world @ hand.head) - (rig.matrix_world @ arm.head)).normalized()
        after = math.degrees(math.asin(max(-1.0, min(1.0, -after_dir.dot(up)))))
        turned.append(f"{side} {before:+.0f} -> {after:+.0f}")

    bpy.ops.object.mode_set(mode="OBJECT")
    if not turned:
        print("t-pose    no arm bones found; left as modelled")
        return

    # Bake the deformation into the mesh before the rest changes under it.
    for mesh in meshes:
        modifier = next((m for m in mesh.modifiers if m.type == "ARMATURE"), None)
        if modifier is None:
            continue
        bpy.context.view_layer.objects.active = mesh
        copied = mesh.modifiers.new(modifier.name + "_bake", "ARMATURE")
        copied.object = modifier.object
        copied.use_deform_preserve_volume = modifier.use_deform_preserve_volume
        while mesh.modifiers[0] != copied:
            bpy.ops.object.modifier_move_up(modifier=copied.name)
        bpy.ops.object.modifier_apply(modifier=copied.name)

    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply()
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()
    print("t-pose    arms, degrees below horizontal: " + ", ".join(turned))


def bake_size(rig, meshes, target):
    """Scale armature and mesh together so the character stands `target` metres tall."""
    # Height is the Z extent, not the largest of the three: bake_world has already stood
    # him up, so if Z is not the tallest axis something is wrong and scaling by the widest
    # axis would quietly hide it.
    spans = [bounds(m, world=False) for m in meshes]
    tall = max((hi[2] - lo[2]) if STAND_UP else max(hi[i] - lo[i] for i in range(3))
               for lo, hi in spans)
    # Compared against DEPTH, not against the widest axis. A T-posed character is wider
    # than he is tall - Santi Wong is 1.70 m with a 1.95 m arm span - so "Z must be the
    # largest extent" calls a correctly standing chef a fallen one. Depth is the axis
    # that cannot legitimately exceed height on a figure who is on his feet. The real
    # test is head-above-feet by bone, below.
    deepest = max(hi[1] - lo[1] for lo, hi in spans)
    if STAND_UP and tall < deepest - 1e-6:
        raise SystemExit(f"REFUSED: not upright - Z extent {tall:.3f} is less than the "
                         f"depth ({deepest:.3f}); the character is lying down")
    factor = target / tall
    scale = Matrix.Scale(factor, 4)
    rig.data.transform(scale)
    rig.scale = (1.0, 1.0, 1.0)
    for mesh in meshes:
        mesh.data.transform(scale)
        mesh.data.update()
        # The mesh object's own transform is left alone. It carries the turn from the FBX's
        # Y-up into Blender's Z-up, and clearing it lays the character on his face.
    bpy.context.view_layer.update()
    return factor


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    source, image, out = Path(argv[0]), Path(argv[1]), Path(argv[2])
    height = float(argv[3]) if len(argv) > 3 else 1.9
    global STAND_UP
    STAND_UP = not (len(argv) > 4 and argv[4] == "nostand")

    clear()
    # Same flags as merge_animations.py uses for the clips. See the docstring.
    bpy.ops.import_scene.fbx(filepath=str(source), ignore_leaf_bones=False,
                             automatic_bone_orientation=False)

    armatures = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if len(armatures) != 1 or not meshes:
        print(f"REFUSED: {len(armatures)} armatures, {len(meshes)} meshes")
        return 1

    rig = armatures[0]
    names = [b.name for b in rig.data.bones]
    mixamo = [n for n in names if n.lower().startswith("mixamorig")]
    print(f"armature  {rig.name}  {len(names)} bones, {len(mixamo)} mixamorig")
    for want in ("Hips", "Spine", "Head", "RightArm", "RightHand", "RightHandThumb1",
                 "LeftFoot"):
        hit = [n for n in names if n.endswith(want)]
        print(f"  {want:<16} {hit[0] if hit else 'MISSING'}")
    # A bone COUNT does not say whether this is a Mixamo rig - it says which skeleton LOD
    # Mixamo was set to. 41 bones is a real Mixamo skeleton with thumb and index only;
    # the Standard Skeleton (65) has all five digits, which is what animator.gd filters on.
    essential = [n for n in ("Hips", "Spine", "Head", "LeftFoot", "RightHand")
                 if not any(b.endswith(n) for b in names)]
    if essential:
        print(f"REFUSED: not a Mixamo skeleton - missing {essential}")
        return 1
    digits = sorted({d for d in ("Thumb", "Index", "Middle", "Ring", "Pinky")
                     if any(d in b for b in names)})
    print(f"fingers   {digits}")
    if len(digits) < 5:
        print(f"  WARNING: only {len(digits)} of 5 digits. Mixamo rigged at a reduced "
              f"skeleton LOD; re-rig with Standard Skeleton (65) for hand animation.")

    # AFTER bake_world, never before: the roll is copied by comparing bone axes between
    # two armatures, and until he has been stood up his data is Y-up while the reference
    # skeleton's is Z-up, so every target vector is a quarter turn out and the alignment
    # silently does nothing useful.
    # FIRST, before anything transforms the data by hand: to_tpose() applies the
    # armature modifier to bake the new arm position into the mesh, and that is only
    # right while the skin's bind still matches the data Mixamo shipped.
    if os.environ.get("NO_TPOSE") != "1":
        to_tpose(rig, meshes)

    bake_world(rig, meshes)
    # OFF by default. align_rolls() was written while chasing a rolled-hands bug that
    # turned out to be the art, and on a correctly built character it does harm: measured
    # at the same frame of the same idle, thumb-above-index came out R +0.45 / L +0.40
    # without it - symmetric, and the same sign as Mixamo's own rig - against R -0.23 /
    # L +0.82 with it. It breaks left-right symmetry. Kept behind a flag because it is
    # the right idea for a rig whose rolls genuinely disagree with Mixamo's.
    if os.environ.get("ROLL_ALIGN") == "1":
        align_rolls(rig)
    factor = bake_size(rig, meshes, height)
    # Stand him ON the floor. He arrives hanging below the origin, and a character whose
    # feet are 1.9 m under the ground is one the game has to correct for at runtime.
    lo, hi = bounds(meshes[0], world=False)
    drop = Matrix.Translation((0.0, 0.0, -lo[2]))
    for obj in [rig] + meshes:
        obj.data.transform(drop)
        if obj.type == "MESH":
            obj.data.update()
    bpy.context.view_layer.update()

    # Prove he is the right way UP, not merely the right way along. A model rotated the
    # wrong way about X is upright, correctly sized and standing on the floor - and
    # upside down. Only the bones say which.
    head = rig.data.bones["mixamorig:Head"].head_local[2]
    foot = rig.data.bones["mixamorig:LeftFoot"].head_local[2]
    print(f"upright   head z {head:+.3f}, left foot z {foot:+.3f} -> "
          f"{'head above feet, correct' if head > foot else 'UPSIDE DOWN'}")
    if STAND_UP and head <= foot:
        raise SystemExit("REFUSED: the character is upside down")

    hips = rig.data.bones["mixamorig:Hips"]
    print(f"size      scaled x{factor:.4f} to {height} m, hips at "
          f"{tuple(round(v, 3) for v in hips.head_local)}, armature object scale "
          f"{tuple(round(v, 3) for v in rig.scale)}")

    for mesh in meshes:
        texture(mesh, image)
        lo, hi = bounds(mesh)
        print(f"mesh      {mesh.name}  extent "
              f"X {hi[0]-lo[0]:.3f}  Y {hi[1]-lo[1]:.3f}  Z {hi[2]-lo[2]:.3f}  "
              f"floor Z {lo[2]:+.3f}")
        print(f"          uv layers {[l.name for l in mesh.data.uv_layers]}")

    bpy.context.scene.render.fps = FPS
    bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB",
                              export_animations=False, export_skins=True,
                              # With STAND_UP the data is Blender Z-up and needs the
                              # exporter's conversion. Without it the data is still
                              # Mixamo's Y-up, which is glTF's own convention, so
                              # converting again would lay him down.
                              export_yup=STAND_UP)
    print(f"wrote {out}  {out.stat().st_size/1e6:.1f} MB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
