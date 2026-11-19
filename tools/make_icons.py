# Builds 256 px card icons for monsters that have none: the frame (element border, stars, class badge) is the
# per-pixel median of existing icons with the same element, stars and class; pixels that vary between them are the
# art window, filled with a head crop of the monster's cut-out.
# Usage: python tools/make_icons.py <monster id> ... [--preview out.png]
import json, os, sys
import cv2
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, "assets", "icons")
SIZE = 256
HEAD = 0.72
ORB, ORB_R = (43, 44), 33
BADGE, BADGE_R = (205, 203), 45
STARS = ((60, 11), (243, 46))


def load_icon(mid):
    for ext in ("png", "webp", "jpg"):
        p = os.path.join(ICONS, "%s.%s" % (mid, ext))
        if os.path.exists(p):
            return np.array(Image.open(p).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)).astype(np.float32)
    return None


def frame_for(m, monsters):
    same = [i for i, x in monsters.items() if (x["element"], x["stars"], x.get("class")) == (m["element"], m["stars"], m.get("class"))]
    stack = np.stack([a for a in (load_icon(i) for i in same) if a is not None])
    med = np.median(stack, 0)
    spread = np.median(np.abs(stack - med), 0)[:, :, :3].mean(2)
    frame = (spread < 6) & (med[:, :, 3] > 200)
    frame = cv2.morphologyEx(frame.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)).astype(bool)
    inner = np.zeros((SIZE, SIZE), np.uint8)
    cv2.rectangle(inner, (10, 10), (SIZE - 11, SIZE - 11), 1, -1)
    window = (inner > 0) & ~frame
    n, lab, st, _ = cv2.connectedComponentsWithStats(window.astype(np.uint8))
    keep = np.zeros_like(window)
    if n > 1:
        big = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
        keep = lab == big
    keep = cv2.morphologyEx(keep.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8)) > 0
    donor = next(a for a in (load_icon(i) for i in same) if a is not None)
    decor = np.zeros((SIZE, SIZE), np.uint8)
    cv2.circle(decor, ORB, ORB_R, 1, -1)
    cv2.circle(decor, BADGE, BADGE_R, 1, -1)
    cv2.rectangle(decor, STARS[0], STARS[1], 1, -1)
    return med, donor, keep, decor > 0, len(stack)


def head_crop(mid):
    im = np.array(Image.open(os.path.join(ROOT, "assets", "monsters_cut", mid + ".png")).convert("RGBA")).astype(np.float32)
    ys, xs = np.where(im[:, :, 3] > 40)
    im = im[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = im.shape[:2]
    side = int(max(h, w) * HEAD)
    cols = np.where(im[: max(1, int(h * 0.5)), :, 3].max(0) > 40)[0]
    cx = int(cols.mean()) if len(cols) else w // 2
    x0 = int(np.clip(cx - side / 2, 0, max(0, w - side)))
    crop = np.zeros((side, side, 4), np.float32)
    part = im[0:side, x0:x0 + side]
    crop[: part.shape[0], : part.shape[1]] = part
    crop = cv2.flip(crop, 1)
    return cv2.resize(crop, (SIZE, SIZE), interpolation=cv2.INTER_AREA)


def build(mid, monsters):
    m = monsters[mid]
    med, donor, window, decor, n = frame_for(m, monsters)
    out = med.copy()
    out[window] = np.array([64, 52, 44, 255], np.float32)
    art = head_crop(mid)
    a = art[:, :, 3:4] / 255.0 * window[:, :, None]
    out[:, :, :3] = out[:, :, :3] * (1 - a) + art[:, :, :3] * a
    d = cv2.GaussianBlur(decor.astype(np.float32), (3, 3), 0)[:, :, None]
    out = out * (1 - d) + donor * d
    return out.clip(0, 255).astype(np.uint8), n


def main(args):
    monsters = json.load(open(os.path.join(ROOT, "data", "monsters.json"), encoding="utf-8"))
    preview = None
    if "--preview" in args:
        preview = args[args.index("--preview") + 1]
        args = [a for a in args if a not in ("--preview", preview)]
    tiles = []
    for mid in args:
        img, n = build(mid, monsters)
        print(mid, "frame from", n, "icons")
        if preview:
            tiles.append(img)
        else:
            Image.fromarray(img).save(os.path.join(ICONS, mid + ".png"))
    if preview:
        Image.fromarray(np.hstack(tiles)).save(preview)


if __name__ == "__main__":
    main(sys.argv[1:])
