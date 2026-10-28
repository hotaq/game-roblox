# Jungle skeleton (owner pick 2026-10-28: concept/skeleton/skeleton_jungle_B_jademask.png): a block-build skeleton
# overgrown with moss, vines and small flowers, a carved jade Maya mask with a stone crest, glowing green eyes, a stone
# belt with a leaf loincloth, and a wooden war club edged with obsidian.
# Reuses goblin v2's style setup (24_goblin_v2_model.py: flat block-build colours, square inlets) on the same voxel
# engine and R15 joints, so 02_build_rig.py and the 21 published Goblin_* clips drive it unchanged.
# Run like stage 1 (inside Blender, or headless), then 02 -> 03 -> 04.
import importlib.util
import os

ROOT = os.environ.get("GOBLIN_ROOT", "/Users/chinnaphat/Desktop/cedt/roblox/goblin")
spec = importlib.util.spec_from_file_location("goblin_v2", os.path.join(ROOT, "scripts", "24_goblin_v2_model.py"))
v2 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v2)
m, h3, ax = v2.m, v2.h3, v2.ax

m.TEX = os.path.join(ROOT, "textures", "skeleton_atlas.png")
m.WEAPON_GRID = ((-7, -6, -3), (29, 6, 3))
m.PAL.update({  # sRGB, one flat colour each, from the concept
    "bone": [(238, 228, 198)],
    "jade": [(70, 166, 122)],
    "jade_dk": [(42, 116, 86)],
    "jade_lt": [(112, 200, 152)],
    "stone": [(150, 158, 146)],
    "stone_dk": [(110, 118, 108)],
    "moss": [(104, 178, 66)],
    "vine": [(46, 112, 44)],
    "leaf": [(76, 176, 72)],
    "leaf_dk": [(44, 124, 52)],
    "leaf_lt": [(132, 214, 104)],
    "flower_pink": [(244, 112, 172)],
    "flower_yellow": [(255, 214, 72)],
    "flower_purple": [(172, 112, 232)],
    "obsidian": [(36, 32, 48)],
    "eye": [(110, 255, 120)],
    "eye_hot": [(225, 255, 215)],
    "mouth": [(28, 44, 36)],
})
m.PAL_ID.clear()
m.PAL_ID.update({n: i for i, n in enumerate(m.PAL)})
FLOWERS = ("flower_pink", "flower_yellow", "flower_purple")


