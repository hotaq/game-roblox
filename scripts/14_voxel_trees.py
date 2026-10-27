# 14_voxel_trees.py: LEGO-voxel tree props (oak, birch, pine) for the studded-Plastic map look (GAME-30).
# Run headless:
#   /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python goblin/scripts/14_voxel_trees.py
# or in a live Blender: exec(open(".../14_voxel_trees.py").read())
#
# Built in studs: 1 Blender unit = 1 Roblox stud (Studio reads 1 FBX metre as 1 stud), Z up. A voxel is V studs on a
# side; every voxel top with nothing above it gets V x V round stud bumps, like a LEGO brick. Faces between touching
# voxels are culled. Each colour is its own mesh object (Studio imports one MeshPart per object, so colours stay
# editable as Part.Color on Plastic). Writes export/Tree_<Kind>.fbx, renders/trees_preview.png, blender/voxel_trees.blend.
import math
import os
import random

import bmesh
import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__) if "__file__" in dir() else os.getcwd(), ".."))
if not os.path.isdir(os.path.join(ROOT, "scripts")):  # exec() from a live Blender: fall back to the repo path
    ROOT = "/Users/chinnaphat/Desktop/cedt/roblox/goblin"

V = 2  # studs per voxel
STUD_R, STUD_H, STUD_SEG = 0.3, 0.18, 8

COLORS = {  # sRGB 0-255; the same values go to Part.Color in Studio
    "Bark": (92, 64, 45),
    "BarkDark": (66, 46, 33),
    "Leaf": (72, 148, 62),
    "LeafLight": (96, 170, 72),
    "LeafDark": (52, 116, 50),
    "Birch": (232, 230, 222),
    "BirchMark": (52, 47, 44),
    "BirchLeaf": (122, 184, 78),
    "BirchLeafLight": (146, 200, 92),
    "Pine": (40, 102, 58),
    "PineLight": (54, 122, 66),
}


