"""Turn a textured Meshy GLB into flat plastic for Roblox: one mesh node per palette colour, so Import 3D gives one
MeshPart per colour and each gets a plain Plastic colour (the owner's art direction is untextured studded plastic).

  python3 -I 26_plasticify_glb.py clusters textured.glb [k]            # texture colour clusters, to pick ANCHORS
  python3 -I 26_plasticify_glb.py convert textured.glb out.glb preview.png [geometry.glb|-] [anchor set]
  python3 -I 26_plasticify_glb.py stone untextured.glb out.glb preview.png  # a stone building with no texture
  python3 -I 26_plasticify_glb.py heights model.glb width tile [base] [hex]  # top height per tile, Roblox studs

`stone` colours by geometry: lighter steps up the middle of each face, green moss on the upward faces of about half the
blocks below the top, stone elsewhere. `heights` scales the model to `width` studs and prints the highest surface at
each tile centre (in the orientation Roblox imports it: glTF +Z ends up on Roblox -Z), for MapLayout.

`convert` samples each triangle's texture colour, snaps it to the nearest ANCHORS colour, then makes any connected piece
that is 70%+ one colour all that colour (a brick is one colour). With geometry.glb (Meshy's untextured "generate"
twin, same shape) the colours are moved onto its triangles by nearest centroid. Output is flat-shaded (own vertices
per triangle) so bricks keep hard edges. ANCHORS below are the Overgrown Skull Shrine's (export/Prop_SkullShrine_Plastic.glb);
run `clusters` and edit them for another model.
"""
import io, json, struct, sys
import numpy as np
from PIL import Image, ImageDraw

ANCHOR_SETS = {  # per model: texture colour (from `clusters`) -> palette name
    "skull": [  # Overgrown Skull Shrine
        ((162, 158, 143), "Bone"), ((144, 143, 123), "Bone"),
        ((71, 93, 16), "Green"), ((79, 90, 44), "DarkGreen"), ((113, 119, 78), "DarkGreen"),
        ((81, 55, 26), "Brown"), ((58, 56, 54), "Ink"),
        ((241, 105, 205), "Pink"), ((242, 144, 56), "Orange"), ((165, 117, 221), "Purple"),
    ],
    "totem": [  # Vinebound Tower
        ((131, 132, 134), "Stone"), ((114, 131, 114), "Stone"), ((98, 189, 150), "Jade"),
        ((48, 107, 37), "DarkGreen"), ((60, 111, 50), "DarkGreen"), ((82, 128, 73), "Green"),
        ((100, 135, 58), "Moss"), ((83, 109, 34), "Moss"),
    ],
}
ANCHORS = ANCHOR_SETS["skull"]
PLASTIC = {"Bone": (226, 218, 196), "Green": (75, 151, 75), "DarkGreen": (45, 110, 55), "Brown": (110, 68, 40),
           "Ink": (30, 32, 36), "Pink": (235, 110, 190), "Orange": (245, 145, 45), "Purple": (150, 100, 215),
           "Stone": (150, 154, 140), "Step": (176, 170, 152), "Moss": (80, 150, 66),  # Map1Builder's STONE / stairs
           "Jade": (60, 176, 120)}  # Map1Builder's JADE
NAMES = list(PLASTIC)
COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NUM = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path):
    """First primitive's positions, triangles, uvs (or None) and base colour image (or None)."""
    data = open(path, "rb").read()
    jlen = struct.unpack_from("<I", data, 12)[0]
    g = json.loads(data[20:20 + jlen])
    binary = data[28 + jlen:]

    def view(i):
        bv = g["bufferViews"][i]
        return binary[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]

    def acc(i):
        a = g["accessors"][i]
        n = NUM[a["type"]]
        arr = np.frombuffer(view(a["bufferView"]), COMP[a["componentType"]], a["count"] * n, a.get("byteOffset", 0))
        return arr.reshape(a["count"], n).astype(np.float64)

    prim = g["meshes"][0]["primitives"][0]
    pos, tris = acc(prim["attributes"]["POSITION"]), acc(prim["indices"]).astype(np.int64).reshape(-1, 3)
    uv = acc(prim["attributes"]["TEXCOORD_0"]) if "TEXCOORD_0" in prim["attributes"] else None
    img = None
    if "material" in prim:
        tex = g["materials"][prim["material"]]["pbrMetallicRoughness"].get("baseColorTexture")
        if tex:
            src = g["images"][g["textures"][tex["index"]]["source"]]["bufferView"]
            img = np.asarray(Image.open(io.BytesIO(view(src))).convert("RGB")).astype(np.float64)
    return pos, tris, uv, img


