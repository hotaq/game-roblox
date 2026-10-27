# 10_voxel_textures.py: 16x16 pixel-art block textures in the "Voxel Jungle" palette (art direction sheet).
# Run with plain python3 (needs Pillow): python3 goblin/scripts/10_voxel_textures.py
# Writes goblin/textures/voxel/<name>.png at 1024x1024 (each texel = 64x64 px, nearest-neighbour) so Roblox's
# bilinear MaterialVariant filtering can't blur the pixels, plus _sheet.png (all of them side by side).
import os
import random

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "textures", "voxel")
N, SCALE = 16, 64

# Two palettes, same clusters and layout (PALETTE=bright python3 ... writes textures/voxel_bright/):
#  muted: earthy dark-fantasy (art ref: chunky voxel goblin camp, overcast daylight)
#  bright: same detail, saturated kid-friendly colors (most Roblox players are kids on phones)
#  soft: bright, toned down a notch (user's pick): gentler saturation, warm-gray stone, creamy bone
PALETTE = os.environ.get("PALETTE", "muted")
if PALETTE != "muted":
    OUT += "_" + PALETTE
if PALETTE == "soft":
    MOSS_OLIVE, FOREST, LEAF = (112, 170, 72), (62, 116, 54), (128, 186, 84)
    BARK, EARTH = (128, 88, 58), (176, 130, 88)
    STONE, RUIN = (156, 154, 150), (214, 196, 160)
    TEAL, TURQ, LIME = (60, 150, 200), (130, 204, 230), (186, 226, 110)
    BONE, CLOTH = (232, 222, 196), (190, 64, 54)
elif PALETTE == "bright":
    MOSS_OLIVE, FOREST, LEAF = (106, 178, 60), (50, 118, 44), (124, 198, 70)
    BARK, EARTH = (134, 86, 50), (184, 128, 76)
    STONE, RUIN = (156, 162, 172), (218, 196, 152)
    TEAL, TURQ, LIME = (40, 150, 210), (110, 210, 240), (190, 236, 90)
    BONE, CLOTH = (242, 234, 210), (206, 50, 40)
else:
    MOSS_OLIVE, FOREST, LEAF = (84, 112, 50), (46, 70, 34), (96, 128, 56)
    BARK, EARTH = (98, 62, 40), (122, 82, 52)
    STONE, RUIN = (122, 122, 124), (170, 154, 124)
    TEAL, TURQ, LIME = (46, 92, 110), (88, 136, 150), (132, 150, 70)
    BONE, CLOTH = (216, 206, 180), (128, 34, 30)


def shade(c, k):
    return tuple(max(0, min(255, round(v * k))) for v in c)


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def blobs(rng, count, rmin, rmax):
    """Set of (x, y) covered by `count` wrapped round blobs, for moss patches and pebbles."""
    s = set()
    for _ in range(count):
        cx, cy, r = rng.randrange(N), rng.randrange(N), rng.uniform(rmin, rmax)
        for dx in range(-3, 4):
            for dy in range(-3, 4):
                if dx * dx + dy * dy <= r * r:
                    s.add(((cx + dx) % N, (cy + dy) % N))
    return s


def grass(rng):
    base = [shade(MOSS_OLIVE, 1.12), shade(MOSS_OLIVE, 1.0), mix(MOSS_OLIVE, LEAF, 0.4), shade(MOSS_OLIVE, 1.22)]
    px = [[rng.choice(base) for _ in range(N)] for _ in range(N)]
    for x, y in blobs(rng, 7, 0.8, 1.6):
        px[y][x] = mix(LEAF, FOREST, 0.55)
    for _ in range(10):
        px[rng.randrange(N)][rng.randrange(N)] = shade(FOREST, 0.8)
    for _ in range(6):
        px[rng.randrange(N)][rng.randrange(N)] = mix(MOSS_OLIVE, LIME, 0.45)
    return px


def dirt(rng):
    base = [EARTH, shade(EARTH, 0.9), shade(EARTH, 1.08), mix(EARTH, BARK, 0.3)]
    px = [[rng.choice(base) for _ in range(N)] for _ in range(N)]
    for x, y in blobs(rng, 7, 0.5, 1.0):
        px[y][x] = mix(STONE, EARTH, 0.4)
    for x, y in blobs(rng, 5, 0.6, 1.2):
        px[y][x] = shade(EARTH, 0.68)
    for _ in range(8):
        px[rng.randrange(N)][rng.randrange(N)] = shade(BARK, 0.8)
    return px


