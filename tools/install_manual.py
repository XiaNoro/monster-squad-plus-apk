import json, os, re, sys, shutil, difflib
import cv2

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Desktop/ManualAssets")
MAX_SIDE = 420
ALIAS = {"motspaape": None, "noknog": "no_kong"}
STONES = {"red": "destruction", "blue": "clarity", "green": "blessed", "pink": "windfury", "purple": "steel",
          "yellow": "thunder", "gold": "bravery", "heart": "vitality", "clock": "time", "white": "spirit"}

norm = lambda s: re.sub(r"[^a-z0-9]", "", s.lower())


def trim(img):
    if img.shape[2] == 4:
        pts = cv2.findNonZero((img[..., 3] > 10).astype("uint8"))
        if pts is not None:
            x, y, w, h = cv2.boundingRect(pts)
            img = img[max(0, y - 1):y + h + 1, max(0, x - 1):x + w + 1]
    k = MAX_SIDE / max(img.shape[:2])
    if k < 1:
        img = cv2.resize(img, (round(img.shape[1] * k), round(img.shape[0] * k)), interpolation=cv2.INTER_AREA)
    return img


def save(img, path, backup_dir=None):
    if backup_dir and os.path.exists(path):
        os.makedirs(backup_dir, exist_ok=True)
        dst = os.path.join(backup_dir, os.path.basename(path))
        if not os.path.exists(dst):
            shutil.copy2(path, dst)
    cv2.imwrite(path, img)


def monsters():
    mons = json.load(open(os.path.join(ROOT, "data/monsters.json"), encoding="utf-8"))
    by = {}
    for mid, m in mons.items():
        by.setdefault(norm(m["name"]), mid)
        by.setdefault(norm(mid), mid)
    d = os.path.join(SRC, "Monsters")
    done, skipped = [], []
    for f in sorted(os.listdir(d)):
        if not f.lower().endswith(".png"):
            continue
        k = norm(f[:-4])
        mid = ALIAS[k] if k in ALIAS else by.get(k)
        if mid is None and k not in ALIAS:
            c = difflib.get_close_matches(k, list(by), n=1, cutoff=0.85)
            mid = by[c[0]] if c else None
        if mid is None:
            skipped.append(f)
            continue
        img = cv2.imread(os.path.join(d, f), cv2.IMREAD_UNCHANGED)
        save(trim(img), os.path.join(ROOT, "assets/monsters_cut", mid + ".png"), os.path.join(ROOT, "research/monsters_cut_pre_manual"))
        done.append(mid)
    print("monsters", len(done), "skipped", skipped)


def pets():
    d = os.path.join(SRC, "pets")
    for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
        if f.lower().endswith(".png"):
            save(trim(cv2.imread(os.path.join(d, f), cv2.IMREAD_UNCHANGED)), os.path.join(ROOT, "assets/pets", norm(f[:-4]) + ".png"))
            print("pet", f)


def stones():
    d = os.path.join(SRC, "Mstones")
    for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
        m = re.match(r"([a-z])([a-z]+)stone\.png$", f.lower())
        if m and m.group(2) in STONES:
            out = "%s_%s.png" % (STONES[m.group(2)], m.group(1).upper())
            save(trim(cv2.imread(os.path.join(d, f), cv2.IMREAD_UNCHANGED)), os.path.join(ROOT, "assets/stone_icons", out))
            print("stone", f, "->", out)


monsters()
pets()
stones()
