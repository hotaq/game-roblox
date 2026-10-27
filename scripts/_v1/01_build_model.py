# Goblin enemy - stage 1: model + palette atlas texture.
# Run inside Blender (Scripting tab > Open > Run, or: blender -b -P 01_build_model.py).
# Units: metres. Front = -Y, up = +Z. Goblin's right hand = -X. Height ~1.55 m (~5.5 studs).
import bpy, bmesh, math, os
import numpy as np
from mathutils import Vector, Matrix, Euler

ROOT = os.environ.get("GOBLIN_ROOT", "/Users/chinnaphat/Desktop/cedt/roblox/goblin")
TEX = os.path.join(ROOT, "textures", "goblin_atlas.png")

# ---------------------------------------------------------------- palette atlas
# 4x4 grid of 64px swatches in a 256px texture. Index -> (name, rgb)
PAL = [
    ("skin", (0.36, 0.56, 0.20)), ("skin_dark", (0.20, 0.36, 0.12)), ("hair", (0.19, 0.10, 0.05)),
    ("leather", (0.46, 0.27, 0.14)), ("leather_dark", (0.26, 0.15, 0.08)), ("cloth_red", (0.40, 0.13, 0.09)),
    ("cloth_blue", (0.10, 0.24, 0.40)), ("metal", (0.28, 0.56, 0.56)), ("gold", (0.88, 0.62, 0.12)),
    ("teeth", (0.90, 0.84, 0.66)), ("mouth", (0.10, 0.03, 0.03)), ("pants", (0.23, 0.14, 0.08)),
    ("blade", (0.44, 0.62, 0.66)), ("grip", (0.14, 0.09, 0.07)), ("eye", (1.0, 0.86, 0.20)),
    ("rust", (0.50, 0.24, 0.13)),
]
P = {n: i for i, (n, _) in enumerate(PAL)}
GRID, SW, RES = 4, 64, 256


def make_atlas():
    rng = np.random.default_rng(7)
    img = np.zeros((RES, RES, 4), np.float32)
    img[..., 3] = 1
    for i, (name, rgb) in enumerate(PAL):
        cx, cy = i % GRID, i // GRID
        # coarse + fine noise so flat low-poly faces read as painted, not plastic
        coarse = np.kron(rng.random((8, 8)), np.ones((8, 8)))
        fine = rng.random((SW, SW))
        shade = 0.82 + 0.12 * coarse + 0.08 * fine
        grad = np.linspace(0.92, 1.06, SW)[:, None]
        sw = np.array(rgb)[None, None, :] * (shade * grad)[..., None]
        if name == "blade":  # rust/blood speckle on the blade
            mask = rng.random((SW, SW)) > 0.93
            sw[mask] = np.array(PAL[P["rust"]][1])
        if name in ("leather", "leather_dark"):  # scratches
            mask = rng.random((SW, SW)) > 0.97
            sw[mask] *= 1.35
        img[cy * SW:(cy + 1) * SW, cx * SW:(cx + 1) * SW, :3] = np.clip(sw, 0, 1)
    im = bpy.data.images.get("goblin_atlas") or bpy.data.images.new("goblin_atlas", RES, RES)
    im.scale(RES, RES)
    im.pixels.foreach_set(img.ravel())
    im.filepath_raw = TEX
    im.file_format = "PNG"
    os.makedirs(os.path.dirname(TEX), exist_ok=True)
    im.save()
    return im


# ---------------------------------------------------------------- primitives (return BMesh)
def cube(sx, sy, sz, top=(1, 1), shift_top=(0, 0), bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts:
        v.co.x *= sx; v.co.y *= sy; v.co.z *= sz
        if v.co.z > 0:
            v.co.x = v.co.x * top[0] + shift_top[0]
            v.co.y = v.co.y * top[1] + shift_top[1]
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES")
    return bm


def cone(r1, r2, depth, seg=6):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=depth)
    return bm


def ico(r, sub=1):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    return bm


def torus(R, r, seg=8, ring=4):
    bm = bmesh.new()
    rows = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        row = []
        for j in range(ring):
            b = 2 * math.pi * j / ring
            d = R + r * math.cos(b)
            row.append(bm.verts.new((d * math.cos(a), d * math.sin(a), r * math.sin(b))))
        rows.append(row)
    for i in range(seg):
        for j in range(ring):
            a, b = rows[i], rows[(i + 1) % seg]
            bm.faces.new((a[j], b[j], b[(j + 1) % ring], a[(j + 1) % ring]))
    return bm


