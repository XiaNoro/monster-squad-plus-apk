import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import video_inventory as vi

FFMPEG = os.path.abspath("research/bin/ffmpeg.exe")


def extract(path, out, every=2):
    os.makedirs(out, exist_ok=True)
    subprocess.run([FFMPEG, "-loglevel", "error", "-y", "-i", path, "-vf", "fps=1/%d,scale=854:-2" % every, "-q:v", "4", os.path.join(out, "f%05d.jpg")], check=False)
    for f in sorted(os.listdir(out)):
        if f.startswith("f") and f.endswith(".jpg"):
            n = int(f[1:6])
            os.replace(os.path.join(out, f), os.path.join(out, "%05d.jpg" % ((n - 1) * every)))


def ocr(d):
    subprocess.run(["powershell", "-NoProfile", "-File", "tools/ocr_frames.ps1", os.path.abspath(d)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)


def main():
    done = 0
    for v in vi.videos():
        if v["dup"] or not v["path"]:
            continue
        d = v["frames"]
        if d and os.path.exists(os.path.join(d, "ocr.tsv")):
            continue
        if not d:
            d = os.path.join(vi.ROOT, "frames" + v["folder"][len("video"):], v["base"])
        if not os.path.isdir(d) or not any(f.endswith(".jpg") for f in os.listdir(d)):
            extract(v["path"], d)
        ocr(d)
        done += 1
        print("ocr %s (%d frames)" % (v["old"], len([f for f in os.listdir(d) if f.endswith(".jpg")])), flush=True)
    print("ocr done:", done)


if __name__ == "__main__":
    main()
