# Goblin enemy - VFX textures. Plain Python 3 + Pillow (not Blender):  python3 07_vfx_textures.py
# Pixel-art sprites drawn at low resolution and upscaled with nearest-neighbour, white/grey + alpha so Roblox
# tints them with ParticleEmitter.Color / Trail.Color. Output: textures/vfx/*.png and a preview sheet in docs/.
import math, os, random
from PIL import Image

ROOT = os.environ.get("GOBLIN_ROOT", os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "textures", "vfx")
LEVELS = (0, 90, 170, 255)  # quantised alpha = chunky pixel-art edges


def q(a):
    return min(LEVELS, key=lambda l: abs(l - a))


def canvas(w, h):
    return [[(255, 255, 255, 0) for _ in range(w)] for _ in range(h)]


def save(px, name, scale):
    h, w = len(px), len(px[0])
    img = Image.new("RGBA", (w, h))
    img.putdata([c for row in px for c in row])
    img = img.resize((w * scale, h * scale), Image.NEAREST)
    img.save(os.path.join(OUT, name))
    return img


def slash():
    """Trail texture: X runs along the trail, Y across it (row 0 = blade base side, last row = tip side)."""
    rnd = random.Random(3)
    w, h = 32, 8
    px = canvas(w, h)
    for y in range(h):
        edge = y / (h - 1)  # brighter toward the tip edge
        for x in range(w):
            a = 255 * (0.25 + 0.75 * edge ** 1.5)
            if y < h - 2 and rnd.random() < 0.35:
                a *= 0.35  # broken streaks
            v = 255 if y >= h - 2 else 220
            px[y][x] = (v, v, v, q(a))
    return save(px, "vfx_slash.png", 8)


def spark():
    px = canvas(16, 16)
    for y in range(16):
        for x in range(16):
            dx, dy = abs(x - 7.5), abs(y - 7.5)
            if min(dx, dy) < 1:  # 4-point star: solid arms that step down in alpha toward the tips
                a = 255 if max(dx, dy) < 3 else 170 if max(dx, dy) < 5.5 else 90 if max(dx, dy) < 7.5 else 0
            elif dx == dy and dx < 3:
                a = 170  # short diagonals
            else:
                a = 0
            if a:
                px[y][x] = (255, 255, 255, a)
    return save(px, "vfx_spark.png", 8)


def burst():
    px = canvas(16, 16)
    c = 7.5
    for y in range(16):
        for x in range(16):
            dx, dy = x - c, y - c
            r = math.hypot(dx, dy)
            ang = (math.degrees(math.atan2(dy, dx)) + 360) % 45
            ray = 1 - min(ang, 45 - ang) / 9  # 8 rays
            if 3 <= r <= 7.5 and ray > 0:
                px[y][x] = (255, 255, 255, q(255 * ray * (1 - (r - 3) / 6)))
            elif r < 2.2:
                px[y][x] = (255, 255, 255, 255)
    return save(px, "vfx_burst.png", 8)


def blob(name, seed, lobes, shade_top=True):
    rnd = random.Random(seed)
    px = canvas(16, 16)
    for y in range(16):
        for x in range(16):
            d = min(math.hypot(x - lx, y - ly) / lr for lx, ly, lr in lobes)
            if d < 1:
                a = 255 if d < 0.6 else 170 if d < 0.85 else 90
                if rnd.random() < 0.12:
                    a = q(a * 0.6)
                v = 255 - int(70 * (y / 15)) if shade_top else 230  # lit from above
                px[y][x] = (v, v, v, a)
    return save(px, name, 8)


def ring():
    px = canvas(32, 32)
    c = 15.5
    for y in range(32):
        for x in range(32):
            r = math.hypot(x - c, y - c)
            if 12.5 <= r <= 15:
                px[y][x] = (255, 255, 255, 255)
            elif 10 <= r < 12.5:
                px[y][x] = (255, 255, 255, q(255 * (r - 10) / 2.5 * 0.7))
    return save(px, "vfx_ring.png", 4)


def pixel():
    px = canvas(8, 8)
    for y in range(8):
        for x in range(8):
            edge = x in (0, 7) or y in (0, 7)
            v = 150 if edge else 255 - 12 * y
            px[y][x] = (v, v, v, 255)
    return save(px, "vfx_pixel.png", 16)


def main():
    os.makedirs(OUT, exist_ok=True)
    imgs = [slash(), spark(), burst(),
            blob("vfx_dust.png", 5, [(7.5, 9, 6.5), (4.5, 7, 3.5), (11, 7, 3.5)]),
            blob("vfx_smoke.png", 9, [(7.5, 8, 5), (5, 5, 4), (10.5, 5.5, 4), (7.5, 11, 4.5)]),
            ring(), pixel()]
    # preview sheet: each sprite tinted the way the game uses it, on a dark background
    tints = [(120, 230, 230), (255, 230, 120), (255, 255, 255), (170, 140, 100), (60, 60, 60), (255, 70, 40),
             (90, 170, 60)]
    cell = 160
    sheet = Image.new("RGBA", (cell * len(imgs) + 40 * 2, cell + 40), (40, 42, 48, 255))
    x = 40
    for img, t in zip(imgs, tints):
        im = img.copy()
        im.thumbnail((cell - 20, cell - 20), Image.NEAREST)
        r, g, b, a = im.split()
        tinted = Image.merge("RGBA", (r.point(lambda v: v * t[0] // 255), g.point(lambda v: v * t[1] // 255),
                                      b.point(lambda v: v * t[2] // 255), a))
        sheet.alpha_composite(tinted, (x + (cell - im.width) // 2 - 10, 20 + (cell - im.height) // 2 - 10))
        x += cell
    sheet.save(os.path.join(ROOT, "docs", "vfx_textures_preview.png"))
    print("wrote", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
