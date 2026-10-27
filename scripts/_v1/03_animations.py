# Goblin enemy - stage 3: animation set + manifest.
# Run after 02_build_rig.py. Creates one Action per animation on Goblin_Rig (fake user, so they persist)
# and writes docs/animation_manifest.json (single source of truth for durations, loops, priorities, events).
#
# Rotations are authored as degrees about the rig's *rest* axes (X+ = top of bone tilts forward,
# Y+ = top tilts toward goblin's left (+X), Z+ = twists toward goblin's left). Locations in metres,
# same axes (Y- = forward). Legs are driven by IK_Foot_L/R targets (parented to HumanoidRootPart,
# which is never animated: Roblox moves it), so feet stay planted.
import bpy, math, json, os
from mathutils import Euler, Vector

ROOT = os.environ.get("GOBLIN_ROOT", "/Users/chinnaphat/Desktop/cedt/roblox/goblin")
FPS = 30
RIG = "Goblin_Rig"

BASE = {  # hunched, sneaky combat-ready stance
    "LowerTorso": {"l": (0, 0.03, -0.07), "r": (10, 0, 0)},
    "UpperTorso": {"r": (16, 0, 0)},
    "Head": {"r": (-20, 0, 0)},
    "Ear_L": {"r": (0, 6, 0)}, "Ear_R": {"r": (0, -6, 0)},
    "LeftUpperArm": {"r": (-30, -14, 0)}, "LeftLowerArm": {"r": (-25, 0, 0)}, "LeftHand": {"r": (0, 0, 0)},
    "RightUpperArm": {"r": (-36, 12, 0)}, "RightLowerArm": {"r": (-42, 0, 0)}, "RightHand": {"r": (12, 0, 0)},
    "Weapon": {"r": (0, 0, 0)},
    "IK_Foot_L": {"l": (0.03, -0.07, 0), "r": (0, 0, 8)},
    "IK_Foot_R": {"l": (-0.03, 0.06, 0), "r": (0, 0, -8)},
}
BONES = list(BASE)


def P(**over):
    """Full pose = BASE with per-bone channel overrides: P(Head={'r':(..)}, ...). Tuples = rotation."""
    pose = {b: dict(ch) for b, ch in BASE.items()}
    for b, v in over.items():
        pose[b].update(v if isinstance(v, dict) else {"r": v})
    return pose


# ------------------------------------------------------------------ keying
def _rest3(rig, b):
    return rig.data.bones[b].matrix_local.to_3x3()


def apply_pose(rig, pose, frame, bones=None, interp=None):
    for b in bones or pose:
        pb = rig.pose.bones[b]
        R = _rest3(rig, b)
        ch = pose[b]
        rx, ry, rz = (math.radians(a) for a in ch.get("r", (0, 0, 0)))
        qw = Euler((rx, ry, rz), "XYZ").to_matrix()
        pb.rotation_quaternion = (R.inverted() @ qw @ R).to_quaternion()
        pb.location = R.inverted() @ Vector(ch.get("l", (0, 0, 0)))
        pb.keyframe_insert("rotation_quaternion", frame=frame, group=b)
        pb.keyframe_insert("location", frame=frame, group=b)


def fcurves(action):
    try:  # Blender 4.4+ slotted actions
        out = []
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    out.extend(bag.fcurves)
        return out
    except AttributeError:
        return list(action.fcurves)


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def smooth(t):
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ procedural locomotion
def gait(frames, dist, stance, lift, hip, bob, lean, arm, ears, wide=0.035, toe=25):
    """In-place cycle. dist = ground covered per cycle (m); feet slide back at exactly dist/time during stance."""
    travel = stance * dist
    keys = []
    for f in range(frames + 1):
        p = (f % frames) / frames
        pose = P()
        for side, ph0, sx in (("L", 0.0, 1), ("R", 0.5, -1)):
            ph = (p + ph0) % 1
            if ph < stance:
                y, z, pitch = -travel / 2 + travel * ph / stance, 0.0, 0.0
            else:
                t = (ph - stance) / (1 - stance)
                y = travel / 2 - travel * smooth(t)
                z = lift * math.sin(math.pi * t)
                pitch = toe * math.sin(math.pi * t) * (1 - 2 * t)
            pose["IK_Foot_" + side] = {"l": (wide * sx, y, z), "r": (pitch, 0, 6 * sx)}
        c2 = math.cos(4 * math.pi * p)  # two bobs per cycle: low at contact
        c1 = math.cos(2 * math.pi * p)  # +1 when left foot is forward
        pose["LowerTorso"] = {"l": (0, 0.0, hip + bob * (0.5 - 0.5 * c2)), "r": (lean * 0.4, 3 * c1, -6 * c1)}
        pose["UpperTorso"] = {"r": (lean, -2 * c1, 9 * c1)}
        pose["Head"] = {"r": (-lean - 8, 0, -4 * c1)}
        pose["LeftUpperArm"] = {"r": (-34 + arm * c1, -16, 0)}
        pose["LeftLowerArm"] = {"r": (-30 - arm * 0.4 * (1 - c1), 0, 0)}
        pose["RightUpperArm"] = {"r": (-40 - arm * 0.5 * c1, 14, 0)}
        pose["RightLowerArm"] = {"r": (-40, 0, 0)}
        e = ears * abs(math.sin(2 * math.pi * p))
        pose["Ear_L"] = {"r": (0, 6 + e, 0)}
        pose["Ear_R"] = {"r": (0, -6 - e, 0)}
        keys.append((f, pose))
    return keys


