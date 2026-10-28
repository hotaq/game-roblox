# 18_r15_anims.py: player sword animations on the R15 rig from 17_r15_rig.py (GAME-35).
#   SwordIdle  (loop, 3 s): giant sword planted beside the right foot, right hand resting on the grip at hip
#              height, left hand on the hip, chin up; breathes, shifts weight and glances aside, the sword stays put.
#   SwordRun   (loop, 0.67 s at walk speed 16): leans into a run, left arm pumps, right hand drags the sword behind,
#              its tip scraping the ground on its edge (solved per frame like the idle grip).
#   SwordHold  (loop, 2 s): stopped after a run, sword still trailing behind; the client plants it after a few seconds.
#   SwordPlant (once, 0.7 s): hold -> idle, lifts the sword high point down and slams it into the ground.
#   SwordPull  (once, 0.5 s): idle -> run, yanks the sword out and swings it down behind into the drag.
#   SwordDashF / F2 / B / L / R (once, 0.37 s, GAME-44): the dash, relative to where the character faces, posed after the
#              owner's reference (REF below): snaps from SwordHold into the pose and holds it; F and F2 alternate.
# Run headless (opens blender/r15_rig.blend, adds the actions, saves it back and renders previews):
#   /Applications/Blender.app/Contents/MacOS/Blender -b goblin/blender/r15_rig.blend --python goblin/scripts/18_r15_anims.py
#
# Poses are written as rotations about the rest-pose WORLD axes at each joint (Blender: +X = the character's left,
# -Y = forward, +Z = up), chained parent -> child, then converted to bone channels. So "Rx(-60) on RightUpperArm" means
# "swing the right arm 60 degrees forward", whatever the bone's roll; on the upright torso and head, +Rx tips forward.
import itertools
import math
import os

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

ROOT = "/Users/chinnaphat/Desktop/cedt/roblox/goblin"
FPS = 30
RIGHT_ARM = ["RightUpperArm", "RightLowerArm", "RightHand"]
CHAIN = ["HumanoidRootPart", "LowerTorso", "UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand",
         "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperLeg", "RightLowerLeg", "RightFoot",
         "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"]

# The owner's pick (pose 3 of the reference sheet): sword laid across the shoulders behind the neck, hilt in the right
# hand at the right shoulder, blade out past the left shoulder. Angles found by a numeric search for grip at
# (-1.35, 0.05, 4.2) with the blade along (1, 0.5, 0.12).
CARRY = {"RightUpperArm": (19.9, 239.6, 115.8), "RightLowerArm": (-129.0, 0, 110.9), "RightHand": (-23.6, 87.0, -90.6)}
# Idle: the giant sword stands point down beside the right foot, grip at hip height so the right arm hangs relaxed (the
# blade is longer than the character is tall, so much of it is in the ground), left hand on the hip. The top leans in.
PLANTED = Matrix.Translation((-1.8, -0.7, 2.5)) @ Matrix.Rotation(0.2, 4, "Y") @ Matrix.Rotation(math.pi, 4, "X")
RAISED = Matrix.Translation((-1.6, -0.4, 5.2)) @ PLANTED.to_3x3().to_4x4()  # lifted high before the slam
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


def sword_rest(rig):
    """The sword's matrix (armature space) with the rig in rest pose; it rides on RightHand."""
    rig.animation_data_create()
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    return rig.matrix_world.inverted() @ bpy.data.objects["Sword"].matrix_world


