# Goblin enemy - stage 3: animation set + manifest. Run after 02_build_rig.py.
#
# How a clip is made:
#   1. Key poses (dicts) at a few frames. Body bones use degrees about the armature axes
#      (X+ = top of bone tips forward, Y+ = tips toward goblin's left (+X), Z+ = twists toward its left)
#      and metres for locations (Y- = forward). The sword arm is NOT posed by angles: each key says where the
#      grip is (g, metres from the right shoulder), where the blade points (b) and which way the edge faces (e),
#      all in world axes, so a level slash stays level however far the goblin leans. A 2-bone solver builds the
#      arm from that and places the elbow where the wrist stays straight.
#   2. Every frame is sampled with cubic Hermite splines (moving holds instead of stop-start keys). Keys marked
#      "hold" ease in/out; planted feet hold automatically and get a lifted mid-step when they move.
#   3. Follow-through: head and free arm sample a few frames late (drag); hips lead.
#   4. Springs: ears and waist cloth lag/overshoot from the motion (cloth also falls toward gravity and is pushed
#      out of the way by the thighs). Loops are simulated 3 cycles so the seam is clean.
#   5. Floor guards: hips lift where the body would clip the floor; the wrist turns where the blade would.
# Feet are IK targets parented to Root (never animated: Roblox moves HumanoidRootPart), so locomotion is in place.
import bpy, math, json, os
from bisect import bisect_right
from mathutils import Euler, Vector, Matrix, Quaternion

ROOT = os.environ.get("GOBLIN_ROOT", "/Users/chinnaphat/Desktop/cedt/roblox/goblin")
FPS = 30
RIG = "Goblin_Rig"
BODY_MESHES = [n + "_Geo" for n in (
    "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
    "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg",
    "RightLowerLeg", "RightFoot")]
DELAY = {"Head": 2, "LeftUpperArm": 1, "LeftLowerArm": 2, "LeftHand": 3, "LowerTorso": -1}
SPRINGS = [  # bone, stiffness, damping (per frame), gravity mix
    ("Ear_L", 0.40, 0.36, 0.0), ("Ear_R", 0.40, 0.36, 0.0),
    ("Cloth_F", 0.15, 0.28, 0.55), ("Cloth_B", 0.15, 0.28, 0.55),
]
MAX_WRIST = 65  # degrees; beyond this the hand (and blade) is eased back toward the forearm


def dirv(f=0, b=0, u=0, d=0, l=0, r=0):
    """Direction from named parts: forward/back/up/down/left(+X)/right(-X)."""
    return tuple(Vector((l - r, b - f, u - d)).normalized())


F, D, U, B = dirv(f=1), dirv(d=1), dirv(u=1), dirv(b=1)


def sword(g, b, e=D, p=(-0.5, 0.5, -0.6)):
    return {"g": g, "b": b, "e": e, "p": p}


GUARD = sword((-0.06, -0.27, -0.32), dirv(f=1, u=0.25, r=0.15), dirv(d=1, f=0.2), (-0.7, 0.3, -0.4))
CARRY = sword((-0.01, -0.06, -0.40), dirv(f=0.55, d=0.8, r=0.25), D, (-0.3, 0.6, -0.5))  # reference pose

BASE = {  # hunched, sneaky combat stance
    "LowerTorso": {"l": (0, 0.02, -0.06), "r": (10, 0, 0)},
    "UpperTorso": {"r": (14, 0, 0)},
    "Head": {"r": (-18, 0, 0)},
    "Ear_L": {"r": (0, 0, 0)}, "Ear_R": {"r": (0, 0, 0)},
    "LeftUpperArm": {"r": (-26, -12, 0)}, "LeftLowerArm": {"r": (-22, 0, 0)}, "LeftHand": {"r": (0, 0, 0)},
    "IK_Foot_L": {"l": (0.025, -0.06, 0), "r": (0, 0, 8)},
    "IK_Foot_R": {"l": (-0.025, 0.05, 0), "r": (0, 0, -8)},
    "SWORD": GUARD,
}


def P(**over):
    pose = {b: dict(ch) for b, ch in BASE.items()}
    for b, v in over.items():
        if b == "SWORD":
            pose[b] = v
        else:
            pose.setdefault(b, {}).update(v if isinstance(v, dict) else {"r": v})
    return pose


def Q(*parts):
    over = {}
    for p in parts:
        over.update(p)
    return P(**over)


def body(hip=None, hipr=None, chest=None, head=None):
    d = {}
    if hip is not None or hipr is not None:
        d["LowerTorso"] = {"l": hip or BASE["LowerTorso"]["l"], "r": hipr or BASE["LowerTorso"]["r"]}
    if chest is not None:
        d["UpperTorso"] = {"r": chest}
    if head is not None:
        d["Head"] = {"r": head}
    return d


def ears(perk=0, back=0, tilt=0):
    """perk > 0 = up, back > 0 = swept back, tilt > 0 = tips forward. Mirrored for the right ear."""
    return {"Ear_L": {"r": (tilt, -perk, back)}, "Ear_R": {"r": (tilt, perk, -back)}}


def arm_l(up, lo, hand=(0, 0, 0)):
    return {"LeftUpperArm": {"r": up}, "LeftLowerArm": {"r": lo}, "LeftHand": {"r": hand}}


def feet(l=None, r=None):
    d = {}
    if l:
        d["IK_Foot_L"] = {"l": l[0], "r": l[1]}
    if r:
        d["IK_Foot_R"] = {"l": r[0], "r": r[1]}
    return d


def SW(g, b, e=D, p=(-0.5, 0.5, -0.6)):
    return {"SWORD": sword(g, b, e, p)}


CLIPS = {}


def clip(name, frames, loop, priority, keys, events=None, notes="", displacement=None, extra=None, dense=False,
         strict=False):
    if loop and keys[-1][0] != frames:
        keys = keys + [(frames, keys[0][1])]
    CLIPS[name] = dict(frames=frames, loop=loop, priority=priority, keys=keys, events=events or {},
                       notes=notes, displacement=displacement, extra=extra, dense=dense, strict=strict)


# ================================================================== clips
IDLE = Q(body(hip=(0, 0.02, -0.04), hipr=(6, 0, 0), chest=(10, 0, 0), head=(-12, 0, 0)),
         arm_l((-8, -10, 0), (-14, 0, 0)), {"SWORD": CARRY})


def idle_extra(f, pose):
    br = math.sin(2 * math.pi * f / 60)  # breathing, 2 s
    pose["UpperTorso"]["r"][0] += 2.0 * br
    pose["LowerTorso"]["l"][2] += 0.004 * br
    for side, f0 in (("Ear_L", 22), ("Ear_R", 82)):  # quick ear flicks
        k = f - f0
        if 0 <= k < 8:
            flick = math.sin(math.pi * k / 4) * (1 - k / 8)
            pose[side]["r"][0] -= 18 * flick
            pose[side]["r"][1] += (-12 if side == "Ear_L" else 12) * flick