# ------------------------------------------------------------------ authored clips
# Each clip: frames, loop, priority, keys [(frame, pose)], events {name: frame}, notes.
# Sword-arm helper poses (right arm = sword arm).
def arm_r(up, lo, hand=(0, 0, 0)):
    return {"RightUpperArm": {"r": up}, "RightLowerArm": {"r": lo}, "RightHand": {"r": hand}}


def arm_l(up, lo, hand=(0, 0, 0)):
    return {"LeftUpperArm": {"r": up}, "LeftLowerArm": {"r": lo}, "LeftHand": {"r": hand}}


def feet(l=None, r=None):
    d = {}
    if l: d["IK_Foot_L"] = {"l": l[0], "r": l[1]}
    if r: d["IK_Foot_R"] = {"l": r[0], "r": r[1]}
    return d


def body(hip=None, hipr=None, chest=None, head=None, earl=None, earr=None):
    d = {}
    if hip is not None or hipr is not None:
        d["LowerTorso"] = {"l": hip or BASE["LowerTorso"]["l"], "r": hipr or BASE["LowerTorso"]["r"]}
    if chest: d["UpperTorso"] = {"r": chest}
    if head: d["Head"] = {"r": head}
    if earl: d["Ear_L"] = {"r": earl}
    if earr: d["Ear_R"] = {"r": earr}
    return d


def Q(*parts):
    over = {}
    for p in parts:
        over.update(p)
    return P(**over)


CLIPS = {}


def clip(name, frames, loop, priority, keys, events=None, notes="", displacement=None):
    CLIPS[name] = dict(frames=frames, loop=loop, priority=priority, keys=keys, events=events or {},
                       notes=notes, displacement=displacement)


# Idle: breathing, a look around, ear twitches. Partial keys ("only") layer ear twitches over breathing.
inhale = Q(body(hip=(0, 0.03, -0.075), chest=(19, 0, 0), head=(-21, 0, 6)),
           arm_l((-32, -16, 0), (-27, 0, 0)), arm_r((-37, 14, 0), (-37, 0, 0)))
clip("Idle", 60, True, "Idle", [
    (0, P()), (30, inhale), (60, P()),
    ("only", 16, {"Ear_L": {"r": (0, 6, 0)}}), ("only", 19, {"Ear_L": {"r": (-10, -16, 0)}}),
    ("only", 22, {"Ear_L": {"r": (0, 8, 0)}}), ("only", 25, {"Ear_L": {"r": (-6, -10, 0)}}),
    ("only", 29, {"Ear_L": {"r": (0, 6, 0)}}),
    ("only", 40, {"Ear_R": {"r": (0, -6, 0)}}), ("only", 43, {"Ear_R": {"r": (-10, 16, 0)}}),
    ("only", 47, {"Ear_R": {"r": (0, -6, 0)}}),
], notes="Breathing + ear flicks. Play 'IdleChatter' sound occasionally from script, not from events.")

clip("Alert", 30, False, "Action", [
    (0, P()),
    (4, Q(body(hip=(0, 0.03, -0.04), chest=(6, 0, 0), head=(-12, 0, 0), earl=(0, -28, 0), earr=(0, 28, 0)),
          arm_l((-20, -30, 0), (-40, 0, 0)), arm_r((-20, 30, 0), (-50, 0, 0)))),
    (10, Q(body(hip=(0, 0.04, -0.10), hipr=(14, 0, 0), chest=(24, 0, 0), head=(-30, 0, 0), earl=(0, -20, 0), earr=(0, 20, 0)),
           arm_l((-45, -20, 0), (-60, 0, 0)), arm_r((-55, 18, 0), (-60, 0, -10)))),
    (18, Q(body(hip=(0, 0.04, -0.09), hipr=(12, 0, 0), chest=(20, 0, 0), head=(-26, 0, 0), earl=(0, -8, 0), earr=(0, 8, 0)),
           arm_l((-40, -18, 0), (-50, 0, 0)), arm_r((-50, 16, 0), (-55, 0, -10)))),
    (30, P()),
], events={"Alert": 3, "Recover": 22}, notes="Startle (ears perk, rises) then drops into a crouch.")