def solve_grip(rig, rot, lift, rest, goal, guess=None, ref=None, pull=1e-5):
    """Right arm angles (degrees) for which goal(sword matrix) -> residual list is ~0. The elbow is a hinge (RightLowerArm
    turns about X only, 0 to 150 degrees forward), so the arm can't wring itself between frames. Levenberg-Marquardt from guess, pulled toward ref
    (default: guess) with weight pull per degree; with no guess, tries several starts and keeps the least twisted arm
    that reaches. Returns (angles, largest of the first 3 residuals)."""
    import numpy as np
    up, low, hand = RIGHT_ARM
    if guess is None:
        tries = []
        for ux, uz, lx in itertools.product((-90, -45, 0, 45), (-60, 0, 40), (-90, -30)):
            a, err = solve_grip(rig, rot, lift, rest, goal, {up: (ux, 0, uz), low: (lx, 0, 0), hand: (0, 0, 0)})
            bend = sum(Euler([math.radians(x) for x in v]).to_quaternion().angle for v in a.values())
            tries.append((err > 0.01, bend, a))
        return solve_grip(rig, rot, lift, rest, goal, min(tries, key=lambda t: t[:2])[2])

    def quat(v):
        return Euler([math.radians(x) for x in v]).to_quaternion()

    base, ref = {k: quat(guess[k]) for k in (up, hand)}, ref or guess
    ref_q = {k: quat(ref[k]) for k in (up, hand)}

    def turn(v):  # rotation vector (degrees) -> quaternion
        v = Vector(v)
        return Quaternion(v.normalized(), math.radians(v.length)) if v.length > 1e-9 else Quaternion()

    def unpack(p):  # p = upper arm and hand turns (world axes, on top of guess) and the elbow angle
        q = {up: turn(p[0:3]) @ base[up], hand: turn(p[4:7]) @ base[hand]}
        out = {k: tuple(math.degrees(x) for x in q[k].to_euler("XYZ", Euler([math.radians(a) for a in guess[k]])))
               for k in q}
        out[low] = (p[3], 0.0, 0.0)
        return out, q

    def resid(p):
        arms, q = unpack(p)
        off = []
        for k in (up, hand):  # how far each joint is from ref, as a rotation vector in degrees
            d = q[k] @ ref_q[k].inverted()
            if d.w < 0:
                d.negate()
            off += list(d.axis * math.degrees(d.angle))
        off.append(p[3] - ref[low][0])
        return np.concatenate([goal(world_deltas(rig, dict(rot, **arms), lift)["RightHand"] @ rest),
                               pull * np.array(off), [0.05 * max(0.0, p[3], -150 - p[3])]])  # elbow bends 0..150 forward

    p, lam = np.array([0, 0, 0, guess[low][0], 0, 0, 0], float), 1e-3
    r0 = resid(p)
    for _ in range(80):  # shrink the damping on a good step, grow it on a bad one
        jac = np.array([(resid(p + d) - r0) / 0.1 for d in np.eye(7) * 0.1]).T
        jtj = jac.T @ jac
        q = p - np.linalg.solve(jtj + lam * np.diag(np.diag(jtj) + 1e-9), jac.T @ r0)
        rq = resid(q)
        if rq @ rq < r0 @ r0:
            p, r0, lam = q, rq, lam * 0.3
        else:
            lam *= 10
    return unpack(p)[0], float(np.abs(r0[:3]).max())


def planted(s):  # grip on the spot, blade along PLANTED's, flat facing forward if that costs the arm little
    m = s.to_3x3()
    return list(s.translation - PLANTED.translation) + list(m.col[2] - PLANTED.to_3x3().col[2]) + [0.05 * m.col[0].y]


def idle(rig):
    n = 3 * FPS
    rest = sword_rest(rig)
    new_action(rig, "EXP_SwordIdle", n)
    arms, worst, first = None, 0.0, None
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
            "UpperTorso": (3 + 2.5 * b, -1.6 * hip, -6 * look),  # leans in a little, chest rises with the breath
            "Head": (-8 - 1.5 * b, 3, -20 * look),  # chin up, staring ahead, glances aside
            "RightUpperLeg": (0, 12 - hip, 0),  # wide stance
            "LeftUpperLeg": (0, -12 - hip, 0),
            "RightFoot": (0, -12 + hip, 0),
            "LeftFoot": (0, 12 + hip, 0),
        })
        lift = -0.12 + 0.02 * b
        arms, err = solve_grip(rig, rot, lift, rest, planted, arms)
        worst = max(worst, err)
        rot.update(arms)
        key(rig, f, rot, lift)
        first = first or (rot, lift, PLANTED)
    print("SwordIdle: sword drifts at most %.3f studs from the planted spot" % worst)
    return first


