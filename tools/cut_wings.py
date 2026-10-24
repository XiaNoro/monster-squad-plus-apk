# Cuts the +5 monster tag wing out of a hub frame in research/videos/a47QbDBWmOY.mp4 (bronze, Lv.49 Mantiroar)
# and recolours it into assets/ui/wing_gold.png and wing_white.png. The element icon centre lands on ANCHOR
# at 2x the 32px in-game icon, so the textures are drawn at half size.
import glob, os
import cv2
import numpy as np

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "assets", "ui")
TIMES = (2, 16, 54, 174)
BOX = (166, 332, 251, 432)
VIDEO_H = 1070
GAME_H = 640
SIZE = (144, 144)
ANCHOR = (100, 96)

RAMPS = {
    "gold": [(0.0, (60, 30, 4)), (0.35, (196, 112, 8)), (0.65, (250, 188, 36)), (0.85, (255, 226, 96)), (1.0, (255, 248, 190))],
    "white": [(0.0, (22, 28, 78)), (0.35, (138, 144, 200)), (0.65, (208, 212, 242)), (0.85, (236, 238, 252)), (1.0, (255, 255, 255))],
}


def frame():
    path = glob.glob(os.path.join(ROOT, "research", "videos", "**", "a47QbDBWmOY.mp4"), recursive=True)[0]
    cap = cv2.VideoCapture(path)
    frames = []
    for t in TIMES:
        cap.set(cv2.CAP_PROP_POS_MSEC, t * 1000)
        ok, f = cap.read()
        frames.append(f[BOX[1]:BOX[3], BOX[0]:BOX[2]])
    return np.median(np.stack(frames), axis=0).astype(np.uint8)


def wing_mask(crop):
    hsv = cv2.cvtColor(crop, cv2.COLOR_BGR2HSV).astype(int)
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    m = ((((h >= 4) & (h <= 24) & (s > 50) & (v > 90)) | ((v < 120) & ((h <= 25) | (s < 60)))) * 255).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(m)
    m = ((lab == 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))) * 255).astype(np.uint8)
    ff = m.copy()
    cv2.floodFill(ff, np.zeros((m.shape[0] + 2, m.shape[1] + 2), np.uint8), (0, 0), 255)
    return m | cv2.bitwise_not(ff)


def main():
    crop = frame()
    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
    cx, cy, _ = cv2.HoughCircles(cv2.medianBlur(gray, 3), cv2.HOUGH_GRADIENT, 1, 40, param1=80, param2=20, minRadius=18, maxRadius=32)[0][0]
    r = 16 * VIDEO_H / GAME_H
    m = wing_mask(crop)
    yy, xx = np.mgrid[0:m.shape[0], 0:m.shape[1]]
    inside = (xx - cx) ** 2 + (yy - cy) ** 2 <= r ** 2
    m[(xx > cx - r * 0.55) & ~inside] = 0
    rows = np.where(m[:, : int(cx - r)].any(axis=1))[0]
    under = inside & (xx < cx + r * 0.3) & (yy >= rows.min()) & (yy <= rows.max())
    rgb = cv2.inpaint(crop, ((inside & under) * 255).astype(np.uint8), 5, cv2.INPAINT_TELEA)
    m[under] = 255
    m[inside & ~under] = 0
    m = ((cv2.GaussianBlur(m, (5, 5), 0) > 127) * 255).astype(np.uint8)
    lum = cv2.bilateralFilter(cv2.cvtColor(rgb, cv2.COLOR_BGR2GRAY), 5, 30, 5).astype(float)
    lo, hi = np.percentile(lum[m > 0], 2), np.percentile(lum[m > 0], 99)
    t = np.clip((lum - lo) / (hi - lo), 0, 1)
    k = 2 * GAME_H / VIDEO_H
    os.makedirs(OUT, exist_ok=True)
    for name, ramp in RAMPS.items():
        pos = [p for p, _ in ramp]
        col = np.stack([np.interp(t, pos, [c[i] for _, c in ramp]) for i in (2, 1, 0)], axis=-1)
        rgba = np.dstack([col, cv2.GaussianBlur(m, (3, 3), 0)]).astype(np.uint8)
        big = cv2.resize(rgba, None, fx=k, fy=k, interpolation=cv2.INTER_CUBIC)
        big[..., 3] = cv2.GaussianBlur(((big[..., 3] > 127) * 255).astype(np.uint8), (3, 3), 0)
        canvas = np.zeros((SIZE[1], SIZE[0], 4), np.uint8)
        ox, oy = int(round(ANCHOR[0] - cx * k)), int(round(ANCHOR[1] - cy * k))
        h, w = big.shape[:2]
        sx0, sy0 = max(0, -ox), max(0, -oy)
        dx0, dy0 = max(0, ox), max(0, oy)
        ww, hh = min(w - sx0, SIZE[0] - dx0), min(h - sy0, SIZE[1] - dy0)
        canvas[dy0:dy0 + hh, dx0:dx0 + ww] = big[sy0:sy0 + hh, sx0:sx0 + ww]
        cv2.imwrite(os.path.join(OUT, "wing_%s.png" % name), canvas)


main()