# Attack1: horizontal slash from the goblin's right to left.
clip("Attack1", 30, False, "Action", [
    (0, P()),
    (8, Q(body(hip=(0, 0.05, -0.09), hipr=(10, 0, -18), chest=(12, 0, -28), head=(-18, 0, 30)),
          arm_r((-60, 70, 0), (-50, 0, 0), (0, -20, 0)), arm_l((-50, -10, 0), (-40, 0, 0)),
          feet(r=((-0.05, 0.10, 0), (0, 0, -20))))),
    (11, Q(body(hip=(0, 0.0, -0.10), hipr=(12, 0, 0), chest=(18, 0, 0), head=(-22, 0, 0)),
           arm_r((-85, 30, 0), (-15, 0, 0), (0, 0, 0)), arm_l((-20, -30, 0), (-30, 0, 0)),
           feet(r=((-0.05, 0.10, 0), (0, 0, -20))))),
    (14, Q(body(hip=(0, -0.02, -0.11), hipr=(12, 0, 22), chest=(20, 0, 34), head=(-22, 0, -30)),
           arm_r((-80, -30, 70), (-15, 0, 0), (0, 10, 0)), arm_l((-10, -40, 0), (-20, 0, 0)),
           feet(r=((-0.05, 0.10, 0), (0, 0, -20))))),
    (20, Q(body(hip=(0, -0.01, -0.10), hipr=(12, 0, 18), chest=(20, 0, 26), head=(-22, 0, -22)),
           arm_r((-60, -20, 60), (-30, 0, 0)), arm_l((-15, -35, 0), (-25, 0, 0)))),
    (30, P()),
], events={"Swing": 9, "HitStart": 11, "HitEnd": 15, "Recover": 22})

# Attack2: overhead chop.
clip("Attack2", 34, False, "Action", [
    (0, P()),
    (10, Q(body(hip=(0, 0.06, -0.05), hipr=(-2, 0, 0), chest=(-8, 0, 0), head=(-6, 0, 0), earl=(0, -14, 0), earr=(0, 14, 0)),
           arm_r((-165, 10, 0), (-60, 0, 0), (-20, 0, 0)), arm_l((-60, -20, 0), (-50, 0, 0)),
           feet(l=((0.03, -0.10, 0), (0, 0, 8))))),
    (13, Q(body(hip=(0, 0.0, -0.10), hipr=(14, 0, 0), chest=(22, 0, 0), head=(-26, 0, 0)),
           arm_r((-110, 6, 0), (-10, 0, 0), (0, 0, 0)), arm_l((-20, -25, 0), (-30, 0, 0)),
           feet(l=((0.03, -0.14, 0), (0, 0, 8))))),
    (16, Q(body(hip=(0, -0.02, -0.15), hipr=(22, 0, 0), chest=(34, 0, 0), head=(-36, 0, 0), earl=(0, 18, 0), earr=(0, -18, 0)),
           arm_r((-40, 4, 0), (-10, 0, 0), (10, 0, 0)), arm_l((-5, -30, 0), (-20, 0, 0)),
           feet(l=((0.03, -0.14, 0), (0, 0, 8))))),
    (22, Q(body(hip=(0, -0.02, -0.14), hipr=(20, 0, 0), chest=(30, 0, 0), head=(-32, 0, 0)),
           arm_r((-42, 4, 0), (-14, 0, 0)), arm_l((-10, -28, 0), (-22, 0, 0)),
           feet(l=((0.03, -0.14, 0), (0, 0, 8))))),
    (34, P()),
], events={"Swing": 11, "HitStart": 13, "HitEnd": 17, "Recover": 24})

# Attack3: stepping thrust.
clip("Attack3", 28, False, "Action", [
    (0, P()),
    (7, Q(body(hip=(0, 0.07, -0.09), hipr=(8, 0, -14), chest=(12, 0, -24), head=(-16, 0, 24)),
          arm_r((10, 25, 0), (-100, 0, 0), (-10, 0, 0)), arm_l((-60, -10, 0), (-40, 0, 0)))),
    (10, Q(body(hip=(0, -0.06, -0.12), hipr=(16, 0, 14), chest=(24, 0, 22), head=(-30, 0, -20)),
           arm_r((-95, 4, 0), (-5, 0, 0), (0, 0, 0)), arm_l((-10, -30, 0), (-20, 0, 0)),
           feet(r=((-0.04, -0.16, 0), (0, 0, -6)), l=((0.04, 0.10, 0), (0, 0, 10))))),
    (16, Q(body(hip=(0, -0.05, -0.12), hipr=(14, 0, 12), chest=(22, 0, 18), head=(-28, 0, -16)),
           arm_r((-88, 6, 0), (-12, 0, 0)), arm_l((-15, -28, 0), (-22, 0, 0)),
           feet(r=((-0.04, -0.16, 0), (0, 0, -6)), l=((0.04, 0.10, 0), (0, 0, 10))))),
    (28, P()),
], events={"Swing": 8, "HitStart": 9, "HitEnd": 13, "Footstep": 10, "Recover": 18})

