# Finds monsters that are the same creature in different colours or with different element toppers (Smee, Smoo, Smella,
# Smull...) so they can share one size. Two monsters are variants when they have the same star rating, their art
# silhouettes match (IoU >= SILHOUETTE of the alpha masks squeezed to 48x48, mirrored or not), their dark line art lines up
# (correlation >= LINES), and they sit at the same place in evolution lines of the same length (or the silhouettes match
# almost exactly, >= STRICT). Variants' evolutions and pre-evolutions are variants too, which joins families whose
# toppers differ more at one stage. NOT lists look-alikes rejected by eye, SOLO monsters whose evolution line changes
# creature (the yetis after Torban). Each member gets a height factor against the group's first member: its art is
# scaled until the silhouettes overlap best with the feet aligned, so bodies match even when toppers differ (Smish's
# flames). Measured sizes agree (Smish predicted from Smoovie 1.613, measured 1.604). Writes
# data/monster_variants.json, which tools/guess_monster_sizes.py uses.
# Usage: python tools/find_monster_variants.py
import glob, json, os, sys
import cv2
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "monster_variants.json")
SILHOUETTE = 0.83
STRICT = 0.9
LINES = 0.3
NOT = [("humbath", "permbear")]
SOLO = {"giant_foot", "titan_foot"}


def chain(mons, mid):
    line = [mid]
    a = mid
    while mons[a].get("evolves_from") in mons and mons[a]["evolves_from"] not in line:
        a = mons[a]["evolves_from"]
        line.insert(0, a)
    b = mid
    while mons[b].get("evolves_into") in mons and mons[b]["evolves_into"] not in line:
        b = mons[b]["evolves_into"]
        line.append(b)
    return len(line), line.index(mid)


def load(mid):
    im = cv2.imread(os.path.join(ROOT, "assets", "monsters_cut", mid + ".png"), cv2.IMREAD_UNCHANGED)
    ys, xs = np.where(im[:, :, 3] > 128)
    c = im[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    mask = cv2.resize(c[:, :, 3], (48, 48), interpolation=cv2.INTER_AREA) > 128
    g = cv2.cvtColor(c[:, :, :3], cv2.COLOR_BGR2GRAY).astype(np.float32)
    g[c[:, :, 3] < 128] = 255
    g = cv2.resize(g, (128, 128), interpolation=cv2.INTER_AREA)
    dark = cv2.resize(np.clip((90 - g) / 90, 0, 1), (64, 64), interpolation=cv2.INTER_AREA)
    return mask.reshape(-1), cv2.GaussianBlur(dark, (5, 5), 1.2)


def full_mask(mid):
    a = cv2.imread(os.path.join(ROOT, "assets", "monsters_cut", mid + ".png"), cv2.IMREAD_UNCHANGED)[:, :, 3] > 128
    ys, xs = np.where(a)
    return a.shape[0], a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def on_floor(m, size=800):
    c = np.zeros((size, size), bool)
    h, w = m.shape
    c[size - 40 - h:size - 40, size // 2 - w // 2:size // 2 - w // 2 + w] = m
    return c


def height_factor(ref, mem):
    (rh, rm), (mh, mm) = ref, mem
    a = on_floor(cv2.resize(rm.astype(np.uint8), (rm.shape[1] // 2, rm.shape[0] // 2), interpolation=cv2.INTER_NEAREST) > 0)
    best = (0.0, 1.0)
    for flip in (False, True):
        m = mm[:, ::-1] if flip else mm
        for s in np.exp(np.linspace(np.log(0.6), np.log(1.6), 61)):
            size = (max(1, int(round(m.shape[1] * s / 2))), max(1, int(round(m.shape[0] * s / 2))))
            b = on_floor(cv2.resize(m.astype(np.uint8), size, interpolation=cv2.INTER_NEAREST) > 0)
            iou = (a & b).sum() / (a | b).sum()
            if iou > best[0]:
                best = (iou, s)
    return mh * best[1] / rh


def lines(a, b):
    best = -1.0
    for bb in (b, b[:, ::-1]):
        x, y = a - a.mean(), bb - bb.mean()
        best = max(best, float((x * y).sum() / (np.sqrt((x * x).sum() * (y * y).sum()) + 1e-9)))
    return best


def main():
    mons = json.load(open(os.path.join(ROOT, "data", "monsters.json"), encoding="utf-8"))
    ids = sorted(os.path.basename(p)[:-4] for p in glob.glob(os.path.join(ROOT, "assets", "monsters_cut", "*.png")))
    ids = [m for m in ids if m in mons]
    art = [load(m) for m in ids]
    M = np.array([a[0] for a in art], dtype=np.float32)
    Mf = np.array([a[0].reshape(48, 48)[:, ::-1].reshape(-1) for a in art], dtype=np.float32)
    area = M.sum(1)
    inter, inter_f = M @ M.T, M @ Mf.T
    iou = np.maximum(inter / (area[:, None] + area[None, :] - inter), inter_f / (area[:, None] + area[None, :] - inter_f))
    stars = np.array([int(mons[m]["stars"]) for m in ids])
    shape = [chain(mons, m) for m in ids]
    idx = {m: k for k, m in enumerate(ids)}
    banned = {frozenset((idx[a], idx[b])) for a, b in NOT if a in idx and b in idx}
    banned |= {frozenset((idx[s], j)) for s in SOLO if s in idx for j in range(len(ids)) if j != idx[s]}
    pairs = set()
    for i, j in zip(*np.where(np.triu(iou >= SILHOUETTE, 1) & (stars[:, None] == stars[None, :]))):
        if frozenset((i, j)) in banned:
            continue
        if (shape[i] == shape[j] or iou[i, j] >= STRICT) and lines(art[i][1], art[j][1]) >= LINES:
            pairs.add(frozenset((i, j)))
    todo = list(pairs)
    while todo:
        i, j = tuple(todo.pop())
        for rel in ("evolves_into", "evolves_from"):
            a, b = mons[ids[i]].get(rel), mons[ids[j]].get(rel)
            if a in idx and b in idx and a != b and shape[idx[a]] == shape[idx[b]]:
                p = frozenset((idx[a], idx[b]))
                if p not in pairs and p not in banned and stars[idx[a]] == stars[idx[b]]:
                    pairs.add(p)
                    todo.append(p)
    of = list(range(len(ids)))

    def root(x):
        while of[x] != x:
            of[x] = of[of[x]]
            x = of[x]
        return x

    for p in pairs:
        i, j = tuple(p)
        of[root(i)] = root(j)
    groups = {}
    for i in range(len(ids)):
        groups.setdefault(root(i), []).append(i)
    out = []
    for g in sorted(sorted(ids[i] for i in g) for g in groups.values() if len(g) > 1):
        ref = full_mask(g[0])
        out.append({m: 1.0 if m == g[0] else round(height_factor(ref, full_mask(m)), 3) for m in g})
    json.dump({"_about": "Monsters that are the same creature in different colours (tools/find_monster_variants.py). "
                         "Each group shares one body size; a member's height is the group size times its factor.",
               "groups": out}, open(OUT, "w", encoding="utf-8"), indent="\t")
    print("%d groups, %d monsters -> %s" % (len(out), sum(len(g) for g in out), OUT))


if __name__ == "__main__":
    main()