clip("Idle", 120, True, "Idle", [
    (0, IDLE),
    (36, Q(body(hip=(0.015, 0.02, -0.045), hipr=(6, 2, 3), chest=(11, -1, -4), head=(-14, 0, -25)),
           arm_l((-8, -10, 0), (-16, 0, 0)), {"SWORD": CARRY}), "hold"),
    (60, Q(body(hip=(0.01, 0.02, -0.04), hipr=(6, 1, 0), chest=(9, 0, 0), head=(-8, 0, 0)),
           arm_l((-6, -10, 0), (-12, 0, 0)), {"SWORD": CARRY})),
    (86, Q(body(hip=(-0.012, 0.02, -0.045), hipr=(6, -2, -3), chest=(11, 1, 5), head=(-16, 4, 28)),
           arm_l((-10, -10, 0), (-18, 0, 0)),
           SW((-0.02, -0.08, -0.39), dirv(f=0.7, d=0.7, r=0.2), D, (-0.3, 0.6, -0.5))), "hold"),
    (120, IDLE),
], extra=idle_extra, notes="Relaxed carry (reference pose), breathing, glances left/right, ear flicks.")


def combat_extra(f, pose):
    k = math.sin(2 * math.pi * f / 20)
    pose["LowerTorso"]["l"][2] += 0.012 * (0.5 + 0.5 * k)
    pose["UpperTorso"]["r"][0] += 2.5 * k
    pose["Head"]["r"][2] += 6 * math.sin(2 * math.pi * f / 40)
    g = list(pose["SWORD"]["g"])
    g[2] += 0.015 * k
    pose["SWORD"]["g"] = g


clip("CombatIdle", 40, True, "Idle", [
    (0, P()),
    (20, Q(body(hip=(0.012, 0.02, -0.07), hipr=(11, 2, 6), chest=(15, -1, -6)),
           SW((-0.04, -0.29, -0.31), dirv(f=1, u=0.35, r=0.1), dirv(d=1, f=0.2), (-0.7, 0.3, -0.4)))),
], extra=combat_extra, notes="Bouncy guard between attacks; sword tip stays on the target.")

clip("Alert", 30, False, "Action", [
    (0, IDLE),
    (4, Q(body(hip=(0, 0.03, -0.02), hipr=(2, 0, 0), chest=(0, 0, 0), head=(-6, 0, 0)), ears(perk=30, back=-10),
          arm_l((-20, -30, 0), (-40, 0, 0)), SW((-0.04, -0.10, -0.36), dirv(f=0.8, d=0.5, r=0.2)))),
    (10, Q(body(hip=(0, 0.04, -0.11), hipr=(16, 0, 0), chest=(26, 0, 0), head=(-34, 0, 0)), ears(perk=5, back=25),
           arm_l((-55, -24, 0), (-50, 0, 0)),
           SW((-0.04, -0.30, -0.26), dirv(f=1, u=0.35, r=0.1), dirv(d=1, f=0.2), (-0.7, 0.3, -0.4))), "hold"),
    (17, Q(body(hip=(0, 0.04, -0.09), hipr=(13, 0, 0), chest=(20, 0, 0), head=(-26, 0, 0)), ears(back=10),
           arm_l((-40, -18, 0), (-42, 0, 0)))),
    (30, P()),
], events={"Alert": 3, "Recover": 22}, notes="Ears snap up, snarl-crouch into guard.")

# Attack1: flat forehand slash, right to left. Edge leads the swing the whole way.
clip("Attack1", 30, False, "Action", [
    (0, P()),
    (6, Q(body(hip=(0, 0.05, -0.10), hipr=(10, 0, -16), chest=(10, 0, -34), head=(-16, 0, 30)), ears(back=20),
          arm_l((-60, -20, 0), (-40, 0, 0)),
          SW((-0.30, 0.10, -0.08), dirv(b=1, r=0.5, u=0.3), dirv(r=1, f=0.4), (-0.6, 0.6, -0.2)),
          feet(r=((-0.03, 0.10, 0), (0, 0, -18)))), "hold"),
    (9, Q(body(hip=(0, 0.02, -0.11), hipr=(12, 0, -4), chest=(14, 0, -6), head=(-20, 0, 6)),
          arm_l((-30, -30, 0), (-30, 0, 0)),
          SW((-0.30, -0.33, -0.12), dirv(f=0.7, r=0.7), dirv(f=0.5, l=1), (-0.7, 0.3, -0.4)),
          feet(r=((-0.03, 0.10, 0), (0, 0, -18))))),
    (11, Q(body(hip=(0, -0.01, -0.12), hipr=(14, 0, 12), chest=(22, 0, 30), head=(-24, 0, -26)), ears(back=-10),
           arm_l((-10, -40, 0), (-20, 0, 0)),
           SW((0.14, -0.42, -0.15), dirv(f=1, l=0.6), dirv(l=1, b=0.3), (-0.5, 0.2, -0.7)),
           feet(r=((-0.03, 0.10, 0), (0, 0, -18))))),
    (14, Q(body(hip=(0, -0.02, -0.12), hipr=(14, 0, 18), chest=(22, 0, 44), head=(-24, 0, -38)),
           arm_l((10, -40, 0), (-20, 0, 0)),
           SW((0.30, -0.26, -0.22), dirv(f=0.8, d=0.6, l=0.3), dirv(l=1), (-0.3, -0.2, -0.9)),
           feet(r=((-0.03, 0.10, 0), (0, 0, -18))))),
    (19, Q(body(hip=(0, -0.01, -0.11), hipr=(13, 0, 14), chest=(20, 0, 36), head=(-22, 0, -30)),
           arm_l((0, -36, 0), (-24, 0, 0)),
           SW((0.24, -0.26, -0.28), dirv(f=0.6, d=1, l=0.2), dirv(l=1), (-0.3, -0.2, -0.9))), "hold"),
    (30, P()),
], events={"Swing": 8, "HitStart": 10, "HitEnd": 14, "Recover": 20}, strict=True)