# Heavy: long two-stage windup with a shake (telegraph), ground slam.
wind = Q(body(hip=(0, 0.08, -0.04), hipr=(-6, 0, -10), chest=(-14, 0, -20), head=(-2, 0, 16), earl=(0, -24, 0), earr=(0, 24, 0)),
         arm_r((-175, 30, 0), (-70, 0, 0), (-30, 0, 0)), arm_l((-140, -30, 0), (-40, 0, 0)),
         feet(l=((0.05, -0.10, 0), (0, 0, 12)), r=((-0.05, 0.10, 0), (0, 0, -12))))
wind2 = Q(body(hip=(0, 0.09, -0.03), hipr=(-8, 0, -12), chest=(-18, 0, -22), head=(-2, 0, 18), earl=(0, -26, 0), earr=(0, 26, 0)),
          arm_r((-180, 34, 0), (-75, 0, 0), (-34, 0, 0)), arm_l((-145, -32, 0), (-42, 0, 0)),
          feet(l=((0.05, -0.10, 0), (0, 0, 12)), r=((-0.05, 0.10, 0), (0, 0, -12))))
slam = Q(body(hip=(0, -0.04, -0.20), hipr=(28, 0, 6), chest=(40, 0, 8), head=(-40, 0, 0), earl=(0, 22, 0), earr=(0, -22, 0)),
         arm_r((-30, 6, 0), (-6, 0, 0), (14, 0, 0)), arm_l((-20, -20, 0), (-20, 0, 0)),
         feet(l=((0.06, -0.18, 0), (0, 0, 12)), r=((-0.05, 0.12, 0), (0, 0, -12))))
clip("HeavyAttack", 60, False, "Action", [
    (0, P()), (14, wind), (18, wind2), (21, wind), (24, wind2), (27, wind), (30, wind2), (34, slam), (44, slam), (60, P()),
], events={"Telegraph": 4, "Swing": 31, "HitStart": 33, "HitEnd": 37, "Impact": 34, "Recover": 46},
   notes="Windup shake frames 14-30 = telegraph window (1 s before the hit).")

# Lunge: crouch, leap (root displaced by script), stab, land, recover.
clip("LungeAttack", 40, False, "Action", [
    (0, P()),
    (9, Q(body(hip=(0, 0.08, -0.17), hipr=(24, 0, 0), chest=(30, 0, 0), head=(-38, 0, 0), earl=(0, 24, 0), earr=(0, -24, 0)),
          arm_r((10, 20, 0), (-90, 0, 0), (-10, 0, 0)), arm_l((20, -30, 0), (-30, 0, 0)),
          feet(l=((0.05, 0.02, 0), (0, 0, 10)), r=((-0.05, 0.08, 0), (0, 0, -10))))),
    (13, Q(body(hip=(0, -0.04, 0.02), hipr=(30, 0, 8), chest=(30, 0, 12), head=(-40, 0, -8), earl=(0, 30, 0), earr=(0, -30, 0)),
           arm_r((-90, 6, 0), (-8, 0, 0)), arm_l((30, -40, 0), (-20, 0, 0)),
           feet(l=((0.05, 0.12, 0.10), (30, 0, 10)), r=((-0.05, -0.12, 0.14), (-10, 0, -10))))),
    (18, Q(body(hip=(0, -0.06, -0.10), hipr=(22, 0, 10), chest=(26, 0, 14), head=(-34, 0, -10)),
           arm_r((-92, 4, 0), (-4, 0, 0)), arm_l((20, -40, 0), (-20, 0, 0)),
           feet(l=((0.05, 0.14, 0.0), (0, 0, 10)), r=((-0.05, -0.18, 0.0), (0, 0, -10))))),
    (24, Q(body(hip=(0, -0.04, -0.13), hipr=(20, 0, 8), chest=(24, 0, 10), head=(-30, 0, -6)),
           arm_r((-70, 10, 0), (-20, 0, 0)), arm_l((0, -30, 0), (-25, 0, 0)),
           feet(l=((0.05, 0.14, 0.0), (0, 0, 10)), r=((-0.05, -0.18, 0.0), (0, 0, -10))))),
    (40, P()),
], events={"LungeStart": 10, "Swing": 12, "HitStart": 14, "HitEnd": 21, "Footstep": 18, "Recover": 28},
   displacement="Move HumanoidRootPart forward ~10 studs between LungeStart (0.33 s) and 0.62 s.")