def stone(rng, base_c, moss, brick):
    px = [[shade(base_c, rng.choice((0.92, 1.0, 1.0, 1.07))) for _ in range(N)] for _ in range(N)]
    mortar = shade(base_c, 0.78)
    if brick:  # 8x4 bricks, every other row offset by 4
        for y in range(N):
            for x in range(N):
                off = 4 if (y // 4) % 2 else 0
                if y % 4 == 3 or (x + off) % 8 == 7:
                    px[y][x] = mortar
    else:  # two big cut stones with a crack
        for x in range(N):
            px[9][x] = mortar
        for y in range(9):
            px[y][6] = mortar
        for y in range(10, N):
            px[y][12] = mortar
    for _ in range(10):  # light chips
        px[rng.randrange(N)][rng.randrange(N)] = shade(base_c, 1.18)
    for x, y in blobs(rng, moss, 1.0, 2.2):
        px[y][x] = rng.choice((LEAF, MOSS_OLIVE, mix(LEAF, FOREST, 0.4)))
    return px


def bark(rng):
    cols = [rng.choice((0.85, 1.0, 1.12)) for _ in range(N)]
    px = [[shade(BARK, cols[x] * rng.choice((0.94, 1.0, 1.0, 1.06))) for x in range(N)] for _ in range(N)]
    for x in range(0, N, 4):  # dark grooves
        for y in range(N):
            if rng.random() < 0.8:
                px[y][x] = shade(BARK, 0.62)
    vx = rng.randrange(N)  # one wandering vine
    for y in range(N):
        vx = (vx + rng.choice((-1, 0, 0, 1))) % N
        px[y][vx] = LEAF if y % 3 else MOSS_OLIVE
    return px


def bone(rng):
    px = [[shade(BONE, rng.choice((0.9, 0.96, 1.0, 1.0, 1.05))) for _ in range(N)] for _ in range(N)]
    for x, y in blobs(rng, 4, 0.6, 1.3):  # old stains
        px[y][x] = mix(BONE, EARTH, 0.35)
    x, y = rng.randrange(N), rng.randrange(N)  # one hairline crack
    for _ in range(7):
        px[y][x] = shade(BONE, 0.68)
        x, y = (x + rng.choice((0, 1))) % N, (y + 1) % N
    return px


def cloth(rng):
    rows = [rng.choice((0.85, 1.0, 1.0, 1.1)) for _ in range(N)]  # weave stripes
    px = [[shade(CLOTH, rows[y] * rng.choice((0.92, 1.0, 1.06))) for x in range(N)] for y in range(N)]
    for x, y in blobs(rng, 4, 0.7, 1.5):  # grime
        px[y][x] = mix(CLOTH, EARTH, 0.45)
    return px


def leaves(rng):
    base = [LEAF, shade(LEAF, 1.15), mix(LEAF, FOREST, 0.5), FOREST]
    px = [[rng.choice(base) for _ in range(N)] for _ in range(N)]
    for x, y in blobs(rng, 6, 0.6, 1.3):
        px[y][x] = shade(MOSS_OLIVE, 1.1)
    for _ in range(10):
        px[rng.randrange(N)][rng.randrange(N)] = shade(FOREST, 0.7)
    return px


def water(rng):
    px = [[mix(TEAL, TURQ, rng.choice((0.25, 0.35, 0.45))) for _ in range(N)] for _ in range(N)]
    for _ in range(5):  # short ripple dashes
        x, y = rng.randrange(N), rng.randrange(N)
        for i in range(3):
            px[y][(x + i) % N] = mix(TURQ, (255, 255, 255), 0.35)
    return px


TEXTURES = {
    "grass": grass,
    "dirt": dirt,
    "mossy_stone": lambda r: stone(r, STONE, 7, False),
    "ruin_brick": lambda r: stone(r, RUIN, 3, True),
    "bark": bark,
    "leaves": leaves,
    "water": water,
    "bone": bone,
    "cloth": cloth,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    sheet = Image.new("RGB", (N * len(TEXTURES) * 8 + 8 * len(TEXTURES), N * 8), (20, 20, 20))
    for i, (name, fn) in enumerate(TEXTURES.items()):
        px = fn(random.Random(name))
        img = Image.new("RGB", (N, N))
        img.putdata([c for row in px for c in row])
        img.resize((N * SCALE, N * SCALE), Image.NEAREST).save(os.path.join(OUT, name + ".png"), optimize=True)
        sheet.paste(img.resize((N * 8, N * 8), Image.NEAREST), (i * (N * 8 + 8), 0))
    sheet.save(os.path.join(OUT, "_sheet.png"))
    print("wrote", len(TEXTURES), "textures to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
