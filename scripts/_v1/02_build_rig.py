# Goblin enemy - stage 2: R15-named deform rig + separate IK controls + skin weights.
# Run after 01_build_model.py in the same Blender session/file.
#
# Rig choice: one skinned mesh set on a custom armature whose deform bones use the R15 names and
# hierarchy (HumanoidRootPart > LowerTorso > UpperTorso > Head ...). Roblox imports it as skinned
# MeshParts + Bones driven by an Animator, R15-style animation curves map 1:1 by bone name, and a
# Humanoid still handles movement/pathfinding through HumanoidRootPart. Extra deform bones:
# Ear_L/Ear_R (ear flicks) and Weapon (sword grip, child of RightHand).
import bpy, math
from mathutils import Vector, Matrix

RIG = "Goblin_Rig"
L, R = 1, -1  # goblin's left is +X, right is -X (front = -Y)

# name: (head, tail, parent, deform)
def side(s, n):
    return ("Left" if s == L else "Right") + n


BONES = {"HumanoidRootPart": ((0, 0, 0.0), (0, 0, 0.30), None, True)}
BONES.update({
    "LowerTorso": ((0, 0, 0.62), (0, 0, 0.76), "HumanoidRootPart", True),
    "UpperTorso": ((0, 0, 0.76), (0, 0, 1.05), "LowerTorso", True),
    "Head": ((0, 0, 1.06), (0, 0, 1.42), "UpperTorso", True),
})
for s in (L, R):
    x = 0.34 * s
    BONES.update({
        side(s, "UpperArm"): ((x, 0, 0.99), (x, 0.0, 0.79), "UpperTorso", True),
        side(s, "LowerArm"): ((x, 0.0, 0.79), (x, 0, 0.61), side(s, "UpperArm"), True),
        side(s, "Hand"): ((x, 0, 0.61), (x, 0, 0.49), side(s, "LowerArm"), True),
        side(s, "UpperLeg"): ((0.12 * s, 0, 0.60), (0.12 * s, -0.015, 0.37), "LowerTorso", True),
        side(s, "LowerLeg"): ((0.12 * s, -0.015, 0.37), (0.12 * s, 0, 0.13), side(s, "UpperLeg"), True),
        side(s, "Foot"): ((0.12 * s, 0, 0.13), (0.12 * s, -0.17, 0.05), side(s, "LowerLeg"), True),
        ("Ear_L" if s == L else "Ear_R"): ((0.17 * s, 0.023, 1.346), (0.607 * s, 0.023, 1.665), "Head", True),
        # --- animation controls (non-deform, not exported) ---
        ("IK_Foot_L" if s == L else "IK_Foot_R"): ((0.12 * s, 0, 0.13), (0.12 * s, -0.17, 0.05), "HumanoidRootPart", False),
        ("Pole_Knee_L" if s == L else "Pole_Knee_R"): ((0.12 * s, -0.5, 0.37), (0.12 * s, -0.6, 0.37), "HumanoidRootPart", False),
    })


def clamp01(v):
    return max(0.0, min(1.0, v))


def ramp(z, z0, w):
    """0 below z0-w, 1 above z0+w, linear between."""
    return clamp01((z - (z0 - w)) / (2 * w))


def weights_for(co, obj_name):
    """Region-based skinning for chunky box limbs: rigid parts with short linear blends at joints."""
    x, y, z = co
    ax = abs(x)
    s = L if x >= 0 else R
    if obj_name == "Goblin_Sword":
        return {"Weapon": 1.0}
    if obj_name == "Goblin_Eyes":
        return {"Head": 1.0}
    # ears + earring
    if ax > 0.205 and z > 1.22:
        return {("Ear_L" if s == L else "Ear_R"): 1.0}
    # pauldrons: torso near the neck, arm toward the outer edge
    if obj_name == "Goblin_Armor" and z > 0.91 and ax > 0.2:
        a = clamp01((ax - 0.24) / 0.16)
        return {"UpperTorso": 1 - a, side(s, "UpperArm"): a}
    # arms
    if ax > 0.262 and 0.46 < z < 1.0:
        up = ramp(z, 0.79, 0.03)
        lo = ramp(z, 0.61, 0.025)
        return {side(s, "UpperArm"): up, side(s, "LowerArm"): lo - up if lo > up else 0.0,
                side(s, "Hand"): 1 - lo}
    # head / neck
    if z > 1.03:
        h = ramp(z, 1.075, 0.03)
        return {"Head": h, "UpperTorso": 1 - h}
    # torso
    if z > 0.70 or (ax < 0.115 and z > 0.40 and abs(y) > 0.137):  # waist cloth stays with the hips
        u = ramp(z, 0.76, 0.04)
        return {"UpperTorso": u, "LowerTorso": 1 - u}
    # legs
    hip = ramp(z, 0.61, 0.035)
    knee = ramp(z, 0.37, 0.03)
    ankle = ramp(z, 0.175, 0.012)
    w = {"LowerTorso": hip, side(s, "UpperLeg"): max(0.0, knee - hip),
         side(s, "LowerLeg"): max(0.0, ankle - knee), side(s, "Foot"): 1 - ankle}
    return w


