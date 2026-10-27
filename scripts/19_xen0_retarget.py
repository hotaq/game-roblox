# 19_xen0_retarget.py: moves the player sword animations onto MrXen0's R15 rig (FK/IK, devforum.roblox.com/t/3606878),
# so the owner can keep editing them with IK. GAME-35.
#   blender/MrXen0_R15RIG_v1.2.blend  the rig as downloaded (third-party, kept out of git)
#   blender/r15_rig.blend             our rig + EXP_SwordIdle / Run / Hold / Plant / Pull from 18_r15_anims.py
# Run headless (scripts in the rig file stay off; they only draw its RigUI panel):
#   /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --disable-autoexec \
#     goblin/blender/MrXen0_R15RIG_v1.2.blend --python goblin/scripts/19_xen0_retarget.py
# Writes blender/r15_xen0.blend: the rig in FK mode, the phase-5 sword on the RightHand bone, actions SwordIdle and
# SwordRun, SwordHold, SwordPlant, SwordPull keyed on the FK / torso / head controls, plus renders/sword_carry_xen0.png.
#
# How: for every part P, our rig gives the world delta D = Pose @ Rest^-1 per frame. MrXen0's rig faces +Y where ours
# faces -Y, so its target is R @ D @ R^-1 @ Rest_xen0(P) with R = 180 degrees about Z. Each deform bone copies the
# full transform of one control (through ORG / MCH_SWITCH bones), so the control's pose matrix is set to that target,
# parents first.
import math
import os

import bpy
from mathutils import Matrix, Vector

ROOT = "/Users/chinnaphat/Desktop/cedt/roblox/goblin"
R = Matrix.Rotation(math.pi, 4, "Z")
CONTROLS = [  # (control, part it drives), parents before children
    ("UpTorso", "UpperTorso"), ("LowTorso", "LowerTorso"), ("HEAD", "Head"),
    ("FK_UpperArm.R", "RightUpperArm"), ("FK_UpperArm.L", "LeftUpperArm"),
    ("FK_UpperLeg.R", "RightUpperLeg"), ("FK_UpperLeg.L", "LeftUpperLeg"),
    ("FK_LowerArm.R", "RightLowerArm"), ("FK_LowerArm.L", "LeftLowerArm"),
    ("FK_LowerLeg.R", "RightLowerLeg"), ("FK_LowerLeg.L", "LeftLowerLeg"),
    ("FK_Hand.R", "RightHand"), ("FK_Hand.L", "LeftHand"), ("FK_Foot.R", "RightFoot"), ("FK_Foot.L", "LeftFoot"),
]

xen = bpy.data.objects["Roblox_R15"]
with bpy.data.libraries.load(os.path.join(ROOT, "blender", "r15_rig.blend")) as (src, dst):
    dst.objects = ["R15_Rig", "Sword"] + [n for n in src.objects if n.startswith("Sword_Phase5_")]
    dst.actions = ["EXP_SwordIdle", "EXP_SwordRun", "EXP_SwordHold", "EXP_SwordPlant", "EXP_SwordPull"]
ours = next(o for o in dst.objects if o.name.startswith("R15_Rig"))
for o in dst.objects:
    bpy.context.scene.collection.objects.link(o)

props = xen.pose.bones["PROPERTIES"]
for k in ("ARM_IK_FK.L", "ARM_IK_FK.R", "LEG_IK_FK.L", "LEG_IK_FK.R"):
    props[k] = 0.0  # FK: the animation is keyed on the FK controls (RigUI's snap buttons convert to IK)


def targets(frame):
    bpy.context.scene.frame_set(frame)
    out = {}
    for _, part in CONTROLS:
        pb = ours.pose.bones[part]
        d = pb.matrix @ pb.bone.matrix_local.inverted()
        out[part] = R @ d @ R.inverted() @ xen.data.bones[part].matrix_local
    return out


def apply(tg):
    for ctrl, part in CONTROLS:  # the control moves by its part's delta (LowTorso pivots at the waist, not the hips)
        xen.pose.bones[ctrl].matrix = tg[part] @ xen.data.bones[part].matrix_local.inverted() @ \
            xen.data.bones[ctrl].matrix_local
        bpy.context.view_layer.update()