def drag(grip):
    """Goal: the sword's tip scrapes the ground behind, on its edge; the hand stays near grip, loosely."""
    def goal(m):
        tip = m @ Vector((0, 0, 5.05))
        return [0.0, 0.0, tip.z + 0.05] + [0.3 * x for x in m.translation - grip] + \
            [0.3 * m.to_3x3().col[0].x, 0.2 * (tip.y - 5.4), 0.2 * (tip.x + 2.3)]
    return goal


def run(rig):
    n = 20  # one full cycle (two strides) in 0.67 s
    rest = sword_rest(rig)
    old = bpy.data.actions.get("EXP_SwordWalk")
    if old:
        bpy.data.actions.remove(old)
    new_action(rig, "EXP_SwordRun", n)
    arms, worst, first = None, 0.0, None
    for f in range(0, n + 1):
        ph = 2 * math.pi * f / n
        s, c = math.sin(ph), math.cos(ph)
        knee_l, knee_r = 15 + 85 * max(0.0, c), 15 + 85 * max(0.0, -c)  # the swinging leg folds up
        rot = {
            # leans into the run, hips twist with the legs, shoulders counter-twist
            "LowerTorso": (10, 0, 10 * s),
            "UpperTorso": (14, 3, -14 * s),
            "Head": (-16, 0, 6 * s),  # eyes stay on the road
            "LeftUpperArm": (55 * s, -12, 0),  # free arm pumps against the left leg
            "LeftLowerArm": (-70 - 25 * max(0.0, -s), 0, 0),
            "LeftUpperLeg": (-10 - 45 * s, 0, 0),
            "RightUpperLeg": (-10 + 45 * s, 0, 0),
            "LeftLowerLeg": (knee_l, 0, 0),
            "RightLowerLeg": (knee_r, 0, 0),
            "LeftFoot": (-0.35 * knee_l + 15 * s, 0, 0),
            "RightFoot": (-0.35 * knee_r - 15 * s, 0, 0),
        }
        lift = -0.3 + 0.15 * math.cos(2 * ph)
        arms, err = solve_grip(rig, rot, lift, rest, drag(Vector((-1.7, 1.0 + 0.15 * s, 2.0 + 0.5 * lift))), arms)
        worst = max(worst, err)
        rot.update(arms)
        key(rig, f, rot, lift)
        first = first or (rot, lift, world_deltas(rig, rot, lift)["RightHand"] @ rest)
    print("SwordRun: sword tip off the ground by at most %.3f studs" % worst)
    return first


def guard(rig):
    """SwordHold (loop, 2 s): stopped but still on guard, the sword trailing behind as in the run; breathes."""
    n = 2 * FPS
    rest = sword_rest(rig)
    new_action(rig, "EXP_SwordHold", n)
    arms, worst, first = None, 0.0, None
    for f in range(0, n + 1, 2):
        b = math.sin(2 * math.pi * f / n)
        rot = {
            "LowerTorso": (4, 0, 0),
            "UpperTorso": (6 + 2 * b, 0, 6),  # leans in a little, chest rises with the breath
            "Head": (-8 - 1.5 * b, 0, -4),
            "LeftUpperArm": (8, -10 - 2 * b, 0),  # free arm loose at the side
            "LeftLowerArm": (-25, 0, 0),
            "RightUpperLeg": (-6, 10, 0),  # feet apart, knees soft
            "LeftUpperLeg": (-6, -10, 0),
            "RightLowerLeg": (12, 0, 0),
            "LeftLowerLeg": (12, 0, 0),
            "RightFoot": (-6, -10, 0),
            "LeftFoot": (-6, 10, 0),
        }
        lift = -0.15 + 0.02 * b
        arms, err = solve_grip(rig, rot, lift, rest, drag(Vector((-1.7, 0.9, 2.0 + 0.5 * lift))), arms)
        worst = max(worst, err)
        rot.update(arms)
        key(rig, f, rot, lift)
        first = first or (rot, lift, world_deltas(rig, rot, lift)["RightHand"] @ rest)
    print("SwordHold: sword tip off the ground by at most %.3f studs" % worst)
    return first