def face_colors(uv, tris, img):
    h, w, _ = img.shape
    centre = uv[tris].mean(1)
    samples = [centre] + [uv[tris[:, k]] * 0.6 + centre * 0.4 for k in range(3)]  # centre + 3 inset corners
    cols = [img[np.clip((p[:, 1] % 1) * h, 0, h - 1).astype(int), np.clip((p[:, 0] % 1) * w, 0, w - 1).astype(int)]
            for p in samples]  # glTF uv origin is the image's top-left
    return np.median(np.stack(cols), 0)


def islands(pos, tris):
    """Connected-piece label per triangle (vertices welded by position: exporters split them on uv seams)."""
    weld = np.unique(np.round(pos, 5), axis=0, return_inverse=True)[1].reshape(-1)
    parent = np.arange(weld.max() + 1)

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for a, b, c in weld[tris]:
        ra = find(a)
        parent[find(b)] = ra
        parent[find(c)] = ra
    return np.unique([find(v) for v in weld[tris[:, 0]]], return_inverse=True)[1]


def classify(cols, lab, area):
    anchors = np.array([a for a, _ in ANCHORS], float)
    cls = np.array([NAMES.index(n) for _, n in ANCHORS])[((cols[:, None] - anchors[None]) ** 2).sum(2).argmin(1)]
    out = cls.copy()
    for i in range(lab.max() + 1):
        f = lab == i
        w = np.bincount(cls[f], weights=area[f], minlength=len(NAMES))
        if w.max() >= 0.7 * w.sum():
            out[f] = w.argmax()
    return out


def nearest(src, dst, chunk=800):
    out = np.empty(len(dst), np.int64)
    s2 = (src ** 2).sum(1)
    for i in range(0, len(dst), chunk):
        out[i:i + chunk] = (s2[None] - 2 * dst[i:i + chunk] @ src.T).argmin(1)
    return out


def write_glb(path, pos, tris, cls):
    """Flat-shaded, one node + mesh + material per palette colour that is used."""
    v = pos[tris]
    fn = np.cross(v[:, 1] - v[:, 0], v[:, 2] - v[:, 0])
    fn /= np.linalg.norm(fn, axis=1, keepdims=True) + 1e-12
    bin_, views, accs, meshes, nodes, mats = bytearray(), [], [], [], [], []

    def add(arr, target, comp, typ, minmax=False):
        bin_.extend(b"\0" * (-len(bin_) % 4))
        views.append({"buffer": 0, "byteOffset": len(bin_), "byteLength": arr.nbytes, "target": target})
        bin_.extend(arr.tobytes())
        a = {"bufferView": len(views) - 1, "componentType": comp, "count": len(arr), "type": typ}
        if minmax:
            a["min"], a["max"] = arr.min(0).tolist(), arr.max(0).tolist()
        accs.append(a)
        return len(accs) - 1

    for k, name in enumerate(NAMES):
        sel = cls == k
        if not sel.any():
            continue
        p = add(v[sel].reshape(-1, 3).astype(np.float32), 34962, 5126, "VEC3", True)
        n = add(np.repeat(fn[sel], 3, axis=0).astype(np.float32), 34962, 5126, "VEC3")
        i = add(np.arange(sel.sum() * 3, dtype=np.uint32), 34963, 5125, "SCALAR")
        mats.append({"name": name, "pbrMetallicRoughness": {"baseColorFactor": [c / 255 for c in PLASTIC[name]] + [1],
                                                             "metallicFactor": 0, "roughnessFactor": 0.6}})
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": p, "NORMAL": n}, "indices": i,
                                                     "material": len(mats) - 1}]})
        nodes.append({"name": name, "mesh": len(meshes) - 1})
    bin_.extend(b"\0" * (-len(bin_) % 4))
    g = {"asset": {"version": "2.0", "generator": "26_plasticify_glb"}, "scene": 0,
         "scenes": [{"nodes": list(range(len(nodes)))}], "nodes": nodes, "meshes": meshes, "materials": mats,
         "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(bin_)}]}
    js = json.dumps(g, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 28 + len(js) + len(bin_)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(bin_), 0x004E4942) + bytes(bin_))
    return [m["name"] for m in meshes]


