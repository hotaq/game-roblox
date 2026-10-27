# Goblin enemy - stage 2: Roblox R15 rig + foot IK controls. Run after 01_build_model.py.
#
# Deform bones follow the Roblox R15 hierarchy and names (Root > HumanoidRootNode > LowerTorso ...) so the
# 15 <Part>_Geo meshes import as an R15 Humanoid that pathfinding and Animator drive natively. Extra deform
# bones: Ear_L/R (Head), Cloth_F/B (LowerTorso, waist cloth), Weapon (RightHand, sword grip).
# Voxel parts are rigid, so every vertex has a single 1.0 weight (assigned in stage 1).
# IK_Foot_* / Pole_Knee_* are animation controls only; stage 5 drops them and bakes to FK.
import bpy, math
from mathutils import Vector

V = 0.0225
RIG = "Goblin_Rig"

BONES = {  # name: (head voxel, tail voxel, parent, deform)
    "Root": ((0, 0, 0), (0, 0, 4), None, True),
    "HumanoidRootNode": ((0, 0, 27), (0, 0, 31), "Root", True),
    "LowerTorso": ((0, 0, 27), (0, 0, 34), "HumanoidRootNode", True),
    "UpperTorso": ((0, 0, 34), (0, 0, 52), "LowerTorso", True),
    "Head": ((0, 0, 52), (0, 0, 68), "UpperTorso", True),
    "Ear_L": ((8, 0, 62), (27, 0, 80), "Head", True),
    "Ear_R": ((-8, 0, 62), (-27, 0, 80), "Head", True),
    "Cloth_F": ((0, -8.5, 30), (0, -8.5, 14), "LowerTorso", True),
    "Cloth_B": ((0, 8.5, 30), (0, 8.5, 14), "LowerTorso", True),
}
for s, S, k in ((1, "Left", "L"), (-1, "Right", "R")):
    x, lx = 16 * s, 5.5 * s
    BONES.update({
        S + "UpperArm": ((x, 0, 49), (x, 0, 39), "UpperTorso", True),
        S + "LowerArm": ((x, 0, 39), (x, 0, 30), S + "UpperArm", True),
        S + "Hand": ((x, 0, 30), (x, 0, 21), S + "LowerArm", True),
        # knee sits slightly forward: a perfectly straight chain gives the IK solver no bend direction
        S + "UpperLeg": ((lx, 0, 27), (lx, -0.7, 14), "LowerTorso", True),
        S + "LowerLeg": ((lx, -0.7, 14), (lx, 0, 5), S + "UpperLeg", True),
        S + "Foot": ((lx, 0, 5), (lx, -8, 1), S + "LowerLeg", True),
        "IK_Foot_" + k: ((lx, 0, 5), (lx, -8, 1), "Root", False),
        "Pole_Knee_" + k: ((lx, -20, 14), (lx, -24, 14), "Root", False),
    })


def build():
    old = bpy.data.objects.get(RIG)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
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
        b.head, b.tail = Vector(h) * V, Vector(t) * V
        b.roll = 0
        b.use_deform = deform
    for name, (h, t, parent, deform) in BONES.items():
        if parent:
            eb[name].parent = eb[parent]
    # Weapon = sword grip frame: Y along the blade (forward at rest), Z toward the cutting edge (down at rest)
    w = eb.new("Weapon")
    w.head = Vector((-16, 0, 25.5)) * V
    w.tail = w.head + Vector((0, -0.15, 0))
    w.align_roll(Vector((0, 0, -1)))
    w.parent = eb["RightHand"]
    # VFX locators: unweighted deform bones (so they export) that the Roblox VFX read each frame.
    for name, h, t, parent in (("VFX_BladeBase", (-16, -12, 24.8), (-16, -14, 24.8), "Weapon"),
                               ("VFX_BladeTip", (-16, -31, 36.5), (-16, -33, 36.5), "Weapon"),
                               ("VFX_Eyes", (0, -9.5, 60), (0, -11.5, 60), "Head"),
                               ("VFX_HeadTop", (0, 0, 79), (0, 0, 81), "Head")):
        b = eb.new(name)
        b.head, b.tail = Vector(h) * V, Vector(t) * V
        b.parent = eb[parent]
    bpy.ops.object.mode_set(mode="OBJECT")

    for cname in ("DEF", "CTRL"):
        if cname not in arm.collections:
            arm.collections.new(cname)
    for b in arm.bones:
        arm.collections["DEF" if b.use_deform else "CTRL"].assign(b)

    for k, S in (("L", "Left"), ("R", "Right")):
        c = rig.pose.bones[S + "LowerLeg"].constraints.new("IK")
        c.target, c.subtarget = rig, "IK_Foot_" + k
        c.pole_target, c.pole_subtarget = rig, "Pole_Knee_" + k
        c.pole_angle = math.radians(-90)
        c.chain_count = 2
        cr = rig.pose.bones[S + "Foot"].constraints.new("COPY_ROTATION")
        cr.target, cr.subtarget = rig, "IK_Foot_" + k  # IK_Foot rests aligned with the foot, so REPLACE is exact
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"

    for ob in bpy.data.collections["GOBLIN_Mesh"].objects:
        for m in [m for m in ob.modifiers if m.type == "ARMATURE"]:
            ob.modifiers.remove(m)
        ob.modifiers.new("Armature", "ARMATURE").object = rig
        ob.parent = rig
    bpy.context.view_layer.update()
    # rest check: constraints must not move anything at rest
    err = max((rig.pose.bones[n].matrix.translation - rig.data.bones[n].matrix_local.translation).length
              for n in ("LeftFoot", "RightFoot", "LeftLowerLeg", "RightLowerLeg"))
    print("rig bones:", len(arm.bones), "deform:", sum(b.use_deform for b in arm.bones), "rest IK err: %.6f" % err)


if __name__ == "__main__":
    build()
