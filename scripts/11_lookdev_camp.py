# 11_lookdev_camp.py: Blender look-dev of the goblin war camp ground, with the pixel textures, before Roblox.
# Run headless:
#   /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python goblin/scripts/11_lookdev_camp.py
# Builds the same layout as roblox/BuildFlatGround.luau (in studs, scaled S = 0.3 m/stud to match the goblin),
# textures every block like Roblox will (one 16x16 texture tile per 4 studs, nearest-neighbour), appends the
# goblin from blender/goblin.blend, renders renders/lookdev_camp_{spawn,aerial}.png and saves
# blender/lookdev_camp.blend.
import math
import os
import random

import bmesh
import bpy
from mathutils import Euler, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
STYLE = os.environ.get("STYLE", "muted")  # STYLE=bright: textures/voxel_bright + sunny light, renders *_bright.png
LOOK = {
    "muted": dict(tex="voxel", sky=(0.28, 0.36, 0.5), sun=2.6, angle=8, sun_col=(1, 0.96, 0.9),
                  tuft=((62, 88, 40), (88, 112, 52))),
    "bright": dict(tex="voxel_bright", sky=(0.34, 0.6, 1.0), sun=3.4, angle=3, sun_col=(1, 0.95, 0.85),
                   tuft=((58, 132, 44), (104, 172, 58))),
    "soft": dict(tex="voxel_soft", sky=(0.42, 0.6, 0.92), sun=3.0, angle=10, sun_col=(1, 0.96, 0.88),
                 tuft=((70, 128, 54), (110, 164, 70))),
}[STYLE]
SUFFIX = "" if STYLE == "muted" else "_" + STYLE
TEX = os.path.join(ROOT, "textures", LOOK["tex"])
S = 0.3  # metres per Roblox stud
rng = random.Random(21)

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
scene = bpy.context.scene


def R(x, y, z):  # Roblox position (studs, Y up, -Z forward) -> Blender (metres, Z up)
    return Vector((x * S, -z * S, y * S))


# ---------- materials ----------
def tex_mat(name, image, tint=(1, 1, 1)):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.95
    img = nt.nodes.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(os.path.join(TEX, image + ".png"), check_existing=True)
    img.interpolation = "Closest"  # pixels stay square, like the 64x-upscaled textures in Roblox
    obj = nt.nodes.new("ShaderNodeObjectInfo")  # per-block tint = Part.Color in Roblox
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type, mul.blend_type = "RGBA", "MULTIPLY"
    mul.inputs["Factor"].default_value = 1
    nt.links.new(img.outputs["Color"], mul.inputs[6])
    nt.links.new(obj.outputs["Color"], mul.inputs[7])
    nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
    m["tint"] = tint
    return m


