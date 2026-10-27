# 15_maya_ruins.py: LEGO-voxel Maya ruin kit for Map 1 "Forest ruins" (GAME-31): a stepped pyramid temple with a
# front stairway and top shrine, carved stelae, pillars (standing / broken / fallen), a ruined wall and rubble.
# Grey stone in three shades, moss on exposed tops, jade glyphs and faded red-ochre paint as accents.
# Run headless:
#   /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python goblin/scripts/15_maya_ruins.py
# or in a live Blender: exec(open(".../15_maya_ruins.py").read())
# Mesh building and export live in voxel_kit.py (1 unit = 1 stud, 2-stud voxels, studded tops).
# Writes export/Ruin_<Piece>.fbx and blender/maya_ruins.blend.
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else "/Users/chinnaphat/Desktop/cedt/roblox/goblin/scripts")
import voxel_kit  # noqa: E402

COLORS = {  # sRGB 0-255; the same values go to Part.Color in Studio
    "Stone": (156, 152, 140),
    "StoneLight": (182, 178, 165),
    "StoneDark": (118, 114, 104),
    "Moss": (88, 142, 64),
    "MossDark": (66, 116, 54),
    "Vine": (52, 104, 48),
    "Jade": (56, 158, 128),
    "Ochre": (168, 82, 56),
}


def stone(rng):  # mostly one grey; a few lighter/darker blocks so it doesn't look like camo
    r = rng.random()
    return "StoneLight" if r < 0.08 else ("StoneDark" if r < 0.16 else "Stone")


def box(vox, x0, x1, y0, y1, z0, z1, pick):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            for z in range(z0, z1 + 1):
                vox[(x, y, z)] = pick()


