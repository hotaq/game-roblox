# Goblin enemy - horde mesh: the 17 GOBLIN_Mesh parts joined into ONE skinned mesh for the Megabonk-style horde.
# Run headless after 05_export.py (needs Goblin_ExportRig):
#   /Applications/Blender.app/Contents/MacOS/Blender -b goblin/blender/goblin.blend --python goblin/scripts/12_horde_mesh.py
# Writes export/GoblinHorde.fbx: same rig and export settings as export/Goblin.fbx, one mesh, one material (the eyes'
# own material is dropped and their UVs point at a yellow atlas texel). Import it with Studio's 3D Importer, then run
# roblox/BuildHordeModel.luau to turn it into ReplicatedStorage.Goblin.HordeModel. The .blend is not saved.
# Goblin v2 (24_goblin_v2_model.py): GOBLIN_STYLE=v2 ... -b goblin/blender/goblin_v2.blend --python ...12_horde_mesh.py
# writes export/GoblinV2Horde.fbx instead, keeps the eyes' own atlas texels and builds the export rig if 05 never ran.
# The jungle skeleton (25_skeleton_model.py, blender/skeleton.blend): GOBLIN_STYLE=skeleton -> export/SkeletonHorde.fbx.
import importlib.util
import os

import bpy

ROOT = os.environ.get("GOBLIN_ROOT", "/Users/chinnaphat/Desktop/cedt/roblox/goblin")
STYLE = os.environ.get("GOBLIN_STYLE", "v1")
NAME = {"v2": "GoblinV2Horde", "skeleton": "SkeletonHorde"}.get(STYLE, "GoblinHorde")
EYE_TEXEL = (894, 366) if STYLE == "v1" else None  # v1 atlas pixel (255, 201, 35), counted from the top-left like Roblox

spec = importlib.util.spec_from_file_location("export05", os.path.join(ROOT, "scripts", "05_export.py"))
export05 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(export05)

rig = bpy.data.objects.get(export05.EXP)
if not rig:  # a fresh build that never ran 05 (no baked animations needed for the model file)
    rig = export05.make_export_rig(bpy.data.objects[export05.SRC])
    export05.retarget_meshes(rig)
for c in [c for pb in rig.pose.bones for c in pb.constraints]:
    c.mute = True  # rest pose, as 05_export does for the model file
rig.animation_data_create()
rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.location, pb.rotation_quaternion = (0, 0, 0), (1, 0, 0, 0)

body = bpy.data.materials["M_Goblin_Voxel"]
eye_uv = EYE_TEXEL and ((EYE_TEXEL[0] + 0.5) / 1024, 1 - (EYE_TEXEL[1] + 0.5) / 1024)  # Blender's V runs bottom-up
parts = []
for ob in export05.meshes():
    dup = ob.copy()
    dup.data = ob.data.copy()
    bpy.context.scene.collection.objects.link(dup)
    if eye_uv and ob.name.startswith("Eyes"):
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
horde.name = horde.data.name = NAME

os.makedirs(os.path.join(ROOT, "export"), exist_ok=True)
out = os.path.join(ROOT, "export", NAME + ".fbx")
export05.fbx(out, [rig, horde], False)
print("HORDE MESH", out, "verts", len(horde.data.vertices), "groups", len(horde.vertex_groups))