def build():
    for n in (RIG,):
        if n in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[n], do_unlink=True)
    arm = bpy.data.armatures.new(RIG)
    rig = bpy.data.objects.new(RIG, arm)
    coll = bpy.data.collections.get("GOBLIN_Rig") or bpy.data.collections.new("GOBLIN_Rig")
    if coll.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(coll)
    coll.objects.link(rig)
    arm.display_type = "STICK"
    rig.show_in_front = True

    bpy.context.view_layer.objects.active = rig
    for o in bpy.context.selected_objects:
        o.select_set(False)
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.edit_bones
    for name, (h, t, parent, deform) in BONES.items():
        b = eb.new(name)
        b.head, b.tail = Vector(h), Vector(t)
        b.use_deform = deform
        b.roll = 0
    for name, (h, t, parent, deform) in BONES.items():
        if parent:
            eb[name].parent = eb[parent]
            eb[name].use_connect = False
    # weapon bone sits on the sword's grip: y-axis = grip axis (toward pommel), x-axis = sword local X
    sw = bpy.data.objects["Goblin_Sword"]
    m = sw.matrix_world.normalized()
    b = eb.new("Weapon")
    b.head = m.translation
    b.tail = m.translation + m.to_3x3() @ Vector((0, 0, 0.12))
    b.align_roll(m.to_3x3() @ Vector((1, 0, 0)))
    b.parent = eb["RightHand"]
    bpy.ops.object.mode_set(mode="OBJECT")

    # bone collections: DEF (exported) / CTRL (animator-only)
    for cname in ("DEF", "CTRL"):
        if cname not in arm.collections:
            arm.collections.new(cname)
    for b in arm.bones:
        arm.collections["DEF" if b.use_deform else "CTRL"].assign(b)

    # leg IK: controls drive the deform chain; baked out before export
    for s in ("L", "R"):
        full = "Left" if s == "L" else "Right"
        pb = rig.pose.bones[full + "LowerLeg"]
        c = pb.constraints.new("IK")
        c.target, c.subtarget = rig, "IK_Foot_" + s
        c.pole_target, c.pole_subtarget = rig, "Pole_Knee_" + s
        c.pole_angle = math.radians(-90)
        c.chain_count = 2
        foot = rig.pose.bones[full + "Foot"]
        cr = foot.constraints.new("COPY_ROTATION")
        cr.target, cr.subtarget = rig, "IK_Foot_" + s
        cr.mix_mode = "REPLACE"  # IK_Foot rests aligned with the foot bone, so world copy is exact
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ" if pb.name.startswith(("IK_", "Pole_")) else "QUATERNION"

    # sword: bake its object transform (run 01 first on re-runs: this makes it identity) into the mesh so every skinned mesh has identity transforms
    sw.data.transform(sw.matrix_world)
    sw.matrix_world = Matrix.Identity(4)

    # skin
    for name in ("Goblin_Body", "Goblin_Armor", "Goblin_Eyes", "Goblin_Sword"):
        ob = bpy.data.objects[name]
        ob.vertex_groups.clear()
        groups = {}
        for v in ob.data.vertices:
            for bone, w in weights_for(ob.matrix_world @ v.co, name).items():
                if w <= 1e-4:
                    continue
                if bone not in groups:
                    groups[bone] = ob.vertex_groups.new(name=bone)
                groups[bone].add([v.index], w, "REPLACE")
        for mod in [m for m in ob.modifiers if m.type == "ARMATURE"]:
            ob.modifiers.remove(mod)
        mod = ob.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
        ob.parent = rig
        ob.matrix_parent_inverse = rig.matrix_world.inverted()
    print("rig bones:", len(arm.bones), "deform:", sum(b.use_deform for b in arm.bones))


if __name__ == "__main__":
    build()
