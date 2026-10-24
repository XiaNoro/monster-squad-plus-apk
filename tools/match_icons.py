# Identifies monster icons in a footage frame (stage drop lists, boss slots, rewards) by comparing each crop
# with every wiki icon in assets/icons. Boxes are x,y,w,h in the frame's own pixels around the whole 92px card.
# Prints the top 3 ids per box with scores (higher is better).
# Usage: python tools/match_icons.py <frame.png|jpg> x,y,w,h [x,y,w,h ...]
import sys, os, glob
import numpy as np
import cv2

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 92
INNER = (slice(14, 70), slice(12, 80))


def prep(img):
    img = cv2.resize(img, (S, S), interpolation=cv2.INTER_AREA)[INNER]
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB).astype(np.float32)
    lab -= lab.mean(axis=(0, 1))
    return lab / (np.linalg.norm(lab) + 1e-6)


def library():
    lib = {}
    for p in glob.glob(os.path.join(ROOT, "assets", "icons", "*.webp")):
        img = cv2.imread(p, cv2.IMREAD_UNCHANGED)
        if img is None:
            continue
        if img.shape[2] == 4:
            a = img[..., 3:4] / 255.0
            img = (img[..., :3] * a + 128 * (1 - a)).astype(np.uint8)
        lib[os.path.splitext(os.path.basename(p))[0]] = prep(img)
    return lib


def stack(lib):
    keys = list(lib)
    return keys, np.stack([lib[k].reshape(-1) for k in keys])


def best(frame, box, keys, mat, n=3):
    x, y, w, h = box
    step = max(2, w // 30)
    scores = np.full(len(keys), -1.0)
    for dx in (-step, 0, step):
        for dy in (-step, 0, step):
            crop = frame[max(0, y + dy):y + dy + h, max(0, x + dx):x + dx + w]
            if crop.size == 0:
                continue
            scores = np.maximum(scores, mat @ prep(crop).reshape(-1))
    order = np.argsort(-scores)[:n]
    return [(keys[i], float(scores[i])) for i in order]


def main():
    frame = cv2.imread(sys.argv[1])
    keys, mat = stack(library())
    for arg in sys.argv[2:]:
        top = best(frame, [int(v) for v in arg.split(",")], keys, mat)
        print(arg, " ".join("%s:%.3f" % kv for kv in top))


if __name__ == "__main__":
    main()
