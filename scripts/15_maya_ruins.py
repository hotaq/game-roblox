# 15_maya_ruins.py: LEGO-voxel Maya ruin kit for Map 1 "Forest ruins" (GAME-31), built at 1-stud voxels for detail.
#
# Ruin_Pyramid: five talud-tablero tiers (sloped base, recessed glyph panel, light cornice), Chaac masks on the corners,
# a walkable 1-stud stairway with sloped balustrades and Kukulkan serpent heads, and a top shrine with a corbel-arch
# door, a jade mosaic frieze and a lattice roof comb. Plus stelae with carved glyph faces, pillars (standing / broken /
# fallen), a ruined wall with a glyph panel, and rubble. Weathering: fallen blocks, cracks, moss clumps that drip down
# faces, leafy vines.
# Run headless:
#   /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python goblin/scripts/15_maya_ruins.py
# or in a live Blender: exec(open(".../15_maya_ruins.py").read())
# Mesh building and export live in voxel_kit.py (1 unit = 1 stud, studded tops). Writes export/Ruin_<Piece>.fbx and
# blender/maya_ruins.blend.
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else "/Users/chinnaphat/Desktop/cedt/roblox/goblin/scripts")
import voxel_kit  # noqa: E402

COLORS = {  # sRGB 0-255; the same values go to Part.Color in Studio
    "Stone": (158, 150, 132),  # warm limestone
    "StoneLight": (182, 174, 154),
    "StoneDark": (116, 110, 98),
    "Cornice": (198, 190, 170),  # tier lips and caps, lighter so the structure reads
    "Crack": (84, 80, 72),
    "Moss": (92, 146, 66),
    "MossDark": (66, 116, 54),
    "Vine": (48, 98, 46),
    "Leaf": (86, 150, 60),
    "Jade": (54, 160, 128),
    "JadeDark": (34, 112, 92),
    "Ochre": (170, 84, 56),
}
V1 = 1  # these pieces build at 1 stud per voxel
voxel_kit.STUD_SEG = 6  # 1-stud studs are small on screen; 6 sides keeps the pyramid's triangle count down


def stone(rng):  # mostly one tone; a few lighter/darker blocks
    r = rng.random()
    return "StoneLight" if r < 0.07 else ("StoneDark" if r < 0.14 else "Stone")


def box(vox, x0, x1, y0, y1, z0, z1, pick):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            for z in range(z0, z1 + 1):
                vox[(x, y, z)] = pick() if callable(pick) else pick