def overgrow(vox, rng, patches=6, radius=2.5):
    """Moss in a few clumps on exposed tops (clustered, not sprinkled)."""
    tops = [p for p, c in vox.items() if c.startswith("Stone") and (p[0], p[1], p[2] + 1) not in vox]
    centres = rng.sample(tops, min(patches, len(tops)))
    for p in tops:
        for c in centres:
            if (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (2 * (p[2] - c[2])) ** 2 <= radius ** 2 and rng.random() < 0.85:
                vox[p] = "MossDark" if rng.random() < 0.3 else "Moss"
                break


def pyramid(seed):
    rng, vox = random.Random(seed), {}
    z = 0
    for half, h in ((9, 2), (8, 2), (7, 2), (6, 2), (5, 2), (4, 2)):  # six steep tiers, each 1 voxel in
        for dz in range(h):
            for x in range(-half, half + 1):
                for y in range(-half, half + 1):
                    edge = max(abs(x), abs(y)) == half
                    if edge and dz == h - 1 and rng.random() < 0.12:
                        continue  # a few fallen edge blocks
                    vox[(x, y, z + dz)] = stone(rng)
        z += h
    top = z
    for k in range(top):  # front stairway: one voxel up, one voxel in, 3 wide, with darker side ramps
        for y in range(-14 + k, 0):
            for x in (-1, 0, 1):
                vox.setdefault((x, y, k), "StoneLight")
            for x in (-2, 2):
                vox.setdefault((x, y, k), "StoneDark")
    for x in range(-2, 3):  # shrine on top: walls with a front doorway, roof slab, perforated roof comb
        for y in range(-2, 3):
            for dz in range(3):
                wall = max(abs(x), abs(y)) == 2
                door = y == -2 and x == 0 and dz < 2
                if wall and not door:
                    vox[(x, y, top + dz)] = "Ochre" if rng.random() < 0.12 else stone(rng)
            vox[(x, y, top + 3)] = "StoneDark"
    for x in (-1, 0, 1):
        vox[(x, -2, top + 2)] = "Jade"  # glyph band over the door
    for x in (-2, -1, 1, 2):  # roof comb with gaps
        vox[(x, 1, top + 4)] = stone(rng)
    for x in (-2, 0, 2):
        vox[(x, 1, top + 5)] = stone(rng)
    overgrow(vox, rng, patches=9, radius=2.8)
    for _ in range(12):  # vines hanging down the tier faces
        half = rng.choice((9, 8, 7, 6, 5))
        side = rng.choice(((1, 0), (-1, 0), (0, 1)))
        t = rng.randint(-half + 1, half - 1)
        x, y = (side[0] * (half + 1), t) if side[0] else (t, side[1] * (half + 1))
        zt = {9: 1, 8: 3, 7: 5, 6: 7, 5: 9}[half]
        for dz in range(rng.randint(1, 2)):
            vox.setdefault((x, y, zt - dz), "Vine")
    return vox


def stela(seed, broken=False):
    rng, vox = random.Random(seed), {}
    box(vox, -1, 2, -1, 1, 0, 0, lambda: "StoneDark")  # plinth
    h = 3 if broken else 5
    box(vox, 0, 1, 0, 0, 1, h, lambda: stone(rng))
    for x, z in ((0, 2), (1, 3), (0, 4)):  # carved glyphs on the front face
        if z <= h:
            vox[(x, 0, z)] = "Jade"
    if broken:
        vox.pop((1, 0, h), None)
        vox[(3, -1, 0)] = vox[(-2, 1, 0)] = stone(rng)  # broken-off chunks on the ground
    overgrow(vox, rng, 1, 1.5)
    return vox


def pillar(seed, kind="standing"):
    rng, vox = random.Random(seed), {}
    if kind == "fallen":
        box(vox, 0, 6, 0, 1, 0, 1, lambda: stone(rng))  # shaft lying along x
        box(vox, 7, 8, -1, 2, 0, 2, lambda: "StoneDark")  # capital at the end
        box(vox, -2, -1, 0, 1, 0, 0, lambda: stone(rng))  # the snapped-off base stub
    else:
        box(vox, -1, 2, -1, 2, 0, 0, lambda: "StoneDark")  # base
        h = 6 if kind == "standing" else rng.randint(3, 4)
        box(vox, 0, 1, 0, 1, 1, h, lambda: stone(rng))
        if kind == "standing":
            box(vox, -1, 2, -1, 2, h + 1, h + 1, lambda: "StoneDark")  # capital
            vox[(0, -1, 3)] = "Jade"
        else:
            vox.pop((1, 1, h), None)  # jagged break
            vox[(3, 0, 0)] = vox[(-2, 2, 0)] = stone(rng)
    overgrow(vox, rng, 1, 1.5)
    return vox


def wall(seed):
    rng, vox = random.Random(seed), {}
    for x in range(10):
        if x in (4, 5):
            continue  # a collapsed gap to run through
        h = rng.randint(2, 5)
        for z in range(h):
            vox[(x, 0, z)] = "Ochre" if z == 1 and rng.random() < 0.15 else stone(rng)
    vox[(2, 0, 1)] = "Jade"
    for x in (4, 5, 6):  # rubble from the collapse
        vox[(x, rng.choice((-1, 1)), 0)] = stone(rng)
    overgrow(vox, rng, 2, 1.5)
    return vox


def rubble(seed):
    rng, vox = random.Random(seed), {}
    for _ in range(14):
        x, y = rng.randint(-2, 2), rng.randint(-2, 2)
        z = 0
        while (x, y, z) in vox:
            z += 1
        if z < 2:
            vox[(x, y, z)] = stone(rng)
    overgrow(vox, rng, 2, 1.5)
    return vox


voxel_kit.clear_scene()
voxel_kit.export_all([
    ("Ruin_Pyramid", pyramid(11), COLORS, (0, 0, 0)),
    ("Ruin_Stela", stela(21), COLORS, (34, -24, 0)),
    ("Ruin_StelaBroken", stela(22, broken=True), COLORS, (44, -24, 0)),
    ("Ruin_Pillar", pillar(31), COLORS, (34, -6, 0)),
    ("Ruin_PillarBroken", pillar(32, "broken"), COLORS, (46, -6, 0)),
    ("Ruin_PillarFallen", pillar(33, "fallen"), COLORS, (36, 10, 0)),
    ("Ruin_Wall", wall(41), COLORS, (-44, 16, 0)),
    ("Ruin_Rubble", rubble(51), COLORS, (-36, -16, 0)),
], "maya_ruins.blend")