def material(name):
    m = bpy.data.materials.get("Tree_" + name) or bpy.data.materials.new("Tree_" + name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    lin = [((c / 255) / 12.92 if c / 255 <= 0.04045 else ((c / 255 + 0.055) / 1.055) ** 2.4) for c in COLORS[name]]
    bsdf.inputs["Base Color"].default_value = (*lin, 1)
    bsdf.inputs["Roughness"].default_value = 0.55
    m.diffuse_color = (*lin, 1)
    return m


FACES = [  # neighbour offset, 4 corner offsets (unit cube, counter-clockwise seen from outside)
    ((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
    ((-1, 0, 0), [(0, 1, 0), (0, 0, 0), (0, 0, 1), (0, 1, 1)]),
    ((0, 1, 0), [(1, 1, 0), (0, 1, 0), (0, 1, 1), (1, 1, 1)]),
    ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
    ((0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]),
    ((0, 0, -1), [(0, 1, 0), (1, 1, 0), (1, 0, 0), (0, 0, 0)]),
]


def build(name, voxels, offset=(0, 0, 0)):
    """voxels: {(x, y, z): colour}. Returns the mesh objects, one per colour, parented to an empty `name`."""
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    root.location = offset
    objs = []
    for colour in sorted(set(voxels.values())):
        bm = bmesh.new()
        for (x, y, z), c in voxels.items():
            if c != colour:
                continue
            for (dx, dy, dz), corners in FACES:
                if (x + dx, y + dy, z + dz) in voxels:
                    continue
                vs = [bm.verts.new(((x + cx) * V, (y + cy) * V, (z + cz) * V)) for cx, cy, cz in corners]
                bm.faces.new(vs)
                if dz == 1:  # exposed top: V x V studs
                    for i in range(V):
                        for j in range(V):
                            stud(bm, x * V + i + 0.5, y * V + j + 0.5, (z + 1) * V)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        me = bpy.data.meshes.new(f"{name}_{colour}")
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(f"{name}_{colour}", me)
        ob.data.materials.append(material(colour))
        bpy.context.collection.objects.link(ob)
        ob.parent = root
        objs.append(ob)
    return root, objs


def stud(bm, cx, cy, z):
    ring_lo = [bm.verts.new((cx + STUD_R * math.cos(a), cy + STUD_R * math.sin(a), z))
               for a in (2 * math.pi * k / STUD_SEG for k in range(STUD_SEG))]
    ring_hi = [bm.verts.new((v.co.x, v.co.y, z + STUD_H)) for v in ring_lo]
    for k in range(STUD_SEG):
        n = (k + 1) % STUD_SEG
        bm.faces.new((ring_lo[k], ring_lo[n], ring_hi[n], ring_hi[k]))
    bm.faces.new(ring_hi)


def blob(vox, cx, cy, cz, rx, ry, rz, pick, rng, rough=0.25):
    """Ellipsoid of leaf voxels with a ragged, stepped edge; `pick(dz, rng)` chooses the shade by height."""
    for x in range(math.floor(cx - rx), math.ceil(cx + rx) + 1):
        for y in range(math.floor(cy - ry), math.ceil(cy + ry) + 1):
            for z in range(math.floor(cz - rz), math.ceil(cz + rz) + 1):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + ((z - cz) / rz) ** 2
                if d <= 1 + rng.uniform(-rough, rough * 0.5):
                    vox[(x, y, z)] = pick(z - cz, rng)


def oak(seed):
    rng, vox = random.Random(seed), {}
    h = rng.randint(4, 5)
    for z in range(h):  # 2x2 trunk with darker bark streaks
        for x in (0, 1):
            for y in (0, 1):
                vox[(x, y, z)] = "BarkDark" if rng.random() < 0.2 else "Bark"
    vox[(2, 0, 0)] = vox[(-1, 1, 0)] = "Bark"  # root nubs
    shade = lambda dz, r: "LeafDark" if dz < -1 else ("LeafLight" if dz > 0.5 and r.random() < 0.6 else "Leaf")
    blob(vox, 0.5, 0.5, h + 2.2, 3.1, 3.1, 3.0, shade, rng)
    blob(vox, 0.5, 0.5, h + 4.6, 2.0, 2.0, 1.6, shade, rng)  # a smaller top tier so the crown is round, not flat
    for _ in range(3):  # side clumps for an uneven crown
        a = rng.uniform(0, 2 * math.pi)
        blob(vox, 0.5 + 2.7 * math.cos(a), 0.5 + 2.7 * math.sin(a), h + rng.uniform(1.0, 2.6), 1.8, 1.8, 1.6, shade, rng)
    return vox


def birch(seed):
    rng, vox = random.Random(seed), {}
    h = rng.randint(7, 9)
    for z in range(h):  # mostly white, an occasional dark mark (not zebra stripes)
        vox[(0, 0, z)] = "BirchMark" if z in (2, 5) or (z > 1 and rng.random() < 0.12) else "Birch"
    shade = lambda dz, r: "BirchLeafLight" if dz > 0 and r.random() < 0.5 else "BirchLeaf"
    blob(vox, 0, 0, h + 1.2, 2.5, 2.5, 3.0, shade, rng, rough=0.2)
    return vox


def pine(seed):
    rng, vox = random.Random(seed), {}
    for z in range(2):
        vox[(0, 0, z)] = "Bark"
    z = 2
    for r in (3, 3, 2, 2, 1, 1, 0):  # stepped tiers, each a little narrower
        for x in range(-r, r + 1):
            for y in range(-r, r + 1):
                if abs(x) + abs(y) <= r + 1 and not (abs(x) == r and abs(y) == r and rng.random() < 0.7):
                    vox[(x, y, z)] = "PineLight" if z % 2 == 0 and rng.random() < 0.35 else "Pine"
        z += 1
    vox[(0, 0, z)] = "Pine"
    return vox


def export(root, objs, path):
    for o in bpy.context.scene.objects:
        if o:
            o.select_set(False)
    for o in objs:
        o.select_set(True)
    root.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"EMPTY", "MESH"},
        apply_scale_options="FBX_SCALE_UNITS", global_scale=1.0, axis_forward="-Z", axis_up="Y",
        mesh_smooth_type="FACE", path_mode="AUTO",
    )


for o in list(bpy.data.objects):  # start clean (this script owns the scene it runs in)
    bpy.data.objects.remove(o, do_unlink=True)

trees = [("Tree_Oak", oak(1), (0, 0, 0)), ("Tree_Birch", birch(2), (26, 0, 0)), ("Tree_Pine", pine(3), (-24, 0, 0))]
os.makedirs(os.path.join(ROOT, "export"), exist_ok=True)
for name, vox, at in trees:
    root, objs = build(name, vox, at)
    saved = root.location.copy()
    root.location = (0, 0, 0)  # export each tree at the origin, trunk base centred
    export(root, objs, os.path.join(ROOT, "export", name + ".fbx"))
    root.location = saved
    tris = sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
    print(f"{name}: {len(vox)} voxels, {len(objs)} colours, {tris} tris")

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "blender", "voxel_trees.blend"))
