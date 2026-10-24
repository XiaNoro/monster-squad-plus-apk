# Gives every field strip in assets/fields the rounded corners of the game's own strip (L_forest_02.png).
# Usage: python tools/round_strips.py
import glob, os
import cv2
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
mask = cv2.imread(os.path.join(ROOT, "assets/apk/sprites/betaUI00/L_forest_02.png"), cv2.IMREAD_UNCHANGED)[:, :, 3]
for f in glob.glob(os.path.join(ROOT, "assets/fields/*.png")):
    im = cv2.imread(f, cv2.IMREAD_UNCHANGED)
    if im.shape[2] == 3:
        im = np.dstack([im, np.full(im.shape[:2], 255, np.uint8)])
    m = cv2.resize(mask, (im.shape[1], im.shape[0]), interpolation=cv2.INTER_AREA)
    im[:, :, 3] = np.minimum(im[:, :, 3], m)
    cv2.imwrite(f, im)
    print(os.path.basename(f))