def blend(a, b, t):
    """Pose dicts a -> b at t (missing bones are (0, 0, 0))."""
    return {k: tuple(x + (y - x) * t for x, y in zip(a.get(k, (0, 0, 0)), b.get(k, (0, 0, 0)))) for k in set(a) | set(b)}


def mlerp(a, b, t, arc=0.0):
    """Sword matrix a -> b at t. The blade swings straight from one direction to the other (a quaternion slerp could
    swing the tip round the body while it rolls the flat); the grip rises by arc mid-way."""
    z = a.col[2].xyz.slerp(b.col[2].xyz, t)
    bx = b.col[0].xyz if a.col[0].xyz.dot(b.col[0].xyz) >= 0 else -b.col[0].xyz  # either face of the flat will do
    x = a.col[0].xyz.lerp(bx, t)
    x = (x - x.dot(z) * z).normalized()
    m = Matrix((x, z.cross(x), z)).transposed().to_4x4()
    m.translation = a.translation.lerp(b.translation, t) + Vector((0, 0, arc * math.sin(math.pi * t)))
    return m


def bump(f, at, width):
    return math.exp(-((f - at) / width) ** 2)


def hold(target):  # grip on target, blade along it, flat (either face) as close as the arm allows
    def goal(m):
        r, tr = m.to_3x3(), target.to_3x3()
        return list(m.translation - target.translation) + list(r.col[2] - tr.col[2]) + \
            [0.3 * x for x in r.col[0].cross(tr.col[0])]
    return goal


def slerp_arm(a, b, t, near):
    """Right arm angles a -> b at t, as Eulers close to near (so the solver's pull toward them never wraps)."""
    out = {}
    for k in RIGHT_ARM:
        qa, qb = (Euler([math.radians(x) for x in v]).to_quaternion() for v in (a[k], b[k]))
        if qa.dot(qb) < 0:  # the short way round
            qb.negate()
        out[k] = tuple(math.degrees(x) for x in qa.slerp(qb, t).to_euler("XYZ", Euler([math.radians(x) for x in near[k]])))
    return out


def transition(rig, name, start, end, segments, extra):
    """One-shot from start to end (each (pose, lift, sword matrix) from idle() / run()). The sword moves through
    segments [(frames, sword matrix at the segment's end, shape(t), grip arc)]. The right arm is solved at each segment
    end, eased between those, and pulled onto the sword's path, so it lands on the next loop's elbow and wrist without
    flipping on the way. The body blends with an ease, plus extra(f) -> (pose offsets, lift offset)."""
    rest = sword_rest(rig)
    n = sum(seg[0] for seg in segments)
    new_action(rig, name, n)

    def body(f):
        dr, dl = extra(f)
        t = ease(f / n)
        rot = blend(start[0], end[0], t)
        rot = {k: tuple(x + y for x, y in zip(rot.get(k, (0, 0, 0)), dr.get(k, (0, 0, 0)))) for k in set(rot) | set(dr)}
        return rot, start[1] + (end[1] - start[1]) * t + dl

    ends = [(start[2], {k: start[0][k] for k in RIGHT_ARM}), (end[2], {k: end[0][k] for k in RIGHT_ARM})]
    keys, f = [ends[0]], 0
    for frames, target, _, _ in segments:
        f += frames
        same = [arms for m, arms in ends if m is target]
        # solve from the end whose blade points most alike, so the hand keeps the same grip on the way
        near = min(ends, key=lambda e: (e[0].col[2].xyz - target.col[2].xyz).length)[1]
        keys.append((target, same[0] if same else solve_grip(rig, *body(f), rest, hold(target), near)[0]))
    arms, worst, f = keys[0][1], 0.0, 0
    rot, lift = body(0)
    key(rig, 0, dict(rot, **arms), lift)
    for i, (frames, target, shape, arc) in enumerate(segments):
        for j in range(1, frames + 1):
            f += 1
            t = shape(j / frames)
            rot, lift = body(f)
            ref = slerp_arm(keys[i][1], keys[i + 1][1], t, arms)
            arms, err = solve_grip(rig, rot, lift, rest, hold(mlerp(keys[i][0], target, t, arc)), ref, ref, 1e-2)
            worst = max(worst, err)
            key(rig, f, dict(rot, **arms), lift)
    print("%s: grip off its path by at most %.3f studs" % (name, worst))