# Attack2: overhead chop. Blade cocked behind the head, edge up -> forward -> down.
clip("Attack2", 34, False, "Action", [
    (0, P()),
    (9, Q(body(hip=(0, 0.06, -0.03), hipr=(-2, 0, -6), chest=(-12, 0, -10), head=(-2, 0, 10)), ears(perk=10, back=20),
          arm_l((-90, -10, 0), (-20, 0, 0)),
          SW((0.06, 0.06, 0.40), dirv(b=1, d=0.25, l=0.1), U, (-0.7, -0.2, 0.4)),
          feet(l=((0.025, -0.10, 0), (0, 0, 8)))), "hold"),
    (12, Q(body(hip=(0, 0.02, -0.06), hipr=(6, 0, 0), chest=(4, 0, 0), head=(-10, 0, 0)),
           arm_l((-60, -20, 0), (-30, 0, 0)),
           SW((0.08, -0.26, 0.30), dirv(u=1, f=0.4), F, (-0.8, 0.0, 0.2)),
           feet(l=((0.025, -0.13, 0), (0, 0, 8))))),
    (14, Q(body(hip=(0, -0.02, -0.14), hipr=(20, 0, 2), chest=(36, 0, 4), head=(-36, 0, 0)), ears(back=-15, tilt=15),
           arm_l((-10, -30, 0), (-20, 0, 0)),
           SW((0.10, -0.45, -0.10), dirv(f=1, d=0.6), dirv(d=1, f=0.4), (-0.7, 0.2, -0.3)),
           feet(l=((0.025, -0.13, 0), (0, 0, 8))))),
    (17, Q(body(hip=(0, -0.03, -0.16), hipr=(22, 0, 2), chest=(40, 0, 4), head=(-38, 0, 0)),
           arm_l((0, -30, 0), (-20, 0, 0)),
           SW((0.08, -0.36, -0.32), dirv(f=1, d=0.45), dirv(d=1, f=0.3), (-0.6, 0.3, -0.4)),
           feet(l=((0.025, -0.13, 0), (0, 0, 8))))),
    (23, Q(body(hip=(0, -0.02, -0.15), hipr=(20, 0, 2), chest=(36, 0, 4), head=(-34, 0, 0)),
           arm_l((-6, -28, 0), (-22, 0, 0)),
           SW((0.08, -0.36, -0.30), dirv(f=1, d=0.35), dirv(d=1, f=0.3), (-0.6, 0.3, -0.4)),
           feet(l=((0.025, -0.13, 0), (0, 0, 8)))), "hold"),
    (34, P()),
], events={"Swing": 11, "HitStart": 13, "HitEnd": 17, "Recover": 24}, strict=True)

# Attack3: stepping thrust, edge down, point leads.
clip("Attack3", 28, False, "Action", [
    (0, P()),
    (6, Q(body(hip=(0, 0.07, -0.10), hipr=(8, 0, -12), chest=(10, 0, -26), head=(-16, 0, 24)), ears(back=25),
          arm_l((-60, -10, 0), (-40, 0, 0)),
          SW((-0.04, 0.20, -0.24), dirv(f=1, u=0.12), D, (-0.4, 0.8, -0.3))), "hold"),
    (10, Q(body(hip=(0, -0.06, -0.12), hipr=(16, 0, 14), chest=(26, 0, 22), head=(-32, 0, -20)), ears(back=-10),
           arm_l((10, -30, 0), (-20, 0, 0)),
           SW((0.06, -0.52, -0.12), dirv(f=1, d=0.04), D, (-0.6, 0.3, -0.6)),
           feet(r=((-0.035, -0.16, 0), (0, 0, -6)), l=((0.035, 0.10, 0), (0, 0, 10))))),
    (16, Q(body(hip=(0, -0.05, -0.12), hipr=(14, 0, 12), chest=(22, 0, 18), head=(-28, 0, -16)),
           arm_l((0, -28, 0), (-22, 0, 0)),
           SW((0.05, -0.48, -0.16), dirv(f=1, d=0.12), D, (-0.6, 0.3, -0.6)),
           feet(r=((-0.035, -0.16, 0), (0, 0, -6)), l=((0.035, 0.10, 0), (0, 0, 10)))), "hold"),
    (28, P()),
], events={"Swing": 8, "HitStart": 9, "HitEnd": 13, "Footstep": 10, "Recover": 18}, strict=True)


# HeavyAttack: crouched windup with a trembling telegraph, hop, two-handed slam into the ground.
def heavy_extra(f, pose):
    if 12 <= f <= 29:
        s = math.sin(f * 2.6)
        pose["UpperTorso"]["r"][2] += 2.5 * s
        pose["Head"]["r"][1] += 3 * s
        g = list(pose["SWORD"]["g"])
        g[0] += 0.012 * s
        pose["SWORD"]["g"] = g


wind = Q(body(hip=(0, 0.08, -0.16), hipr=(4, 0, -10), chest=(-10, 0, -18), head=(-6, 0, 16)), ears(back=35),
         arm_l((-165, 18, 0), (-30, 0, 0)),
         SW((0.14, 0.08, 0.42), dirv(b=1, d=0.5), U, (-0.7, -0.1, 0.4)),
         feet(l=((0.05, -0.10, 0), (0, 0, 12)), r=((-0.05, 0.10, 0), (0, 0, -12))))
clip("HeavyAttack", 60, False, "Action", [
    (0, P()),
    (12, wind),
    (28, Q(body(hip=(0, 0.09, -0.13), hipr=(0, 0, -12), chest=(-16, 0, -20), head=(-2, 0, 18)), ears(back=40),
           arm_l((-170, 20, 0), (-32, 0, 0)),
           SW((0.14, 0.10, 0.44), dirv(b=1, d=0.65), U, (-0.7, -0.1, 0.4)),
           feet(l=((0.05, -0.10, 0), (0, 0, 12)), r=((-0.05, 0.10, 0), (0, 0, -12)))), "hold"),
    (31, Q(body(hip=(0, -0.02, 0.05), hipr=(8, 0, -4), chest=(6, 0, -6), head=(-12, 0, 4)), ears(back=10),
           arm_l((-150, 10, 0), (-20, 0, 0)),
           SW((0.10, -0.24, 0.42), dirv(u=1, f=0.35), F, (-0.8, 0, 0.2)),
           feet(l=((0.05, -0.12, 0.10), (-20, 0, 12)), r=((-0.05, 0.08, 0.12), (-20, 0, -12))))),
    (34, Q(body(hip=(0, -0.05, -0.20), hipr=(26, 0, 4), chest=(44, 0, 6), head=(-42, 0, 0)), ears(back=-25, tilt=20),
           arm_l((-40, 20, 0), (-10, 0, 0)),
           SW((0.12, -0.48, -0.30), dirv(f=0.6, d=1), dirv(d=1, f=0.5), (-0.7, 0.2, -0.3)),
           feet(l=((0.06, -0.16, 0), (0, 0, 14)), r=((-0.06, 0.12, 0), (0, 0, -14))))),
    (44, Q(body(hip=(0, -0.05, -0.19), hipr=(25, 0, 4), chest=(42, 0, 6), head=(-38, 0, 0)),
           arm_l((-38, 18, 0), (-12, 0, 0)),
           SW((0.12, -0.47, -0.29), dirv(f=0.6, d=1), dirv(d=1, f=0.5), (-0.7, 0.2, -0.3)),
           feet(l=((0.06, -0.16, 0), (0, 0, 14)), r=((-0.06, 0.12, 0), (0, 0, -14)))), "hold"),
    (60, P()),
], events={"Telegraph": 4, "Swing": 31, "HitStart": 33, "HitEnd": 37, "Impact": 34, "Recover": 46},
   extra=heavy_extra, strict=True, notes="Frames 12-29 tremble = 0.6 s telegraph window before the slam.")