def preview(path, pos, tris, cls, size=900):
    """Front view (glTF +Z faces the viewer), flat shaded, painter's algorithm."""
    img = Image.new("RGB", (size, size), (200, 205, 210))
    d = ImageDraw.Draw(img)
    v = pos[tris]
    lo, hi = pos.min(0), pos.max(0)
    scale = 0.9 * size / max(hi[0] - lo[0], hi[1] - lo[1])
    fn = np.cross(v[:, 1] - v[:, 0], v[:, 2] - v[:, 0])
    fn /= np.linalg.norm(fn, axis=1, keepdims=True) + 1e-9
    shade = 0.45 + 0.55 * np.clip(fn @ (np.array([0.4, 0.6, 0.7]) / np.linalg.norm([0.4, 0.6, 0.7])), 0, 1)
    for t in np.argsort(v[:, :, 2].mean(1)):
        if fn[t, 2] > 0:
            pts = [((x - (lo[0] + hi[0]) / 2) * scale + size / 2, size / 2 - (y - (lo[1] + hi[1]) / 2) * scale)
                   for x, y, _ in v[t]]
            d.polygon(pts, fill=tuple(int(c * shade[t]) for c in PLASTIC[NAMES[cls[t]]]))
    img.save(path)


def stone_classes(pos, tris):
    v = pos[tris]
    c = v.mean(1)
    fn = np.cross(v[:, 1] - v[:, 0], v[:, 2] - v[:, 0])
    ny = fn[:, 1] / (np.linalg.norm(fn, axis=1) + 1e-12)
    lo, hi = pos.min(0), pos.max(0)
    t = (c[:, 1] - lo[1]) / (hi[1] - lo[1])
    width = max(hi[0] - lo[0], hi[2] - lo[2])
    mid = (lo + hi) / 2
    steps = ((np.abs(c[:, 0] - mid[0]) < 0.09 * width) | (np.abs(c[:, 2] - mid[2]) < 0.09 * width)) & (t < 0.7)
    lab = islands(pos, tris)
    mossy = ((lab * 0.6180339887) % 1) < 0.55  # about half the blocks, fixed per block
    cls = np.full(len(tris), NAMES.index("Stone"))
    cls[steps] = NAMES.index("Step")
    cls[(ny > 0.7) & ~steps & (t < 0.72) & mossy] = NAMES.index("Moss")
    return cls