def plant(rig, hold0, idle0):
    """Hold -> idle (0.7 s): lifts the sword high, point down, and slams it into the ground; the body dips on impact."""
    def extra(f):  # leans back as it lifts, crunches forward on impact
        up, hit = bump(f, 8, 3), bump(f, 13, 2.5)
        return {"UpperTorso": (-12 * up + 12 * hit, 0, 10 * up), "Head": (6 * up - 6 * hit, 0, 0),
                "LowerTorso": (6 * hit, 0, 0)}, -0.25 * hit

    transition(rig, "EXP_SwordPlant", hold0, idle0, [
        (9, RAISED, ease, 0.8),
        (3, PLANTED, lambda t: t * t, 0),  # accelerates into the ground
        (9, PLANTED, ease, 0),
    ], extra)


def pull(rig, idle0, run0):
    """Idle -> run (0.5 s): yanks the sword up out of the ground, then swings it down behind into the drag."""
    def extra(f):  # crouches to pull, leans back as the blade comes free
        return {"UpperTorso": (-10 * bump(f, 5, 2.5), 0, 0)}, -0.15 * bump(f, 1.5, 1.5)

    transition(rig, "EXP_SwordPull", idle0, run0, [
        (5, RAISED, lambda t: 1 - (1 - t) ** 2, 0),  # fast out of the ground
        (10, run0[2], ease, 0.8),
    ], extra)


