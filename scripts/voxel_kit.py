# voxel_kit.py: shared LEGO-voxel mesh builder for the prop scripts (14_voxel_trees, 15_maya_ruins).
#
# Built in studs: 1 Blender unit = 1 Roblox stud (Studio reads 1 FBX metre as 1 stud), Z up. A voxel is V studs on a
# side; every voxel top with nothing above it gets V x V round stud bumps, like a LEGO brick. Faces between touching
# voxels are culled. Each colour is its own mesh object (Studio imports one MeshPart per object, so colours stay
# editable as Part.Color on Plastic); big colours are also split into CHUNK x CHUNK-voxel columns so no mesh passes
# Roblox's 20k-triangle MeshPart limit.
import math
import os

import bmesh
import bpy

ROOT = "/Users/chinnaphat/Desktop/cedt/roblox/goblin"
V = 2  # default studs per voxel (props can build at 1 for finer detail)
STUD_R, STUD_H, STUD_SEG = 0.3, 0.18, 8
CHUNK = 20  # voxels per side of one mesh chunk
TRI_LIMIT = 20000

FACES = [  # neighbour offset, 4 corner offsets (unit cube, counter-clockwise seen from outside)
    ((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
    ((-1, 0, 0), [(0, 1, 0), (0, 0, 0), (0, 0, 1), (0, 1, 1)]),
    ((0, 1, 0), [(1, 1, 0), (0, 1, 0), (0, 1, 1), (1, 1, 1)]),
    ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
    ((0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]),
    ((0, 0, -1), [(0, 1, 0), (1, 1, 0), (1, 0, 0), (0, 0, 0)]),
]


def material(name, rgb):
    m = bpy.data.materials.get("Voxel_" + name) or bpy.data.materials.new("Voxel_" + name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    lin = [((c / 255) / 12.92 if c / 255 <= 0.04045 else ((c / 255 + 0.055) / 1.055) ** 2.4) for c in rgb]
    bsdf.inputs["Base Color"].default_value = (*lin, 1)
    bsdf.inputs["Roughness"].default_value = 0.55
    m.diffuse_color = (*lin, 1)
    return m


def stud(bm, cx, cy, z):
    ring_lo = [bm.verts.new((cx + STUD_R * math.cos(a), cy + STUD_R * math.sin(a), z))
               for a in (2 * math.pi * k / STUD_SEG for k in range(STUD_SEG))]
    ring_hi = [bm.verts.new((v.co.x, v.co.y, z + STUD_H)) for v in ring_lo]
    for k in range(STUD_SEG):
        n = (k + 1) % STUD_SEG
        bm.faces.new((ring_lo[k], ring_lo[n], ring_hi[n], ring_hi[k]))
    bm.faces.new(ring_hi)


def build(name, voxels, colors, offset=(0, 0, 0), v=V):
    """voxels: {(x, y, z): colour name}. Returns (root empty, mesh objects): one per colour per chunk."""
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    root.location = offset
    by_colour = {}
    for p, c in voxels.items():
        by_colour.setdefault(c, []).append(p)
    objs = []
    for colour, cells in sorted(by_colour.items()):
        ob = mesh_object(f"{name}_{colour}", cells, voxels, colour, colors, v)
        parts, size = [ob], CHUNK
        while max(tris(o) for o in parts) > TRI_LIMIT and size >= 2:  # too big for one MeshPart: split into columns
            for o in parts:
                bpy.data.objects.remove(o, do_unlink=True)
            chunks = {}
            for x, y, z in cells:
                chunks.setdefault((x // size, y // size), []).append((x, y, z))
            parts = [mesh_object(f"{name}_{colour}_{cx}_{cy}", part, voxels, colour, colors, v) for (cx, cy), part in sorted(chunks.items())]
            size //= 2
        for o in parts:
            o.parent = root
        objs += parts
    worst = max(tris(o) for o in objs)
    assert worst <= TRI_LIMIT, f"{name}: a mesh has {worst} tris, over Roblox's {TRI_LIMIT}; lower CHUNK"
    return root, objs


def mesh_object(label, cells, voxels, colour, colors, v=V):
    bm = bmesh.new()
    for x, y, z in cells:
        for (dx, dy, dz), corners in FACES:
            if (x + dx, y + dy, z + dz) in voxels:
                continue
            bm.faces.new([bm.verts.new(((x + ox) * v, (y + oy) * v, (z + oz) * v)) for ox, oy, oz in corners])
            if dz == 1:  # exposed top: v x v studs
                for i in range(v):
                    for j in range(v):
                        stud(bm, x * v + i + 0.5, y * v + j + 0.5, (z + 1) * v)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    me = bpy.data.meshes.new(label)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(label, me)
    ob.data.materials.append(material(colour, colors[colour]))
    bpy.context.collection.objects.link(ob)
    return ob


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


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


def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)


def export_all(pieces, blend_name):
    """pieces: [(name, voxels, colors, preview offset[, studs per voxel])]. Exports each at the origin, keeps them laid
    out for previews."""
    os.makedirs(os.path.join(ROOT, "export"), exist_ok=True)
    for name, vox, colors, at, *v in pieces:
        root, objs = build(name, vox, colors, at, *v)
        saved = root.location.copy()
        root.location = (0, 0, 0)
        export(root, objs, os.path.join(ROOT, "export", name + ".fbx"))
        root.location = saved
        print(f"{name}: {len(vox)} voxels, {len(objs)} meshes, {sum(tris(o) for o in objs)} tris (max {max(tris(o) for o in objs)})")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "blender", blend_name))