def heights(pos, tris, width, tile, base=0.0):
    """Highest surface at every map tile centre once scaled to `width` studs with its bottom at `base`, as Roblox
    imports it. The grid is the map's (centres at odd multiples of tile/2), covering whole tiles of the footprint."""
    lo, hi = pos.min(0), pos.max(0)
    k = width / (hi[0] - lo[0])  # Roblox's Model:ScaleTo is uniform, and the width is the model's X size
    p = (pos - [(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2]) * k
    p[:, 0], p[:, 2] = -p[:, 0], -p[:, 2]  # Roblox's import turns the model half way round
    p[:, 1] += base
    v = p[tris]
    half = tile * round(width / 2 / tile)
    centres = np.arange(-half + tile / 2, half, tile)
    out = np.zeros((len(centres), len(centres)))
    a, b, c = v[:, 0], v[:, 1], v[:, 2]
    for i, x in enumerate(centres):
        for j, z in enumerate(centres):
            # barycentric test of (x, z) against every triangle's xz projection
            d = (b[:, 2] - c[:, 2]) * (a[:, 0] - c[:, 0]) + (c[:, 0] - b[:, 0]) * (a[:, 2] - c[:, 2])
            with np.errstate(divide="ignore", invalid="ignore"):
                w1 = ((b[:, 2] - c[:, 2]) * (x - c[:, 0]) + (c[:, 0] - b[:, 0]) * (z - c[:, 2])) / d
                w2 = ((c[:, 2] - a[:, 2]) * (x - c[:, 0]) + (a[:, 0] - c[:, 0]) * (z - c[:, 2])) / d
            w3 = 1 - w1 - w2
            inside = (w1 >= 0) & (w2 >= 0) & (w3 >= 0) & (np.abs(d) > 1e-12)
            if inside.any():
                out[i, j] = max(0.0, (w1 * a[:, 1] + w2 * b[:, 1] + w3 * c[:, 1])[inside].max())
    return centres, out, half, p[:, 1].max()


def kmeans(x, k, iters=30, seed=1):
    c = x[np.random.default_rng(seed).choice(len(x), k, replace=False)]
    for _ in range(iters):
        lab = ((x[:, None] - c[None]) ** 2).sum(2).argmin(1)
        c = np.array([x[lab == i].mean(0) if (lab == i).any() else c[i] for i in range(k)])
    return c, lab


if __name__ == "__main__" and sys.argv[1] in ("stone", "heights"):
    pos, tris = read_glb(sys.argv[2])[:2]
    if sys.argv[1] == "stone":
        cls = stone_classes(pos, tris)
        names = write_glb(sys.argv[3], pos, tris, cls)
        print("meshes:", ", ".join(f"{n} {(cls == NAMES.index(n)).sum()}" for n in names))
        preview(sys.argv[4], pos, tris, cls)
    else:
        base = float(sys.argv[5]) if len(sys.argv) > 5 else 0.0
        centres, h, half, top = heights(pos, tris, float(sys.argv[3]), float(sys.argv[4]), base)
        print(f"-- half {half:g}, top {top:.1f}, tile centres {centres[0]:g}..{centres[-1]:g}, rows = x, columns = z")
        for row in h:
            if len(sys.argv) > 6 and sys.argv[6] == "hex":  # two hex digits per cell, one string per row
                print('"' + "".join(f"{int(round(v)):02x}" for v in row) + '",')
            else:
                print("{ " + ", ".join(str(int(round(v))) for v in row) + " },")
elif __name__ == "__main__":
    mode, textured = sys.argv[1], sys.argv[2]
    tpos, ttris, tuv, timg = read_glb(textured)
    assert tuv is not None and timg is not None, "the first GLB needs uvs and a base colour texture"
    tcols = face_colors(tuv, ttris, timg)
    if mode == "clusters":
        centres, cl = kmeans(tcols, int(sys.argv[3]) if len(sys.argv) > 3 else 10)
        for i in np.argsort(-np.bincount(cl, minlength=len(centres))):
            print(f"rgb {tuple(int(c) for c in centres[i])}: {(cl == i).sum()} triangles")
    else:
        out, png = sys.argv[3], sys.argv[4]
        if len(sys.argv) > 6:
            ANCHORS = ANCHOR_SETS[sys.argv[6]]
        if len(sys.argv) > 5 and sys.argv[5] != "-":  # untextured twin: its geometry, the textured model's colours
            pos, tris = read_glb(sys.argv[5])[:2]
            cols = tcols[nearest(tpos[ttris].mean(1), pos[tris].mean(1))]
        else:
            pos, tris, cols = tpos, ttris, tcols
        v = pos[tris]
        cls = classify(cols, islands(pos, tris), np.linalg.norm(np.cross(v[:, 1] - v[:, 0], v[:, 2] - v[:, 0]), axis=1) / 2)
        names = write_glb(out, pos, tris, cls)
        print("meshes:", ", ".join(f"{n} {(cls == NAMES.index(n)).sum()}" for n in names))
        preview(png, pos, tris, cls)
