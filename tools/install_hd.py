import os, re, sys, glob, shutil
import cv2

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1]
BACKUP = os.path.join(ROOT, "research", "assets_pre_hd")
FIELD_SIZE = (716, 204)
FIELD_TOP = 8 / 120
FIELD_H = 102 / 120
CATS = {
    "Icons": ("icons", 256),
    "Skills Icons": ("skill_icons", 128),
    "Island": ("islands", "2x"),
    "Pets": ("pets", 512),
    "stones": ("stone_icons", 256),
    "ui": ("ui", 216),
    "Fields": ("fields", "field"),
    "battle_Background": ("battle_bg", "same"),
}


def trim(img):
    if img.shape[2] == 4:
        pts = cv2.findNonZero((img[..., 3] > 10).astype("uint8"))
        if pts is not None:
            x, y, w, h = cv2.boundingRect(pts)
            img = img[y:y + h, x:x + w]
    return img


def fit(img, w, h):
    k = min(w / img.shape[1], h / img.shape[0])
    return cv2.resize(img, (max(1, round(img.shape[1] * k)), max(1, round(img.shape[0] * k))),
                      interpolation=cv2.INTER_AREA if k < 1 else cv2.INTER_LANCZOS4)


def write(img, path, folder):
    if os.path.exists(path):
        dst = os.path.join(BACKUP, folder, os.path.basename(path))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if not os.path.exists(dst):
            shutil.copy2(path, dst)
    if path.endswith(".webp"):
        cv2.imwrite(path, img, [cv2.IMWRITE_WEBP_QUALITY, 92])
    else:
        cv2.imwrite(path, img)


def original(folder, path):
    b = os.path.join(BACKUP, folder, os.path.basename(path))
    return b if os.path.exists(b) else path


def target(folder, name, src_name):
    olds = [p for p in glob.glob(os.path.join(ROOT, "assets", folder, name + ".*")) if not p.endswith(".import")]
    pngs = [p for p in olds if p.endswith(".png")]
    if folder == "pets":
        return os.path.join(ROOT, "assets", folder, name + ".png"), original(folder, (pngs or olds)[0])
    return olds[0], original(folder, olds[0])


def install(cat):
    folder, rule = CATS[cat]
    done = 0
    for f in sorted(os.listdir(os.path.join(SRC, cat))):
        if "__webp" in f or not f.endswith(".png"):
            continue
        name = re.sub(r"_marked( \(1\))?\.png$", "", f)
        out, ref = target(folder, name, f)
        img = cv2.imread(os.path.join(SRC, cat, f), cv2.IMREAD_UNCHANGED)
        old = cv2.imread(ref, cv2.IMREAD_UNCHANGED)
        if rule == "field":
            h = img.shape[0]
            img = cv2.resize(img[round(h * FIELD_TOP):round(h * (FIELD_TOP + FIELD_H))], FIELD_SIZE, interpolation=cv2.INTER_AREA)
        elif rule == "same":
            img = cv2.resize(img, (old.shape[1], old.shape[0]), interpolation=cv2.INTER_AREA)
        elif rule == "2x":
            img = fit(trim(img), old.shape[1] * 2, old.shape[0] * 2)
        else:
            img = trim(img)
            if max(img.shape[:2]) > rule:
                img = fit(img, rule, rule)
        write(img, out, folder)
        done += 1
    print(cat, "->", folder, done)


def upscale_rest_islands():
    have = {re.sub(r"_marked\.png$", "", f) for f in os.listdir(os.path.join(SRC, "Island"))}
    for p in glob.glob(os.path.join(ROOT, "assets", "islands", "*.*")):
        name, ext = os.path.splitext(os.path.basename(p))
        if ext != ".import" and name not in have:
            img = cv2.imread(original("islands", p), cv2.IMREAD_UNCHANGED)
            write(cv2.resize(img, (img.shape[1] * 2, img.shape[0] * 2), interpolation=cv2.INTER_LANCZOS4), p, "islands")
            print("island 2x", name)


for c in CATS:
    install(c)
upscale_rest_islands()