def slab(profile, thick):
    """Extrude a 2D profile [(u, v)] lying in the XZ plane by `thick` along Y (centred)."""
    bm = bmesh.new()
    front = [bm.verts.new((u, -thick / 2, v)) for u, v in profile]
    back = [bm.verts.new((u, thick / 2, v)) for u, v in profile]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(profile)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    return bm


# ---------------------------------------------------------------- assembly
class Group:
    def __init__(self):
        self.bm = bmesh.new()

    def add(self, src, mat, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
        m = Matrix.LocRotScale(Vector(loc), Euler([math.radians(a) for a in rot]), Vector(scale))
        vmap = {v: self.bm.verts.new(m @ v.co) for v in src.verts}
        for f in src.faces:
            nf = self.bm.faces.new([vmap[v] for v in f.verts])
            nf.material_index = P[mat]
        src.free()

    def absorb(self, other, pivot, k):
        """Merge another group in, uniformly scaled by k about pivot (keeps material ids)."""
        pv = Vector(pivot)
        for v in other.bm.verts:
            v.co = pv + (v.co - pv) * k
        tmp = bpy.data.meshes.new("_tmp")
        other.bm.to_mesh(tmp)
        other.bm.free()
        self.bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)

    def mirror_add(self, make, mat, loc, rot=(0, 0, 0), scale=(1, 1, 1)):
        """Add a part on the goblin's left (+X) and its mirror on the right (-X)."""
        x, y, z = loc
        self.add(make(), mat, (x, y, z), rot, scale)
        self.add(make(), mat, (-x, y, z), (rot[0], -rot[1], -rot[2]), scale)


