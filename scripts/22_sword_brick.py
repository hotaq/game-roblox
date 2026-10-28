# 22_sword_brick.py: turns a Meshy sword GLB (the owner's new default sword, one phase per file) into a
# (The brick-built version decimated badly; the smooth "shadow blade" survives 5k fine and is the one in use.)
# Roblox-ready GLB: decimated to TRIS triangles (UVs, base colour, roughness and normal maps kept, maps cut to 1024 px),
# grip centre on the origin, blade +Z, flat faces +/-Y, sized so the blade matches the old phase's blade (16_swords.py
# PHASES) in studs. The grip is found from the width profile: the guard is the widest slice, the grip the narrow run
# under it, the pommel where it widens again.
# Run headless:
#   /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python goblin/scripts/22_sword_brick.py -- <in.glb> <phase>
# Writes export/SwordBrick_Phase<phase>.glb.
import os
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = "/Users/chinnaphat/Desktop/cedt/roblox/goblin"
TRIS = 5000
BLADE = [2.4, 2.9, 3.3, 3.6, 4.1]  # old blade length per phase (16_swords.py), in studs

src, phase = sys.argv[sys.argv.index("--") + 1], int(sys.argv[-1])
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=src)
o = next(x for x in bpy.context.scene.objects if x.type == "MESH")
bpy.context.view_layer.objects.active = o
o.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Width profile along Z in 60 slices.
zs = [v.co.z for v in o.data.vertices]
z0, z1 = min(zs), max(zs)
N = 60
width = [0.0] * N
for v in o.data.vertices:
    i = min(N - 1, int((v.co.z - z0) / (z1 - z0) * N))
    width[i] = max(width[i], abs(v.co.x))
z_of = lambda i: z0 + (i + 0.5) * (z1 - z0) / N  # noqa: E731
guard = max(range(N), key=lambda i: width[i])
under = sorted(w for w in width[:guard] if w > 0)
grip_w = under[len(under) // 2]  # the grip is most of what's under the guard (min would catch a pointed pommel)
top = guard
while top > 0 and width[top - 1] > grip_w * 1.3:  # walk down off the guard
    top -= 1
bottom = top
while bottom > 0 and width[bottom - 1] <= grip_w * 1.3:  # down the grip until the pommel widens it
    bottom -= 1
grip_z = (z_of(top) + z_of(bottom)) / 2
blade = z1 - z_of(guard)
scale = BLADE[phase - 1] / blade
print(f"guard z={z_of(guard):.3f} grip z={z_of(bottom):.3f}..{z_of(top):.3f} -> centre {grip_z:.3f}, scale {scale:.3f}")

d = o.modifiers.new("Decimate", "DECIMATE")
d.decimate_type, d.use_collapse_triangulate = "COLLAPSE", True
d.ratio = TRIS / sum(len(p.vertices) - 2 for p in o.data.polygons)
bpy.ops.object.modifier_apply(modifier="Decimate")
o.data.transform(Matrix.Scale(scale, 4) @ Matrix.Translation(Vector((0, 0, -grip_z))))
o.name = f"SwordBrick_Phase{phase}"
for img in bpy.data.images:
    if img.size[0] > 1024:
        img.scale(1024, 1024)

out = f"{ROOT}/export/SwordShadow_Phase{phase}.glb"
bpy.ops.export_scene.gltf(filepath=out, use_selection=True, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=90)
zs = [v.co.z for v in o.data.vertices]
print(f"{out}: {sum(len(p.vertices) - 2 for p in o.data.polygons)} tris, length {max(zs) - min(zs):.2f} studs "
      f"(z {min(zs):.2f}..{max(zs):.2f}), {os.path.getsize(out) / 1e6:.2f} MB")