# Hit reactions (Action priority so they override locomotion but not each other).
def hit(name, hipr, chest, head, hip, arms_out):
    clip(name, 18, False, "Action", [
        (0, P()),
        (3, Q(body(hip=hip, hipr=hipr, chest=chest, head=head, earl=(0, -24, 0), earr=(0, 24, 0)),
              arm_l((-10, -14 - arms_out, 0), (-15, 0, 0)), arm_r((-15, 12 + arms_out, 0), (-20, 0, 0)))),
        (7, Q(body(hip=hip, hipr=tuple(a * 0.6 for a in hipr), chest=tuple(a * 0.6 for a in chest),
                   head=tuple(a * 0.6 for a in head)))),
        (18, P()),
    ], events={"Recover": 12})


hit("HitFront", (-4, 0, 0), (-18, 0, 0), (-30, 0, 0), (0, 0.06, -0.06), 14)
hit("HitLeft", (6, -8, -14), (10, -16, -22), (-12, -20, -16), (-0.04, 0.03, -0.07), 10)  # struck on its left side
hit("HitRight", (6, 8, 14), (10, 16, 22), (-12, 20, 16), (0.04, 0.03, -0.07), 10)

# Stun: dizzy wobble loop, sword drooping.
def daze(a):
    s, c = math.sin(a), math.cos(a)
    return Q(body(hip=(0.015 * s, 0.03, -0.11), hipr=(14, 5 * c, 0), chest=(28 + 4 * s, 7 * c, 4 * s),
                  head=(-6 + 6 * c, 10 * s, 6 * c), earl=(14, 24, 0), earr=(14, -24, 0)),
             arm_l((-5, -12, 0), (-10, 0, 0)), arm_r((-8, 10, 0), (-12, 0, 0), (30, 0, 0)))
clip("Stun", 48, True, "Action", [(f, daze(2 * math.pi * f / 48)) for f in range(0, 49, 6)],
     events={"StunStars": 0}, notes="Loop while stunned; stop with fade 0.15.")

# Knockback: flung back (script pushes root), scrambling steps, recover.
clip("Knockback", 45, False, "Action", [
    (0, P()),
    (4, Q(body(hip=(0, 0.10, -0.06), hipr=(-12, 0, 0), chest=(-20, 0, 0), head=(-34, 0, 0), earl=(0, -30, 0), earr=(0, 30, 0)),
          arm_l((-60, -50, 0), (-20, 0, 0)), arm_r((-70, 50, 0), (-20, 0, 0)),
          feet(l=((0.04, 0.0, 0.08), (-10, 0, 8)), r=((-0.04, 0.06, 0.0), (0, 0, -8))))),
    (10, Q(body(hip=(0, 0.06, -0.12), hipr=(0, 0, 0), chest=(4, 0, 0), head=(-20, 0, 0)),
           arm_l((-50, -40, 0), (-30, 0, 0)), arm_r((-60, 40, 0), (-30, 0, 0)),
           feet(l=((0.04, 0.16, 0.0), (0, 0, 8)), r=((-0.04, 0.02, 0.06), (-10, 0, -8))))),
    (16, Q(body(hip=(0, 0.04, -0.13), hipr=(16, 0, 0), chest=(24, 0, 0), head=(-30, 0, 0)),
           arm_l((-40, -30, 0), (-40, 0, 0)), arm_r((-45, 25, 0), (-40, 0, 0)),
           feet(l=((0.04, 0.12, 0.0), (0, 0, 8)), r=((-0.04, 0.14, 0.0), (0, 0, -8))))),
    (28, Q(body(hip=(0, 0.04, -0.12), hipr=(14, 0, 0), chest=(22, 0, 0), head=(-26, 0, 0)),
           feet(l=((0.04, 0.02, 0.0), (0, 0, 8)), r=((-0.04, 0.10, 0.0), (0, 0, -8))))),
    (45, P()),
], events={"Footstep": 10, "Footstep2": 16, "Recover": 30},
   displacement="Push HumanoidRootPart back ~8 studs over 0-0.35 s (server ApplyImpulse / LinearVelocity).")

# Death: stagger, knees, fall face-down (head turned so nose/ears clear the floor). Holds last frame.
def dead(k):
    return Q(body(hip=(0, -0.30, -0.40 - 0.01 * k), hipr=(84 + 2 * k, 0, 4), chest=(2, 0, 0), head=(-50, 0, 28 + 3 * k),
                  earl=(-30, 10, 0), earr=(-30, -10, 0)),
             arm_l((-150 - 4 * k, -28, 0), (-8, 0, 0)), arm_r((-140 - 3 * k, 34, 0), (-6, 0, 0), (0, 0, 0)),
             feet(l=((0.06, 0.14, 0.07), (88, 0, 8)), r=((-0.06, 0.15, 0.07), (88, 0, -8))))