# The dashes follow the owner's reference, the Toolbox "Dash Animations Tutorial" (asset 79699704844002, an R6 rig with
# Front / Front2 / Left / Right / Back): each R6 part's rotation relative to the root at its held pose, Roblox axes,
# row-major 3x3, taken in Studio by forward kinematics (root * C0 * pose * C1^-1) at t = 0.167. F: torso pitched ~72 deg
# into a dive, arms swept back; F2 is its mirror (forward dashes alternate); L / R: a 46 deg twist and 41 deg lean with a
# leg kicked out; B: leaning back with the arms spread. The R6 torso becomes LowerTorso (UpperTorso follows), arms and
# legs their upper parts with the lower ones straight, as on R6; the sword rides in the right hand.
REF = {
    "F": {
        "Torso": (0.8468, 0.0000, -0.5320, 0.5050, 0.3147, 0.8037, 0.1674, -0.9492, 0.2665),
        "Head": (0.9452, -0.1278, -0.3005, 0.1918, 0.9620, 0.1943, 0.2642, -0.2413, 0.9338),
        "Left Arm": (0.0937, -0.8051, 0.5858, 0.7607, -0.3217, -0.5638, 0.6423, 0.4984, 0.5823),
        "Right Arm": (-0.3789, 0.1857, -0.9066, 0.9245, 0.1203, -0.3618, 0.0419, -0.9752, -0.2173),
        "Left Leg": (0.9269, 0.0000, -0.3754, 0.3563, 0.3147, 0.8798, 0.1181, -0.9492, 0.2917),
        "Right Leg": (0.8468, -0.1632, -0.5063, 0.5050, 0.5461, 0.6684, 0.1674, -0.8217, 0.5448),
    },
    "F2": {
        "Torso": (0.8468, 0.0000, 0.5320, -0.5050, 0.3147, 0.8037, -0.1674, -0.9492, 0.2665),
        "Head": (0.9452, 0.1278, 0.3005, -0.1918, 0.9620, 0.1943, -0.2642, -0.2413, 0.9338),
        "Left Arm": (-0.3789, -0.1857, 0.9066, -0.9245, 0.1203, -0.3618, -0.0419, -0.9752, -0.2173),
        "Right Arm": (0.0937, 0.8051, -0.5858, -0.7607, -0.3217, -0.5638, -0.6423, 0.4984, 0.5823),
        "Left Leg": (0.8468, 0.1632, 0.5063, -0.5050, 0.5461, 0.6684, -0.1674, -0.8217, 0.5448),
        "Right Leg": (0.9269, 0.0000, 0.3754, -0.3563, 0.3147, 0.8798, -0.1181, -0.9492, 0.2917),
    },
    "L": {
        "Torso": (0.5225, -0.7218, 0.4539, 0.5991, 0.6896, 0.4069, -0.6067, 0.0594, 0.7927),
        "Head": (0.5225, -0.7218, 0.4539, 0.5991, 0.6896, 0.4069, -0.6067, 0.0594, 0.7927),
        "Left Arm": (0.6418, 0.0962, 0.7608, 0.7657, -0.1344, -0.6290, 0.0417, 0.9862, -0.1599),
        "Right Arm": (-0.0884, -0.9919, 0.0914, 0.9640, -0.0621, 0.2584, -0.2506, 0.1110, 0.9617),
        "Left Leg": (0.4283, -0.7218, 0.5437, 0.5123, 0.6896, 0.5119, -0.7444, 0.0594, 0.6651),
        "Right Leg": (0.2189, -0.8637, 0.4539, 0.8115, 0.4195, 0.4069, -0.5418, 0.2793, 0.7927),
    },
    "R": {
        "Torso": (0.5225, 0.7218, -0.4539, -0.5991, 0.6896, 0.4069, 0.6067, 0.0594, 0.7927),
        "Head": (0.5225, 0.7218, -0.4539, -0.5991, 0.6896, 0.4069, 0.6067, 0.0594, 0.7927),
        "Left Arm": (-0.0884, 0.9919, -0.0914, -0.9640, -0.0621, 0.2584, 0.2506, 0.1110, 0.9617),
        "Right Arm": (0.6418, -0.0962, -0.7608, -0.7657, -0.1344, -0.6290, -0.0417, 0.9862, -0.1599),
        "Left Leg": (0.2189, 0.8637, -0.4539, -0.8115, 0.4195, 0.4069, 0.5418, 0.2793, 0.7927),
        "Right Leg": (0.4283, 0.7218, -0.5437, -0.5123, 0.6896, 0.5119, 0.7444, 0.0594, 0.6651),
    },
    "B": {
        "Torso": (1.0000, 0.0000, 0.0000, 0.0000, 0.9086, -0.4176, 0.0000, 0.4176, 0.9086),
        "Head": (1.0000, 0.0000, 0.0000, 0.0000, 0.9927, 0.1205, 0.0000, -0.1205, 0.9927),
        "Left Arm": (0.8490, 0.5173, -0.1075, 0.0007, -0.2046, -0.9788, -0.5284, 0.8310, -0.1741),
        "Right Arm": (0.8526, -0.5225, 0.0000, -0.1518, -0.2477, -0.9569, 0.5000, 0.8159, -0.2905),
        "Left Leg": (1.0000, 0.0000, 0.0000, 0.0000, 0.8331, -0.5532, 0.0000, 0.5532, 0.8331),
        "Right Leg": (1.0000, -0.0082, -0.0015, 0.0076, 0.9697, -0.2441, 0.0035, 0.2441, 0.9698),
    },
}
ROBLOX_TO_BLENDER = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))  # Roblox (x right, y up, -z forward) -> ours
R6_TO_R15 = {"Torso": "LowerTorso", "Head": "Head", "Left Arm": "LeftUpperArm", "Right Arm": "RightUpperArm",
             "Left Leg": "LeftUpperLeg", "Right Leg": "RightUpperLeg"}