clip("LungeAttack", 40, False, "Action", [
    (0, P()),
    (8, Q(body(hip=(0, 0.07, -0.17), hipr=(24, 0, 0), chest=(30, 0, 0), head=(-40, 0, 0)), ears(back=35),
          arm_l((-40, -20, 0), (-40, 0, 0)),
          SW((-0.02, 0.15, -0.26), dirv(f=1, u=0.2), D, (-0.4, 0.8, -0.3)),
          feet(l=((0.05, 0.02, 0), (0, 0, 10)), r=((-0.05, 0.08, 0), (0, 0, -10)))), "hold"),
    (13, Q(body(hip=(0, -0.05, 0.0), hipr=(26, 0, 8), chest=(28, 0, 12), head=(-38, 0, -8)), ears(back=45),
           arm_l((30, -40, 0), (-20, 0, 0)),
           SW((0.05, -0.52, -0.10), F, D, (-0.6, 0.3, -0.6)),
           feet(l=((0.05, 0.16, 0.14), (30, 0, 10)), r=((-0.05, -0.12, 0.10), (-15, 0, -10))))),
    (18, Q(body(hip=(0, -0.06, -0.15), hipr=(20, 0, 10), chest=(24, 0, 14), head=(-32, 0, -10)), ears(back=-10, tilt=10),
           arm_l((20, -40, 0), (-20, 0, 0)),
           SW((0.05, -0.50, -0.16), dirv(f=1, d=0.15), D, (-0.6, 0.3, -0.6)),
           feet(l=((0.05, 0.16, 0), (0, 0, 10)), r=((-0.05, -0.18, 0), (0, 0, -10))))),
    (25, Q(body(hip=(0, -0.05, -0.14), hipr=(18, 0, 8), chest=(22, 0, 10), head=(-28, 0, -6)),
           arm_l((0, -30, 0), (-25, 0, 0)),
           SW((0.04, -0.42, -0.22), dirv(f=1, d=0.3), D, (-0.6, 0.3, -0.6)),
           feet(l=((0.05, 0.16, 0), (0, 0, 10)), r=((-0.05, -0.18, 0), (0, 0, -10)))), "hold"),
    (40, P()),
], events={"LungeStart": 10, "Swing": 12, "HitStart": 13, "HitEnd": 20, "Footstep": 18, "Recover": 28},
   displacement="Move HumanoidRootPart forward ~10 studs between LungeStart (0.33 s) and 0.6 s.", strict=True)


def hit(name, hip, hipr, chest, head, sw):
    clip(name, 20, False, "Action", [
        (0, P()),
        (3, Q(body(hip=hip, hipr=hipr, chest=chest, head=head), ears(back=-30, tilt=-20),
              arm_l((-40, -45, 0), (-20, 0, 0)), {"SWORD": sw})),
        (8, Q(body(hip=hip, hipr=tuple(a * 0.35 for a in hipr), chest=tuple(a * 0.3 + 6 for a in chest),
                   head=tuple(a * 0.3 for a in head)), ears(back=10))),
        (20, P()),
    ], events={"Recover": 13})


hit("HitFront", (0, 0.07, -0.05), (-6, 0, 0), (-22, 0, 0), (-34, 0, 0),
    sword((-0.22, 0.02, -0.26), dirv(f=0.5, u=0.6, r=0.5), D, (-0.6, 0.6, 0)))
hit("HitLeft", (-0.04, 0.03, -0.07), (6, -10, -16), (10, -18, -26), (-12, -22, -20),
    sword((-0.26, -0.10, -0.20), dirv(f=0.6, u=0.4, r=0.6), D, (-0.6, 0.6, 0)))
hit("HitRight", (0.04, 0.03, -0.07), (6, 10, 16), (10, 18, 26), (-12, 22, 20),
    sword((0.10, -0.26, -0.30), dirv(f=1, u=0.2, l=0.5), D, (-0.6, 0.3, -0.4)))


def daze(a):
    s, c = math.sin(a), math.cos(a)
    return Q(body(hip=(0.02 * s, 0.03, -0.11), hipr=(14, 6 * c, 0), chest=(28 + 5 * s, 8 * c, 5 * s),
                  head=(-4 + 8 * c, 12 * s, 8 * c)), ears(perk=-25, tilt=15),
             arm_l((-4, -12, 0), (-8, 0, 0)),
             SW((-0.02 + 0.02 * s, -0.12, -0.42), dirv(f=0.5, d=1, r=0.3), D, (-0.3, 0.6, -0.5)))


clip("Stun", 48, True, "Action", [(f, daze(2 * math.pi * f / 48)) for f in range(0, 49, 8)],
     events={"StunStars": 0}, notes="Loop while stunned; stop with fade 0.15. Blade tip drags on the floor.")

clip("Knockback", 45, False, "Action", [
    (0, P()),
    (3, Q(body(hip=(0, 0.10, -0.03), hipr=(-14, 0, 0), chest=(-24, 0, 0), head=(-38, 0, 0)), ears(back=-35, tilt=-25),
          arm_l((-80, -50, 0), (-20, 0, 0)), SW((-0.12, -0.20, 0.10), dirv(u=1, b=0.4, r=0.3), dirv(f=1), (-0.7, 0, 0)),
          feet(l=((0.035, -0.04, 0.06), (-10, 0, 8)), r=((-0.035, 0.06, 0.0), (0, 0, -8))))),
    (9, Q(body(hip=(0, 0.08, -0.12), hipr=(0, 0, 0), chest=(4, 0, 0), head=(-20, 0, 0)),
          arm_l((-50, -40, 0), (-30, 0, 0)), SW((-0.16, -0.10, -0.20), dirv(f=0.7, u=0.5, r=0.4)),
          feet(l=((0.035, 0.16, 0.0), (0, 0, 8)), r=((-0.035, 0.06, 0.0), (0, 0, -8))))),
    (15, Q(body(hip=(0, 0.05, -0.14), hipr=(16, 0, 0), chest=(24, 0, 0), head=(-30, 0, 0)),
           arm_l((-40, -30, 0), (-40, 0, 0)),
           feet(l=((0.035, 0.14, 0.0), (0, 0, 8)), r=((-0.035, 0.16, 0.0), (0, 0, -8))))),
    (26, Q(body(hip=(0, 0.04, -0.12), hipr=(13, 0, 0), chest=(20, 0, 0), head=(-24, 0, 0))), "hold"),
    (45, P()),
], events={"Footstep": 9, "Footstep2": 15, "Recover": 30},
   displacement="Push HumanoidRootPart back ~8 studs over 0-0.35 s (server-side LinearVelocity).")