DEAD_A, DEAD_B = dead(0), dead(1)
clip("Death", 60, False, "Action", [
    (0, P()),
    (6, Q(body(hip=(0, 0.08, -0.06), hipr=(-10, 0, 0), chest=(-16, 0, 0), head=(-30, 0, 0), earl=(0, -30, 0), earr=(0, 30, 0)),
          arm_l((-40, -40, 0), (-20, 0, 0)), arm_r((-50, 40, 0), (-20, 0, 0)))),
    (18, Q(body(hip=(0, 0.02, -0.30), hipr=(6, 0, 4), chest=(10, 0, 4), head=(10, 0, 0), earl=(0, 20, 0), earr=(0, -20, 0)),
           arm_l((-10, -10, 0), (-10, 0, 0)), arm_r((-10, 10, 0), (-10, 0, 0), (30, 0, 0)),
           feet(l=((0.05, 0.02, 0.0), (0, 0, 8)), r=((-0.05, 0.08, 0.0), (0, 0, -8))))),
    (28, Q(body(hip=(0, -0.10, -0.36), hipr=(50, 0, 6), chest=(30, 0, 4), head=(10, 0, 10), earl=(10, 30, 0), earr=(10, -30, 0)),
           arm_l((-80, -20, 0), (-20, 0, 0)), arm_r((-70, 30, 0), (-20, 0, 0), (40, 0, 0)),
           feet(l=((0.05, 0.10, 0.095), (40, 0, 8)), r=((-0.05, 0.14, 0.095), (40, 0, -8))))),
    (36, DEAD_A),
    (60, DEAD_B),
], events={"Death": 0, "BodyFall": 34, "Dissolve": 45}, notes="Freeze on last frame (track:AdjustSpeed(0) near end).")

# Turns: upper body leads, feet re-step. Script rotates the root 90 deg over the clip.
def turn(name, s):
    clip(name, 24, False, "Movement", [
        (0, P()),
        (6, Q(body(hipr=(10, 0, 10 * s), chest=(16, 0, 18 * s), head=(-20, 0, 24 * s)),
              feet(l=((0.03, -0.07, 0.07), (0, 0, 8 + 20 * s)) if s > 0 else None))),
        (10, Q(body(hipr=(10, 0, 12 * s), chest=(16, 0, 18 * s), head=(-20, 0, 20 * s)),
               feet(l=((0.03, -0.07, 0.0), (0, 0, 8)), r=((-0.03, 0.06, 0.07), (0, 0, -8 + 20 * s))))),
        (16, Q(body(hipr=(10, 0, 6 * s), chest=(16, 0, 8 * s), head=(-20, 0, 8 * s)),
               feet(r=((-0.03, 0.06, 0.0), (0, 0, -8))))),
        (24, P()),
    ], events={"Footstep": 9, "Footstep2": 16},
       displacement="Rotate HumanoidRootPart 90 deg (%s) over the clip." % ("left" if s > 0 else "right"))


turn("TurnLeft", 1)
turn("TurnRight", -1)

# Jump / Fall / Land (Humanoid Jumping/Freefall/Landed states).
tuck = Q(body(hip=(0, 0.02, -0.02), hipr=(6, 0, 0), chest=(12, 0, 0), head=(-14, 0, 0), earl=(0, -20, 0), earr=(0, 20, 0)),
         arm_l((-60, -40, 0), (-40, 0, 0)), arm_r((-60, 40, 0), (-40, 0, 0)),
         feet(l=((0.04, 0.0, 0.14), (-14, 0, 8)), r=((-0.04, 0.06, 0.10), (-6, 0, -8))))
clip("Jump", 10, False, "Movement", [
    (0, Q(body(hip=(0, 0.04, -0.14), hipr=(18, 0, 0), chest=(22, 0, 0)))),
    (4, Q(body(hip=(0, 0.0, 0.0), hipr=(4, 0, 0), chest=(8, 0, 0), earl=(0, -24, 0), earr=(0, 24, 0)),
          arm_l((-90, -40, 0), (-20, 0, 0)), arm_r((-80, 40, 0), (-20, 0, 0)),
          feet(l=((0.03, 0.02, 0.07), (20, 0, 8)), r=((-0.03, 0.08, 0.07), (20, 0, -8))))),
    (10, tuck),
], events={"Jump": 2})
tuck2 = Q(body(hip=(0, 0.02, -0.02), hipr=(6, 0, 0), chest=(12, 0, 0), head=(-14, 0, 0), earl=(0, -10, 0), earr=(0, 10, 0)),
          arm_l((-70, -46, 0), (-40, 0, 0)), arm_r((-66, 46, 0), (-40, 0, 0)),
          feet(l=((0.04, 0.0, 0.12), (-14, 0, 8)), r=((-0.04, 0.06, 0.12), (-6, 0, -8))))
