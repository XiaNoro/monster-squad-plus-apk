# Labelled sheet of wiki icons for quick visual identification.  Usage: python tools/icon_sheet.py out.png id [id ...]
import os, sys
import cv2
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ids = sys.argv[2:]
cells = []
for i in ids:
    img = cv2.imread(os.path.join(ROOT, "assets/icons", i + ".webp"), cv2.IMREAD_UNCHANGED)
    if img is None:
        img = np.zeros((92, 92, 3), np.uint8)
    if img.shape[2] == 4:
        a = img[..., 3:4] / 255.0
        img = (img[..., :3] * a + 40 * (1 - a)).astype(np.uint8)
    img = cv2.resize(img, (110, 110))
    cell = np.zeros((132, 120, 3), np.uint8)
    cell[0:110, 5:115] = img
    cv2.putText(cell, i[:16], (2, 127), cv2.FONT_HERSHEY_SIMPLEX, 0.38, (255, 255, 255), 1)
    cells.append(cell)
cols = 10
while len(cells) % cols:
    cells.append(np.zeros_like(cells[0]))
rows = [np.hstack(cells[r:r + cols]) for r in range(0, len(cells), cols)]
cv2.imwrite(sys.argv[1], np.vstack(rows))
