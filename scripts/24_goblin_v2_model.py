# Goblin v2 - stage 1 replacement: the goblin of concept/goblin_v2/goblin_A_voxel.png (big cube head, pixel ears,
# glowing eyes, brown tunic with a rope belt, bone necklace, wooden club), drawn in the Roblox block-build art style the
# owner picked on 2026-10-28: flat bright colours, no pixel noise, square inlets pressed into the big faces.
# Same voxel engine, labels and joint positions as 01_build_model.py, so 02_build_rig.py, the 21 published Goblin_*
# animations and 05/12 export work unchanged. Only the paint (body + weapon), palette, shading and atlas file differ.
# Run like stage 1 (inside Blender, or headless), then 02 -> 03 -> 04 -> 05 as usual.
import importlib.util
import os

import numpy as np

ROOT = os.environ.get("GOBLIN_ROOT", "/Users/chinnaphat/Desktop/cedt/roblox/goblin")
spec = importlib.util.spec_from_file_location("model01", os.path.join(ROOT, "scripts", "01_build_model.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
h3, ax = m.h3, m.ax

m.TEX = os.path.join(ROOT, "textures", "goblin_v2_atlas.png")
m.WEAPON_GRID = ((-7, -5, -4), (29, 5, 4))
m.PAL.update({  # sRGB, one flat colour each: bright toy-plastic versions of the concept's colours
    "skin": [(108, 192, 74)],
    "skin_dk": [(70, 146, 54)],
    "skin_lt": [(140, 214, 100)],
    "ear_in": [(222, 132, 120)],
    "ear_deep": [(190, 98, 92)],
    "eye": [(255, 222, 64)],
    "eye_hot": [(255, 250, 200)],
    "mouth": [(52, 30, 40)],
    "teeth": [(250, 250, 242)],
    "tunic": [(164, 104, 62)],
    "tunic_dk": [(122, 74, 44)],
    "rope": [(242, 196, 96)],
    "rope_dk": [(204, 150, 66)],
    "bone": [(248, 244, 228)],
    "wood": [(176, 112, 60)],
    "wood_dk": [(128, 78, 40)],
})
m.PAL_ID.clear()
m.PAL_ID.update({n: i for i, n in enumerate(m.PAL)})
m.shade = lambda name, x, y, z: [c / 255.0 for c in m.PAL[name][0]]  # flat: no per-voxel jitter or specks
m.SHADE.update({"rim": 1.0, "bottom": 1.0, "side": 1.0, "top_edge": 1.0, "under_edge": 1.0, "concave": 0.88,
                "material": 1.0, "face_up": 1.04, "face_down": 0.9})  # Roblox lights the blocks; keep only AO

INLET_EVERY, INLET_SIZE = 6, 3.0  # voxels (6 voxels ~ half a stud)
NO_INLET = {m.LID["Eyes"]}


def inlets(q, up, S):
    """Press a square inlet into every INLET_EVERY-voxel cell of a quad, where the cell is one flat colour: the
    upper and left walls in shadow, the lower and right walls catching the light. Side faces have world Z along
    the columns, top/bottom faces have X along the rows."""
    axis, sg, sl, i, i2, j, j2, label = q[:8]
    if label in NO_INLET:
        return up
    out, H, W = up.copy(), up.shape[0], up.shape[1]
    n, bw = round(INLET_SIZE * S), max(1, S // 3)
    off = (INLET_EVERY - INLET_SIZE) / 2
    for b in range(i - i % INLET_EVERY, i2, INLET_EVERY):
        for c in range(j - j % INLET_EVERY, j2, INLET_EVERY):
            r0, c0 = round((b + off - i) * S), round((c + off - j) * S)
            r1, c1 = r0 + n, c0 + n
            if r0 < S // 2 or c0 < S // 2 or r1 > H - S // 2 or c1 > W - S // 2:
                continue
            if np.ptp(up[r0 - 1:r1 + 1, c0 - 1:c1 + 1].reshape(-1, 3), axis=0).max() > 0.02:
                continue  # crosses a colour edge (eye, mouth, belt): leave it plain
            sq = out[r0:r1, c0:c1]
            sq *= 0.96
            if axis == 2:  # top/bottom: shadow on the low-row and low-column walls
                sq[:bw] *= 0.7
                sq[:, :bw] *= 0.78
                sq[-bw:] *= 1.2
                sq[:, -bw:] *= 1.14
            else:  # side: columns run up the wall, so the top wall (high column) is in shadow
                sq[:, -bw:] *= 0.7
                sq[:bw] *= 0.8
                sq[:, :bw] *= 1.2
                sq[-bw:] *= 1.12
    return np.clip(out, 0, 1)


m.PATTERN = inlets
SKIN, CLOTH = "skin", "tunic"
ROPE = lambda x, y, z: "rope_dk" if (x + y) % 3 == 0 else "rope"  # twisted-rope bands


def paint_body(G):
    # legs + feet (ankle z=5, knee z=14, hip z=27 as in 02's rig)
    G.mbox(1, 10, -9, 4, 0, 5, "{S}Foot", SKIN)
    G.mbox(1, 10, -10, -9, 0, 2, "{S}Foot", SKIN)  # toe cap
    G.mclear(4, 5, -10, -9, 0, 2)
    G.mclear(7, 8, -10, -9, 0, 2)
    G.mbox(2, 10, -4, 4, 5, 14, "{S}LowerLeg", SKIN)
    G.mbox(2, 10, -4, 4, 14, 27, "{S}UpperLeg", SKIN)
    # tunic skirt: one half per thigh (like v1's tassets) so a stride doesn't push a leg through it; ragged hem
    G.mbox(0, 12, -7, 7, 17, 27, "{S}UpperLeg", CLOTH)
    for x in range(12):
        bottom = 13 + int(h3(x, 0, 3) * 4)
        G.mbox(x, x + 1, -7, 7, bottom, 17, "{S}UpperLeg",
               lambda x, y, z, b=bottom: "tunic_dk" if z == b else CLOTH)

    # hips: tunic, rope belt with a knot on the goblin's left, two dangling rope ends (front cloth bone)
    G.box(-12, 12, -7, 7, 27, 34, "LowerTorso", CLOTH)
    G.box(-13, 13, -8, 8, 29, 32, "LowerTorso", ROPE)
    G.box(3, 7, -10, -8, 28, 33, "LowerTorso", ROPE)
    for x0, bottom in ((3, 19), (5, 22)):
        G.box(x0, x0 + 1, -10, -9, bottom, 28, "Cloth_F", lambda x, y, z: "rope_dk" if z % 3 == 0 else "rope")
    for x in range(-5, 5):  # short torn back flap
        G.box(x, x + 1, 7, 8, 18 + int(h3(x, 8, 4) * 4), 29, "Cloth_B", CLOTH)

    # chest: sleeveless tunic, stitched V-neck showing skin, bone pendant on a cord
    G.box(-11, 11, -7, 7, 34, 49, "UpperTorso", CLOTH)
    G.box(-11, 11, -7, 7, 48, 49, "UpperTorso", "tunic_dk")
    for z in range(44, 49):
        half = z - 43
        G.box(-half, half, -7, -6, z, z + 1, "UpperTorso", SKIN)
        for x in (-half - 1, half):
            G.box(x, x + 1, -8, -6, z, z + 1, "UpperTorso", "tunic_dk")
    G.box(-1, 1, -8, -7, 40, 45, "UpperTorso", "bone")
    G.box(1, 2, -8, -7, 40, 42, "UpperTorso", "bone")
    G.box(-5, 5, -5, 5, 49, 52, "UpperTorso", SKIN)  # neck

    # arms hang straight (the rig's rest pose); blocky open hands with finger grooves and a thumb
    G.mbox(12, 20, -4, 4, 39, 50, "{S}UpperArm", SKIN)
    G.mbox(12, 20, -4, 4, 32, 39, "{S}LowerArm", SKIN)
    G.mbox(11, 21, -5, 5, 30, 32, "{S}LowerArm", SKIN)  # wrist cuff
    G.mbox(11, 21, -5, 5, 21, 30, "{S}Hand",
           lambda x, y, z: "skin_dk" if y in (-5, 4) and z < 26 and ax(x) in (14, 17) else SKIN)
    G.mclear(14, 15, -5, 5, 21, 23)
    G.mclear(17, 18, -5, 5, 21, 23)
    G.mbox(10, 13, -7, -4, 24, 29, "{S}Hand", SKIN)  # thumb

    # head: one big cube, ~36% of the height
    G.box(-14, 14, -13, 11, 52, 80, "Head", SKIN)
    for x in range(2, 10):  # angry brows, inner ends low, standing one voxel proud
        zb = 67 + (x - 2) // 3
        G.box(x, x + 1, -14, -13, zb, zb + 2, "Head", "skin_dk")
        G.box(-x - 1, -x, -14, -13, zb, zb + 2, "Head", "skin_dk")
    for x0 in (3, -9):  # glowing eyes, flush with the face
        G.box(x0, x0 + 6, -13, -12, 61, 66, "Eyes",
              lambda x, y, z: "eye_hot" if z == 65 and ax(x) == 4 else "eye")
    G.box(-1, 1, -14, -13, 62, 67, "Head", SKIN)  # nose bridge
    G.box(-2, 2, -16, -13, 58, 62, "Head", lambda x, y, z: "skin_lt" if z == 61 else SKIN)
    G.box(-2, -1, -16, -15, 58, 59, "Head", "skin_dk")  # nostrils
    G.box(1, 2, -16, -15, 58, 59, "Head", "skin_dk")
    # wide grin carved into the face: upper teeth row, a few lower teeth, corners turned up
    G.box(-8, 8, -13, -12, 53, 57, "Head", "mouth")
    G.box(-9, -8, -13, -12, 55, 58, "Head", "mouth")
    G.box(8, 9, -13, -12, 55, 58, "Head", "mouth")
    for x in range(-7, 7):
        if x % 3 != 2:
            G.box(x, x + 1, -13, -12, 55, 57, "Head", "teeth")
        if x % 4 == 1:
            G.box(x, x + 1, -13, -12, 53, 54, "Head", "teeth")
    # ears: flat pixel triangles pointing out and a little up, brown inner ear on the front face
    for s, lab in ((1, "Ear_L"), (-1, "Ear_R")):
        for d in range(16):
            zb, zt = 62 + round(d * 0.85), 72 + round(d * 0.3)
            zt = max(zt, zb + 1)
            thick = 3 if d < 6 else 2 if d < 12 else 1
            x = 14 + d if s > 0 else -15 - d
            for z in range(zb, zt):
                for y in range(-2, -2 + thick):
                    inner = y == -2 and 1 <= d < 12 and zb + 1 <= z < zt - 1
                    c = ("ear_deep" if 3 <= d < 9 and zb + 3 <= z < zt - 2 else "ear_in") if inner else \
                        "skin_lt" if z == zt - 1 else SKIN
                    G.box(x, x + 1, y, y + 1, z, z + 1, lab, c)
    G.box(16, 17, -3, -2, 58, 62, "Ear_L", "bone")  # bone earring under the left ear
    G.box(17, 18, -3, -2, 58, 59, "Ear_L", "bone")


def paint_club(S):
    """Wooden club in grip space (01's paint_sword frame): u = along it, w = down at rest, t = sideways."""
    S.box(-6, -4, -2, 2, -2, 2, "Weapon", "wood_dk")  # pommel knob
    S.box(-4, 10, -1, 1, -1, 1, "Weapon", lambda u, w, t: "wood_dk" if -2 <= u <= 3 and u % 2 else "wood")
    S.box(10, 14, -2, 2, -2, 2, "Weapon", "wood")
    S.box(14, 27, -3, 3, -3, 3, "Weapon", "wood")
    for u, w, t in ((17, -4, 0), (21, 3, -1), (24, -1, 3), (19, 1, -4), (25, -4, -2)):  # knots
        S.box(u, u + 2, w, w + 1, t, t + 1, "Weapon", "wood_dk")
    for w in (-3, 2):  # rounded end
        for t in (-3, 2):
            S.clear(26, 27, w, w + 1, t, t + 1)


m.paint_body = paint_body
m.paint_sword = paint_club

if __name__ == "__main__":
    m.main()
