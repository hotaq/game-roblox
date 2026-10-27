# Goblin enemy - stage 4: animation QA. Per action: lowest body point (floor penetration), lowest sword point,
# worst IK reach error (overextension), planted-foot slip (in-place loops: belt-speed jitter), loop seam error.
import bpy

BODY = [n + "_Geo" for n in (
    "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
    "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg",
    "RightLowerLeg", "RightFoot")]


def min_z(dg, names):
    lo = 9.0
    for n in names:
        ob = bpy.data.objects[n].evaluated_get(dg)
        me = ob.to_mesh()
        lo = min(lo, min((ob.matrix_world @ v.co).z for v in me.vertices))
        ob.to_mesh_clear()
    return lo


def pose_vec(rig):
    return [c for pb in rig.pose.bones for c in (*pb.matrix.translation, *pb.matrix.to_quaternion())]


def check(name, rig, scn):
    act = bpy.data.actions[name]
    rig.animation_data.action = act
    if act.slots:
        rig.animation_data.action_slot = act.slots[0]
    f0, f1 = (int(x) for x in act.frame_range)
    lo, lo_f, lo_sw, ik_err, slip = 9.0, 0, 9.0, 0.0, 0.0
    prev = {}
    for f in range(f0, f1 + 1):
        scn.frame_set(f)
        dg = bpy.context.evaluated_depsgraph_get()
        z = min_z(dg, BODY)
        if z < lo:
            lo, lo_f = z, f
        lo_sw = min(lo_sw, min_z(dg, ["Sword_Geo"]))
        for s, S in (("L", "Left"), ("R", "Right")):
            foot = rig.pose.bones[S + "Foot"].head
            tgt = rig.pose.bones["IK_Foot_" + s].head
            ik_err = max(ik_err, (foot - tgt).length)
            planted = tgt.z < 0.1126 + 1e-4  # ankle height at rest
            if planted and s in prev and prev[s][1]:
                v = (tgt - prev[s][0]).length
                if name in ("Walk", "Run"):
                    if s + "v" in prev:
                        slip = max(slip, abs(v - prev[s + "v"]))
                    prev[s + "v"] = v
                else:
                    slip = max(slip, v)
            else:
                prev.pop(s + "v", None)
            prev[s] = (tgt.copy(), planted)
    scn.frame_set(f0)
    a = pose_vec(rig)
    scn.frame_set(f1)
    b = pose_vec(rig)
    seam = max(abs(x - y) for x, y in zip(a, b))
    return dict(bodyMinZ=round(lo, 3), atFrame=lo_f, swordMinZ=round(lo_sw, 3), ikErr=round(ik_err, 4),
                slip=round(slip, 4), seam=round(seam, 4) if act.get("loop") else None)


def run():
    rig = bpy.data.objects["Goblin_Rig"]
    scn = bpy.context.scene
    keep = rig.animation_data.action
    out = {}
    for act in bpy.data.actions:
        if "loop" in act and not act.name.startswith("EXP_"):
            out[act.name] = check(act.name, rig, scn)
            print(act.name, out[act.name])
    rig.animation_data.action = keep
    if keep and keep.slots:
        rig.animation_data.action_slot = keep.slots[0]
    return out


if __name__ == "__main__":
    run()
