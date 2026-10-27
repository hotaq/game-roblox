# Goblin enemy - stage 5b: baked Blender actions -> Roblox KeyframeSequences (no Animation Editor needed).
#   /Applications/Blender.app/Contents/MacOS/Blender -b blender/goblin.blend --python scripts/09_gen_anims.py
# Writes roblox/GoblinAnims.rbxmx: Folder "GoblinAnims" with one KeyframeSequence per EXP_<Name> action (from 05).
# In Studio: right-click ServerStorage > Insert from File... > GoblinAnims.rbxmx. Publish each with right-click >
# Save to Roblox, then paste the IDs into GoblinConfig.Animations.
#
# How: per frame, each deform bone's world-space delta D = Pose @ Rest^-1 (Blender, metres) is converted to Roblox
# model space (x -> -x, z up -> y, y -> z, metres -> studs) and applied to the imported rig's rest CFrames
# (docs/studio_rig_rest.txt, read from Studio). Each joint's Transform is then solved from the parent/child targets:
#   AnimationConstraint: Part1 = Part0 * Att0 * T * Att1^-1      Bone: World = ParentWorld * Bone.CFrame * T
# HumanoidRootPart stays put (Roblox convention); root motion lands on the Root joint.
import bpy, json, os
import numpy as np

ROOT = os.environ.get("GOBLIN_ROOT", "/Users/chinnaphat/Desktop/cedt/roblox/goblin")
REST = os.path.join(ROOT, "docs", "studio_rig_rest.txt")
MANIFEST = os.path.join(ROOT, "docs", "animation_manifest.json")
OUT = os.path.join(ROOT, "roblox", "GoblinAnims.rbxmx")
STUDS = 1 / 0.28
A = np.array([[-1, 0, 0], [0, 0, 1], [0, 1, 0]], float)  # Blender axes -> Roblox model axes
POS_TOL, ROT_TOL = 0.004, np.radians(0.25)  # keyframe reduction: max error vs linear interpolation
PRIORITY = {"Idle": 0, "Movement": 1, "Action": 2}


def cf(v):  # 12 Roblox CFrame components -> 4x4
    m = np.eye(4)
    m[:3, 3] = v[:3]
    m[:3, :3] = np.array(v[3:]).reshape(3, 3)
    return m


def load_rest():
    parts, joints, bones = {}, {}, {}
    for line in open(REST):
        f = line.split()
        if not f or f[0] == "#":
            continue
        if f[0] == "P":
            parts[f[1]] = cf(list(map(float, f[2:14])))
        elif f[0] == "J":
            joints[f[1]] = (f[2], cf(list(map(float, f[3:15]))), cf(list(map(float, f[15:27]))))
        elif f[0] == "B":
            bones[f[1]] = (f[2], cf(list(map(float, f[3:15]))))
    return parts, joints, bones


def to_roblox(d):
    r = np.eye(4)
    r[:3, :3] = A @ d[:3, :3] @ A.T
    r[:3, 3] = A @ d[:3, 3] * STUDS
    return r


def solve(deltas, parts, joints, bones, rest_world):
    """deltas: bone name -> Roblox-space world delta. Returns joint/bone name -> Transform (4x4)."""
    world = {n: deltas[n] @ rest_world[n] for n in rest_world if n in deltas}
    world["HumanoidRootPart"] = rest_world["HumanoidRootPart"]
    inv = np.linalg.inv
    out = {}
    for p1, (p0, a0, a1) in joints.items():
        out[p1] = inv(world[p0] @ a0) @ world[p1] @ a1
    for b, (parent, c) in bones.items():
        out[b] = inv(c) @ inv(world[parent]) @ world[b]
    return out


def rot_angle(a, b):
    r = a[:3, :3].T @ b[:3, :3]
    return np.arccos(np.clip((np.trace(r) - 1) / 2, -1, 1))


def lerp(a, b, t):  # linear position + slerp rotation, matching Roblox's Linear pose easing
    from mathutils import Matrix
    qa, qb = Matrix(a[:3, :3].tolist()).to_quaternion(), Matrix(b[:3, :3].tolist()).to_quaternion()
    m = np.eye(4)
    m[:3, :3] = np.array(qa.slerp(qb, t).to_matrix())
    m[:3, 3] = a[:3, 3] + (b[:3, 3] - a[:3, 3]) * t
    return m


