# 18_r15_anims.py: player sword animations on the R15 rig from 17_r15_rig.py (GAME-35).
#   SwordIdle  (loop, 2.4 s): sword resting on the right shoulder, slow breathing and a small weight shift.
#   SwordWalk  (loop, 1.0 s at walk speed 16): swaggering walk, sword stays on the shoulder, left arm swings,
#              hips and shoulders counter-twist, slight lean back, body bobs on each step.
# Run headless (opens blender/r15_rig.blend, adds the actions, saves it back and renders previews):
#   /Applications/Blender.app/Contents/MacOS/Blender -b goblin/blender/r15_rig.blend --python goblin/scripts/18_r15_anims.py
#
# Poses are written as rotations about the rest-pose WORLD axes at each joint (Blender: +X = the character's left,
# -Y = forward, +Z = up), chained parent -> child, then converted to bone channels. So "Rx(-60) on RightUpperArm" means
# "swing the right arm 60 degrees forward", whatever the bone's roll.
import math
import os

import bpy
from mathutils import Euler, Matrix, Vector

ROOT = "/Users/chinnaphat/Desktop/cedt/roblox/goblin"
FPS = 30
CHAIN = ["HumanoidRootPart", "LowerTorso", "UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand",
         "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperLeg", "RightLowerLeg", "RightFoot",
         "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"]

# The sword-on-shoulder carry: arm forward and a little out, elbow folded up, so the blade (forward at rest) ends up
# pointing back and up over the right shoulder.
CARRY = {"RightUpperArm": (-38, 32, 0), "RightLowerArm": (-118, 0, 0), "RightHand": (-16, 0, -6)}


def pose_matrices(rig, rot, lift=0.0):
    """rot: bone -> (rx, ry, rz) degrees about world axes at the bone's rest head. Returns bone -> basis matrix."""
    bones = rig.data.bones
    world = {}
    basis = {}
    for name in CHAIN:
        b = bones[name]
        p = b.head_local
        r = Euler([math.radians(a) for a in rot.get(name, (0, 0, 0))], "XYZ").to_matrix().to_4x4()
        local = Matrix.Translation(p) @ r @ Matrix.Translation(-p)
        if name == "LowerTorso":
            local = Matrix.Translation((0, 0, lift)) @ local
        parent = world.get(b.parent.name) if b.parent else Matrix.Identity(4)
        world[name] = parent @ local
        pose = world[name] @ b.matrix_local
        if b.parent:
            parent_pose = world[b.parent.name] @ b.parent.matrix_local
            rest_local = b.parent.matrix_local.inverted() @ b.matrix_local
            basis[name] = rest_local.inverted() @ (parent_pose.inverted() @ pose)
        else:
            basis[name] = b.matrix_local.inverted() @ pose
    return basis


def key(rig, frame, rot, lift=0.0):
    for name, m in pose_matrices(rig, rot, lift).items():
        pb = rig.pose.bones[name]
        pb.rotation_mode = "QUATERNION"
        loc, q, _ = m.decompose()
        pb.location, pb.rotation_quaternion = loc, q
        pb.keyframe_insert("location", frame=frame)
        pb.keyframe_insert("rotation_quaternion", frame=frame)


def new_action(rig, name, frames):
    act = bpy.data.actions.get(name)
    if act:
        bpy.data.actions.remove(act)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    act.frame_range = (0, frames)
    return act


def idle(rig):
    n = int(2.4 * FPS)
    new_action(rig, "EXP_SwordIdle", n)
    for f in range(0, n + 1, 3):
        ph = 2 * math.pi * f / n
        b = math.sin(ph)
        rot = dict(CARRY)
        rot["RightUpperArm"] = (-38 + 2 * b, 32, 0)
        rot.update({
            "LowerTorso": (0, 1.5 * b, 0),  # weight shift side to side
            "UpperTorso": (2 + 1.5 * b, -1.5 * b, 0),  # breathing, a slight lean back
            "Head": (-1 * b, 1 * b, 0),
            "LeftUpperArm": (-4, -9 - 2 * b, 0),
            "LeftLowerArm": (-14, 0, 0),
            "LeftUpperLeg": (0, -5 - 1.5 * b, 0),
            "RightUpperLeg": (0, 5 - 1.5 * b, 0),
            "LeftFoot": (0, 5 + 1.5 * b, 0),
            "RightFoot": (0, -5 + 1.5 * b, 0),
        })
        key(rig, f, rot, lift=-0.03 * (1 - math.cos(ph)) / 2)


