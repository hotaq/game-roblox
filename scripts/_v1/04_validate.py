# Goblin enemy - stage 4: animation QA. Prints per-action: lowest mesh point (floor penetration),
# worst IK foot error (overextension = sliding), loop seam error, and stance-foot slip for Walk/Run.
import bpy, json
from mathutils import Vector

MESHES = ("Goblin_Body", "Goblin_Armor", "Goblin_Sword")


def min_z(dg, names):
    lo = 9.0
    for n in names:
        ob = bpy.data.objects[n].evaluated_get(dg)
        me = ob.to_mesh()
        mw = ob.matrix_world
        lo = min(lo, min((mw @ v.co).z for v in me.vertices))
        ob.to_mesh_clear()
    return lo


def pose_vec(rig):
    return [c for pb in rig.pose.bones for c in (*pb.matrix.translation, *pb.matrix.to_quaternion())]


def check(name, rig, scn):
    act = bpy.data.actions[name]
    rig.animation_data.action = act
    if act.slots:
        rig.animation_data.action_slot = act.slots[0]
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    lo, lo_sw, lo_f, ik_err, slip = 9.0, 9.0, 0, 0.0, 0.0
    prev = {}
    for f in range(f0, f1 + 1):
        scn.frame_set(f)
        dg = bpy.context.evaluated_depsgraph_get()
        z = min_z(dg, MESHES[:2])
        if z < lo:
            lo, lo_f = z, f
        lo_sw = min(lo_sw, min_z(dg, MESHES[2:]))
        for s in ("L", "R"):
            foot = rig.pose.bones[("Left" if s == "L" else "Right") + "Foot"].head
            tgt = rig.pose.bones["IK_Foot_" + s].head
            ik_err = max(ik_err, (foot - tgt).length)
            # slip: stance foot (on the ground) should move at constant speed (in-place) or not at all
            if tgt.z < 0.131 and s in prev and prev[s].z < 0.131:
                v = (tgt - prev[s]).length
                if name not in ("Walk", "Run"):
                    slip = max(slip, v)  # planted foot must not move at all
                else:
                    prev_v = prev.get(s + "v")
                    if prev_v is not None:
                        slip = max(slip, abs(v - prev_v))  # in-place: constant belt speed
                    prev[s + "v"] = v
            else:
                prev.pop(s + "v", None)
            prev[s] = tgt.copy()
    scn.frame_set(f0); a = pose_vec(rig)
    scn.frame_set(f1); b = pose_vec(rig)
    seam = max(abs(x - y) for x, y in zip(a, b))
    return dict(minZ=round(lo, 3), atFrame=lo_f, swordMinZ=round(lo_sw, 3), ikErr=round(ik_err, 4), slipAccel=round(slip, 4),
                seam=round(seam, 4) if act.get("loop") else None)


def run():
    rig = bpy.data.objects["Goblin_Rig"]
    scn = bpy.context.scene
    keep = rig.animation_data.action
    out = {}
    for act in bpy.data.actions:
        if "loop" in act:
            out[act.name] = check(act.name, rig, scn)
            print(act.name, out[act.name])
    rig.animation_data.action = keep
    return out


if __name__ == "__main__":
    run()
