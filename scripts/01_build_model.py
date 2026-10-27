# Goblin enemy - stage 1: voxel model + pixel atlas.
# Run inside Blender (Scripting tab > Open > Run) or: blender -b -P 01_build_model.py
#
# The goblin is painted into a voxel grid (1 voxel = V metres), one label per voxel = the bone that moves it.
# Each mesh is greedy-meshed (merged flat quads) and every voxel face becomes one texel in a shared atlas,
# upscaled S x S with edge gutters so Roblox's bilinear filtering keeps the pixel-art look.
# Axes: +X = goblin's left, -Y = front, +Z = up. Feet at Z = 0. ~78 voxels tall (1.75 m, ~6.3 studs).
import bpy, colorsys, math, os
import numpy as np
from mathutils import Vector

ROOT = os.environ.get("GOBLIN_ROOT", "/Users/chinnaphat/Desktop/cedt/roblox/goblin")
TEX = os.path.join(ROOT, "textures", "goblin_atlas.png")
V = 0.0225
ATLAS_W = 1024
SATURATION, BRIGHTNESS = 1.05, 1.0  # global vividness on top of the palette
# pixel-art shading baked per texel (multipliers): lit top rim, dark outline on the other edges, AO in corners
SHADE = {"rim": 1.2, "bottom": 0.42, "side": 0.58, "top_edge": 0.72, "under_edge": 0.45, "concave": 0.62,
         "material": 0.74, "face_up": 1.06, "face_down": 0.8}
NO_OUTLINE = ("eye", "eye_hot", "gold", "rivet", "teeth", "blade_edge")

PAL = {  # sRGB 0-255 shade variants, picked per voxel by hash
    "skin": [(98, 160, 52), (86, 146, 46), (108, 170, 58), (78, 134, 42)],
    "skin_dk": [(60, 108, 34), (52, 96, 30)],
    "skin_lt": [(126, 184, 70), (118, 178, 64)],
    "ear_in": [(96, 100, 42), (84, 88, 38), (104, 108, 46)],
    "ear_deep": [(70, 66, 32), (62, 58, 28)],
    "ear_tip": [(112, 64, 36), (96, 54, 32), (124, 74, 40)],
    "hair": [(112, 60, 32), (92, 48, 26), (130, 74, 40), (74, 38, 22)],
    "eye": [(255, 206, 40), (255, 192, 30)],
    "eye_hot": [(255, 246, 170)],
    "mouth": [(44, 16, 14), (36, 12, 12)],
    "teeth": [(238, 226, 188), (220, 206, 164)],
    "scarf": [(130, 38, 32), (112, 32, 28), (146, 48, 38)],
    "leather": [(132, 78, 42), (124, 72, 38), (138, 84, 46), (118, 68, 36)],
    "leather_dk": [(84, 48, 28), (72, 40, 24), (94, 54, 30)],
    "tunic": [(76, 44, 26), (66, 38, 22), (84, 50, 30)],
    "pants": [(70, 42, 26), (62, 36, 22), (78, 46, 28)],
    "boot": [(100, 58, 32), (88, 50, 28), (112, 66, 36)],
    "sole": [(48, 30, 20), (40, 26, 18)],
    "rivet": [(70, 196, 196), (52, 170, 176)],
    "mail_lt": [(150, 186, 196), (136, 172, 184)],
    "mail_dk": [(78, 104, 120), (66, 92, 108)],
    "steel": [(156, 162, 168), (130, 136, 142)],
    "gold": [(246, 196, 44), (222, 160, 24)],
    "cloth": [(42, 84, 146), (34, 68, 124), (54, 100, 164), (28, 56, 104)],
    "blade": [(150, 200, 206), (134, 184, 194), (166, 214, 220)],
    "blade_edge": [(214, 240, 240), (200, 232, 234)],
    "blade_dk": [(96, 140, 154), (84, 126, 140)],
    "rust": [(150, 72, 50), (124, 58, 44), (170, 92, 60)],
    "guard": [(58, 92, 124), (46, 76, 104), (70, 108, 140)],
    "grip": [(64, 38, 24), (50, 30, 20)],
}