def walk(rig):
    n = FPS  # one full cycle (two steps) per second
    new_action(rig, "EXP_SwordWalk", n)
    for f in range(0, n + 1):
        ph = 2 * math.pi * f / n
        s, c = math.sin(ph), math.cos(ph)
        rot = dict(CARRY)
        rot["RightUpperArm"] = (-38 + 3 * math.sin(2 * ph), 32, 0)
        rot.update({
            # hips twist with the legs, shoulders counter-twist and lean back: the swagger
            "LowerTorso": (0, 3 * s, 7 * s),
            "UpperTorso": (5, -2 * s, -12 * s),
            "Head": (2 * math.cos(2 * ph), 0, 5 * s),
            "LeftUpperArm": (26 * s, -9, 0),
            "LeftLowerArm": (-16 - 12 * max(0.0, -s), 0, 0),
            "LeftUpperLeg": (-30 * s, 0, 0),
            "RightUpperLeg": (30 * s, 0, 0),
            "LeftLowerLeg": (8 + 42 * max(0.0, c), 0, 0),
            "RightLowerLeg": (8 + 42 * max(0.0, -c), 0, 0),
            "LeftFoot": (-0.35 * (8 + 42 * max(0.0, c)) + 12 * s, 0, 0),
            "RightFoot": (-0.35 * (8 + 42 * max(0.0, -c)) - 12 * s, 0, 0),
        })
        key(rig, f, rot, lift=0.09 * math.cos(2 * ph) - 0.03)


def render(rig, path, shots):
    """shots: [(action, frame, camera position)] -> a row of views in one image."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light, sh.color_type, sh.show_cavity, sh.background_type = "STUDIO", "MATERIAL", True, "WORLD"
    sc.world = sc.world or bpy.data.worlds.new("World")
    sc.world.color = (0.62, 0.64, 0.68)
    cam = bpy.data.objects.get("PreviewCam") or bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    if cam.name not in sc.collection.objects:
        sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 50
    sc.render.resolution_x, sc.render.resolution_y = 600, 760
    tiles = []
    for i, (act, frame, at) in enumerate(shots):
        cam.location = at
        cam.rotation_euler = (Vector((0, 0, 2.7)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        rig.animation_data.action = bpy.data.actions[act]
        sc.frame_set(frame)
        p = os.path.join(ROOT, "renders", "_tile%d.png" % i)
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        tiles.append(p)
    imgs = [bpy.data.images.load(p) for p in tiles]
    w, h = imgs[0].size
    sheet = bpy.data.images.new("sheet", w * len(imgs), h)
    px = [0.0] * (w * len(imgs) * h * 4)
    for i, im in enumerate(imgs):
        src = list(im.pixels)
        for y in range(h):
            row = y * w * len(imgs) * 4 + i * w * 4
            px[row:row + w * 4] = src[y * w * 4:(y + 1) * w * 4]
    sheet.pixels = px
    sheet.filepath_raw, sheet.file_format = path, "PNG"
    sheet.save()
    for p in tiles:
        os.remove(p)


FRONT, SIDE, BACK34, FRONT34 = (0, -12, 3.6), (-12, 0, 3.6), (-7, 8, 5.5), (6.5, -9.5, 4.2)
rig = bpy.data.objects["R15_Rig"]
idle(rig)
walk(rig)
bpy.context.scene.render.fps = FPS
bpy.ops.wm.save_mainfile()
render(rig, os.path.join(ROOT, "renders", "sword_carry_anims.png"),
       [("EXP_SwordIdle", 0, FRONT), ("EXP_SwordIdle", 0, SIDE), ("EXP_SwordIdle", 0, BACK34),
        ("EXP_SwordWalk", 0, FRONT34), ("EXP_SwordWalk", 7, FRONT34), ("EXP_SwordWalk", 15, FRONT34)])
print("actions:", [a.name for a in bpy.data.actions])
