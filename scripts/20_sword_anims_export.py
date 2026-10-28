# 20_sword_anims_export.py: the player sword animations (GAME-35) -> Roblox KeyframeSequences.
#   /Applications/Blender.app/Contents/MacOS/Blender -b --disable-autoexec goblin/blender/r15_xen0.blend \
#     --python goblin/scripts/20_sword_anims_export.py
# Reads SwordIdle / SwordRun / SwordHold / SwordPlant / SwordPull / SwordDashF/B/L/R on MrXen0's rig in r15_xen0.blend (from 19, so pose tweaks made
# there are what ships) and writes roblox/SwordAnims.rbxmx: Folder "SwordAnims" with one KeyframeSequence each.
# Same maths and helpers as 09_gen_anims.py, except: the deform bones are named after the R15 parts, the rig is in
# studs and faces +Y, so Blender (x, y, z) -> Roblox (x, z, -y); limb joints keep rotation only (MrXen0's rest pivots
# sit up to 0.08 studs off Roblox's, which would otherwise pull the limbs apart), the Root joint keeps its translation.
import importlib.util
import os

import bpy
import numpy as np

ROOT = "/Users/chinnaphat/Desktop/cedt/roblox/goblin"
spec = importlib.util.spec_from_file_location("gen", os.path.join(ROOT, "scripts", "09_gen_anims.py"))
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)
gen.REST = os.path.join(ROOT, "docs", "r15_rig_rest.txt")
OUT = os.path.join(ROOT, "roblox", "SwordAnims.rbxmx")
A = np.array([[1, 0, 0], [0, 0, 1], [0, -1, 0]], float)
ANIMS = {"SwordIdle": (True, 0), "SwordRun": (True, 1), "SwordHold": (True, 0), "SwordPlant": (False, 2), "SwordPull": (False, 2),
         **{"SwordDash" + d: (False, 2) for d in "FBLR"}}  # loop, priority


def to_roblox(d):
    r = np.eye(4)
    r[:3, :3] = A @ d[:3, :3] @ A.T
    r[:3, 3] = A @ d[:3, 3]
    return r


parts, joints, _ = gen.load_rest()
kids = gen.tree(joints, {})
rig = bpy.data.objects["Roblox_R15"]
mw = np.array(rig.matrix_world)
rest_inv = {n: np.linalg.inv(np.array(rig.data.bones[n].matrix_local)) for n in joints}
fps = bpy.context.scene.render.fps
items = []
for name, (loop, priority) in ANIMS.items():
    act = bpy.data.actions[name]
    rig.animation_data.action = act
    if act.slots:
        rig.animation_data.action_slot = act.slots[0]
    f0, f1 = (int(x) for x in act.frame_range)
    frames, drift = [], 0.0
    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        deltas = {n: to_roblox(mw @ np.array(rig.pose.bones[n].matrix) @ rest_inv[n] @ np.linalg.inv(mw)) for n in joints}
        t = gen.solve(deltas, parts, joints, {}, parts)
        for n in t:
            if n != "LowerTorso":
                drift = max(drift, np.linalg.norm(t[n][:3, 3]))
                t[n][:3, 3] = 0
        frames.append(t)
    keep = gen.reduce(frames, [])
    kfs = "".join('<Item class="Keyframe"><Properties><string name="Name">Keyframe</string>'
                  '<float name="Time">%.5g</float></Properties>%s</Item>'
                  % (k / fps, gen.pose_xml("HumanoidRootPart", frames[k], kids)) for k in keep)
    items.append('<Item class="KeyframeSequence"><Properties><string name="Name">%s</string>'
                 '<bool name="Loop">%s</bool><token name="Priority">%d</token></Properties>%s</Item>'
                 % (name, str(loop).lower(), priority, kfs))
    print("anim %s: %d frames -> %d keyframes, limb joint offset dropped: %.3f studs" % (name, len(frames), len(keep), drift))
with open(OUT, "w") as fh:
    fh.write('<roblox version="4"><Item class="Folder"><Properties><string name="Name">SwordAnims</string>'
             '</Properties>%s</Item></roblox>' % "".join(items))
print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")