def overgrown(base: str, moss: float = 0.16, seed: int = 41):
    """`base` with clumps of moss (3x3-voxel cells, a few flowers in them) and the odd vine band wrapped round it."""
    def f(x, y, z):
        if h3(x // 3, y // 3, z // 3, seed) < moss:
            r = h3(x, y, z, seed + 1)
            return FLOWERS[int(r * 50) % 3] if r < 0.05 else "moss"
        if z % 6 == 0 and h3(x // 6, 0, z // 6, seed + 2) < 0.35:
            return "vine"
        return base
    return f


BONE = overgrown("bone")
STONE = overgrown("stone", 0.25, 43)


def paint_body(G):
    # legs: thin bone shafts with knobby knees and ankles (ankle z=5, knee z=14, hip z=27 as in 02's rig)
    G.mbox(2, 10, -8, 3, 0, 4, "{S}Foot", BONE)
    G.mbox(3, 9, -3, 3, 4, 6, "{S}Foot", "bone")  # ankle knob
    G.mclear(4, 5, -8, -6, 0, 2)  # toes
    G.mclear(7, 8, -8, -6, 0, 2)
    G.mbox(4, 8, -2, 2, 6, 12, "{S}LowerLeg", BONE)
    G.mbox(3, 9, -3, 3, 12, 16, "{S}LowerLeg", BONE)  # knee knob
    G.mbox(4, 8, -2, 2, 16, 27, "{S}UpperLeg", BONE)
    # leaf loincloth: one half per thigh (like v2's skirt) so a stride doesn't push a leg through it; each 4-voxel
    # leaf has a dark edge and a pointed tip
    for x in range(12):
        p = x % 4
        tip = 13 if p in (1, 2) else 16
        G.mbox(x, x + 1, -7, 7, tip, 28, "{S}UpperLeg", "leaf_dk" if p == 0 else "leaf")
    for lab, y in (("Cloth_F", -9), ("Cloth_B", 7)):  # a bigger centre leaf hanging front and back
        for z in range(15, 29):
            half = min(3, (z - 15) // 2)
            G.box(-half - 1, half + 1, y, y + 1, z, z + 1, lab, lambda x, y, z: "leaf_lt" if x in (-1, 0) else "leaf")

    # hips: carved stone belt with mossy top; the spine runs up the back
    G.box(-11, 11, -7, 7, 28, 33, "LowerTorso",
          lambda x, y, z: "stone_dk" if z in (28, 32) or (z == 30 and ax(x) % 4 == 1) else STONE(x, y, z))
    G.box(-1, 1, 2, 5, 33, 34, "LowerTorso", "bone")
    G.box(-1, 1, 2, 5, 34, 50, "UpperTorso", BONE)

    # chest: three hollow rib rings, a sternum, collarbones and a short neck
    for z0 in (37, 41, 45):
        G.box(-10, 10, -6, 5, z0, z0 + 2, "UpperTorso", BONE)
        G.clear(-8, 8, -4, 3, z0, z0 + 2)
    G.box(-1, 1, -7, -5, 36, 48, "UpperTorso", "bone")
    G.box(-13, 13, -3, 2, 48, 50, "UpperTorso", BONE)
    G.box(-2, 2, -2, 2, 50, 52, "UpperTorso", "bone")

    # arms hang straight (the rig's rest pose): knobby shoulder and elbow, thin shafts, blocky bony hands
    G.mbox(13, 19, -3, 3, 45, 51, "{S}UpperArm", BONE)
    G.mbox(14, 18, -2, 2, 39, 45, "{S}UpperArm", BONE)
    G.mbox(13, 19, -3, 3, 36, 40, "{S}LowerArm", BONE)
    G.mbox(14, 18, -2, 2, 30, 36, "{S}LowerArm", BONE)
    G.mbox(13, 19, -3, 3, 23, 30, "{S}Hand", "bone")
    G.mclear(15, 16, -3, 3, 23, 26)  # finger gaps
    G.mclear(17, 18, -3, 3, 23, 25)
    G.mbox(12, 14, -5, -3, 25, 28, "{S}Hand", "bone")  # thumb

    # head: bone cube under a carved jade mask, glowing green eyes in raised frames, a grid of carved teeth,
    # glyphs on the forehead and a mossy stone crest on top
    G.box(-14, 14, -13, 11, 52, 80, "Head", overgrown("bone", 0.12, 47))
    G.box(-13, 13, -14, -13, 53, 80, "Head", "jade")
    G.box(-12, 12, -15, -14, 70, 73, "Head", "jade_lt")  # brow ridge
    for x0 in (3, -9):
        G.box(x0 - 1, x0 + 7, -15, -14, 61, 69, "Head", "jade_dk")  # eye frame
        G.clear(x0, x0 + 6, -15, -14, 62, 68)
        G.box(x0, x0 + 6, -14, -13, 62, 68, "Eyes", lambda x, y, z: "eye_hot" if z == 67 and ax(x) == 4 else "eye")
    G.box(-1, 1, -15, -14, 57, 63, "Head", "jade_lt")  # nose ridge
    G.box(-2, -1, -15, -14, 57, 58, "Head", "jade_dk")
    G.box(1, 2, -15, -14, 57, 58, "Head", "jade_dk")
    G.box(-8, 8, -15, -14, 52, 57, "Head", lambda x, y, z: "mouth" if x % 3 == 2 or z == 54 else "jade_lt")
    for x0 in (-10, -5, 3, 8):  # forehead glyphs
        G.box(x0, x0 + 2, -15, -14, 75, 77, "Head", "jade_dk")
    for y in range(-12, 9):  # crest, tallest at the front
        G.box(-2, 2, y, y + 1, 80, 86 - (y + 12) // 5, "Head", STONE)


def paint_club(S):
    """Maya-style war club in grip space (01's paint_sword frame): u = along it, w = down at rest, t = sideways."""
    S.box(-6, -4, -2, 2, -2, 2, "Weapon", "wood_dk")  # pommel
    S.box(-4, 10, -1, 1, -1, 1, "Weapon", lambda u, w, t: "vine" if u in (-1, 2, 5) else "wood_dk")  # vine-wrapped grip
    S.box(10, 27, -3, 3, -1, 1, "Weapon", "wood")  # flat paddle
    for u in range(11, 26, 3):  # obsidian teeth along both edges
        for w0 in (-5, 3):
            S.box(u, u + 2, w0, w0 + 2, -1, 1, "Weapon", "obsidian")
    S.box(27, 28, -3, 3, -1, 1, "Weapon", "wood_dk")  # end cap


m.paint_body = paint_body
m.paint_sword = paint_club

if __name__ == "__main__":
    m.main()