def dead(k):
    return Q(body(hip=(0, -0.30, -0.40 - 0.01 * k), hipr=(84 + 2 * k, 0, 4), chest=(2, 0, 0), head=(-50, 0, 28 + 3 * k)),
             ears(perk=-20, tilt=-30),
             arm_l((-150 - 4 * k, -28, 0), (-8, 0, 0)),
             SW((-0.06, -0.36, -0.06), dirv(f=1, r=0.5), dirv(r=1, b=0.5), (-0.6, 0, 0.6)),  # sword flat on the ground
             feet(l=((0.06, 0.14, 0.07), (88, 0, 8)), r=((-0.06, 0.15, 0.07), (88, 0, -8))))


clip("Death", 60, False, "Action", [
    (0, P()),
    (5, Q(body(hip=(0, 0.08, -0.06), hipr=(-10, 0, 0), chest=(-18, 0, 0), head=(-32, 0, 0)), ears(back=-30),
          arm_l((-50, -40, 0), (-20, 0, 0)), SW((-0.18, -0.10, -0.20), dirv(f=0.6, u=0.6, r=0.4)))),
    (16, Q(body(hip=(0, 0.02, -0.28), hipr=(6, 0, 4), chest=(12, 0, 4), head=(10, 0, 0)), ears(perk=-10),
           arm_l((-10, -10, 0), (-10, 0, 0)), SW((-0.02, -0.10, -0.40), dirv(f=0.6, d=1, r=0.2)),
           feet(l=((0.05, 0.02, 0.0), (0, 0, 8)), r=((-0.05, 0.08, 0.0), (0, 0, -8))))),
    (26, Q(body(hip=(0, -0.10, -0.36), hipr=(50, 0, 6), chest=(30, 0, 4), head=(10, 0, 10)), ears(perk=-20),
           arm_l((-80, -20, 0), (-20, 0, 0)), SW((-0.02, -0.30, -0.20), dirv(f=1, d=0.3)),
           feet(l=((0.05, 0.10, 0.095), (40, 0, 8)), r=((-0.05, 0.14, 0.095), (40, 0, -8))))),
    (34, dead(0)),
    (60, dead(1)),
], events={"Death": 0, "BodyFall": 33, "Dissolve": 45}, notes="Freeze on last frame (track:AdjustSpeed(0) near end).")


def turn(name, s):
    clip(name, 24, False, "Movement", [
        (0, P()),
        (6, Q(body(hipr=(10, 0, 10 * s), chest=(16, 0, 20 * s), head=(-20, 0, 28 * s)), ears(back=10))),
        (12, Q(body(hipr=(10, 0, 14 * s), chest=(16, 0, 18 * s), head=(-20, 0, 18 * s)),
               feet(l=((0.035, -0.03, 0), (0, 0, 8 + 25 * s)), r=((-0.035, 0.03, 0), (0, 0, -8 + 25 * s))))),
        (24, P()),
    ], events={"Footstep": 8, "Footstep2": 16},
       displacement="Rotate HumanoidRootPart 90 deg (%s) over the clip." % ("left" if s > 0 else "right"))


turn("TurnLeft", 1)
turn("TurnRight", -1)

tuck = Q(body(hip=(0, 0.02, -0.02), hipr=(6, 0, 0), chest=(12, 0, 0), head=(-14, 0, 0)), ears(perk=15, back=20),
         arm_l((-70, -40, 0), (-40, 0, 0)), SW((-0.10, -0.20, -0.10), dirv(f=0.6, u=0.5, r=0.4)),
         feet(l=((0.04, 0.0, 0.14), (-14, 0, 8)), r=((-0.04, 0.06, 0.10), (-6, 0, -8))))
clip("Jump", 10, False, "Movement", [
    (0, Q(body(hip=(0, 0.04, -0.14), hipr=(18, 0, 0), chest=(22, 0, 0)))),
    (4, Q(body(hip=(0, 0.0, 0.0), hipr=(4, 0, 0), chest=(8, 0, 0)), ears(perk=20),
          arm_l((-90, -40, 0), (-20, 0, 0)), SW((-0.12, -0.25, 0.0), dirv(f=0.5, u=0.7, r=0.3)),
          feet(l=((0.03, 0.02, 0.07), (20, 0, 8)), r=((-0.03, 0.08, 0.07), (20, 0, -8))))),
    (10, tuck),
], events={"Jump": 2})
clip("Fall", 20, True, "Movement", [
    (0, tuck),
    (10, Q(body(hip=(0, 0.02, -0.02), hipr=(6, 0, 0), chest=(12, 0, 0), head=(-14, 0, 0)), ears(perk=5, back=30),
           arm_l((-76, -46, 0), (-40, 0, 0)), SW((-0.12, -0.18, -0.08), dirv(f=0.6, u=0.6, r=0.4)),
           feet(l=((0.04, 0.0, 0.12), (-14, 0, 8)), r=((-0.04, 0.06, 0.12), (-6, 0, -8))))),
])
clip("Land", 14, False, "Movement", [
    (0, tuck),
    (3, Q(body(hip=(0, 0.04, -0.18), hipr=(22, 0, 0), chest=(30, 0, 0), head=(-32, 0, 0)), ears(back=-20, tilt=20),
          arm_l((-40, -30, 0), (-40, 0, 0)))),
    (14, P()),
], events={"Footstep": 1})


# ------------------------------------------------------------------ locomotion (generated, dense)
def gait(N, dist, stance, lift, hip, bob, lean, armswing, sway, sw_fn, wide=0.03, toe=28):
    travel = stance * dist
    keys = []
    for f in range(N + 1):
        p = (f % N) / N
        pose = P()
        for side, ph0, sx in (("L", 0.0, 1), ("R", 0.5, -1)):
            ph = (p + ph0) % 1
            if ph < stance:
                y, z, pitch = -travel / 2 + travel * ph / stance, 0.0, 0.0
            else:
                t = (ph - stance) / (1 - stance)
                y = travel / 2 - travel * (t * t * (3 - 2 * t))
                z = lift * math.sin(math.pi * t) ** 1.3
                pitch = -toe * math.sin(math.pi * t)  # toes up through the swing
            pose["IK_Foot_" + side] = {"l": (wide * sx, y, z), "r": (pitch, 0, 6 * sx)}
        c1 = math.cos(2 * math.pi * p)  # +1: left foot forward
        c2 = math.cos(4 * math.pi * p)  # low at contacts
        sx = math.cos(2 * math.pi * (p - stance / 2))  # weight over the stance foot
        pose["LowerTorso"] = {"l": (sway * sx, 0.0, hip + bob * (0.5 - 0.5 * c2)),
                              "r": (lean * 0.4, -3 * sx, -8 * c1)}
        pose["UpperTorso"] = {"r": (lean + 2 * c2, 2 * sx, 11 * c1)}
        pose["Head"] = {"r": (-lean - 6 - 2 * c2, -2 * sx, -5 * c1)}
        pose["LeftUpperArm"] = {"r": (-lean - 4 + armswing * c1, -12, 0)}  # hangs ~vertical in the world
        pose["LeftLowerArm"] = {"r": (-14 - armswing * 0.35 * (1 + c1), 0, 0)}
        pose["SWORD"] = sw_fn(c1, c2)
        keys.append((f, pose))
    return keys


