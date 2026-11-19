import sys
import cv2
import numpy as np

FRAME = "F:/monster-squad+/research/videos/frames_hd/fjoSkRC4Q1E/2550.jpg"
OUT = "assets/apk/sprites/betaUI00/"
SS = 4


def banner():
    im = cv2.imread(FRAME)
    col = im[600:690, 500:540].astype(np.float32).mean(1)
    rows = [y for y in range(len(col)) if col[y][2] > 190 and col[y][0] < 130]
    w, h, top, tall, notch, edge = 34 * SS, 32 * SS, 3 * SS, 25 * SS, 10 * SS, int(0.8 * SS)
    grad = cv2.resize(col[rows[0]:rows[-1] + 1][:, None, :], (1, tall - 2 * edge), interpolation=cv2.INTER_CUBIC)[:, 0, :]

    def shape(grow, dy=0):
        y0, y1, mid = top - grow + dy, top + tall + grow + dy, top + tall // 2 + dy
        k = grow * 1.6
        m = np.zeros((h, w), np.uint8)
        pts = np.array([[-k, y0], [w + k, y0], [w - notch + k, mid], [w + k, y1], [-k, y1], [notch - k, mid]], np.int32)
        cv2.fillPoly(m, [pts], 255, lineType=cv2.LINE_AA)
        return m.astype(np.float32) / 255.0

    img = np.zeros((h, w, 4), np.float32)
    ink = np.array([10, 45, 95], np.float32)
    shadow, outer, inner = shape(0, SS) * 0.45, shape(0), shape(-edge)
    fill = np.zeros((h, w, 3), np.float32)
    fill[top + edge:top + tall - edge] = grad[:, None, :]
    alpha = np.maximum(outer, shadow)
    rgb = ink[None, None, :] * (1 - inner[:, :, None]) + fill * inner[:, :, None]
    img[:, :, :3] = rgb
    img[:, :, 3] = alpha * 255
    rgb_small = cv2.resize(img[:, :, :3] * (alpha[:, :, None] + 1e-6), (34, 32), interpolation=cv2.INTER_AREA)
    a_small = cv2.resize(alpha, (34, 32), interpolation=cv2.INTER_AREA)
    out = np.dstack([rgb_small / (a_small[:, :, None] + 1e-6), a_small * 255])
    cv2.imwrite(OUT + "9_frame_07.png", np.clip(out, 0, 255).astype(np.uint8))


def line(name, rising):
    step, n, length, width, tip = np.array([24.0, -21.0 if rising else 21.0]), 5, 22.0, 15.0, 8.0
    w, h = 124, 110
    img = np.zeros((h * SS, w * SS, 4), np.uint8)
    d = step / np.linalg.norm(step)
    p = np.array([-d[1], d[0]])
    if p[1] > 0:
        p = -p
    start = np.array([14.0, h - 14.0 if rising else 14.0])
    for k in range(n):
        c = start + step * k
        back, mid, front = c - d * length / 2, c + d * (length / 2 - tip), c + d * length / 2
        light = [back + p * width / 2, mid + p * width / 2, front, back]
        dark = [back - p * width / 2, mid - p * width / 2, front, back]
        for poly, colour in ((light, (250, 200, 150, 190)), (dark, (240, 170, 105, 190))):
            cv2.fillPoly(img, [(np.array(poly) * SS).astype(np.int32)], colour, lineType=cv2.LINE_AA)
    cv2.imwrite(OUT + name, cv2.resize(img, (w * 2, h * 2), interpolation=cv2.INTER_AREA))


banner()
line("K_line_01.png", False)
line("K_line_02.png", True)
