# 16_swords.py: the held Wooden Sword at levels 1-5 ("phases" on the owner's concept sheet, GAME-35), low-poly and
# flat shaded: faceted dark blade (diamond cross-section, barbs from phase 2), purple grip and guard, gold horns and
# pommel, amber / cyan / pink gems, neon lines on the blade at phase 4 (cyan) and 5 (cyan fork + pink).
# Run headless:
#   /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python goblin/scripts/16_swords.py
# Built in studs, Z up; the grip is centred on the origin, the blade points +Z, flat faces toward +/-Y. One mesh object
# per colour (Studio imports one MeshPart per object; colours stay editable, *Glow objects get Neon). Writes
# export/Sword_Phase<n>.fbx, blender/swords.blend and renders/swords_blender.png.
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else "/Users/chinnaphat/Desktop/cedt/roblox/goblin/scripts")
import voxel_kit  # noqa: E402

COLORS = {  # sRGB 0-255, the same values go to MeshPart.Color in Studio
    "Steel": (58, 60, 76),
    "Silver": (196, 200, 212),
    "Gold": (214, 168, 72),
    "Purple": (92, 64, 140),
    "PurpleDark": (60, 42, 96),
    "Amber": (255, 196, 40),
    "CyanGlow": (80, 230, 255),
    "PinkGlow": (255, 80, 230),
}
# What changes per phase: blade length / half-width, barbs per edge, horn length, purple wing layers, blade gems,
# neon line style.
PHASES = [
    dict(blade=2.4, hw=0.18, barbs=0, horn=0.45, wings=0, gems=False, side_gems=False, line=None),
    dict(blade=2.9, hw=0.2, barbs=2, horn=0.7, wings=0, gems=False, side_gems=True, line=None),
    dict(blade=3.3, hw=0.22, barbs=3, horn=0.95, wings=1, gems=True, side_gems=True, line=None),
    dict(blade=3.6, hw=0.23, barbs=4, horn=1.05, wings=2, gems=True, side_gems=True, line="cyan"),
    dict(blade=4.1, hw=0.25, barbs=5, horn=1.2, wings=3, gems=True, side_gems=True, line="fork"),
]
RIDGE = 0.075  # half thickness of the blade along its centre ridge
GLOW_PROUD = 0.012


class Kit:
    """One bmesh per colour; shapes are added with a world matrix."""

    def __init__(self):
        self.bms = {}

    def bm(self, colour):
        return self.bms.setdefault(colour, bmesh.new())

    def cube(self, colour, size, at, rot=Matrix.Identity(4), bevel=0.0):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        if bevel:
            bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel / max(size), segments=1, affect="EDGES")
        bmesh.ops.transform(bm, matrix=Matrix.Translation(at) @ rot @ Matrix.Diagonal((*size, 1)), verts=bm.verts)
        self.merge(colour, bm)

    def cone(self, colour, r1, r2, depth, at, rot=Matrix.Identity(4), segs=4, scale=(1, 1, 1)):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
        # base at z=0, growing +z
        bmesh.ops.translate(bm, vec=(0, 0, depth / 2), verts=bm.verts)
        bmesh.ops.transform(bm, matrix=Matrix.Translation(at) @ rot @ Matrix.Diagonal((*scale, 1)), verts=bm.verts)
        self.merge(colour, bm)

    def gem(self, colour, r, at, depth_scale=1.0):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)
        bmesh.ops.transform(bm, matrix=Matrix.Translation(at) @ Matrix.Diagonal((1, depth_scale, 1, 1)), verts=bm.verts)
        self.merge(colour, bm)

    def plate(self, colour, pts, y, thick=0.02):
        """Flat prism: polygon `pts` [(x, z)] in the blade plane, centred at depth y."""
        bm = self.bm(colour)
        front = [bm.verts.new((x, y - thick / 2, z)) for x, z in pts]
        back = [bm.verts.new((x, y + thick / 2, z)) for x, z in pts]
        bm.faces.new(front)
        bm.faces.new(list(reversed(back)))
        for i in range(len(pts)):
            j = (i + 1) % len(pts)
            bm.faces.new((front[j], front[i], back[i], back[j]))

    def merge(self, colour, src):
        me = bpy.data.meshes.new("tmp")
        src.to_mesh(me)
        src.free()
        self.bm(colour).from_mesh(me)
        bpy.data.meshes.remove(me)