clip("Fall", 20, True, "Movement", [(0, tuck), (10, tuck2), (20, tuck)])
clip("Land", 12, False, "Movement", [
    (0, tuck),
    (3, Q(body(hip=(0, 0.04, -0.18), hipr=(22, 0, 0), chest=(28, 0, 0), head=(-30, 0, 0), earl=(0, 20, 0), earr=(0, -20, 0)),
          arm_l((-40, -30, 0), (-40, 0, 0)), arm_r((-40, 30, 0), (-40, 0, 0)))),
    (12, P()),
], events={"Footstep": 1})

LOCO = {
    # name: (frames, dist m/cycle, stance, lift, hip, bob, lean, arm, ears)
    "Walk": (24, 0.90, 0.58, 0.09, -0.11, 0.03, 20, 20, 8),
    "Run": (14, 1.40, 0.38, 0.15, -0.12, 0.05, 30, 32, 14),
}


def auto_steps(keys):
    """A planted foot that changes place between two keys would slide: insert a lifted step at the midpoint."""
    full = sorted((k for k in keys if isinstance(k[0], int)), key=lambda k: k[0])
    extra = []
    for (fa, pa), (fb, pb) in zip(full, full[1:]):
        if fb - fa < 2:
            continue
        for ik in ("IK_Foot_L", "IK_Foot_R"):
            la, lb = Vector(pa[ik]["l"]), Vector(pb[ik]["l"])
            d = (la.xy - lb.xy).length
            if la.z < 1e-4 and lb.z < 1e-4 and d > 0.01:
                mid = (la + lb) / 2
                mid.z = min(0.08, max(0.04, 0.4 * d + 0.03))
                rot = mix(pa[ik].get("r", (0, 0, 0)), pb[ik].get("r", (0, 0, 0)), 0.5)
                # step happens early in the interval so the foot is down before the next key
                fm = fa + max(1, min(4, (fb - fa) // 2))
                extra.append(("only", fm, {ik: {"l": tuple(mid), "r": rot}}))
    return keys + extra


def sword_floor_guard(rig, act, f0, f1, clearance=0.01):
    """Per frame, pivot the Weapon bone about the grip (a wrist turn) just enough to keep the blade above the
    floor. Sword verts are 100% Weapon-weighted, so their height is computed directly from the bone matrix."""
    from mathutils import Matrix, Quaternion
    sw = bpy.data.objects["Goblin_Sword"]
    pts = [v.co.copy() for v in sw.data.vertices]
    pb = rig.pose.bones["Weapon"]
    binv = rig.data.bones["Weapon"].matrix_local.inverted()
    scn = bpy.context.scene
    fixes = {}
    for f in range(f0, f1 + 1):
        scn.frame_set(f)
        M = pb.matrix.copy()

        def lowest(m):
            return min((m @ binv @ p).z for p in pts)

        if lowest(M) >= clearance:
            continue
        grip = M.translation.copy()
        tip = min((M @ binv @ p for p in pts), key=lambda v: v.z)
        axis = (tip - grip).cross(Vector((0, 0, 1)))
        if axis.length < 1e-6:
            axis = Vector((1, 0, 0))
        axis.normalize()
        # smallest wrist turn (either way) that clears the floor; if none does, the best available
        best = None
        for deg in sorted(range(-150, 151, 4), key=abs):
            R = Matrix.Translation(grip) @ Quaternion(axis, math.radians(deg)).to_matrix().to_4x4() @ Matrix.Translation(-grip)
            z = lowest(R @ M)
            if z >= clearance:
                best = R @ M
                break
            if best is None or z > best[0]:
                best = (z, R @ M)
        fixes[f] = best if not isinstance(best, tuple) else best[1]
    if not fixes:
        return 0
    # rewrite Weapon keys densely over the clip so corrected frames blend with untouched ones
    rest = {}
    for f in range(f0, f1 + 1):
        scn.frame_set(f)
        rest[f] = pb.matrix.copy()
    for fc in [fc for fc in fcurves(act) if 'pose.bones["Weapon"]' in fc.data_path]:
        fc.keyframe_points.clear()
    for f in range(f0, f1 + 1):
        scn.frame_set(f)
        pb.matrix = fixes.get(f, rest[f])
        bpy.context.view_layer.update()
        pb.keyframe_insert("rotation_quaternion", frame=f, group="Weapon")
        pb.keyframe_insert("location", frame=f, group="Weapon")
    return len(fixes)


def body_floor_guard(rig, act, f0, f1, clearance=0.0):
    """Raise the hips on any frame where body/armor dips below the floor (feet stay on their IK targets)."""
    scn = bpy.context.scene
    pb = rig.pose.bones["LowerTorso"]
    R = _rest3(rig, "LowerTorso")
    lift = {}
    for f in range(f0, f1 + 1):
        scn.frame_set(f)
        total = 0.0
        for _ in range(3):
            dg = bpy.context.evaluated_depsgraph_get()
            lo = 9.0
            for n in ("Goblin_Body", "Goblin_Armor"):
                ob = bpy.data.objects[n].evaluated_get(dg)
                me = ob.to_mesh()
                lo = min(lo, min((ob.matrix_world @ v.co).z for v in me.vertices))
                ob.to_mesh_clear()
            if lo >= clearance - 1e-4:
                break
            d = clearance - lo + 0.002
            total += d
            pb.location = pb.location + R.inverted() @ Vector((0, 0, d))
            bpy.context.view_layer.update()
        if total:
            lift[f] = total
    if not lift:
        return 0
    base = {}
    for f in range(f0, f1 + 1):
        scn.frame_set(f)
        base[f] = pb.location.copy()
    for fc in [fc for fc in fcurves(act) if fc.data_path == 'pose.bones["LowerTorso"].location']:
        fc.keyframe_points.clear()
    for f in range(f0, f1 + 1):
        pb.location = base[f] + R.inverted() @ Vector((0, 0, lift.get(f, 0.0)))
        pb.keyframe_insert("location", frame=f, group="LowerTorso")
    return len(lift)


def build_all():
    rig = bpy.data.objects[RIG]
    rig.animation_data_create()
    scn = bpy.context.scene
    scn.render.fps = FPS
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    manifest = {"fps": FPS, "studsPerMeter": None, "animations": {}}

    for name, (frames, dist, stance, lift, hip, bob, lean, arm, ears) in LOCO.items():
        footsteps = {"Footstep": 0, "Footstep2": frames // 2}
        clip(name, frames, True, "Movement", [("loco", gait(frames, dist, stance, lift, hip, bob, lean, arm, ears))],
             events=footsteps, notes="In place. Native ground speed %.2f m/s." % (dist / (frames / FPS)))
        CLIPS[name]["speed_mps"] = dist / (frames / FPS)

    for name, c in CLIPS.items():
        old = bpy.data.actions.get(name)
        if old:
            bpy.data.actions.remove(old)
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        rig.animation_data.action = act
        for pb in rig.pose.bones:
            pb.location = (0, 0, 0)
            pb.rotation_quaternion = (1, 0, 0, 0)
        for k in auto_steps(c["keys"]):
            if k[0] == "loco":
                for f, pose in k[1]:
                    apply_pose(rig, pose, f)
            elif k[0] == "only":
                _, f, part = k
                full = P(**part)
                apply_pose(rig, full, f, bones=list(part))
            else:
                apply_pose(rig, k[1], k[0])
        linear = any(k[0] == "loco" for k in c["keys"])
        for fc in fcurves(act):
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR" if linear else "BEZIER"
                if not linear:
                    kp.handle_left_type = kp.handle_right_type = "AUTO_CLAMPED"
            if c["loop"]:
                fc.modifiers.new("CYCLES") if not fc.modifiers else None
        act.frame_range = (0, c["frames"])
        act.use_frame_range = True
        n = body_floor_guard(rig, act, 0, c["frames"])
        if n:
            print("  %s: body floor guard on %d frames" % (name, n))
        n = sword_floor_guard(rig, act, 0, c["frames"])
        if n:
            print("  %s: sword floor guard on %d frames" % (name, n))
        act["loop"] = c["loop"]
        act["priority"] = c["priority"]
        act["events"] = json.dumps(c["events"])
        manifest["animations"][name] = {
            "frames": c["frames"], "duration": round(c["frames"] / FPS, 4), "loop": c["loop"],
            "priority": c["priority"],
            "events": {e: round(f / FPS, 4) for e, f in sorted(c["events"].items(), key=lambda kv: kv[1])},
            "displacement": c["displacement"], "notes": c["notes"],
        }
        if "speed_mps" in c:
            manifest["animations"][name]["nativeSpeedMps"] = round(c["speed_mps"], 4)
    rig.animation_data.action = bpy.data.actions["Idle"]
    os.makedirs(os.path.join(ROOT, "docs"), exist_ok=True)
    with open(os.path.join(ROOT, "docs", "animation_manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=2)
    print("actions:", list(CLIPS))


if __name__ == "__main__":
    build_all()
