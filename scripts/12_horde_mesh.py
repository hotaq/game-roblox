# Goblin enemy - horde mesh: the 17 GOBLIN_Mesh parts joined into ONE skinned mesh for the Megabonk-style horde.
# Run headless after 05_export.py (needs Goblin_ExportRig):
#   /Applications/Blender.app/Contents/MacOS/Blender -b goblin/blender/goblin.blend --python goblin/scripts/12_horde_mesh.py
# Writes export/GoblinHorde.fbx: same rig and export settings as export/Goblin.fbx, one mesh, one material (the eyes'
# own material is dropped and their UVs point at a yellow atlas texel). Import it with Studio's 3D Importer, then run
# roblox/BuildHordeModel.luau to turn it into ReplicatedStorage.Goblin.HordeModel. The .blend is not saved.
import importlib.util
import os

import bpy

ROOT = os.environ.get("GOBLIN_ROOT", "/Users/chinnaphat/Desktop/cedt/roblox/goblin")
EYE_TEXEL = (894, 366)  # atlas pixel (255, 201, 35), counted from the top-left like Roblox

spec = importlib.util.spec_from_file_location("export05", os.path.join(ROOT, "scripts", "05_export.py"))
export05 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(export05)

rig = bpy.data.objects[export05.EXP]
for c in [c for pb in rig.pose.bones for c in pb.constraints]:
    c.mute = True  # rest pose, as 05_export does for the model file
rig.animation_data_create()
rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.location, pb.rotation_quaternion = (0, 0, 0), (1, 0, 0, 0)

body = bpy.data.materials["M_Goblin_Voxel"]
eye_uv = ((EYE_TEXEL[0] + 0.5) / 1024, 1 - (EYE_TEXEL[1] + 0.5) / 1024)  # Blender's V runs bottom-up
parts = []
for ob in export05.meshes():
    dup = ob.copy()
    dup.data = ob.data.copy()
    bpy.context.scene.collection.objects.link(dup)
    if ob.name.startswith("Eyes"):
        for loop_uv in dup.data.uv_layers.active.data:
            loop_uv.uv = eye_uv
    dup.data.materials.clear()
    dup.data.materials.append(body)
    parts.append(dup)

bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
for o in bpy.context.view_layer.objects:
    o.select_set(False)
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()  # vertex groups merge by name, so every part keeps its skin weights
horde = bpy.context.view_layer.objects.active
horde.name = horde.data.name = "GoblinHorde"

os.makedirs(os.path.join(ROOT, "export"), exist_ok=True)
out = os.path.join(ROOT, "export", "GoblinHorde.fbx")
export05.fbx(out, [rig, horde], False)
print("HORDE MESH", out, "verts", len(horde.data.vertices), "groups", len(horde.vertex_groups))