# R6 tucks a leg by sliding the whole leg up its hip (about a stud); R15 bends that knee instead: the thigh swings
# forward 35 degrees about its own hip axis and the shin folds back 80.
TUCK = {"F": "Right", "F2": "Left", "L": "Left", "R": "Right"}


def ref_rot(which):
    """REF[which] as a pose dict (world-axis rotations at each joint, chained as in world_deltas)."""
    w = {k: ROBLOX_TO_BLENDER @ Matrix((v[0:3], v[3:6], v[6:9])) @ ROBLOX_TO_BLENDER.transposed()
         for k, v in REF[which].items()}
    rot = {}
    for part, bone in R6_TO_R15.items():
        local = w[part] if part == "Torso" else w["Torso"].transposed() @ w[part]  # every other part hangs off the torso
        if which in TUCK and bone == TUCK[which] + "UpperLeg":
            local = local @ Matrix.Rotation(math.radians(-35), 3, "X")
            rot[TUCK[which] + "LowerLeg"] = (80, 0, 0)
        rot[bone] = tuple(math.degrees(a) for a in local.to_euler("XYZ"))
    return rot


def dash(rig, hold0, which):
    """SwordDash<which> (11 frames, 0.37 s): from SwordHold's first frame it snaps into the reference pose in 4 frames
    (ease out) and holds it; the client fades the track out over its end."""
    n = 11
    new_action(rig, "EXP_SwordDash" + which, n)
    a, b = hold0[0], ref_rot(which)
    for f in range(n + 1):
        t = 1 - (1 - min(1.0, f / 4)) ** 3
        rot = {}
        for k in set(a) | set(b):
            qa, qb = (Euler([math.radians(x) for x in d.get(k, (0, 0, 0))]).to_quaternion() for d in (a, b))
            if qa.dot(qb) < 0:  # the short way round
                qb.negate()
            rot[k] = tuple(math.degrees(x) for x in qa.slerp(qb, t).to_euler("XYZ"))
        key(rig, f, rot, hold0[1] * (1 - t))
    print("EXP_SwordDash" + which + ": reference pose from frame 4")


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
idle0 = idle(rig)
run0 = run(rig)
hold0 = guard(rig)
plant(rig, hold0, idle0)
pull(rig, idle0, run0)
for which in REF:
    dash(rig, hold0, which)
bpy.context.scene.render.fps = FPS
bpy.ops.wm.save_mainfile()
render(rig, os.path.join(ROOT, "renders", "sword_carry_anims.png"),
       [("EXP_SwordIdle", 0, FRONT), ("EXP_SwordIdle", 0, SIDE), ("EXP_SwordIdle", 0, BACK34),
        ("EXP_SwordRun", 0, FRONT34), ("EXP_SwordRun", 5, FRONT34), ("EXP_SwordRun", 10, FRONT34)])
render(rig, os.path.join(ROOT, "renders", "sword_dash_anims.png"),
       [("EXP_SwordDashF", 8, SIDE), ("EXP_SwordDashF2", 8, FRONT34), ("EXP_SwordDashL", 8, FRONT),
        ("EXP_SwordDashR", 8, FRONT), ("EXP_SwordDashB", 8, SIDE), ("EXP_SwordDashB", 8, FRONT34)])
print("actions:", [a.name for a in bpy.data.actions])
