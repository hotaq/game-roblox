# 14_voxel_trees.py: LEGO-voxel tree props (oak, birch, pine) for the studded-Plastic map look (GAME-30).
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


voxel_kit.clear_scene()
voxel_kit.export_all([("Tree_Oak", oak(1), COLORS, (0, 0, 0)), ("Tree_Birch", birch(2), COLORS, (26, 0, 0)),
                      ("Tree_Pine", pine(3), COLORS, (-24, 0, 0))], "voxel_trees.blend")
