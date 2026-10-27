# 13_icons.py: pixel-art icons for the run UI (weapons, passive tomes, HUD skull/gem/heart) in one sprite sheet.
# Run with plain python3 (needs Pillow): python3 goblin/scripts/13_icons.py
# Each icon is drawn as filled shapes on a 16x16 grid, then gets a 1-pixel dark outline and top-light/bottom-dark
# shading automatically, and is scaled 8x (nearest neighbour) into a 128 px cell. Writes goblin/textures/ui/icons.png
# (4 x 3 cells) and prints the cell of each icon for Config.Icons.
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "textures", "ui")
N, SCALE, COLS = 16, 8, 4
INK = (26, 20, 32)


def shade(c, k):
    return tuple(max(0, min(255, round(v * k))) for v in c)


class Icon:
    def __init__(self):
        self.px = [[None] * N for _ in range(N)]

    def dot(self, x, y, c):
        if 0 <= x < N and 0 <= y < N:
            self.px[y][x] = c

    def line(self, x0, y0, x1, y1, c, w=1):
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(steps + 1):
            x, y = round(x0 + (x1 - x0) * i / steps), round(y0 + (y1 - y0) * i / steps)
            for dx in range(w):
                for dy in range(w):
                    self.dot(x + dx, y + dy, c)

    def disc(self, cx, cy, r, c, inner=-1.0):
        for y in range(N):
            for x in range(N):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if inner < d <= r:
                    self.dot(x, y, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.dot(x, y, c)

    def pattern(self, x0, y0, rows, c):
        for dy, row in enumerate(rows):
            for dx, ch in enumerate(row):
                if ch == "#":
                    self.dot(x0 + dx, y0 + dy, c)

    def finish(self):
        """Top-lit / bottom-dark shading on the fills, then a dark outline around everything (8-neighbour)."""
        src = [row[:] for row in self.px]
        for y in range(N):
            for x in range(N):
                c = src[y][x]
                if c is None:
                    continue
                if y == 0 or src[y - 1][x] is None:
                    self.px[y][x] = shade(c, 1.18)
                elif y == N - 1 or src[y + 1][x] is None:
                    self.px[y][x] = shade(c, 0.78)
        for y in range(N):
            for x in range(N):
                if src[y][x] is None and any(
                    0 <= x + dx < N and 0 <= y + dy < N and src[y + dy][x + dx] is not None
                    for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                ):
                    self.px[y][x] = INK
        return self


def sword():
    i = Icon()
    blade, edge, guard, grip = (226, 190, 132), (246, 222, 170), (139, 90, 43), (107, 68, 35)
    i.line(13, 2, 7, 8, blade, 2)
    i.line(13, 2, 8, 7, edge)
    i.line(3, 8, 8, 13, guard)  # cross-guard, across the blade
    i.line(5, 10, 2, 13, grip, 2)
    i.dot(1, 14, guard)
    return i.finish()


def fireball():
    i = Icon()
    i.disc(10, 6.5, 3.2, (255, 150, 50))  # flame trail, shrinking up and away
    i.disc(12, 4, 2.2, (255, 170, 60))
    i.disc(13.5, 2, 1.2, (255, 200, 80))
    i.disc(7, 10, 4.6, (240, 100, 40))
    i.disc(6.4, 9.4, 2.8, (255, 190, 60))
    i.disc(5.8, 8.8, 1.2, (255, 244, 170))
    return i.finish()


def ring():
    i = Icon()
    i.disc(7.5, 8.5, 6.4, (240, 120, 40), inner=3.6)
    i.disc(7.5, 8.5, 5.2, (255, 196, 70), inner=4.4)
    for x, y in ((7, 0), (2, 3), (13, 3), (1, 10), (14, 10)):  # flame licks
        i.dot(x, y, (255, 150, 50))
        i.dot(x, y + 1, (255, 150, 50))
    return i.finish()


def skull():
    i = Icon()
    bone = (238, 232, 214)
    i.disc(7.5, 7, 5.6, bone)
    i.rect(5, 11, 10, 13, bone)
    i.rect(4, 6, 6, 8, INK)
    i.rect(9, 6, 11, 8, INK)
    i.dot(7, 10, INK)
    i.dot(8, 10, INK)
    i.dot(6, 13, INK)
    i.dot(9, 13, INK)
    return i.finish()


def gem():
    i = Icon()
    for y in range(2, 14):
        half = 6 - abs(y - 7) if y <= 7 else round((13 - y) * 6 / 6)
        i.line(7 - half, y, 8 + half, y, (95, 208, 255))
    i.line(5, 4, 7, 2, (200, 244, 255))
    i.line(4, 6, 6, 4, (200, 244, 255))
    return i.finish()


def heart():
    i = Icon()
    red = (232, 72, 77)
    i.disc(5, 6, 3.4, red)
    i.disc(10, 6, 3.4, red)
    for y in range(7, 14):
        i.line(1 + (y - 7), y, 14 - (y - 7), y, red)
    i.dot(4, 4, (255, 170, 170))
    return i.finish()


def tome(cover, emblem):
    """Passives are spell books (Megabonk's tomes): one shape, the cover colour and emblem tell them apart."""
    i = Icon()
    i.rect(3, 2, 13, 14, cover)
    i.rect(3, 2, 4, 14, shade(cover, 0.7))  # spine
    i.rect(5, 13, 13, 14, (240, 232, 214))  # page edges
    i.pattern(6, 5, emblem, (255, 240, 190))
    return i.finish()


EMBLEMS = {
    "might": ["..#..", ".###.", "#####", "..#..", "..#.."],  # up arrow
    "area": ["#####", "#...#", "#...#", "#...#", "#####"],  # frame
    "haste": ["#..#.", ".#..#", "..#..", ".#..#", "#..#."],  # >>
    "magnet": ["#...#", "#...#", "#...#", "#...#", ".###."],  # U
    "force": ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],  # burst
}
COVERS = {
    "might": (214, 160, 40),
    "area": (70, 170, 120),
    "haste": (70, 130, 220),
    "magnet": (214, 90, 140),
    "force": (226, 110, 60),
}

ICONS = [
    ("sword", sword()),
    ("fire", fireball()),
    ("ring", ring()),
    ("skull", skull()),
    *[(k, tome(COVERS[k], EMBLEMS[k])) for k in ("might", "area", "haste", "magnet", "force")],
    ("gem", gem()),
    ("heart", heart()),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    rows = (len(ICONS) + COLS - 1) // COLS
    cell = N * SCALE
    sheet = Image.new("RGBA", (COLS * cell, rows * cell), (0, 0, 0, 0))
    for k, (name, icon) in enumerate(ICONS):
        img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        img.putdata([(c + (255,)) if c else (0, 0, 0, 0) for row in icon.px for c in row])
        x, y = k % COLS, k // COLS
        sheet.paste(img.resize((cell, cell), Image.NEAREST), (x * cell, y * cell))
        print(f"{name} = {{ {x * cell}, {y * cell} }},")
    sheet.save(os.path.join(OUT, "icons.png"), optimize=True)
    print("wrote", os.path.abspath(os.path.join(OUT, "icons.png")), sheet.size)


if __name__ == "__main__":
    main()
