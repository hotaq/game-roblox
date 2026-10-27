# 18_r15_anims.py: player sword animations on the R15 rig from 17_r15_rig.py (GAME-35).
#   SwordIdle  (loop, 3 s): giant sword planted beside the right foot, right hand resting on the grip at shoulder
#              height, left hand on the hip, chin down; breathes, shifts weight and glances aside, the sword stays put.
#   SwordWalk  (loop, 1.0 s at walk speed 16): swaggering walk, sword stays across the shoulders, left arm swings,
#              hips and shoulders counter-twist, slight lean back, body bobs on each step.
# Run headless (opens blender/r15_rig.blend, adds the actions, saves it back and renders previews):
#   /Applications/Blender.app/Contents/MacOS/Blender -b goblin/blender/r15_rig.blend --python goblin/scripts/18_r15_anims.py
#
# Poses are written as rotations about the rest-pose WORLD axes at each joint (Blender: +X = the character's left,
# -Y = forward, +Z = up), chained parent -> child, then converted to bone channels. So "Rx(-60) on RightUpperArm" means
# "swing the right arm 60 degrees forward", whatever the bone's roll.
import itertools
import math
import os

import bpy
from mathutils import Euler, Matrix, Vector

ROOT = "/Users/chinnaphat/Desktop/cedt/roblox/goblin"
FPS = 30
CHAIN = ["HumanoidRootPart", "LowerTorso", "UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand",
         "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperLeg", "RightLowerLeg", "RightFoot",
         "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"]

# The owner's pick (pose 3 of the reference sheet): sword laid across the shoulders behind the neck, hilt in the right
# hand at the right shoulder, blade out past the left shoulder. Angles found by a numeric search for grip at
# (-1.35, 0.05, 4.2) with the blade along (1, 0.5, 0.12).
CARRY = {"RightUpperArm": (19.9, 239.6, 115.8), "RightLowerArm": (-129.0, 0, 110.9), "RightHand": (-23.6, 87.0, -90.6)}
# Idle: the giant sword stands point down beside the right foot, grip at shoulder height under the right hand (the
# blade is longer than the character is tall), left hand on the hip. The top leans in, the flat faces forward.
PLANTED = Matrix.Translation((-2.1, -0.5, 3.0)) @ Matrix.Rotation(0.2, 4, "Y") @ Matrix.Rotation(math.pi, 4, "X")
HIP_HAND = {"LeftUpperArm": (29.5, 0.3, -27.0), "LeftLowerArm": (-53.8, 0, -29.8)}

def world_deltas(rig, rot, lift=0.0):
    """rot: bone -> (rx, ry, rz) degrees about world axes at the bone's rest head. Returns bone -> pose @ rest^-1."""
    world = {}
    for name in CHAIN:
        b = rig.data.bones[name]
        p = b.head_local
        r = Euler([math.radians(a) for a in rot.get(name, (0, 0, 0))], "XYZ").to_matrix().to_4x4()
        local = Matrix.Translation(p) @ r @ Matrix.Translation(-p)
        if name == "LowerTorso":
            local = Matrix.Translation((0, 0, lift)) @ local
        world[name] = (world[b.parent.name] if b.parent else Matrix.Identity(4)) @ local
    return world


def pose_matrices(rig, rot, lift=0.0):
    """Same rot as world_deltas. Returns bone -> basis matrix."""
    bones = rig.data.bones
    world = world_deltas(rig, rot, lift)
    basis = {}
    for name in CHAIN:
        b = bones[name]
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