def reduce(frames, must):
    """Keep the frames needed so every track stays within tolerance of linear interpolation (greedy RDP)."""
    keep = {0, len(frames) - 1} | set(must)

    def worst(i, j):
        best, at = 0, None
        for k in range(i + 1, j):
            t = (k - i) / (j - i)
            for n in frames[k]:
                m = lerp(frames[i][n], frames[j][n], t)
                e = max(np.linalg.norm(m[:3, 3] - frames[k][n][:3, 3]) / POS_TOL, rot_angle(m, frames[k][n]) / ROT_TOL)
                if e > best:
                    best, at = e, k
        return best, at

    stack = sorted(keep)
    segs = list(zip(stack, stack[1:]))
    while segs:
        i, j = segs.pop()
        e, k = worst(i, j)
        if e > 1:
            keep.add(k)
            segs += [(i, k), (k, j)]
    return sorted(keep)


# hierarchy for nesting Poses (parent pose -> children)
def tree(joints, bones):
    kids = {}
    for p1, (p0, _, _) in joints.items():
        kids.setdefault(p0, []).append(p1)
    for b, (parent, _) in bones.items():
        kids.setdefault(parent, []).append(b)
    return kids


def xml_cf(m):
    v = [m[0, 3], m[1, 3], m[2, 3]] + list(m[:3, :3].reshape(-1))
    tags = ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
    return "".join("<%s>%.5g</%s>" % (t, 0.0 if abs(x) < 5e-6 else x, t) for t, x in zip(tags, v))


def pose_xml(name, transforms, kids):
    m = transforms.get(name, np.eye(4))
    inner = "".join(pose_xml(k, transforms, kids) for k in kids.get(name, []))
    return ('<Item class="Pose"><Properties><string name="Name">%s</string><CoordinateFrame name="CFrame">%s'
            '</CoordinateFrame><float name="Weight">1</float><token name="EasingStyle">0</token>'
            '<token name="EasingDirection">0</token></Properties>%s</Item>') % (name, xml_cf(m), inner)


def run():
    parts, joints, bones = load_rest()
    rest_world = dict(parts)
    for b in ["Weapon", "Ear_L", "Ear_R", "VFX_Eyes", "VFX_HeadTop", "Cloth_F", "Cloth_B", "VFX_BladeBase", "VFX_BladeTip"]:
        parent, c = bones[b]
        rest_world[b] = rest_world[parent] @ c  # parents listed before children
    kids = tree(joints, bones)
    manifest = json.load(open(MANIFEST))["animations"]
    fps = bpy.context.scene.render.fps

    rig = bpy.data.objects["Goblin_ExportRig"]
    for c in [c for pb in rig.pose.bones for c in pb.constraints]:
        c.mute = True
    rig.animation_data_create()
    rest_inv = {b.name: np.linalg.inv(np.array(b.matrix_local)) for b in rig.data.bones}

    items = []
    for act in sorted((a for a in bpy.data.actions if a.name.startswith("EXP_")), key=lambda a: a.name):
        name = act.name[4:]
        info = manifest[name]
        rig.animation_data.action = act
        if act.slots:
            rig.animation_data.action_slot = act.slots[0]
        f0, f1 = (int(x) for x in act.frame_range)
        frames = []
        for f in range(f0, f1 + 1):
            bpy.context.scene.frame_set(f)
            mw = np.array(rig.matrix_world)
            deltas = {pb.name: to_roblox(mw @ np.array(pb.matrix) @ rest_inv[pb.name]) for pb in rig.pose.bones}
            frames.append(solve(deltas, parts, joints, bones, rest_world))
        events = {round(t * fps): e for e, t in info["events"].items()}
        keep = reduce(frames, [k for k in events if 0 <= k < len(frames)])
        kfs = []
        for k in keep:
            markers = "".join('<Item class="KeyframeMarker"><Properties><string name="Name">%s</string>'
                              '<string name="Value"></string></Properties></Item>' % e
                              for fr, e in events.items() if fr == k)
            kfs.append('<Item class="Keyframe"><Properties><string name="Name">Keyframe</string>'
                       '<float name="Time">%.5g</float></Properties>%s%s</Item>'
                       % (k / fps, pose_xml("HumanoidRootPart", frames[k], kids), markers))
        items.append('<Item class="KeyframeSequence"><Properties><string name="Name">%s</string>'
                     '<bool name="Loop">%s</bool><token name="Priority">%d</token></Properties>%s</Item>'
                     % (name, str(info["loop"]).lower(), PRIORITY[info["priority"]], "".join(kfs)))
        print("anim", name, len(frames), "frames ->", len(keep), "keyframes")

    rig.animation_data.action = None
    for c in [c for pb in rig.pose.bones for c in pb.constraints]:
        c.mute = False
    with open(OUT, "w") as fh:
        fh.write('<roblox version="4"><Item class="Folder"><Properties><string name="Name">GoblinAnims</string>'
                 '</Properties>%s</Item></roblox>' % "".join(items))
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")


if __name__ == "__main__":
    run()
