# Finds where the APK's sound effects play in downloaded videos (normalised cross-correlation at 8 kHz).
# Usage: python -I tools/match_sounds.py <out.tsv> <sound dir or file>... -- <video>...
import os, subprocess, sys
import numpy as np

SR = 8000
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FFMPEG = os.path.join(ROOT, "research/bin/ffmpeg.exe")
CACHE = os.path.join(ROOT, "research/videos/audio8k")
CHUNK = 1 << 20
MAX_T = int(1.2 * SR)
MIN_SCORE = 0.42


def decode(path):
	p = subprocess.run([FFMPEG, "-v", "error", "-i", path, "-vn", "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True)
	return np.frombuffer(p.stdout, dtype=np.float32).astype(np.float64)


def video_audio(path):
	os.makedirs(CACHE, exist_ok=True)
	c = os.path.join(CACHE, os.path.splitext(os.path.basename(path))[0] + ".npy")
	if not os.path.exists(c):
		np.save(c, decode(path).astype(np.float32))
	return np.load(c).astype(np.float64)


def template(path):
	a = decode(path)
	env = np.abs(a)
	on = np.argmax(env > env.max() * 0.05) if env.max() > 0 else 0
	a = a[on:on + MAX_T]
	a = a - a.mean()
	return a / (np.linalg.norm(a) + 1e-9)


def scan(x, temps, names, video, out):
	n = CHUNK
	for start in range(0, len(x), n - MAX_T):
		seg = x[start:start + n]
		if len(seg) < MAX_T:
			break
		seg = seg - seg.mean()
		X = np.fft.rfft(seg, n)
		c2 = np.concatenate([[0.0], np.cumsum(seg * seg)])
		for t, name in zip(temps, names):
			m = len(t)
			if m >= len(seg):
				continue
			r = np.fft.irfft(X * np.conj(np.fft.rfft(t, n)), n)[: len(seg) - m]
			e = np.sqrt(np.maximum(c2[m:m + len(r)] - c2[: len(r)], 1e-9))
			s = r / e
			s[e < np.sqrt(m) * 0.01] = 0.0
			idx = np.where(s > MIN_SCORE)[0]
			last = -SR
			for i in idx[np.argsort(-s[idx])]:
				if abs(i - last) < SR // 2:
					continue
				lo, hi = max(0, i - SR // 4), i + SR // 4
				if s[i] < s[lo:hi].max():
					continue
				last = i
				out.write("%s\t%.2f\t%s\t%.3f\n" % (video, (start + i) / SR, name, s[i]))
		out.flush()


def main():
	args = sys.argv[1:]
	out_path = args[0]
	cut = args.index("--")
	sounds = []
	for a in args[1:cut]:
		sounds += [os.path.join(a, f) for f in sorted(os.listdir(a)) if f.endswith((".ogg", ".mp3"))] if os.path.isdir(a) else [a]
	sounds = [s for s in sounds if os.path.getsize(s) < 400000]
	temps = [template(s) for s in sounds]
	names = [os.path.basename(s) for s in sounds]
	with open(out_path, "a", encoding="utf-8") as out:
		for v in args[cut + 1:]:
			print("scan", v, flush=True)
			scan(video_audio(v), temps, names, os.path.basename(v), out)


main()