def walk_sword(c1, c2):  # relaxed carry (reference pose) swinging with the stride
    return sword((-0.01, -0.07 - 0.07 * c1, -0.40 + 0.01 * c2), dirv(f=0.65, d=0.75 - 0.1 * c1, r=0.25),
                 D, (-0.3, 0.6, -0.5))


def run_sword(c1, c2):  # blade trailing low behind, swinging with the stride
    return sword((-0.04, 0.10 - 0.12 * c1, -0.34 + 0.02 * c2), dirv(b=1, d=0.45 - 0.1 * c1, r=0.25),
                 dirv(d=1, b=0.2), (-0.4, 0.7, -0.3))


LOCO = {
    # name: (frames, dist m/cycle, stance, lift, hip, bob, lean, armswing, sway, sword)
    "Walk": (26, 0.80, 0.60, 0.07, -0.085, 0.022, 20, 18, 0.012, walk_sword),
    "Run": (16, 1.45, 0.38, 0.13, -0.10, 0.045, 32, 38, 0.010, run_sword),
}
for _n, (_N, _dist, *_rest) in LOCO.items():
    clip(_n, _N, True, "Movement", gait(_N, _dist, *_rest), events={"Footstep": 0, "Footstep2": _N // 2},
         notes="In place. Native ground speed %.2f m/s." % (_dist / (_N / FPS)), dense=True)
    CLIPS[_n]["speed_mps"] = _dist / (_N / FPS)


# ================================================================== engine
def build_channels(c):
    ch = {}
    for k in c["keys"]:
        f, pose, hold = k[0], k[1], len(k) > 2 and k[2] == "hold"
        for bone, d in pose.items():
            for kind, val in d.items():
                lst = ch.setdefault((bone, kind), [])
                lst[:] = [x for x in lst if x[0] != f]
                lst.append([f, list(val), hold])
    for lst in ch.values():
        lst.sort(key=lambda x: x[0])
    if not c["dense"]:
        for s in ("L", "R"):
            lk = ch[("IK_Foot_" + s, "l")]
            for (fa, la, _), (fb, lb, _) in list(zip(lk, lk[1:])):
                d = math.hypot(la[0] - lb[0], la[1] - lb[1])
                if fb - fa >= 3 and la[2] < 1e-4 and lb[2] < 1e-4 and d > 0.01:
                    mid = [(a + b) / 2 for a, b in zip(la, lb)]
                    mid[2] = min(0.07, max(0.04, 0.4 * d + 0.03))
                    lk.append([fa + max(1, min(4, (fb - fa) // 2)), mid, False])
            for k in lk:
                k[2] = k[2] or k[1][2] < 1e-4  # planted feet ease in/out: no sliding into place
            lk.sort(key=lambda x: x[0])
    return ch


def sample(lst, t, loop, N):
    n = len(lst)
    if n == 1:
        return list(lst[0][1])
    ts = [k[0] for k in lst]
    t = t % N if loop else min(max(t, ts[0]), ts[-1])
    i = max(0, min(n - 2, bisect_right(ts, t) - 1))
    dim = len(lst[0][1])

    def tangent(j):
        if lst[j][2]:
            return [0.0] * dim
        if loop:
            prv = (ts[n - 2] - N, lst[n - 2][1]) if j == 0 else (ts[j - 1], lst[j - 1][1])
            nxt = (ts[1] + N, lst[1][1]) if j == n - 1 else (ts[j + 1], lst[j + 1][1])
        else:
            if j == 0 or j == n - 1:
                return [0.0] * dim
            prv, nxt = (ts[j - 1], lst[j - 1][1]), (ts[j + 1], lst[j + 1][1])
        return [(b - a) / (nxt[0] - prv[0]) for a, b in zip(prv[1], nxt[1])]

    t0, t1 = ts[i], ts[i + 1]
    dt = t1 - t0
    s = (t - t0) / dt
    h00, h10, h01, h11 = 2 * s ** 3 - 3 * s ** 2 + 1, s ** 3 - 2 * s ** 2 + s, -2 * s ** 3 + 3 * s ** 2, s ** 3 - s ** 2
    m0, m1 = tangent(i), tangent(i + 1)
    return [h00 * a + h10 * dt * ma + h01 * b + h11 * dt * mb
            for a, b, ma, mb in zip(lst[i][1], lst[i + 1][1], m0, m1)]


def pose_at(c, ch, t):
    N, loop = c["frames"], c["loop"]
    out = {}
    for (bone, kind), lst in ch.items():
        dl = DELAY.get(bone, 0)
        if not loop:
            dl *= min(1.0, max(0.0, (N - t) / 6))  # settle onto the final pose
        out.setdefault(bone, {})[kind] = sample(lst, t - dl, loop, N)
    if c["extra"]:
        c["extra"](t, out)
    return out


def rest3(rig, b):
    return rig.data.bones[b].matrix_local.to_3x3()


def cols(a, b, c):
    m = Matrix((a, b, c))
    m.transpose()
    return m


def arm_rest(rig):
    bones = rig.data.bones
    A = {n: bones[n].matrix_local.copy() for n in ("RightUpperArm", "RightLowerArm", "RightHand",
                                                   "LowerTorso", "UpperTorso")}
    A["S"] = bones["RightUpperArm"].head_local.copy()
    A["L1"] = (bones["RightLowerArm"].head_local - A["S"]).length
    A["L2"] = (bones["RightHand"].head_local - bones["RightLowerArm"].head_local).length
    A["grip"] = bones["Weapon"].head_local - bones["RightHand"].head_local
    h0, b0 = Vector((0, 0, -1)), Vector((0, -1, 0))
    A["F0"] = cols(h0, b0, h0.cross(b0))
    return A


def solve_arm(sw, A, strict=False):
    """Grip position + blade/edge directions (torso-rest space) -> right arm bone basis matrices."""
    b = Vector(sw["b"]).normalized()
    e = Vector(sw["e"])
    e = e - e.dot(b) * b
    if e.length < 1e-4:
        e = Vector((0, 0, -1)) - b.z * b if abs(b.z) < 0.95 else Vector((0, -1, 0))
    h = e.normalized()
    R = cols(h, b, h.cross(b)) @ A["F0"].transposed()
    S, L1, L2 = A["S"], A["L1"], A["L2"]

    def ik(W, h, lean=0.0):
        d = W - S
        dist = min(max(d.length, abs(L1 - L2) + 1e-3), L1 + L2 - 1e-3)
        dn = d.normalized()
        W = S + dn * dist
        # elbow: the key's own pole, leaning toward where the wrist would be straight by `lean`
        pole = Vector(sw["p"]).normalized() + (W - h * L2 - S).normalized() * lean
        pp = pole - pole.dot(dn) * dn
        pp = pp.normalized() if pp.length > 1e-4 else Vector((-1, 0, 0))
        a = (L1 * L1 - L2 * L2 + dist * dist) / (2 * dist)
        E = S + dn * a + pp * math.sqrt(max(0.0, L1 * L1 - a * a))
        return W, E

    # natural elbow first. Attacks (strict) may then swing the elbow / pull the hand in to keep the blade on
    # target; everything else just turns the wrist (blade) a little, which never contorts the arm.
    done = False
    for k in ((1.0, 0.9, 0.8, 0.72) if strict else (1.0,)):
        for lean in ((0.0, 0.6, 1.5, 4.0) if strict else (0.0,)):
            G = S + Vector(sw["g"]) * k
            W, E = ik(G - R @ A["grip"], h, lean)
            f = (W - E).normalized()
            if math.degrees(f.angle(h)) <= MAX_WRIST:
                done = True
                break
        if done:
            break
    for _ in range(4):  # ease the hand toward the forearm, keep the grip where it was asked
        bend = math.degrees(f.angle(h))
        if bend <= MAX_WRIST + 1:
            break
        q = h.rotation_difference(f)
        q = Quaternion(q.axis, q.angle * (1 - MAX_WRIST / bend))
        R = q.to_matrix() @ R
        h = R @ Vector((0, 0, -1))
        W, E = ik(G - R @ A["grip"], h, lean)
        f = (W - E).normalized()
    u = (E - S).normalized()
    Rf = h.rotation_difference(f).to_matrix() @ R
    Ru = f.rotation_difference(u).to_matrix() @ Rf
    M_ua = Matrix.Translation(S) @ (Ru @ A["RightUpperArm"].to_3x3()).to_4x4()
    M_la = Matrix.Translation(E) @ (Rf @ A["RightLowerArm"].to_3x3()).to_4x4()
    M_h = Matrix.Translation(W) @ (R @ A["RightHand"].to_3x3()).to_4x4()
    return {
        "RightUpperArm": A["RightUpperArm"].inverted() @ M_ua,
        "RightLowerArm": (A["RightUpperArm"].inverted() @ A["RightLowerArm"]).inverted() @ (M_ua.inverted() @ M_la),
        "RightHand": (A["RightLowerArm"].inverted() @ A["RightHand"]).inverted() @ (M_la.inverted() @ M_h),
    }, math.degrees(b.angle(R @ Vector((0, -1, 0))))  # how far the wrist limit turned the blade


def basis_of(rig, bone, d):
    R3 = rest3(rig, bone)
    rot = (R3.inverted() @ Euler([math.radians(a) for a in d.get("r", (0, 0, 0))]).to_matrix() @ R3).to_4x4()
    return Matrix.Translation(R3.inverted() @ Vector(d.get("l", (0, 0, 0)))) @ rot


def to_torso_rest(rig, pose, sw, A):
    """World-axis sword spec -> the torso-rest frame the arm solver works in."""
    lt, ut = A["LowerTorso"], A["UpperTorso"]
    M_lt = lt @ basis_of(rig, "LowerTorso", pose["LowerTorso"])
    M_ut = M_lt @ lt.inverted() @ ut @ basis_of(rig, "UpperTorso", pose["UpperTorso"])
    T3inv = (M_ut @ ut.inverted()).to_3x3().inverted()
    return {k: tuple(T3inv @ Vector(sw[k])) for k in ("g", "b", "e", "p")}


def key_pose(rig, pose, f, A, strict=False):
    for bone, d in pose.items():
        if bone == "SWORD":
            continue
        pb = rig.pose.bones[bone]
        R3 = rest3(rig, bone)
        rot = Euler([math.radians(a) for a in d.get("r", (0, 0, 0))]).to_matrix()
        pb.rotation_quaternion = (R3.inverted() @ rot @ R3).to_quaternion()
        pb.location = R3.inverted() @ Vector(d.get("l", (0, 0, 0)))
        pb.keyframe_insert("rotation_quaternion", frame=f, group=bone)
        pb.keyframe_insert("location", frame=f, group=bone)
    basis, bend = solve_arm(to_torso_rest(rig, pose, pose["SWORD"], A), A, strict)
    for bone, m in basis.items():
        pb = rig.pose.bones[bone]
        pb.rotation_quaternion = m.to_quaternion()
        pb.location = m.translation
        pb.keyframe_insert("rotation_quaternion", frame=f, group=bone)
        pb.keyframe_insert("location", frame=f, group=bone)
    return bend


def fcurves(action):
    try:  # Blender 4.4+ slotted actions
        return [fc for layer in action.layers for strip in layer.strips for bag in strip.channelbags
                for fc in bag.fcurves]
    except AttributeError:
        return list(action.fcurves)


def fwd_angle(v):
    return math.atan2(-v.y, -v.z)


def spring_pass(rig, N, loop):
    scn = bpy.context.scene
    names = [s[0] for s in SPRINGS]
    rec, thighs = {n: [] for n in names}, []
    for f in range(N + 1):
        scn.frame_set(f)
        for n in names:
            pb = rig.pose.bones[n]
            rec[n].append((pb.head.copy(), pb.tail.copy()))
        thighs.append([fwd_angle(rig.pose.bones[x].tail - rig.pose.bones[x].head)
                       for x in ("LeftUpperLeg", "RightUpperLeg")])
    seq = list(range(N)) * 3 if loop else list(range(N + 1))
    out = {}
    for n, k, c, grav in SPRINGS:
        h0, t0 = rec[n][0]
        ln = (t0 - h0).length
        p, v, res = t0.copy(), Vector(), {}
        for f in seq:
            head, tail = rec[n][f]
            d = (tail - head).normalized()
            if grav:
                d = (d * (1 - grav) + Vector((0, 0, -1)) * grav).normalized()
            target = head + d * ln
            for _ in range(4):
                v += ((target - p) * k - v * c) * 0.25
                p = p + v * 0.25
                p = head + (p - head).normalized() * ln
            if n.startswith("Cloth"):  # thighs push the cloth out of the way
                w = p - head
                a = fwd_angle(w)
                lim = max(thighs[f]) + math.radians(6) if n == "Cloth_F" else min(thighs[f]) - math.radians(6)
                if (n == "Cloth_F" and a < lim) or (n == "Cloth_B" and a > lim):
                    r = math.hypot(w.y, w.z)
                    p = head + Vector((w.x, -r * math.sin(lim), -r * math.cos(lim)))
            res[f] = p.copy()
        if loop:
            res[N] = res[0]
        out[n] = res
    for f in range(N + 1):
        scn.frame_set(f)
        for n in names:
            pb = rig.pose.bones[n]
            head, tail = pb.head.copy(), pb.tail.copy()
            q = (tail - head).rotation_difference(out[n][f] - head)
            pb.matrix = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-head) @ pb.matrix
            pb.keyframe_insert("rotation_quaternion", frame=f, group=n)
            pb.keyframe_insert("location", frame=f, group=n)


def lowest(names, dg):
    lo = 9.0
    for n in names:
        ob = bpy.data.objects[n].evaluated_get(dg)
        me = ob.to_mesh()
        lo = min(lo, min((ob.matrix_world @ v.co).z for v in me.vertices))
        ob.to_mesh_clear()
    return lo


def body_floor_guard(rig, N, clearance=0.0):
    """Raise a foot's IK target where its boot would dip below the floor, then raise the hips where the rest of
    the body would."""
    scn = bpy.context.scene
    pb = rig.pose.bones["LowerTorso"]
    Rinv = rest3(rig, "LowerTorso").inverted()
    upper = [m for m in BODY_MESHES if "Foot" not in m]
    n = 0
    for f in range(N + 1):
        scn.frame_set(f)
        moved = False
        for s, S in (("L", "Left"), ("R", "Right")):
            ik = rig.pose.bones["IK_Foot_" + s]
            lo = lowest([S + "Foot_Geo"], bpy.context.evaluated_depsgraph_get())
            if lo < clearance - 1e-4:
                ik.location = ik.location + rest3(rig, ik.name).inverted() @ Vector((0, 0, clearance - lo + 0.001))
                bpy.context.view_layer.update()
                ik.keyframe_insert("location", frame=f, group=ik.name)
                moved = True
        for _ in range(6):
            lo = lowest(upper, bpy.context.evaluated_depsgraph_get())
            if lo >= clearance - 1e-4:
                break
            pb.location = pb.location + Rinv @ Vector((0, 0, clearance - lo + 0.002))
            bpy.context.view_layer.update()
            moved = True
        if moved:
            pb.keyframe_insert("location", frame=f, group="LowerTorso")
            n += 1
    return n


def sword_floor_guard(rig, N, clearance=0.01):
    """Turn the wrist (smallest angle, either way) on frames where the blade would go through the floor."""
    scn = bpy.context.scene
    pts = [v.co.copy() for v in bpy.data.objects["Sword_Geo"].data.vertices]
    hand, wpn = rig.pose.bones["RightHand"], rig.pose.bones["Weapon"]
    winv = rig.data.bones["Weapon"].matrix_local.inverted()
    n = 0
    for f in range(N + 1):
        scn.frame_set(f)
        Mw = wpn.matrix @ winv
        if min((Mw @ p).z for p in pts) >= clearance:
            continue
        wrist = hand.head.copy()
        tip = min((Mw @ p for p in pts), key=lambda v: v.z)
        axis = (tip - wrist).cross(Vector((0, 0, 1)))
        axis = axis.normalized() if axis.length > 1e-6 else Vector((1, 0, 0))
        best = None
        for deg in sorted(range(-150, 151, 3), key=abs):
            Rw = (Matrix.Translation(wrist) @ Quaternion(axis, math.radians(deg)).to_matrix().to_4x4()
                  @ Matrix.Translation(-wrist))
            z = min((Rw @ Mw @ p).z for p in pts)
            if best is None or z > best[0]:
                best = (z, Rw)
            if z >= clearance:
                best = (z, Rw)
                break
        hand.matrix = best[1] @ hand.matrix
        hand.keyframe_insert("rotation_quaternion", frame=f, group="RightHand")
        hand.keyframe_insert("location", frame=f, group="RightHand")
        n += 1
    return n


def build_all(only=None):
    rig = bpy.data.objects[RIG]
    rig.animation_data_create()
    scn = bpy.context.scene
    scn.render.fps = FPS
    A = arm_rest(rig)
    mpath = os.path.join(ROOT, "docs", "animation_manifest.json")
    manifest = {"fps": FPS, "animations": {}}
    if only and os.path.exists(mpath):
        manifest = json.load(open(mpath))
    for name, c in CLIPS.items():
        if only and name not in only:
            continue
        N = c["frames"]
        old = bpy.data.actions.get(name)
        if old:
            bpy.data.actions.remove(old)
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        rig.animation_data.action = act
        if act.slots:
            rig.animation_data.action_slot = act.slots[0]
        for pb in rig.pose.bones:
            pb.location, pb.rotation_quaternion = (0, 0, 0), (1, 0, 0, 0)
        ch = build_channels(c)
        bend = max(key_pose(rig, pose_at(c, ch, f), f, A, c["strict"]) for f in range(N + 1))
        for fc in fcurves(act):
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"
        act.frame_range = (0, N)
        act.use_frame_range = True
        scn.frame_start, scn.frame_end = 0, N
        spring_pass(rig, N, c["loop"])
        nb = body_floor_guard(rig, N)
        ns = sword_floor_guard(rig, N)
        print("  %-12s %3d f  blade off-target %3.0f deg  hip-lift %2d f  wrist-turn %2d f" % (name, N, bend, nb, ns))
        act["loop"] = c["loop"]
        act["priority"] = c["priority"]
        act["events"] = json.dumps(c["events"])
        manifest["animations"][name] = {
            "frames": N, "duration": round(N / FPS, 4), "loop": c["loop"], "priority": c["priority"],
            "events": {e: round(f / FPS, 4) for e, f in sorted(c["events"].items(), key=lambda kv: kv[1])},
            "displacement": c["displacement"], "notes": c["notes"],
        }
        if "speed_mps" in c:
            manifest["animations"][name]["nativeSpeedMps"] = round(c["speed_mps"], 4)
    idle = bpy.data.actions["Idle"]
    rig.animation_data.action = idle
    if idle.slots:
        rig.animation_data.action_slot = idle.slots[0]
    os.makedirs(os.path.dirname(mpath), exist_ok=True)
    with open(mpath, "w") as fh:
        json.dump(manifest, fh, indent=2)
    print("actions:", len(manifest["animations"]))


if __name__ == "__main__":
    build_all()
