# 14_voxel_trees.py: LEGO-voxel forest props for Map 1 (GAME-30), at 1-stud voxels to match the Maya ruin kit.
# Oak (thick trunk, roots, branches ending in leaf clumps, shaded crown), birch (tall white trunk with dark lenticel
# marks and twigs), pine (drooping stepped tiers with light tips) and a bush for the forest floor.
# Run headless:
#   /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python goblin/scripts/14_voxel_trees.py
# or in a live Blender: exec(open(".../14_voxel_trees.py").read())
# Mesh building and export live in voxel_kit.py. Writes export/Tree_<Kind>.fbx and blender/voxel_trees.blend.
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else "/Users/chinnaphat/Desktop/cedt/roblox/goblin/scripts")
import voxel_kit  # noqa: E402

COLORS = {  # sRGB 0-255; the same values go to Part.Color in Studio
    "Bark": (92, 64, 45),
    "BarkDark": (66, 46, 33),
    "BarkLight": (118, 86, 60),
    "Leaf": (72, 148, 62),
    "LeafLight": (104, 178, 76),
    "LeafDark": (48, 112, 48),
    "Birch": (232, 230, 222),
    "BirchMark": (52, 47, 44),
    "BirchLeaf": (122, 184, 78),
    "BirchLeafLight": (152, 204, 96),
    "Pine": (36, 96, 56),
    "PineLight": (58, 128, 70),
    "PineDark": (26, 74, 44),
}
V1 = 1  # 1 stud per voxel, same detail level as the ruins
voxel_kit.STUD_SEG = 6


def blob(vox, cx, cy, cz, rx, ry, rz, pick, rng, rough=0.22):
    """Ellipsoid of leaf voxels with a ragged edge; `pick(t, rng)` chooses the shade from height t in -1..1."""
    for x in range(math.floor(cx - rx), math.ceil(cx + rx) + 1):
        for y in range(math.floor(cy - ry), math.ceil(cy + ry) + 1):
            for z in range(math.floor(cz - rz), math.ceil(cz + rz) + 1):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + ((z - cz) / rz) ** 2
                if d <= 1 + rng.uniform(-rough, rough * 0.4) and (x, y, z) not in vox:
                    vox[(x, y, z)] = pick((z - cz) / rz, rng)


def hollow(vox, keep_depth=2):
    """Drop foliage buried deeper than keep_depth on every side: never seen, and it cuts the mesh a lot."""
    foliage = [p for p, c in vox.items() if "Leaf" in c or c.startswith("Pine")]
    dirs = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
    inner = [p for p in foliage if all((p[0] + dx * k, p[1] + dy * k, p[2] + dz * k) in vox
                                       for dx, dy, dz in dirs for k in range(1, keep_depth + 1))]
    for p in inner:
        del vox[p]


def bark(rng):
    r = rng.random()
    return "BarkDark" if r < 0.22 else ("BarkLight" if r < 0.3 else "Bark")


def oak_shade(t, rng):  # dark underside, light top highlights
    if t < -0.35:
        return "LeafDark"
    return "LeafLight" if t > 0.4 and rng.random() < 0.7 else ("LeafDark" if rng.random() < 0.12 else "Leaf")


def oak(seed):
    rng, vox = random.Random(seed), {}
    h = rng.randint(9, 11)
    for z in range(h):  # 3x3 trunk, corners trimmed above the flared base
        for x in (-1, 0, 1):
            for y in (-1, 0, 1):
                if abs(x) + abs(y) < 2 or z <= 1:
                    vox[(x, y, z)] = bark(rng)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):  # roots creeping out along the ground
        for k in range(2, rng.randint(3, 5)):
            vox[(dx * k, dy * k, 0)] = "BarkDark"
    clumps, a0 = [], rng.uniform(0, 2 * math.pi)
    for i in range(3):  # branches: stepped diagonals out of the trunk top, each ending in a leaf clump
        a = a0 + i * 2.1
        x = y = 0.0
        z = h - 3
        for _ in range(5):
            x, y, z = x + math.cos(a) * 1.2, y + math.sin(a) * 1.2, z + 0.8
            vox[(round(x), round(y), round(z))] = bark(rng)
        clumps.append((x, y, z + 1.5))
    blob(vox, 0, 0, h + 4, 6.5, 6.5, 4.8, oak_shade, rng)  # main crown
    for x, y, z in clumps:
        blob(vox, x, y, z, 4.2, 4.2, 3.2, oak_shade, rng)
    blob(vox, 0, 0, h + 8, 3.5, 3.5, 2.5, oak_shade, rng)  # rounded top
    hollow(vox)
    return vox