def finish(group, name, mats, uv_scale=2.0):
    bm = group.bm
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        # planar-project each face along its dominant normal axis, then pack into its palette swatch
        n = f.normal
        ax = max(range(3), key=lambda k: abs(n[k]))
        a, b = [k for k in range(3) if k != ax]
        pts = [(l.vert.co[a] * uv_scale, l.vert.co[b] * uv_scale) for l in f.loops]
        mu, mv = math.floor(min(p[0] for p in pts)), math.floor(min(p[1] for p in pts))
        i = f.material_index
        ox, oy = (i % GRID) * SW + 4, (i // GRID) * SW + 4
        inner = SW - 8
        for l, (pu, pv) in zip(f.loops, pts):
            u = min(max(pu - mu, 0), 1); v = min(max(pv - mv, 0), 1)
            l[uv].uv = ((ox + u * inner) / RES, (oy + v * inner) / RES)
        f.material_index = 0
        f.smooth = False
    me = bpy.data.meshes.get(name) or bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.clear()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.get(name) or bpy.data.objects.new(name, me)
    ob.data = me
    return ob


def atlas_material(img):
    mat = bpy.data.materials.get("M_Goblin_Atlas") or bpy.data.materials.new("M_Goblin_Atlas")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        if n.type not in ("BSDF_PRINCIPLED", "OUTPUT_MATERIAL"):
            nt.nodes.remove(n)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    return mat


def eye_material():
    mat = bpy.data.materials.get("M_Goblin_Eyes") or bpy.data.materials.new("M_Goblin_Eyes")
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (1.0, 0.86, 0.2, 1)
    bsdf.inputs["Emission Color"].default_value = (1.0, 0.8, 0.15, 1)
    bsdf.inputs["Emission Strength"].default_value = 3.0
    return mat


# ---------------------------------------------------------------- the goblin
def build_body():
    g = Group()
    h = build_head()
    g.absorb(h, (0, 0, 1.07), 1.15)  # chunky oversized head, scaled about the neck
    return build_torso(g)


def build_head():
    g = Group()
    # head (big, chunky) + jaw
    g.add(cube(0.34, 0.30, 0.26, top=(1.0, 0.95), bevel=0.035), "skin", (0, 0, 1.30))
    g.add(cube(0.30, 0.26, 0.12, top=(1.1, 1.05), bevel=0.03), "skin", (0, -0.025, 1.155))
    g.add(cube(0.16, 0.10, 0.08, bevel=0.02), "skin_dark", (0, -0.03, 1.10))  # chin
    g.add(cube(0.32, 0.08, 0.05, top=(1, 0.6), bevel=0.012), "skin_dark", (0, -0.15, 1.37), rot=(-12, 0, 0))  # brow
    g.add(cone(0.05, 0.004, 0.16, seg=4), "skin", (0, -0.21, 1.25), rot=(115, 0, 45), scale=(1, 0.8, 1))  # nose
    g.add(cube(0.21, 0.03, 0.065, top=(1.15, 1)), "mouth", (0, -0.152, 1.165))
    for i in range(6):  # teeth: lower row up, upper row down
        x = -0.085 + i * 0.034
        g.add(cone(0.014, 0.0, 0.04, seg=3), "teeth", (x, -0.165, 1.150), scale=(1, 0.6, 1))
        g.add(cone(0.014, 0.0, 0.04, seg=3), "teeth", (x + 0.017, -0.165, 1.182), rot=(180, 0, 0), scale=(1, 0.6, 1))
    # ears: long flat pyramids out to the sides and up
    g.mirror_add(lambda: cone(0.09, 0.006, 0.46, seg=4), "skin", (0.34, 0.02, 1.44), rot=(0, 55, 0), scale=(1, 0.35, 1))
    g.mirror_add(lambda: cone(0.055, 0.004, 0.30, seg=4), "skin_dark", (0.32, -0.005, 1.43), rot=(0, 55, 0), scale=(1, 0.2, 1))
    # mohawk spikes along the crown and down the back of the head
    spikes = [(-0.10, 1.44, -20, 0.13), (-0.05, 1.46, -10, 0.16), (0.00, 1.47, 0, 0.18), (0.05, 1.46, 15, 0.17),
              (0.10, 1.44, 30, 0.15), (0.14, 1.39, 50, 0.13), (0.165, 1.32, 70, 0.11)]
    for y, z, tilt, h in spikes:
        g.add(cone(0.055, 0.0, h * 1.15, seg=4), "hair", (0, y, z + h * 0.35), rot=(tilt, 0, 45), scale=(0.6, 1.2, 1))
        g.add(cone(0.03, 0.0, h * 0.8, seg=4), "hair", (0.025, y + 0.01, z + h * 0.25), rot=(tilt, 20, 45), scale=(0.6, 1.2, 1))
        g.add(cone(0.03, 0.0, h * 0.8, seg=4), "hair", (-0.025, y + 0.01, z + h * 0.25), rot=(tilt, -20, 45), scale=(0.6, 1.2, 1))
    g.add(cube(0.07, 0.14, 0.04, bevel=0.01), "skin_dark", (0, -0.04, 1.255), rot=(0, 0, 0))  # cheek shadow under nose bridge
    g.add(cube(0.08, 0.06, 0.06, bevel=0.015), "hair", (0, -0.06, 1.085))  # goatee tuft
    g.add(torus(0.032, 0.008), "gold", (0.235, -0.01, 1.30), rot=(90, 0, 0))  # gold earring, left ear
    return g


def build_torso(g):
    # neck + torso + hips
    g.add(cube(0.16, 0.15, 0.10), "skin", (0, 0.01, 1.07))
    g.add(cube(0.44, 0.27, 0.32, top=(1.12, 1.05), bevel=0.03), "pants", (0, 0, 0.88))
    g.add(cube(0.38, 0.25, 0.16, bevel=0.025), "pants", (0, 0, 0.66))
    # scarf / cowl
    g.add(cone(0.20, 0.12, 0.10, seg=8), "cloth_red", (0, 0.0, 1.035), scale=(1.15, 0.95, 1))
    g.add(slab([(-0.12, 0.0), (0.12, 0.0), (0.02, -0.16), (-0.03, -0.12)], 0.03), "cloth_red", (0, -0.155, 1.02))
    g.add(slab([(-0.14, 0.0), (0.14, 0.0), (0.0, -0.14)], 0.03), "cloth_red", (0, 0.155, 1.02))
    # arms: green box limbs + fists
    g.mirror_add(lambda: cube(0.15, 0.15, 0.24, bevel=0.02), "skin", (0.34, 0, 0.90))
    g.mirror_add(lambda: cube(0.14, 0.14, 0.20, top=(1.05, 1.05), bevel=0.02), "skin", (0.34, 0, 0.69))
    g.mirror_add(lambda: cube(0.14, 0.15, 0.12, bevel=0.025), "skin", (0.34, -0.005, 0.54))
    g.mirror_add(lambda: cube(0.05, 0.06, 0.05, bevel=0.01), "skin", (0.30, -0.06, 0.565))  # thumbs
    # legs (dark trousers) + boots
    g.mirror_add(lambda: cube(0.17, 0.18, 0.22, bevel=0.02), "pants", (0.12, 0, 0.47))
    g.mirror_add(lambda: cube(0.16, 0.17, 0.20, bevel=0.02), "pants", (0.12, 0, 0.27))
    g.mirror_add(lambda: cube(0.20, 0.30, 0.15, top=(0.95, 0.85), shift_top=(0, 0.02), bevel=0.03), "leather_dark", (0.12, -0.04, 0.085))
    g.mirror_add(lambda: cube(0.21, 0.31, 0.03), "grip", (0.12, -0.04, 0.015))  # sole
    # torn blue waist cloth front + back (jagged hem)
    hem = [(-0.11, 0.0), (0.11, 0.0), (0.10, -0.26), (0.06, -0.20), (0.03, -0.30), (-0.01, -0.21),
           (-0.05, -0.28), (-0.08, -0.19), (-0.10, -0.24)]
    g.add(slab(hem, 0.015), "cloth_blue", (0, -0.145, 0.72), rot=(-4, 0, 0))
    g.add(slab(hem, 0.015), "cloth_blue", (0, 0.145, 0.72), rot=(4, 0, 180))
    return g


def build_armor():
    g = Group()
    # chest leather + belt + bandolier
    g.add(cube(0.48, 0.31, 0.24, top=(1.08, 1.04), bevel=0.03), "leather", (0, 0, 0.90))
    g.add(cube(0.42, 0.29, 0.06, bevel=0.01), "leather_dark", (0, 0, 0.78))
    g.add(cube(0.45, 0.31, 0.07, bevel=0.01), "leather_dark", (0, 0, 0.71))
    g.add(cube(0.42, 0.33, 0.035), "cloth_red", (0, 0, 0.745))
    g.add(cube(0.08, 0.03, 0.62, bevel=0.008), "leather_dark", (0.0, -0.17, 0.90), rot=(0, -42, 0))  # strap front
    g.add(cube(0.08, 0.03, 0.62, bevel=0.008), "leather_dark", (0.0, 0.17, 0.90), rot=(0, 42, 0))  # strap back
    g.add(cube(0.07, 0.035, 0.10, bevel=0.01), "metal", (0.09, -0.19, 0.99), rot=(0, -42, 0))  # buckle
    g.add(torus(0.03, 0.008), "gold", (0.10, -0.195, 1.03), rot=(90, 0, 0))
    g.add(cube(0.05, 0.035, 0.05, bevel=0.01), "metal", (0.0, -0.165, 0.71))  # belt buckle
    # pauldrons: three stacked plates per shoulder
    for i, (z, w, d, out) in enumerate([(1.07, 0.26, 0.30, 0.31), (1.01, 0.27, 0.31, 0.35), (0.95, 0.24, 0.29, 0.39)]):
        g.mirror_add(lambda w=w, d=d: cube(w, d, 0.055, top=(0.85, 0.9), bevel=0.012),
                     "leather" if i != 1 else "leather_dark", (out, 0, z), rot=(0, 28 + i * 6, 0))
    for y in (-0.10, 0.0, 0.10):  # rivets on the top plate
        g.mirror_add(lambda: cube(0.02, 0.02, 0.02), "metal", (0.30, y, 1.105), rot=(0, 28, 0))
        g.mirror_add(lambda: cube(0.02, 0.02, 0.02), "metal", (0.42, y, 0.955), rot=(0, 40, 0))
    for y, z in ((-0.06, 0.93), (0.0, 0.92), (0.06, 0.93)):  # chainmail links under the pauldron
        g.mirror_add(lambda: torus(0.022, 0.006, 6, 3), "metal", (0.285, y, z), rot=(0, 90, 0))
    # bracers + gauntlet cuffs
    for z in (0.74, 0.66):
        g.mirror_add(lambda: cube(0.175, 0.175, 0.055, bevel=0.01), "leather", (0.34, 0, z))
    g.mirror_add(lambda: cube(0.165, 0.17, 0.04), "leather_dark", (0.34, 0, 0.605))
    # tassets: three stacked plates wrapping each thigh
    for i, z in enumerate((0.64, 0.565, 0.49)):
        g.mirror_add(lambda i=i: cube(0.20 + i * 0.01, 0.24 + i * 0.01, 0.085, top=(0.94, 0.94), bevel=0.012),
                     "leather" if i % 2 == 0 else "leather_dark", (0.13, -0.005, z), rot=(0, 6, 0))
        g.mirror_add(lambda: cube(0.018, 0.018, 0.018), "metal", (0.13, -0.13, z + 0.01))
    # knee pads + boot cuffs
    g.mirror_add(lambda: cube(0.14, 0.06, 0.10, bevel=0.015), "leather_dark", (0.12, -0.09, 0.37))
    for z in (0.21, 0.27):
        g.mirror_add(lambda: cube(0.195, 0.205, 0.05, bevel=0.01), "leather", (0.12, 0, z))
    return g


def build_eyes():
    g = Group()
    g.mirror_add(lambda: cube(0.065, 0.02, 0.035, top=(0.8, 1), bevel=0.006), "eye", (0.072, -0.152, 1.31), rot=(0, -14, 0))
    return g


def build_sword():
    """Scimitar in grip space: origin = centre of the grip, blade along -Z, edge toward -X."""
    g = Group()
    g.add(cone(0.022, 0.02, 0.15, seg=6), "grip", (0, 0, 0))
    for z in (-0.04, 0.0, 0.04):  # leather wraps
        g.add(cone(0.026, 0.026, 0.018, seg=6), "leather_dark", (0, 0, z))
    g.add(cube(0.20, 0.04, 0.035, bevel=0.008), "metal", (0, 0, -0.09))  # cross-guard
    g.add(cone(0.016, 0.0, 0.08, seg=4), "metal", (-0.12, 0, -0.06), rot=(0, 35, 0))  # guard hooks
    g.add(cone(0.016, 0.0, 0.08, seg=4), "metal", (0.12, 0, -0.06), rot=(0, -35, 0))
    g.add(torus(0.035, 0.009, 8, 4), "metal", (0.02, 0, 0.11), rot=(90, 0, 0))  # hooked pommel
    # curved blade: profile in (y, z), widening then clipped point
    n = 9
    edge, spine = [], []
    for i in range(n + 1):
        t = i / n
        z = -0.10 - 0.50 * t
        bend = -0.16 * t * t  # sweeps forward (toward the edge)
        w = 0.04 + 0.06 * math.sin(t * math.pi * 0.85)
        spine.append((0.025 + bend * 0.55, z))
        edge.append((-0.03 + bend - w * 0.6, z))
    tip = (-0.21, -0.64)
    prof = [(spine[0][0], spine[0][1])] + spine[1:] + [tip] + list(reversed(edge))
    g.add(slab(prof, 0.016), "blade", (0, 0, 0))  # flat of the blade faces front, edge toward -X
    return g


def main():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    img = make_atlas()
    atlas = atlas_material(img)
    coll = bpy.data.collections.new("GOBLIN_Mesh")
    bpy.context.scene.collection.children.link(coll)
    objs = {
        "Goblin_Body": finish(build_body(), "Goblin_Body", [atlas]),
        "Goblin_Armor": finish(build_armor(), "Goblin_Armor", [atlas]),
        "Goblin_Eyes": finish(build_eyes(), "Goblin_Eyes", [eye_material()]),
        "Goblin_Sword": finish(build_sword(), "Goblin_Sword", [atlas], uv_scale=3.0),
    }
    for ob in objs.values():
        coll.objects.link(ob)
    # sword rests in the right fist, blade angled forward/down like the reference
    sw = objs["Goblin_Sword"]
    sw.location = (-0.34, -0.01, 0.54)
    # edge curls inward toward the feet (Z 180 flips edge to +X), tip pushed forward
    sw.rotation_euler = (math.radians(30), math.radians(12), math.radians(180))
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs.values())
    print("built", list(objs), "tris:", tris)


if __name__ == "__main__":
    main()