LABELS = ["", "Head", "Ear_L", "Ear_R", "Eyes", "UpperTorso", "LowerTorso", "Cloth_F", "Cloth_B",
          "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
          "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "Weapon"]
LID = {n: i for i, n in enumerate(LABELS)}
BONE_OF = {"Eyes": "Head"}  # label -> deform bone (default: same name)

PARTS = ["Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
         "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg",
         "RightLowerLeg", "RightFoot"]
MESHES = {p + "_Geo": [p] for p in PARTS}
MESHES["Head_Geo"] += ["Ear_L", "Ear_R"]
MESHES["LowerTorso_Geo"] += ["Cloth_F", "Cloth_B"]
MESHES["Eyes_Geo"] = ["Eyes"]


def h3(x, y, z, seed=0):
    n = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (seed * 2654435761)
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


PAL_ID = {n: i for i, n in enumerate(PAL)}


def shade(name, x, y, z):
    s = PAL[name]
    c = s[int(h3(x, y, z) * len(s)) % len(s)]
    j = 1.0 + (h3(x, y, z, 7) - 0.5) * 0.16
    if h3(x, y, z, 9) < 0.07:
        j *= 0.8  # sparse dark specks: the hand-placed grain of pixel art
    h, sat, v = colorsys.rgb_to_hsv(*(ch / 255.0 for ch in c))
    return list(colorsys.hsv_to_rgb(h, min(1.0, sat * SATURATION), min(1.0, v * BRIGHTNESS * j)))


def ax(x):
    """Mirror-safe distance from the centre line for a voxel index (cell -1 mirrors cell 0)."""
    return x if x >= 0 else -x - 1


class Grid:
    def __init__(self, lo, hi):
        self.lo = np.array(lo)
        shape = tuple(np.array(hi) - self.lo)
        self.lab = np.zeros(shape, np.int16)
        self.mat = np.full(shape, -1, np.int16)
        self.col = np.zeros(shape + (3,), np.float32)

    def box(self, x0, x1, y0, y1, z0, z1, label, color=None):
        lid = LID[label]
        lo, hi = self.lo, self.lo + np.array(self.lab.shape)
        for x in range(max(x0, lo[0]), min(x1, hi[0])):
            for y in range(max(y0, lo[1]), min(y1, hi[1])):
                for z in range(max(z0, lo[2]), min(z1, hi[2])):
                    i = (x - lo[0], y - lo[1], z - lo[2])
                    self.lab[i] = lid
                    self.mat[i] = -1
                    if lid:
                        name = color(x, y, z) if callable(color) else color
                        self.col[i] = shade(name, x, y, z)
                        self.mat[i] = PAL_ID[name]

    def clear(self, x0, x1, y0, y1, z0, z1):
        self.box(x0, x1, y0, y1, z0, z1, "")

    def mbox(self, x0, x1, y0, y1, z0, z1, label, color=None):
        """Paint on the goblin's left (+X) and mirror to the right."""
        self.box(x0, x1, y0, y1, z0, z1, label.format(S="Left", s="L"), color)
        self.box(-x1, -x0, y0, y1, z0, z1, label.format(S="Right", s="R"), color)

    def mclear(self, x0, x1, y0, y1, z0, z1):
        self.clear(x0, x1, y0, y1, z0, z1)
        self.clear(-x1, -x0, y0, y1, z0, z1)


def plates(z0, base="leather"):
    """Layered armour band: dark bottom row, rivet row above it, leather elsewhere."""
    def f(x, y, z):
        if z == z0:
            return "leather_dk"
        if z == z0 + 1 and (ax(x) + y) % 4 == 1:
            return "rivet"
        return base
    return f


# ------------------------------------------------------------------ the goblin
WRINKLES = {(-3, 66), (-2, 65), (-1, 65), (0, 65), (1, 65), (2, 66), (-5, 67), (4, 67), (-1, 67), (0, 67)}


def paint_body(G):
    # boots + feet (ankle split at z=5)
    G.mbox(1, 10, -11, 5, 0, 1, "{S}Foot", "sole")
    G.mbox(1, 10, -11, 5, 1, 5, "{S}Foot", lambda x, y, z: "leather_dk" if z == 4 and y < -6 else "boot")
    G.mclear(1, 10, -11, -10, 4, 5)
    G.mbox(1, 10, -6, 5, 5, 9, "{S}LowerLeg", "boot")
    G.mbox(0, 11, -7, 6, 9, 11, "{S}LowerLeg",
           lambda x, y, z: "rivet" if z == 10 and (ax(x) + y) % 4 == 1 else ("leather_dk" if z == 9 else "leather"))
    G.mbox(1, 10, -5, 5, 11, 14, "{S}LowerLeg", "pants")
    G.mbox(2, 9, -7, -5, 11, 15, "{S}LowerLeg",
           lambda x, y, z: "rivet" if ax(x) == 5 and z == 13 else "leather_dk")  # knee pad
    # thighs + layered tassets
    G.mbox(1, 10, -5, 5, 14, 27, "{S}UpperLeg", "pants")
    G.mbox(1, 12, -7, 7, 15, 19, "{S}UpperLeg", plates(15))
    G.mbox(1, 12, -7, 6, 19, 23, "{S}UpperLeg", plates(19))
    G.mbox(1, 11, -6, 6, 23, 27, "{S}UpperLeg", plates(23))

    # hips: tunic, red sash, belt, buckle
    G.box(-10, 10, -6, 6, 27, 34, "LowerTorso", "tunic")
    G.box(-12, 12, -8, 8, 28, 30, "LowerTorso", "scarf")
    G.box(-12, 12, -8, 8, 30, 33, "LowerTorso", lambda x, y, z: "leather" if z == 31 and x % 4 == 0 else "leather_dk")
    G.box(-2, 2, -9, -8, 30, 33, "LowerTorso", lambda x, y, z: "gold" if z == 31 and x in (-1, 0) else "steel")
    # torn blue waist cloth, front + back (strands of uneven length)
    for lab, y in (("Cloth_F", -9), ("Cloth_B", 8)):
        for x in range(-5, 5):
            bottom = 13 + int(h3(x, y, 1) * 6)
            if h3(x, y, 2) < 0.25:
                bottom -= 3  # long drip strand
            for z in range(bottom, 30):
                G.box(x, x + 1, y, y + 1, z, z + 1, lab, "cloth")

    # torso: tunic core, plated chest/back/sides
    G.box(-11, 11, -7, 7, 34, 52, "UpperTorso", "tunic")
    chest = lambda x, y, z: ("leather_dk" if z % 4 == 0 else
                             "rivet" if z % 8 == 2 and ax(x) % 4 == 1 else "leather")
    G.box(-10, 10, -8, -7, 36, 50, "UpperTorso", chest)
    G.box(-10, 10, 7, 8, 36, 50, "UpperTorso", chest)
    G.mbox(11, 12, -6, 6, 36, 48, "UpperTorso", chest)
    # scarf collar + front/back triangles
    G.box(-9, 9, -9, 8, 48, 53, "UpperTorso", lambda x, y, z: "leather_dk" if z == 48 else "scarf")
    for z in range(41, 48):
        half = max(1, 7 - (47 - z))
        G.box(-half, half, -10, -9, z, z + 1, "UpperTorso", "scarf")
        G.box(-half, half, 8, 9, z, z + 1, "UpperTorso", "scarf")
    # bandolier: right shoulder (-X) to left hip (+X), front and back
    strap = lambda x, y, z: "leather" if (x + z) % 5 == 0 else "leather_dk"
    for z in range(34, 52):
        xc = round(10 - 20 * (z - 34) / 17)
        G.box(xc - 1, xc + 2, -10, -9, z, z + 1, "UpperTorso", strap)
        G.box(xc - 1, xc + 2, 8, 9, z, z + 1, "UpperTorso", strap)
    G.box(-7, -3, -11, -10, 42, 46, "UpperTorso", lambda x, y, z: "rivet" if (x + z) % 3 == 0 else "steel")
    for y in (-11, 9):
        G.box(-7, -3, y, y + 1, 46, 50, "UpperTorso", "gold")
        G.clear(-6, -4, y, y + 1, 47, 49)
    # chainmail at the armpits
    mail = lambda x, y, z: "mail_lt" if (x + z) % 2 == 0 else "mail_dk"
    G.mbox(9, 13, -9, -7, 40, 46, "UpperTorso", mail)
    G.mbox(11, 13, -6, 6, 41, 46, "UpperTorso", mail)

    # pauldrons: top plate is fixed to the shoulder (torso), the lower lames swing with the upper arm
    G.mbox(9, 19, -8, 8, 51, 54, "UpperTorso", plates(51))
    G.mbox(10, 20, -9, 9, 48, 51, "{S}UpperArm", plates(48))
    G.mbox(12, 21, -9, 9, 45, 48, "{S}UpperArm", plates(45))
    G.mclear(17, 19, -8, 8, 53, 54)
    G.mbox(12, 20, -4, 4, 39, 49, "{S}UpperArm", "skin")
    G.mbox(12, 20, -4, 4, 30, 39, "{S}LowerArm", "skin")
    G.mbox(11, 21, -5, 5, 31, 34, "{S}LowerArm", plates(31))
    G.mbox(11, 21, -5, 5, 35, 38, "{S}LowerArm", plates(35))

    def fist(x, y, z):
        if y in (-5, 4) and ax(x) in (15, 16) and z in (25, 26):
            return "mouth"  # grip hole
        if y == -5 and z in range(22, 28) and ax(x) % 2 == 1:
            return "skin_dk"  # finger creases
        return "skin"
    G.mbox(11, 21, -5, 5, 21, 30, "{S}Hand", fist)
    G.mbox(10, 13, -6, -3, 25, 29, "{S}Hand", "skin_lt")  # thumb

    # head
    G.box(-8, 8, -8, 7, 52, 68, "Head", lambda x, y, z: "skin_lt" if z == 67 else "skin")
    G.box(-7, 7, -9, -8, 53, 63, "Head", "skin")  # face plate
    G.box(-7, 7, -10, -9, 52, 58, "Head", "skin")  # jutting jaw
    G.box(-4, 4, -10, -8, 51, 53, "Head", "skin_dk")  # chin
    G.box(-6, 6, -10, -9, 54, 57, "Head", "mouth")
    G.box(-7, -6, -10, -9, 56, 58, "Head", "mouth")
    G.box(6, 7, -10, -9, 56, 58, "Head", "mouth")
    for x in range(-6, 6):
        if x % 2 == 0:
            G.box(x, x + 1, -10, -9, 56, 57, "Head", "teeth")
        else:
            G.box(x, x + 1, -10, -9, 54, 55, "Head", "teeth")
    for x in (-5, 4):  # fangs
        G.box(x, x + 1, -10, -9, 55, 57, "Head", "teeth")
    for x0 in (1, -6):  # sunken eye sockets
        G.box(x0, x0 + 5, -9, -8, 58, 62, "Head", "skin_dk")
    G.mbox(4, 8, -11, -9, 57, 59, "Head", lambda x, y, z: "skin_lt" if z == 58 else "skin")  # cheekbones
    G.box(-7, 7, -9, -8, 63, 68, "Head", lambda x, y, z: "skin_dk" if (x, z) in WRINKLES else "skin")  # forehead
    for x in range(-7, 7):  # angry brow, low in the middle
        zb = 61 + int(ax(x) // 2.5)
        G.box(x, x + 1, -10, -8, zb, zb + 2, "Head", "skin_dk")
    for x0 in (2, -5):  # glowing eyes under the brow
        G.box(x0, x0 + 3, -9, -8, 59, 61, "Eyes",
              lambda x, y, z: "eye_hot" if z == 60 and ax(x) == 3 else "eye")
    for y, z0, z1 in ((-10, 56, 61), (-11, 56, 60), (-12, 55, 59), (-13, 55, 58), (-14, 55, 57)):  # hooked nose
        G.box(-1, 1, y, y + 1, z0, z1, "Head", lambda x, y, z, z1=z1: "skin_lt" if z == z1 - 1 else "skin")
    # mohawk ridge, highest over the crown, running down the back of the head
    for y in range(-7, 7):
        top = 68 + round(9 - 0.10 * (y + 0.5) ** 2)
        for x in range(-3, 3):
            t = top + (2 if h3(x, y, 5) > 0.55 else 0) - 2 * ax(x)
            if t <= 69:
                continue
            G.box(x, x + 1, y, y + 1, 68, t, "Head", lambda x, y, z: "hair" if (y + z) % 3 else "leather_dk")
    G.box(-3, 3, 7, 8, 57, 69, "Head", lambda x, y, z: "hair" if (x + z) % 3 else "leather_dk")
    # ears: long flat blades sweeping out and up, brown tips, inner ear on the front face
    for s, lab in ((1, "Ear_L"), (-1, "Ear_R")):
        for d in range(20):
            zc = 62 + 0.95 * d  # leaf-shaped: stays broad, then tapers to a point
            hw = 6.5 * (1 - (d / 20) ** 1.8) + 0.5
            zb, zt = round(zc - hw), round(zc + hw)
            zt = max(zt, zb + 1)
            thick = 3 if d < 7 else 2 if d < 14 else 1  # thick at the root, thin blade at the tip
            y0 = 1 - thick
            x = 8 + d if s > 0 else -9 - d
            for z in range(zb, zt):
                inner = zb + 2 <= z < zt - 1 and 1 <= d < 15 and thick >= 2
                for y in range(y0, 1):
                    if d >= 16 or (d >= 13 and z >= zt - 2):
                        c = "ear_tip"
                    elif inner and y == y0:
                        continue  # recessed cup: the rim stays proud, the inner ear sits one voxel back
                    elif inner and y == y0 + 1:
                        c = "ear_deep" if abs(z - zc) < 1.2 and 3 <= d < 12 else "ear_in"
                    elif z == zt - 1 or (y == y0 and z == zb):
                        c = "skin_lt"  # rim
                    else:
                        c = "skin"
                    G.box(x, x + 1, y, y + 1, z, z + 1, lab, c)
        # gold hoop earring hanging under the ear base
        xs = (10, 14) if s > 0 else (-14, -10)
        G.box(xs[0], xs[1], -3, -2, 51, 57, lab, "gold")
        G.clear(xs[0] + 1, xs[1] - 1, -3, -2, 52, 56)
        G.clear(xs[1] - 1, xs[1], -3, -2, 53, 55) if s > 0 else G.clear(xs[0], xs[0] + 1, -3, -2, 53, 55)


def paint_sword(S):
    """Scimitar in grip space: u = along the blade (cells), w = edge side (+), t = thickness."""
    grip = lambda u, w, t: "leather_dk" if u % 2 else "grip"
    S.box(-3, 4, -1, 1, -1, 1, "Weapon", grip)
    S.box(-5, -3, -1, 1, -1, 1, "Weapon", "guard")
    for u, w in ((-6, 0), (-6, -1), (-7, -1), (-7, -2), (-7, -3), (-6, -4), (-5, -4), (-5, -3)):
        S.box(u, u + 1, w, w + 1, -1, 1, "Weapon", "guard")  # hooked pommel
    S.box(4, 6, -4, 4, -1, 1, "Weapon", lambda u, w, t: "rivet" if w in (-1, 0) and u == 5 else "guard")
    for u, w in ((6, -5), (7, -5), (8, -4), (6, 4), (7, 4), (8, 3)):
        S.box(u, u + 1, w, w + 1, -1, 1, "Weapon", "guard")  # guard hooks
    for u in range(6, 32):
        t = (u - 6) / 26
        wc = -0.016 * (u - 6) ** 2
        width = 4 + 3 * math.sin(math.pi * 0.8 * t)
        spine = wc - 1.5
        edge = spine + width
        if u >= 26:
            edge += (spine + 1 - edge) * (u - 26) / 6  # clipped point
        w0, w1 = math.floor(spine), math.ceil(edge)
        for w in range(w0, w1):
            if w == w1 - 1:
                c = "blade_edge"
            elif w == w0:
                c = "blade_dk"
            elif 8 <= u <= 24 and w == w0 + 2:
                c = "blade_dk"  # fuller
            elif h3(u, w, 0, 11) < 0.12:
                c = "rust"
            else:
                c = "blade"
            S.box(u, u + 1, w, w + 1, 0, 1, "Weapon", c)


# ------------------------------------------------------------------ meshing + atlas
def shift(a, axis, k, fill=0):
    """out[i] = a[i + k] along axis, `fill` where that falls outside the grid."""
    out = np.full_like(a, fill)
    src, dst = [slice(None)] * a.ndim, [slice(None)] * a.ndim
    if k > 0:
        src[axis], dst[axis] = slice(k, None), slice(0, -k)
    else:
        src[axis], dst[axis] = slice(0, k), slice(-k, None)
    out[tuple(dst)] = a[tuple(src)]
    return out


def face_colors(grid):
    """Per face direction, voxel colours with pixel-art outlines: a face texel is darkened where its in-plane
    neighbour falls off an edge (convex), steps up into a wall (concave), or changes material."""
    solid = grid.lab != 0
    keep = np.isin(grid.mat, [PAL_ID[n] for n in NO_OUTLINE])
    out = {}
    for axis in range(3):
        for sg in (-1, 1):
            surf = solid & ~shift(solid, axis, sg)
            f = np.ones(solid.shape, np.float32)
            lit = np.zeros(solid.shape, bool)
            for a in (b for b in range(3) if b != axis):
                for k in (-1, 1):
                    nsolid, nsurf = shift(solid, a, k), shift(surf, a, k)
                    nmat = shift(grid.mat, a, k, -1)
                    edge = surf & ~nsolid
                    if axis == 2:
                        f = np.where(edge, np.minimum(f, SHADE["top_edge"] if sg > 0 else SHADE["under_edge"]), f)
                    elif a == 2 and k > 0:
                        lit |= edge  # top rim of a side face catches the light
                    else:
                        f = np.where(edge, np.minimum(f, SHADE["bottom"] if a == 2 else SHADE["side"]), f)
                    f = np.where(surf & nsolid & ~nsurf, np.minimum(f, SHADE["concave"]), f)
                    f = np.where(surf & nsurf & (nmat != grid.mat) & (grid.mat > nmat), np.minimum(f, SHADE["material"]), f)
            f = np.where(lit & (f >= 1.0), SHADE["rim"], f)
            if axis == 2:
                f = f * (SHADE["face_up"] if sg > 0 else SHADE["face_down"])
            f[keep] = 1.0
            out[(axis, sg)] = np.clip(grid.col * f[..., None], 0.0, 1.0)
    return out


def greedy(grid, ids):
    lab = grid.lab
    fcol = face_colors(grid)
    inmesh = np.isin(lab, ids)
    quads = []
    for axis in range(3):
        for sg in (-1, 1):
            nb = np.zeros_like(lab)
            src, dst = [slice(None)] * 3, [slice(None)] * 3
            if sg > 0:
                dst[axis], src[axis] = slice(0, -1), slice(1, None)
            else:
                dst[axis], src[axis] = slice(1, None), slice(0, -1)
            nb[tuple(dst)] = lab[tuple(src)]
            face = np.where(inmesh & (lab != nb), lab, 0)
            col = fcol[(axis, sg)]
            for sl in range(lab.shape[axis]):
                m = np.take(face, sl, axis=axis).copy()
                if not m.any():
                    continue
                cs = np.take(col, sl, axis=axis)
                nB, nC = m.shape
                for i in range(nB):
                    if not m[i].any():
                        continue
                    j = 0
                    while j < nC:
                        L = m[i, j]
                        if L == 0:
                            j += 1
                            continue
                        j2 = j + 1
                        while j2 < nC and m[i, j2] == L:
                            j2 += 1
                        i2 = i + 1
                        while i2 < nB and np.all(m[i2, j:j2] == L):
                            i2 += 1
                        m[i:i2, j:j2] = 0
                        quads.append((axis, sg, sl, i, i2, j, j2, int(L), cs[i:i2, j:j2].copy()))
                        j = j2
    return quads


def quad_geom(q, lo):
    axis, sg, sl, i, i2, j, j2 = q[:7]
    b, c = [k for k in range(3) if k != axis]
    a = sl + (1 if sg > 0 else 0)

    def P(bi, cj):
        p = [0.0, 0.0, 0.0]
        p[axis], p[b], p[c] = a, bi, cj
        return Vector(p) + Vector(lo.tolist())

    h, w = i2 - i, j2 - j
    pts = [P(i, j), P(i2, j), P(i2, j2), P(i, j2)]
    uvs = [(0, 0), (0, h), (w, h), (w, 0)]  # (texel u along c, texel v along b)
    n = (pts[1] - pts[0]).cross(pts[3] - pts[0])
    if n[axis] * sg < 0:
        pts.reverse()
        uvs.reverse()
    return pts, uvs


def pack(sizes, S, g):
    order = sorted(range(len(sizes)), key=lambda k: (-sizes[k][1], -sizes[k][0]))
    x = y = rowh = 0
    pos = [None] * len(sizes)
    for k in order:
        pw, ph = sizes[k][0] * S + 2 * g, sizes[k][1] * S + 2 * g
        if x + pw > ATLAS_W:
            x, y, rowh = 0, y + rowh, 0
        pos[k] = (x, y)
        x += pw
        rowh = max(rowh, ph)
    return pos, y + rowh


def build_atlas(all_quads):
    sizes = [(q[6] - q[5], q[4] - q[3]) for q in all_quads]
    for S, g in ((8, 2), (6, 2), (5, 1), (4, 1), (3, 1)):
        pos, height = pack(sizes, S, g)
        if height <= ATLAS_W:
            break
    H = 1 << (height - 1).bit_length()
    img = np.zeros((H, ATLAS_W, 4), np.float32)
    img[..., 3] = 1
    for q, (px, py) in zip(all_quads, pos):
        patch = q[8]  # rows = v (b), cols = u (c)
        up = np.repeat(np.repeat(patch, S, 0), S, 1)
        up = np.pad(up, ((g, g), (g, g), (0, 0)), mode="edge")
        img[py:py + up.shape[0], px:px + up.shape[1], :3] = up
    im = bpy.data.images.get("goblin_atlas")
    if im:
        bpy.data.images.remove(im)
    im = bpy.data.images.new("goblin_atlas", ATLAS_W, H)
    im.pixels.foreach_set(img.ravel())
    im.filepath_raw = TEX
    im.file_format = "PNG"
    os.makedirs(os.path.dirname(TEX), exist_ok=True)
    im.save()
    return im, pos, S, g, H


def atlas_material(img, name, emit=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
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
    bsdf.inputs["Roughness"].default_value = 0.9
    try:
        bsdf.inputs["Specular IOR Level"].default_value = 0.15  # no grey sheen washing out the pixels
    except KeyError:
        pass
    if emit:
        nt.links.new(tex.outputs[0], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emit
    return mat


def make_mesh(name, quads, lo, S, g, H, mat, xform):
    verts, faces, loops_uv, vlab, vkey = [], [], [], [], {}
    for q, (px, py) in quads:
        pts, uvs = quad_geom(q, lo)
        bone = BONE_OF.get(LABELS[q[7]], LABELS[q[7]])
        f = []
        for p, (tu, tv) in zip(pts, uvs):
            wp = xform(p)
            key = (bone, round(wp.x, 5), round(wp.y, 5), round(wp.z, 5))
            if key not in vkey:
                vkey[key] = len(verts)
                verts.append(wp)
                vlab.append(bone)
            f.append(vkey[key])
            loops_uv.append(((px + g + tu * S) / ATLAS_W, (py + g + tv * S) / H))
        faces.append(f)
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    uvl = me.uv_layers.new(name="UVMap")
    for i, uv in enumerate(loops_uv):
        uvl.data[i].uv = uv
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    for bone in sorted(set(vlab)):
        vg = ob.vertex_groups.new(name=bone)
        vg.add([i for i, b in enumerate(vlab) if b == bone], 1.0, "REPLACE")
    return ob


def main():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    for blk in (bpy.data.meshes, bpy.data.armatures, bpy.data.actions):
        for d in list(blk):
            blk.remove(d)

    G = Grid((-30, -17, 0), (30, 12, 88))
    paint_body(G)
    SG = Grid((-9, -14, -1), (34, 8, 1))
    paint_sword(SG)

    jobs = []  # (mesh name, quads, grid lo, xform)
    for name, labels in MESHES.items():
        jobs.append((name, greedy(G, [LID[l] for l in labels]), G.lo, lambda p: p * V))
    # sword grip-space -> world: u -> -Y (forward), w -> -Z (edge down), t -> +X; grip centre in the right fist
    grip = Vector((-16, 0, 25.5))
    sw_x = lambda p: (grip + Vector((p.z, -(p.x - 0.5), -p.y))) * V
    jobs.append(("Sword_Geo", greedy(SG, [LID["Weapon"]]), SG.lo, sw_x))

    flat = [q for _, qs, _, _ in jobs for q in qs]
    img, pos, S, g, H = build_atlas(flat)
    mat = atlas_material(img, "M_Goblin_Voxel")
    mat_eye = atlas_material(img, "M_Goblin_Eyes", emit=4.0)

    coll = bpy.data.collections.new("GOBLIN_Mesh")
    bpy.context.scene.collection.children.link(coll)
    k = tris = 0
    for name, qs, lo, xf in jobs:
        ob = make_mesh(name, list(zip(qs, pos[k:k + len(qs)])), lo, S, g, H,
                       mat_eye if name == "Eyes_Geo" else mat, xf)
        k += len(qs)
        coll.objects.link(ob)
        tris += 2 * len(qs)
    vs = bpy.context.scene.view_settings  # preview colours as Roblox shows them (sRGB), not AgX-desaturated
    try:
        vs.view_transform = "Standard"
    except TypeError:
        pass
    print("voxel goblin: %d meshes, %d tris, atlas %dx%d @ %dpx/texel" % (len(jobs), tris, ATLAS_W, H, S))


if __name__ == "__main__":
    main()