def exposed_sides(vox, p):
    x, y, z = p
    return [(dx, dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if (x + dx, y + dy, z) not in vox]


def weather(vox, rng, moss_patches=8, moss_r=3.0, cracks=6, vines=6, drips=True):
    """Moss clumps on exposed tops that drip down open faces, vertical cracks, and leafy vines."""
    tops = [p for p, c in vox.items() if c in ("Stone", "StoneLight", "StoneDark", "Cornice") and (p[0], p[1], p[2] + 1) not in vox]
    centres = rng.sample(tops, min(moss_patches, len(tops)))
    for p in tops:
        if any((p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (2 * (p[2] - c[2])) ** 2 <= moss_r ** 2 for c in centres) and rng.random() < 0.85:
            vox[p] = "MossDark" if rng.random() < 0.3 else "Moss"
            if drips and rng.random() < 0.35:  # moss runs down an open face below
                for dx, dy in exposed_sides(vox, p)[:1]:
                    for k in range(1, rng.randint(2, 4)):
                        q = (p[0], p[1], p[2] - k)
                        if q in vox and vox[q].startswith("Stone"):
                            vox[q] = "MossDark"
    walls = [p for p, c in vox.items() if c.startswith("Stone") and exposed_sides(vox, p)]
    for _ in range(cracks):
        x, y, z = rng.choice(walls)
        for k in range(rng.randint(2, 4)):
            if (x, y, z - k) in vox and vox[(x, y, z - k)].startswith("Stone"):
                vox[(x, y, z - k)] = "Crack"
    for _ in range(vines):
        x, y, z = rng.choice(walls)
        sides = exposed_sides(vox, (x, y, z))
        if not sides:
            continue
        dx, dy = sides[0]
        for k in range(rng.randint(3, 6)):  # vine hangs one stud off the face
            q = (x + dx, y + dy, z - k)
            if q in vox or q[2] < 1:
                break
            vox[q] = "Leaf" if rng.random() < 0.3 else "Vine"


def pyramid(seed):
    rng, vox = random.Random(seed), {}
    for x in range(-24, 25):  # platform of 3x3 flagstones in two tones, not per-stud noise
        for y in range(-36, 25):
            vox[(x, y, 0)] = "StoneDark" if (x // 3 + y // 3) % 2 else ("Stone" if rng.random() > 0.04 else "Crack")
    z0 = 1
    halves = (20, 17, 14, 11, 8)
    for half in halves:  # each tier: talud rows 0-1, recessed tablero rows 2-3, cornice row 4
        for row, h in ((0, half), (1, half - 1), (2, half - 1), (3, half - 1), (4, half)):
            z = z0 + row
            for x in range(-h, h + 1):
                for y in range(-h, h + 1):
                    ring = max(abs(x), abs(y))
                    if ring < h - 1 and row < 4:
                        continue  # hollow inside (never seen), saves voxels
                    along = abs(y) if abs(x) == h else abs(x)
                    if row in (2, 3) and ring == h and along < h - 3:
                        continue  # recessed panel: face set back one stud
                    if row == 4 and ring == h and rng.random() < 0.06:
                        continue  # fallen cornice block
                    colour = "Cornice" if row == 4 else stone(rng)
                    if row in (2, 3) and ring == h - 1 and along < h - 3 and along % 4 == 1 and row == 2:
                        colour = "Jade" if rng.random() < 0.75 else "JadeDark"  # glyph inlay in the panel
                    vox[(x, y, z)] = colour
            if row == 4:  # fill the tier top so it reads as a solid ledge
                box(vox, -(h - 1), h - 1, -(h - 1), h - 1, z, z, lambda: stone(rng))
        for sx in (-1, 1):  # Chaac masks on the four corners of the tablero
            for sy in (-1, 1):
                cx, cy = sx * (half - 1), sy * (half - 1)
                vox[(cx, cy, z0 + 2)] = vox[(cx, cy, z0 + 3)] = "StoneLight"
                vox[(cx + sx, cy, z0 + 3)] = vox[(cx, cy + sy, z0 + 3)] = "Ochre"  # eyes
                vox[(cx + sx, cy + sy, z0 + 2)] = "StoneLight"  # the long nose
        z0 += 5
    top = z0  # 26
    face0 = -halves[0]
    for z in range(1, top):  # walkable stairway: 1 up, 1 in, 7 wide, from the platform to the top
        yf = -(halves[-1] + (top - 1 - z))
        for y in range(yf, face0 + 3 if yf < face0 else yf + 3):
            for x in range(-3, 4):
                vox[(x, y, z)] = "StoneLight" if y == yf else "Stone"
        for x in (-5, -4, 4, 5):  # sloped balustrades, one stud above the steps
            vox[(x, yf, z)] = vox[(x, yf, z + 1)] = "StoneDark"
    for sx in (-1, 1):  # Kukulkan serpent heads at the foot of the balustrades
        bx = sx * 4
        yb = -(halves[-1] + top - 2)
        box(vox, bx - 1, bx + 1, yb - 3, yb - 1, 1, 3, "Jade")
        vox[(bx - 1, yb - 3, 3)] = vox[(bx + 1, yb - 3, 3)] = "Ochre"  # eyes
        vox.pop((bx, yb - 3, 1), None)  # open mouth
        vox[(bx, yb - 3, 1)] = "Ochre"
        box(vox, bx - 1, bx + 1, yb - 2, yb - 1, 4, 4, "JadeDark")  # head crest
    hs = 6  # shrine: walls with a corbel-arch door, jade mosaic frieze, roof with an overhanging lip
    for z in range(top, top + 7):
        row = z - top
        for x in range(-hs, hs + 1):
            for y in range(-hs, hs + 1):
                if max(abs(x), abs(y)) != hs:
                    continue
                door = y == -hs and (abs(x) <= 1 and row <= 3 or abs(x) == 0 and row == 4)
                if door:
                    continue
                if row in (5, 6):
                    colour = ("Jade" if (x + y + z) % 2 else "Cornice") if row == 5 else "JadeDark" if (x + y) % 3 == 0 else "Cornice"
                else:
                    colour = "Ochre" if rng.random() < 0.08 else stone(rng)
                vox[(x, y, z)] = colour
    box(vox, -hs - 1, hs + 1, -hs - 1, hs + 1, top + 7, top + 7, "StoneDark")  # roof with lip
    for x in range(-5, 6):  # lattice roof comb over the back half
        for z in range(top + 8, top + 14):
            if z == top + 13 or abs(x) == 5 or (x + z) % 3 != 0:
                vox[(x, 2, z)] = "Ochre" if z == top + 13 and x % 2 == 0 else stone(rng)
    weather(vox, rng, moss_patches=16, moss_r=3.2, cracks=18, vines=16)
    return vox


GLYPH = [  # carved face on a stela front, top row first: J jade, D dark stone, . stone
    "DJJD",
    "J..J",
    "JDDJ",
    "J..J",
    "DJJD",
    ".DD.",
    "D..D",
    "DDDD",
]


def stela(seed, broken=False):
    rng, vox = random.Random(seed), {}
    box(vox, -1, 4, -2, 1, 0, 0, "StoneDark")  # plinth
    box(vox, 0, 3, -1, 0, 1, 1, "Cornice")
    h = 12
    box(vox, 0, 3, -1, 0, 2, h, lambda: stone(rng))
    for r, line in enumerate(GLYPH):
        for c, ch in enumerate(line):
            if ch != ".":
                vox[(c, -1, h - 1 - r)] = "Jade" if ch == "J" else "Crack"
    vox.pop((0, -1, h), None)
    vox.pop((3, -1, h), None)
    vox.pop((0, 0, h), None)
    vox.pop((3, 0, h), None)  # rounded top
    if broken:
        for p in [p for p in vox if p[2] > 6]:
            vox.pop(p)
        vox.pop((2, -1, 6), None)
        vox.pop((3, 0, 6), None)  # jagged break
        box(vox, 5, 8, -1, 0, 0, 1, lambda: stone(rng))  # the fallen top half
        vox[(6, -2, 0)] = "Jade"
    weather(vox, rng, moss_patches=2, moss_r=1.6, cracks=2, vines=1)
    return vox


def pillar(seed, kind="standing"):
    rng, vox = random.Random(seed), {}
    if kind == "fallen":
        for x in range(0, 14):
            if x in (5, 10):
                continue  # broken into drums
            box(vox, x, x, -1, 2, 0, 3, lambda: "StoneDark" if x % 4 == 0 else stone(rng))
        box(vox, 14, 16, -2, 3, 0, 5, lambda: "Cornice")  # capital at the end
        box(vox, -3, -1, -1, 2, 0, 1, lambda: stone(rng))
    else:
        box(vox, -2, 3, -2, 3, 0, 0, "StoneDark")  # stepped base
        box(vox, -1, 2, -1, 2, 1, 1, "Cornice")
        h = 13 if kind == "standing" else rng.randint(6, 8)
        for z in range(2, h + 1):
            box(vox, -1, 2, -1, 2, z, z, lambda: "StoneDark" if z % 4 == 0 else stone(rng))  # carved drums
        if kind == "standing":
            box(vox, -2, 3, -2, 3, h + 1, h + 1, "Cornice")  # capital
            box(vox, -1, 2, -1, 2, h + 2, h + 2, "StoneDark")
            vox[(0, -2, 6)] = vox[(1, -2, 6)] = "Jade"  # glyph band
        else:
            for p in [(2, 2, h), (2, 1, h), (-1, 2, h), (2, 2, h - 1)]:
                vox.pop(p, None)  # jagged break
            box(vox, 4, 6, 0, 2, 0, 1, lambda: stone(rng))
    weather(vox, rng, moss_patches=2, moss_r=1.8, cracks=3, vines=2)
    return vox


def wall(seed):
    rng, vox = random.Random(seed), {}
    for x in range(22):
        if 9 <= x <= 12:
            continue  # collapsed gap to run through
        h = rng.randint(6, 10) if x not in (8, 13) else rng.randint(3, 5)
        for z in range(h):
            for y in (0, 1):
                inset = y == 0 and 2 <= z <= 4 and (2 <= x <= 6 or 15 <= x <= 19)
                if inset:
                    continue  # recessed panel
                vox[(x, y, z)] = "Cornice" if z == h - 1 else stone(rng)
    for x, z in ((3, 3), (5, 3), (16, 3), (18, 3), (4, 2), (17, 4)):
        vox[(x, 1, z)] = "Jade"  # glyphs inside the panels
    for _ in range(10):  # rubble from the collapse
        x, y = rng.randint(8, 13), rng.randint(-2, 3)
        z = 0
        while (x, y, z) in vox:
            z += 1
        if z < 3:
            vox[(x, y, z)] = stone(rng)
    weather(vox, rng, moss_patches=3, moss_r=2.0, cracks=4, vines=3)
    return vox


def rubble(seed):
    rng, vox = random.Random(seed), {}
    for _ in range(9):  # chunks of 1-3 studs
        x, y = rng.randint(-6, 6), rng.randint(-6, 6)
        sx, sy, sz = rng.randint(1, 3), rng.randint(1, 3), rng.randint(1, 2)
        box(vox, x, x + sx - 1, y, y + sy - 1, 0, sz - 1, lambda: stone(rng))
    vox[(0, 0, 0)] = "Jade"  # a broken glyph block
    weather(vox, rng, moss_patches=3, moss_r=1.6, cracks=1, vines=0, drips=False)
    return vox


voxel_kit.clear_scene()
voxel_kit.export_all([
    ("Ruin_Pyramid", pyramid(11), COLORS, (0, 0, 0), V1),
    ("Ruin_Stela", stela(21), COLORS, (40, -30, 0), V1),
    ("Ruin_StelaBroken", stela(22, broken=True), COLORS, (50, -30, 0), V1),
    ("Ruin_Pillar", pillar(31), COLORS, (40, -12, 0), V1),
    ("Ruin_PillarBroken", pillar(32, "broken"), COLORS, (50, -12, 0), V1),
    ("Ruin_PillarFallen", pillar(33, "fallen"), COLORS, (38, 6, 0), V1),
    ("Ruin_Wall", wall(41), COLORS, (-56, 14, 0), V1),
    ("Ruin_Rubble", rubble(51), COLORS, (-44, -20, 0), V1),
], "maya_ruins.blend")
