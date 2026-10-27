# 17_r15_rig.py: Roblox's default R15 body in Blender, for animating the player's sword attacks (GAME-35).
# Part sizes and joint (RigAttachment) positions were read from Studio's default R15 rig
# (Players:CreateHumanoidModelFromDescription(HumanoidDescription.new(), R15), 2026-10-27). Every part is a box of the
# real size, bone-parented to an armature whose bones are named after the parts (= the Pose names a Roblox
# KeyframeSequence uses), with each bone's head on its Motor6D pivot. The phase-5 sword (export/Sword_Phase5.fbx) sits
# in the right hand on RightGripAttachment, the way a Roblox Tool would hold it.
# Run headless:
#   /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python goblin/scripts/17_r15_rig.py
# Writes blender/r15_rig.blend and docs/r15_rig_rest.txt (the rest pose, for the animation exporter).
# Units: 1 Blender unit = 1 stud. Roblox (x, y, z) -> Blender (-x, z, y), so the character faces -Y (Blender front view).
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else "/Users/chinnaphat/Desktop/cedt/roblox/goblin/scripts")
import voxel_kit  # noqa: E402

LIFT = 3.0  # HumanoidRootPart height so the feet stand on z = 0 (HipHeight 2.19 + half the root part)
PARTS = {  # Roblox part centre (rig pivot at the origin) and size, from Studio
    "HumanoidRootPart": ((0, 0, 0), (2, 2, 1)),
    "LowerTorso": ((0, -0.8, 0), (1.9914, 0.4007, 1.004)),
    "UpperTorso": ((0, 0.2, 0), (1.9432, 1.698, 1.004)),
    "Head": ((0, 1.586, 0), (1.159, 1.182, 1.1606)),
    "LeftUpperArm": ((-1.5, 0.3687, 0), (1.0011, 1.2416, 1.0019)),
    "LeftLowerArm": ((-1.5, -0.2241, 0), (1.0011, 1.1175, 1.0019)),
    "LeftHand": ((-1.5, -0.8501, 0), (0.9843, 0.3158, 1.0283)),
    "RightUpperArm": ((1.5, 0.3687, 0), (1.0011, 1.2416, 1.0019)),
    "RightLowerArm": ((1.5, -0.2241, 0), (1.0011, 1.1175, 1.0019)),
    "RightHand": ((1.5, -0.8501, 0), (0.9843, 0.3158, 1.0283)),
    "LeftUpperLeg": ((-0.5, -1.4208, 0), (0.9928, 1.3629, 0.9727)),
    "LeftLowerLeg": ((-0.5, -2.2009, 0), (0.9928, 1.3007, 0.9728)),
    "LeftFoot": ((-0.5, -2.85, 0), (1.0089, 0.312, 1.0011)),
    "RightUpperLeg": ((0.5, -1.4208, 0), (0.9928, 1.3629, 0.9727)),
    "RightLowerLeg": ((0.5, -2.2009, 0), (0.9928, 1.3007, 0.9728)),
    "RightFoot": ((0.5, -2.85, 0), (1.0089, 0.312, 1.0011)),
}
JOINTS = {  # Motor6D name: Part0, Part1, C0 position (in Part0), C1 position (in Part1); all rotations are identity
    "Root": ("HumanoidRootPart", "LowerTorso", (0, -1, 0), (0, -0.2, 0)),
    "Waist": ("LowerTorso", "UpperTorso", (0, 0.2, 0), (0, -0.849, 0)),
    "Neck": ("UpperTorso", "Head", (0, 0.849, 0), (0, -0.5758, 0)),
    "LeftShoulder": ("UpperTorso", "LeftUpperArm", (-0.9716, 0.5975, 0), (0.5005, 0.4189, 0)),
    "LeftElbow": ("LeftUpperArm", "LeftLowerArm", (0, -0.3549, 0), (0, 0.2748, 0)),
    "LeftWrist": ("LeftLowerArm", "LeftHand", (0, -0.5322, 0), (0, 0.1316, 0)),
    "RightShoulder": ("UpperTorso", "RightUpperArm", (0.9716, 0.5975, 0), (-0.5005, 0.4189, 0)),
    "RightElbow": ("RightUpperArm", "RightLowerArm", (0, -0.355, 0), (0, 0.2747, 0)),
    "RightWrist": ("RightLowerArm", "RightHand", (0, -0.5322, 0), (0, 0.1316, 0)),
    "LeftHip": ("LowerTorso", "LeftUpperLeg", (-0.5, -0.2, 0), (0, 0.4714, 0)),
    "LeftKnee": ("LeftUpperLeg", "LeftLowerLeg", (0, -0.4493, 0), (0, 0.4132, 0)),
    "LeftAnkle": ("LeftLowerLeg", "LeftFoot", (0, -0.5965, 0), (0, 0.106, 0)),
    "RightHip": ("LowerTorso", "RightUpperLeg", (0.5, -0.2, 0), (0, 0.4714, 0)),
    "RightKnee": ("RightUpperLeg", "RightLowerLeg", (0, -0.4492, 0), (0, 0.4134, 0)),
    "RightAnkle": ("RightLowerLeg", "RightFoot", (0, -0.5965, 0), (0, 0.106, 0)),
}
GRIP = (0, -0.1578, 0)  # RightGripAttachment in RightHand; its CFrame turns the Handle's +Y to point forward (-Z)
COLORS = {"Skin": (234, 184, 146), "Shirt": (34, 32, 38), "Pants": (96, 26, 32), "Root": (120, 160, 220)}
SKIN = {"Head", "LeftHand", "RightHand"}
SHIRT = {"UpperTorso", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm"}


def rb(p):  # Roblox position (rig pivot at origin) -> Blender, lifted so the feet touch the ground
    x, y, z = p
    return Vector((-x, z, y + LIFT))


def world(name):
    return Vector(PARTS[name][0])


def pivot(joint):  # world position of a Motor6D's pivot = Part1 centre + C1
    _, p1, _, c1 = JOINTS[joint]
    return world(p1) + Vector(c1)


def build():
    voxel_kit.clear_scene()
    arm = bpy.data.armatures.new("R15_Rig")
    rig = bpy.data.objects.new("R15_Rig", arm)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    child_of = {p1: j for j, (_, p1, _, _) in JOINTS.items()}
    kids = {}
    for j, (p0, p1, _, _) in JOINTS.items():
        kids.setdefault(p0, []).append(p1)
    bones = {}
    for name, (centre, size) in PARTS.items():
        b = arm.edit_bones.new(name)
        head = Vector(centre) if name == "HumanoidRootPart" else pivot(child_of[name])
        b.head = rb(head)
        ends = [pivot(child_of[k]) for k in kids.get(name, []) if k not in ("LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg")]
        if ends and name != "HumanoidRootPart":
            b.tail = rb(ends[0])
        else:  # leaf (head, hands, feet) or root: point along the part
            down = -1 if name not in ("Head", "HumanoidRootPart") else 1
            b.tail = rb(head + Vector((0, down * max(size[1], 0.4) * 0.8, 0)))
        if b.length < 0.05:
            b.tail = b.head + Vector((0, 0, 0.3))
        bones[name] = b
    for name in PARTS:
        if name in child_of:
            bones[name].parent = bones[JOINTS[child_of[name]][0]]
    bpy.ops.object.mode_set(mode="OBJECT")

    for name, (centre, size) in PARTS.items():
        colour = "Skin" if name in SKIN else "Shirt" if name in SHIRT else "Root" if name == "HumanoidRootPart" else "Pants"
        me = bpy.data.meshes.new("Body_" + name)
        ob = bpy.data.objects.new("Body_" + name, me)
        bpy.context.collection.objects.link(ob)
        import bmesh
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=(size[0], size[2], size[1]), verts=bm.verts)  # Roblox (x, y, z) size -> Blender (x, z, y)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(voxel_kit.material("R15_" + colour, COLORS[colour]))
        ob.parent, ob.parent_type, ob.parent_bone = rig, "BONE", name
        ob.matrix_world = Matrix.Translation(rb(centre))
        if name == "HumanoidRootPart":
            ob.display_type, ob.hide_render = "WIRE", True  # invisible in Roblox too

    # The phase-5 sword on RightGripAttachment: Handle +Y (Roblox) = forward (-Z) with the arm hanging down.
    bpy.ops.import_scene.fbx(filepath=os.path.join(voxel_kit.ROOT, "export", "Sword_Phase5.fbx"), axis_forward="-Z", axis_up="Y")
    sword = [o for o in bpy.context.selected_objects if o.parent is None][0]
    sword.name = "Sword"
    grip = Matrix.Translation(rb(world("RightHand") + Vector(GRIP))) @ Matrix.Rotation(1.5708, 4, "X")
    sword.parent, sword.parent_type, sword.parent_bone = rig, "BONE", "RightHand"
    sword.matrix_world = grip  # blade +Z -> forward (-Y)
    return rig


def write_rest(path):
    """Rest pose for the KeyframeSequence exporter, in Roblox model space (studs), lifted like the Blender scene.
    P <part> <12 cframe values>; J <part1> <part0> <C0 12 values> <C1 12 values> (09_gen_anims.py format)."""
    ident = [1, 0, 0, 0, 1, 0, 0, 0, 1]
    with open(path, "w") as fh:
        fh.write("# R15 rest pose from scripts/17_r15_rig.py (Roblox model space, HumanoidRootPart at y = %g)\n" % LIFT)
        for name, (c, _) in PARTS.items():
            fh.write("P %s %g %g %g %s\n" % (name, c[0], c[1] + LIFT, c[2], " ".join(map(str, ident))))
        for _, (p0, p1, c0, c1) in JOINTS.items():
            fh.write("J %s %s %g %g %g %s %g %g %g %s\n" % (p1, p0, *c0, " ".join(map(str, ident)), *c1, " ".join(map(str, ident))))


rig = build()
write_rest(os.path.join(voxel_kit.ROOT, "docs", "r15_rig_rest.txt"))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(voxel_kit.ROOT, "blender", "r15_rig.blend"))
print("R15 rig:", len(rig.data.bones), "bones")