def bake(action_name, new_name):
    act = bpy.data.actions[action_name]
    ours.animation_data.action = act
    f0, f1 = (int(x) for x in act.frame_range)
    new = bpy.data.actions.get(new_name) or bpy.data.actions.new(new_name)
    new.use_fake_user = True
    xen.animation_data_create()
    xen.animation_data.action = new
    worst = 0.0
    prev = {}
    for f in range(f0, f1 + 1):
        tg = targets(f)
        xen.animation_data.action = None  # pose freely, then key
        apply(tg)
        for ctrl, _ in CONTROLS:  # no +-180 degree euler flips between keys (they spin the body when interpolated)
            pb = xen.pose.bones[ctrl]
            if pb.rotation_mode != "QUATERNION":
                if ctrl in prev:
                    pb.rotation_euler.make_compatible(prev[ctrl])
                prev[ctrl] = pb.rotation_euler.copy()
        for part, m in tg.items():
            worst = max(worst, (xen.pose.bones[part].matrix.translation - m.translation).length)
        xen.animation_data.action = new
        for ctrl, _ in CONTROLS:
            pb = xen.pose.bones[ctrl]
            for path in ("location", "rotation_quaternion" if pb.rotation_mode == "QUATERNION" else "rotation_euler"):
                pb.keyframe_insert(path, frame=f, group=ctrl)
    new.frame_range = (f0, f1)
    print("%s: %d frames, worst part offset %.3f studs" % (new_name, f1 - f0 + 1, worst))


bake("EXP_SwordIdle", "SwordIdle")
bake("EXP_SwordRun", "SwordRun")
bake("EXP_SwordHold", "SwordHold")
bake("EXP_SwordPlant", "SwordPlant")
bake("EXP_SwordPull", "SwordPull")

# The sword: same place as on our rig, turned to face +Y, riding on the RightHand deform bone.
ours.animation_data.action = None
xen.animation_data.action = None
for pb in list(ours.pose.bones) + list(xen.pose.bones):
    pb.matrix_basis = Matrix.Identity(4)
bpy.context.scene.frame_set(0)
sword = next(o for o in dst.objects if o.name.startswith("Sword") and o.type == "EMPTY")
rest_world = R @ sword.matrix_world
sword.parent, sword.parent_type, sword.parent_bone = xen, "BONE", "RightHand"
bpy.context.view_layer.update()
sword.matrix_world = rest_world
bpy.data.objects.remove(ours, do_unlink=True)
xen.animation_data.action = bpy.data.actions["SwordIdle"]
bpy.context.scene.render.fps = 30  # the actions are keyed at 30 fps (18_r15_anims.py); the rig file defaults to 24
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "blender", "r15_xen0.blend"))

# Preview: idle from the front and the back, run mid-stride.
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light, sh.color_type, sh.background_type = "STUDIO", "MATERIAL", "WORLD"
sc.world = sc.world or bpy.data.worlds.new("World")
sc.world.color = (0.62, 0.64, 0.68)
cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.lens = 42
sc.render.resolution_x, sc.render.resolution_y = 600, 760
tiles = []
for i, (act, frame, at) in enumerate([("SwordIdle", 0, (0, 12, 3.6)), ("SwordIdle", 0, (7, -8, 5.5)),
                                      ("SwordRun", 5, (-6.5, 9.5, 4.2)), ("SwordRun", 10, (-6.5, 9.5, 4.2))]):
    xen.animation_data.action = bpy.data.actions[act]
    sc.frame_set(frame)
    cam.location = at
    cam.rotation_euler = (Vector((-0.6, 0, 2.9)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(ROOT, "renders", "_tile%d.png" % i)
    bpy.ops.render.render(write_still=True)
    tiles.append(sc.render.filepath)
imgs = [bpy.data.images.load(p) for p in tiles]
w, h = imgs[0].size
sheet = bpy.data.images.new("sheet", w * len(imgs), h)
px = [0.0] * (w * len(imgs) * h * 4)
for i, im in enumerate(imgs):
    src_px = list(im.pixels)
    for y in range(h):
        row = (y * len(imgs) + i) * w * 4
        px[row:row + w * 4] = src_px[y * w * 4:(y + 1) * w * 4]
sheet.pixels = px
sheet.filepath_raw, sheet.file_format = os.path.join(ROOT, "renders", "sword_carry_xen0.png"), "PNG"
sheet.save()
for p in tiles:
    os.remove(p)
