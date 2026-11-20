import json
import os

import cv2
import numpy as np

SOURCES = ["assets/monsters_cut", "research/backup_monsters_cut"]
SIDE = 320.0
MIN_INLIERS = 12


def _gray(img, side=SIDE):
    if img.ndim == 3 and img.shape[2] == 4:
        a = img[:, :, 3:4].astype(np.float32) / 255.0
        img = (img[:, :, :3].astype(np.float32) * a + 210.0 * (1 - a)).astype(np.uint8)
    k = side / max(img.shape[:2])
    img = cv2.resize(img, None, fx=k, fy=k, interpolation=cv2.INTER_AREA)
    return cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if img.ndim == 3 else img


class Namer:
    def __init__(self):
        self.names = {k: v.get("name", k) for k, v in json.load(open("data/monsters.json", encoding="utf8")).items()}
        for p in json.load(open("data/pets.json", encoding="utf8")):
            self.names["pet_" + p["id"]] = "Pet: " + p.get("name", p["id"])
        self.sift = cv2.SIFT_create(nfeatures=600)
        ids, pts, des = [], [], []
        self.labels = []
        for src, prefix in [(s, "") for s in SOURCES] + [("assets/pets", "pet_")]:
            if not os.path.isdir(src):
                continue
            for f in sorted(os.listdir(src)):
                mid, ext = os.path.splitext(f)
                mid = prefix + mid
                if ext not in (".png", ".webp") or mid not in self.names:
                    continue
                img = cv2.imread(os.path.join(src, f), cv2.IMREAD_UNCHANGED)
                if img is None or img.ndim != 3:
                    continue
                g = _gray(img)
                for flip in (False, True):
                    kp, d = self.sift.detectAndCompute(cv2.flip(g, 1) if flip else g, None)
                    if d is None or len(kp) < 8:
                        continue
                    lab = len(self.labels)
                    self.labels.append(mid)
                    ids.append(np.full(len(kp), lab, np.int32))
                    pts.append(np.float32([p.pt for p in kp]))
                    des.append(d)
        self.lab = np.concatenate(ids)
        self.pts = np.concatenate(pts)
        self.des = np.concatenate(des).astype(np.float32)
        self.flann = cv2.FlannBasedMatcher(dict(algorithm=1, trees=6), dict(checks=64))
        self.flann.add([self.des])
        self.flann.train()

    def rank(self, crop, side=SIDE):
        g = _gray(crop, side)
        kp, d = self.sift.detectAndCompute(g, None)
        if d is None or len(kp) < 8:
            return []
        qpts = np.float32([p.pt for p in kp])
        per = {}
        for qi, ms in enumerate(self.flann.knnMatch(d.astype(np.float32), k=6)):
            if not ms:
                continue
            m = ms[0]
            first = self.labels[self.lab[m.trainIdx]]
            other = next((n for n in ms[1:] if self.labels[self.lab[n.trainIdx]] != first), None)
            if other is not None and m.distance >= 0.8 * other.distance:
                continue
            per.setdefault(int(self.lab[m.trainIdx]), []).append((m.trainIdx, qi))
        out = {}
        for lab, pairs in sorted(per.items(), key=lambda kv: -len(kv[1]))[:12]:
            if len(pairs) < 5:
                continue
            src = self.pts[[a for a, _ in pairs]]
            dst = qpts[[b for _, b in pairs]]
            M, inl = cv2.estimateAffinePartial2D(src, dst, method=cv2.RANSAC, ransacReprojThreshold=5.0)
            if M is None:
                continue
            s = float(np.hypot(M[0, 0], M[1, 0]))
            if not 0.3 < s < 5.0:
                continue
            mid = self.labels[lab]
            out[mid] = max(out.get(mid, 0), int(inl.sum()))
        return sorted(out.items(), key=lambda kv: -kv[1])

    def name(self, frames, side=SIDE, min_inliers=MIN_INLIERS):
        votes = {}
        for f in frames:
            for mid, n in self.rank(f, side)[:5]:
                votes[mid] = votes.get(mid, 0) + n
        ranked = sorted(votes.items(), key=lambda kv: -kv[1])
        if not ranked:
            return "", 0, "", 0
        best, score = ranked[0]
        nxt, second = ranked[1] if len(ranked) > 1 else ("", 0)
        ok = score >= min_inliers * len(frames) and score >= second * 1.4
        return (best if ok else ""), score, (nxt if ok else best), second


    def name_any(self, frames, min_inliers=MIN_INLIERS):
        mid, score, nxt, second = self.name(frames, min_inliers=min_inliers)
        if mid or max(frames[0].shape[:2]) >= 480:
            return mid, score, nxt, second
        big = [cv2.resize(f, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC) for f in frames]
        return self.name(big, side=640, min_inliers=min_inliers)