def birch(seed):
    rng, vox = random.Random(seed), {}
    h = rng.randint(15, 18)
    for z in range(h):  # 2x2 white trunk
        for x in (0, 1):
            for y in (0, 1):
                vox[(x, y, z)] = "Birch"
    for _ in range(9):  # short dark lenticel dashes
        z = rng.randint(1, h - 2)
        x, y = rng.choice(((0, 0), (1, 0), (0, 1), (1, 1)))
        vox[(x, y, z)] = "BirchMark"
        if rng.random() < 0.5:
            vox[(1 - x, y, z)] = "BirchMark"
    for _ in range(3):  # thin twigs poking out
        z = rng.randint(h - 7, h - 3)
        vox[rng.choice(((2, 0, z), (-1, 1, z), (1, 2, z), (0, -1, z)))] = "Birch"
    shade = lambda t, r: "BirchLeafLight" if t > 0.1 and r.random() < 0.55 else "BirchLeaf"
    blob(vox, 0.5, 0.5, h + 2, 4.0, 4.0, 4.6, shade, rng, rough=0.25)
    for _ in range(3):
        a = rng.uniform(0, 2 * math.pi)
        blob(vox, 0.5 + 3 * math.cos(a), 0.5 + 3 * math.sin(a), h - 1 + rng.uniform(0, 3), 2.4, 2.4, 2.2, shade, rng)
    hollow(vox)
    return vox


def pine(seed):
    rng, vox = random.Random(seed), {}
    for z in range(4):
        for x in (0, 1):
            for y in (0, 1):
                vox[(x, y, z)] = bark(rng)
    z = 4
    for r in (7, 6, 5, 4, 3, 2):  # tiers: a disc with a drooping light rim, a darker core layer above it
        for x in range(-r, r + 2):
            for y in range(-r, r + 2):
                d = math.hypot(x - 0.5, y - 0.5)
                if d <= r + rng.uniform(-0.4, 0.3):
                    rim = d > r - 1.2
                    vox[(x, y, z - (1 if rim and rng.random() < 0.6 else 0))] = "PineLight" if rim else "Pine"
                    if d <= r - 2:
                        vox[(x, y, z + 1)] = "PineDark" if rng.random() < 0.3 else "Pine"
        for zz in range(z - 1, z + 1):  # trunk runs up into the tier disc, never above it
            for x in (0, 1):
                for y in (0, 1):
                    vox.setdefault((x, y, zz), "Bark")
        z += 3
    top = z - 2  # spire sits right on the last tier
    for x in (0, 1):
        for y in (0, 1):
            vox[(x, y, top)] = "Pine"
    for k in range(1, 3):
        vox[(0, 0, top + k)] = vox[(1, 1, top + k)] = "Pine" if k < 2 else "PineLight"
    hollow(vox)
    return vox


def bush(seed):
    rng, vox = random.Random(seed), {}
    for _ in range(3):
        blob(vox, rng.uniform(-1.5, 1.5), rng.uniform(-1.5, 1.5), 1.5, 2.6, 2.6, 2.0, oak_shade, rng, rough=0.3)
    for p in [p for p in vox if p[2] < 0]:
        del vox[p]
    hollow(vox, 1)
    return vox


voxel_kit.clear_scene()
voxel_kit.export_all([
    ("Tree_Oak", oak(1), COLORS, (0, 0, 0), V1),
    ("Tree_Birch", birch(2), COLORS, (24, 0, 0), V1),
    ("Tree_Pine", pine(3), COLORS, (-24, 0, 0), V1),
    ("Tree_Bush", bush(4), COLORS, (12, -16, 0), V1),
], "voxel_trees.blend")