def flat_mat(name, rgb, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    c = (*[(v / 255) ** 2.2 for v in rgb], 1)
    bsdf.inputs["Base Color"].default_value = c
    bsdf.inputs["Roughness"].default_value = 0.9
    if emit:
        bsdf.inputs["Emission Color"].default_value = c
        bsdf.inputs["Emission Strength"].default_value = emit
    return m


MAT = {
    "grass": tex_mat("grass", "grass"),
    "mud": tex_mat("mud", "dirt"),
    "bark": tex_mat("bark", "bark"),
    "stone": tex_mat("stone", "mossy_stone"),
    "bone": tex_mat("bone", "bone"),
    "cloth": tex_mat("cloth", "cloth"),
    "black": flat_mat("black", (30, 24, 22)),
    "iron": flat_mat("iron", (54, 52, 52)),
    "fire0": flat_mat("fire0", (255, 120, 30), 8),
    "fire1": flat_mat("fire1", (255, 190, 50), 8),
    "fire2": flat_mat("fire2", (255, 240, 140), 8),
    "tuft": flat_mat("tuft", LOOK["tuft"][0]),
    "tuft2": flat_mat("tuft2", LOOK["tuft"][1]),
}


# ---------- blocks: box mesh with Roblox-style UVs (4 studs per texture tile on every face) ----------
_mesh_cache = {}


def box_mesh(sx, sy, sz):
    key = (round(sx, 3), round(sy, 3), round(sz, 3))
    if key in _mesh_cache:
        return _mesh_cache[key]
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.verts.ensure_lookup_table()
    for v in bm.verts:  # Roblox size (x, y up, z) -> Blender (x, z->-y, y->z)
        v.co = Vector((v.co.x * sx, v.co.y * sz, v.co.z * sy)) * S
    uv = bm.loops.layers.uv.new()
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        u_i, v_i = [(1, 2), (0, 2), (0, 1)][ax]
        for loop in f.loops:
            co = loop.vert.co / S
            loop[uv].uv = (co[u_i] / 4 + 0.5, co[v_i] / 4 + 0.5)
    me = bpy.data.meshes.new("box")
    bm.to_mesh(me)
    bm.free()
    _mesh_cache[key] = me
    return me


col = bpy.data.collections.new("Camp")
scene.collection.children.link(col)


def block(size, pos, mat, tint=1.0, rot=(0, 0, 0)):
    me = box_mesh(*size)
    if not me.materials:
        me.materials.append(MAT[mat])
    o = bpy.data.objects.new(mat, me)
    if me.materials[0] is not MAT[mat]:  # same size, different material: give this object its own
        o.data = me.copy()
        o.data.materials[0] = MAT[mat]
    o.location = R(*pos)
    o.rotation_euler = Euler(rot)
    o.color = (tint, tint, tint, 1)
    col.objects.link(o)
    return o


# ---------- layout (same numbers as BuildFlatGround.luau) ----------
CX, CZ, RX, RZ = 0, -21, 36, 17


def oval(x, z):
    return ((x - CX) / RX) ** 2 + ((z - CZ) / RZ) ** 2


def noise2(x, z):  # cheap smooth value noise for grass patches
    return (math.sin(x * 0.21 + 1.3) * math.cos(z * 0.17 - 0.4) + math.sin((x + z) * 0.09)) * 0.5


def tuft(x, z):  # 3-5 thin stepped blades
    for _ in range(rng.randint(3, 5)):
        h = rng.uniform(0.6, 1.8)
        block((0.3, h, 0.3), (x + rng.uniform(-0.6, 0.6), h / 2, z + rng.uniform(-0.6, 0.6)),
              rng.choice(("tuft", "tuft", "tuft2")), 1, (rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 0))


for x in range(-60, 60, 4):
    for z in range(-64, 28, 4):
        cx, cz = x + 2, z + 2
        d = oval(cx, cz)
        mud = d <= 0.82 or (d <= 1.05 and rng.random() < 0.5) or (cz <= 6 and cz > -10 and abs(cx) <= 4)
        if mud:
            block((4, 1, 4), (cx, -0.5, cz), "mud", 0.8 if rng.random() < 0.22 else rng.uniform(0.9, 1.0))
        else:
            t = min(1, max(0, noise2(cx, cz) * 0.6 + 0.6 + rng.uniform(-0.1, 0.1)))
            block((4, 1, 4), (cx, -0.5, cz), "grass", 0.85 + 0.15 * t)
            if d > 1.15 and rng.random() < 0.3:
                tuft(cx + rng.uniform(-1.5, 1.5), cz + rng.uniform(-1.5, 1.5))


def stake(x, z, h, out_x, out_z, w=1.8, tips=True):
    tilt = math.radians(rng.uniform(2, 7))
    rot = (out_z * tilt, out_x * tilt, 0)  # lean outward (Roblox -Z is Blender +Y)
    block((w, h, w), (x, h / 2, z), "bark", rng.uniform(0.8, 1), rot)
    block((w + 0.2, 0.3, w + 0.2), (x, h * 0.72, z), "iron", 1, rot)
    if tips:
        block((w * 0.75, 0.7, w * 0.75), (x, h + 0.35, z), "bone", 0.78, rot)
        block((w * 0.5, 0.6, w * 0.5), (x, h + 1.0, z), "bone", 0.78, rot)
        block((w * 0.25, 0.5, w * 0.25), (x, h + 1.55, z), "bone", 0.78, rot)


def rail(p, q, y):
    dx, dz = q[0] - p[0], q[1] - p[1]
    block((math.hypot(dx, dz) + 0.4, 0.7, 0.6), ((p[0] + q[0]) / 2, y, (p[1] + q[1]) / 2), "bark", 0.8,
          (0, 0, math.atan2(-dz, dx)))


def skull(x, y, z, yaw=0.0):
    rot = (0, 0, yaw)
    block((1.4, 1.2, 1.3), (x, y + 0.6, z), "bone", 0.82, rot)
    block((1, 0.4, 1), (x, y - 0.1, z), "bone", 0.82, rot)
    fx, fz = math.sin(yaw) * 0.66, math.cos(yaw) * 0.66  # face toward the spawn (+Z Roblox) when yaw = 0
    for ex in (-0.35, 0.35):
        block((0.38, 0.38, 0.1), (x + ex * math.cos(yaw) + fx, y + 0.65, z + fz), "black", 1, rot)
    block((0.2, 0.25, 0.1), (x + fx, y + 0.3, z + fz), "black", 1, rot)


def banner(x, top, z, w=2.2, h=5):  # tattered cloth: main sheet + ragged strips of uneven length
    block((w, h, 0.2), (x, top - h / 2, z), "cloth", 0.8)
    n = 4
    for i in range(n):
        l = rng.uniform(0.6, 2.2)
        block((w / n, l, 0.2), (x - w / 2 + w / n * (i + 0.5), top - h - l / 2, z), "cloth", rng.uniform(0.65, 0.8))


ring = []
for i in range(96):
    a = i / 96 * math.tau
    x, z = CX + math.sin(a) * (RX + 3), CZ + math.cos(a) * (RZ + 3)
    if z > CZ and abs(x) < 9:
        ring.append(None)
        continue
    stake(x, z, rng.uniform(4, 5.5), math.sin(a), math.cos(a))
    ring.append((x, z))
for p, q in zip(ring, ring[1:] + ring[:1]):
    if p and q:
        rail(p, q, 2.4)

gz = CZ + RZ + 3
for x in (-9, 9):
    stake(x, gz, 8, 0, 1, 2.6, tips=False)
    skull(x, 8.2, gz)
    banner(x, 7.4, gz + 1.45)
block((20, 1, 1), (0, 6.8, gz), "bark", 0.85)
for x in (-4.5, 0, 4.5):
    block((0.15, 1.4, 0.15), (x, 5.6, gz), "iron")
    skull(x, 3.7, gz)

for bx in (-16, 16):
    block((0.6, 9, 0.6), (bx, 4.5, -2), "bark")
    banner(bx + 1.6, 8.6, -2, 2.6, 3.5)

for i in range(8):  # campfire
    a = i / 8 * math.tau
    block((0.9, 0.7, 0.9), (math.sin(a) * 1.9, 0.35, -36 + math.cos(a) * 1.9), "stone")
for yaw in (0.4, -0.5):  # crossed logs
    block((3.4, 0.6, 0.6), (0, 0.4, -36), "bark", 0.7, (0, 0, yaw))
for i in range(3):
    s = 1.6 - (i + 1) * 0.4 + 0.4
    block((s, 0.9, s), (0, 0.6 + (i + 1) * 0.7, -36), f"fire{i}", 1, (0, 0, (i + 1) * 0.5))
fire_light = bpy.data.objects.new("FireLight", bpy.data.lights.new("FireLight", "POINT"))
fire_light.data.color, fire_light.data.energy = (1, 0.55, 0.2), 250
fire_light.location = R(0, 3, -36)
col.objects.link(fire_light)

for (tx, tz) in ((-50, -16), (50, -26), (-26, -48), (28, -48)):
    for i in range(5):
        w = 13 - i * 2.5
        for _ in range(5):
            block((w * rng.uniform(0.5, 0.8), 2, w * rng.uniform(0.5, 0.8)),
                  (tx + rng.uniform(-2.5, 2.5), 1 + i * 2, tz + rng.uniform(-2.5, 2.5)), "stone", rng.uniform(0.7, 0.95))

for ix in (-4, 0, 4):  # spawn pad: 3x3 slabs with grass showing in the seams
    for iz in (-4, 0, 4):
        block((3.7, 1, 3.7), (ix, 0.5, 10 + iz), "stone", rng.uniform(0.82, 1))

# ---------- goblins (appended from goblin.blend, instanced on the showcase grid) ----------
with bpy.data.libraries.load(os.path.join(ROOT, "blender", "goblin.blend"), link=False) as (src, dst):
    dst.collections = [c for c in src.collections if c in ("GOBLIN_Mesh", "GOBLIN_Rig")]
gob = bpy.data.collections.new("Goblin")
for c in dst.collections:
    gob.children.link(c)
for x, z in ((0, -12), (-9, -12), (9, -12), (-18, -21), (18, -21), (0, -30)):
    inst = bpy.data.objects.new("GoblinInst", None)
    inst.instance_type, inst.instance_collection = "COLLECTION", gob
    inst.location = R(x, 0, z)
    col.objects.link(inst)

# ---------- light, world, render ----------
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy, sun.data.angle = LOOK["sun"], math.radians(LOOK["angle"])  # bigger angle = softer shadows
sun.data.color = LOOK["sun_col"]
sun.rotation_euler = Euler((math.radians(50), math.radians(10), math.radians(35)))
scene.collection.objects.link(sun)
world = bpy.data.worlds.new("Sky")
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (*LOOK["sky"], 1)
bg.inputs["Strength"].default_value = 1.2 if STYLE == "soft" else 1.0  # more sky fill = softer shadows
scene.world = world

scene.render.engine = next(e for e in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE") if e in
                           [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items])
scene.view_settings.view_transform = "Standard"  # punchy game colors, like Roblox
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
scene.render.film_transparent = False

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 28
scene.collection.objects.link(cam)
scene.camera = cam
os.makedirs(os.path.join(ROOT, "renders"), exist_ok=True)


def shot(name, eye, look):
    cam.location = R(*eye)
    cam.rotation_euler = (R(*look) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(ROOT, "renders", f"lookdev_camp_{name}{SUFFIX}.png")
    bpy.ops.render.render(write_still=True)


shot("spawn", (0, 7, 16), (0, 3, -22))
shot("aerial", (-30, 26, 24), (2, 0, -22))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "blender", f"lookdev_camp{SUFFIX}.blend"))
print("LOOKDEV DONE")