def lean(out, deg):
    """Rotation that tips +Z outward (toward out*X) by deg."""
    return Matrix.Rotation(math.radians(-out * deg), 4, "Y")


def blade(kit, ph, z0):
    """Faceted blade: rings of a diamond cross-section lofted up a width profile with barbs, closed by a point."""
    hw, length = ph["hw"], ph["blade"]
    tip = hw * 4.0
    body = length - tip
    prof = [(z0, hw * 0.9), (z0 + 0.12, hw)]
    n = ph["barbs"]
    if n:
        span = body * 0.75
        step = span / n
        bw, bh = 0.06 + 0.008 * n, min(0.32, step * 0.75)
        for i in range(n):
            zb = z0 + 0.45 + i * step
            prof += [(zb - 0.001, hw), (zb, hw + bw), (zb + bh, hw)]
    prof += [(z0 + body, hw), (z0 + length, 0.0)]
    bm = kit.bm("Steel")
    rings = []
    for z, w in prof:
        t = RIDGE * (min(w, hw) / hw if w < hw else 1.0)
        if w == 0.0:
            rings.append([bm.verts.new((0, 0, z))])
        else:
            rings.append([bm.verts.new(v) for v in ((-w, 0, z), (0, -t, z), (w, 0, z), (0, t, z))])
    bm.faces.new(list(reversed(rings[0])))
    for a, b in zip(rings, rings[1:]):
        for k in range(4):
            k2 = (k + 1) % 4
            quad = [a[k], a[k2], b[k2 % len(b)], b[k % len(b)]]
            uniq = list(dict.fromkeys(quad))
            if len(uniq) >= 3:
                bm.faces.new(uniq)
    return body