def ease(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


def solve_grip(rig, rot, lift, sword_rest, guess):
    """Right arm angles (degrees) that put the sword (rest matrix sword_rest, riding on RightHand) at PLANTED: grip on
    the spot, blade along PLANTED's, flat facing forward if the arm allows. Levenberg-Marquardt, weakly pulled toward
    guess. Returns (angles, grip position error)."""
    import numpy as np
    names = ["RightUpperArm", "RightLowerArm", "RightHand"]
    p0 = np.array([a for n in names for a in guess[n]], float)

    def resid(p):
        r = dict(rot)
        r.update({n: tuple(p[3 * i:3 * i + 3]) for i, n in enumerate(names)})
        s = world_deltas(rig, r, lift)["RightHand"] @ sword_rest
        m = s.to_3x3()
        out = list(s.translation - PLANTED.translation) + list(m.col[2] - PLANTED.to_3x3().col[2]) + [0.3 * m.col[0].y]
        return np.concatenate([out, 1e-5 * (p - p0)])

    p, lam = p0.copy(), 1e-3
    r0 = resid(p)
    for _ in range(80):  # shrink the damping on a good step, grow it on a bad one
        jac = np.array([(resid(p + d) - r0) / 0.1 for d in np.eye(9) * 0.1]).T
        jtj = jac.T @ jac
        q = p - np.linalg.solve(jtj + lam * np.diag(np.diag(jtj) + 1e-9), jac.T @ r0)
        rq = resid(q)
        if rq @ rq < r0 @ r0:
            p, r0, lam = q, rq, lam * 0.3
        else:
            lam *= 10
    return {n: tuple(p[3 * i:3 * i + 3]) for i, n in enumerate(names)}, float(np.abs(r0[:3]).max())


def idle(rig):
    n = 3 * FPS
    sword = bpy.data.objects["Sword"]
    rig.animation_data_create()
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    sword_rest = rig.matrix_world.inverted() @ sword.matrix_world
    new_action(rig, "EXP_SwordIdle", n)
    arms, worst = None, 0.0
    for f in range(0, n + 1, 2):
        ph = 2 * math.pi * f / n
        w = math.sin(ph)  # weight shift, once per loop
        b = math.sin(2 * ph)  # breathing, twice per loop
        look = ease((f - 15) / 12) - ease((f - 60) / 15)  # glance aside, hold, back
        hip = 5 + 2 * w  # hip cocked away from the sword
        rot = dict(HIP_HAND)
        rot["LeftUpperArm"] = (29.5, 0.3 + 3 * b, -27.0)  # hip elbow flares with the breath
        rot.update({
            "LowerTorso": (0, hip, 0),
            "UpperTorso": (3 + 2.5 * b, -1.6 * hip, -6 * look),  # leans on the sword, chest rises with the breath
            "Head": (-8 - 1.5 * b, 3, -20 * look),  # chin down, staring ahead, glances aside
            "RightUpperLeg": (0, 12 - hip, 0),  # wide stance
            "LeftUpperLeg": (0, -12 - hip, 0),
            "RightFoot": (0, -12 + hip, 0),
            "LeftFoot": (0, 12 + hip, 0),
        })
        lift = -0.12 + 0.02 * b
        if arms is None:  # first frame: try several starts, keep the least twisted arm that reaches
            tries = []
            for ux, uz, lx in itertools.product((-90, -45, 0), (-60, 0, 40), (-90, -30)):
                guess = {"RightUpperArm": (ux, 0, uz), "RightLowerArm": (lx, 0, 0), "RightHand": (0, 0, 0)}
                a, err = solve_grip(rig, rot, lift, sword_rest, guess)
                bend = sum(Euler([math.radians(x) for x in v]).to_quaternion().angle for v in a.values())
                tries.append((err > 0.01, bend, a))
            arms = min(tries, key=lambda t: t[:2])[2]
        arms, err = solve_grip(rig, rot, lift, sword_rest, arms)
        worst = max(worst, err)
        rot.update(arms)
        key(rig, f, rot, lift)
    print("SwordIdle: sword drifts at most %.3f studs from the planted spot" % worst)


def walk(rig):
    n = FPS  # one full cycle (two steps) per second
    new_action(rig, "EXP_SwordWalk", n)
    for f in range(0, n + 1):
        ph = 2 * math.pi * f / n
        s, c = math.sin(ph), math.cos(ph)
        rot = dict(CARRY)
        rot["RightUpperArm"] = (19.9 + 3 * math.sin(2 * ph), 239.6, 115.8)
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
    cam.data.lens = 42
    sc.render.resolution_x, sc.render.resolution_y = 600, 760
    tiles = []
    for i, (act, frame, at) in enumerate(shots):
        cam.location = at
        cam.rotation_euler = (Vector((0.6, 0, 2.9)) - cam.location).to_track_quat("-Z", "Y").to_euler()
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