def build(n):
    ph = PHASES[n - 1]
    kit = Kit()
    # Grip: octagonal purple core, dark bands, collar; pommel: gold diamond with a cyan gem
    kit.cone("Purple", 0.13, 0.13, 1.1, Vector((0, 0, -0.55)), segs=8)
    for z in (-0.35, 0.0, 0.35):
        kit.cone("PurpleDark", 0.155, 0.155, 0.08, Vector((0, 0, z - 0.04)), segs=8)
    kit.cone("PurpleDark", 0.17, 0.14, 0.14, Vector((0, 0, -0.69)), segs=8)
    kit.cone("Gold", 0.2, 0.0, 0.22, Vector((0, 0, -0.84)), scale=(1, 0.55, 1))  # pommel, upper half
    kit.cone("Gold", 0.2, 0.0, 0.22, Vector((0, 0, -0.84)), rot=Matrix.Rotation(math.pi, 4, "X"), scale=(1, 0.55, 1))
    kit.gem("CyanGlow", 0.1, Vector((0, 0, -0.84)), depth_scale=1.4)
    # Guard: purple block, gold collar, amber centre gem in a gold rim, gold horns, purple wings and down-spikes
    gw = 0.7 + 0.08 * n
    kit.cube("Gold", (0.5, 0.3, 0.1), Vector((0, 0, 0.6)), bevel=0.02)
    kit.cube("Purple", (gw, 0.3, 0.3), Vector((0, 0, 0.8)), bevel=0.05)
    kit.cone("Gold", 0.2, 0.2, 0.32, Vector((0, -0.16, 0.8)), rot=Matrix.Rotation(-math.pi / 2, 4, "X"), segs=8)
    kit.gem("Amber", 0.15, Vector((0, 0, 0.8)), depth_scale=1.9)
    for out in (-1, 1):
        kit.cone("Gold", 0.15, 0.0, ph["horn"], Vector((out * gw * 0.42, 0, 0.9)), rot=lean(out, 28), scale=(1, 0.55, 1))
        for w in range(1, ph["wings"] + 1):
            kit.cone("Purple", 0.12, 0.0, ph["horn"] * (0.85 - 0.12 * w), Vector((out * (gw * 0.47 + 0.04 * w), 0, 0.93 - 0.06 * w)),
                     rot=lean(out, 44 + 16 * w), scale=(1, 0.5, 1))
        if n >= 3:
            kit.cone("PurpleDark", 0.07, 0.0, 0.32, Vector((out * gw * 0.22, 0, 0.68)), rot=lean(out, 150), scale=(1, 0.6, 1))
        if ph["side_gems"]:
            kit.gem("CyanGlow", 0.085, Vector((out * gw * 0.36, 0, 0.8)), depth_scale=2.3)
    # Blade, the silver insert with cyan / pink / cyan gems, neon lines
    z0 = 0.95
    body = blade(kit, ph, z0)
    if ph["gems"]:
        for side in (-1, 1):  # silver inlay on each face: a triangle tapering up from the guard
            kit.plate("Silver", [(-ph["hw"] * 0.7, z0), (ph["hw"] * 0.7, z0), (0, z0 + 1.05)], side * (RIDGE + 0.004))
        for i, c in enumerate(("CyanGlow", "PinkGlow", "CyanGlow")):
            kit.gem(c, 0.085 - 0.01 * i, Vector((0, 0, z0 + 0.2 + 0.27 * i)), depth_scale=2.1)
    lo, hi = z0 + 1.05, z0 + body - 0.12

    def line(colour, x, a, b):
        for side in (-1, 1):  # one strip on each face, sitting on the ridge
            kit.cube(colour, (0.07, 0.02, b - a), Vector((x, side * (RIDGE - abs(x) * RIDGE / ph["hw"] + GLOW_PROUD), (a + b) / 2)))

    if ph["line"] == "cyan":
        mid = lo + (hi - lo) * 0.5
        line("CyanGlow", 0, lo, mid - 0.06)
        line("CyanGlow", 0, mid + 0.06, hi)
    elif ph["line"] == "fork":
        mid = lo + (hi - lo) * 0.5
        line("CyanGlow", -0.07, lo, mid)
        line("CyanGlow", 0.07, lo, mid)
        line("PinkGlow", 0, mid + 0.08, hi)
    # Objects, one per colour
    root = bpy.data.objects.new(f"Sword_Phase{n}", None)
    bpy.context.collection.objects.link(root)
    objs = []
    for colour, bm in kit.bms.items():
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        me = bpy.data.meshes.new(f"Sword_Phase{n}_{colour}")
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(me.name, me)
        ob.data.materials.append(voxel_kit.material(colour, COLORS[colour]))
        bpy.context.collection.objects.link(ob)
        ob.parent = root
        objs.append(ob)
    return root, objs


def render_preview(path):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 10.6
    cam.location = (0, -20, 2.05)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


voxel_kit.clear_scene()
os.makedirs(os.path.join(voxel_kit.ROOT, "export"), exist_ok=True)
for n in range(1, 6):
    root, objs = build(n)
    voxel_kit.export(root, objs, os.path.join(voxel_kit.ROOT, "export", f"Sword_Phase{n}.fbx"))
    root.location = ((n - 3) * 2.0, 0, 0)  # laid out for the preview, after export at the origin
    print(f"Sword_Phase{n}: {len(objs)} meshes, {sum(voxel_kit.tris(o) for o in objs)} tris")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(voxel_kit.ROOT, "blender", "swords.blend"))
render_preview(os.path.join(voxel_kit.ROOT, "renders", "swords_blender.png"))
