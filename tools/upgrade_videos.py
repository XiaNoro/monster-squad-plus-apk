import argparse
import json
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import video_inventory as vi

YTDLP = os.path.abspath("research/bin/yt-dlp.exe")
COOKIES = "research/bin/youtube_cookies.txt"
CACHE = os.path.join(vi.ROOT, "formats_cache.json")
MIN_H = 720
FIELDS = ["old", "new", "yid", "old_h", "best_h", "new_h", "status", "when"]


def auth():
    return ["--js-runtimes", "deno:" + os.path.abspath("research/bin/deno.exe"), "--remote-components", "ejs:github", "--cookies", COOKIES]


def best_height(v, cache):
    if v["yid"] in cache:
        return cache[v["yid"]]
    best = 0
    if v["info"]:
        d = json.load(open(v["info"], encoding="utf8"))
        best = max([int(f.get("height") or 0) for f in d.get("formats", []) if f.get("vcodec") not in (None, "none")] or [0])
    if not best and v["yid"]:
        r = subprocess.run([YTDLP, "-J", "--no-warnings", "--skip-download"] + auth() + ["https://www.youtube.com/watch?v=" + v["yid"]], capture_output=True, text=True, encoding="utf8", errors="ignore")
        try:
            d = json.loads(r.stdout)
            best = max([int(f.get("height") or 0) for f in d.get("formats", []) if f.get("vcodec") not in (None, "none")] or [0])
        except ValueError:
            best = -1
    cache[v["yid"]] = best
    json.dump(cache, open(CACHE, "w", encoding="utf8"))
    return best


def write_row(row):
    new = not os.path.exists(vi.MANIFEST)
    with open(vi.MANIFEST, "a", encoding="utf8") as f:
        if new:
            f.write("\t".join(FIELDS) + "\n")
        f.write("\t".join(str(row.get(k, "")) for k in FIELDS) + "\n")


def download(v, dest_dir):
    os.makedirs(dest_dir, exist_ok=True)
    out = os.path.join(dest_dir, v["base"] + ".%(ext)s")
    cmd = [YTDLP, "-q", "--no-warnings", "--ffmpeg-location", os.path.abspath("research/bin"), "-N", "4", "--retries", "10", "--fragment-retries", "10",
           "-S", "res,fps,vcodec:vp9", "-f", "bv*+ba/b", "--merge-output-format", "mp4", "--write-info-json", "--no-part", "-o", out] + auth() + ["https://www.youtube.com/watch?v=" + v["yid"]]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf8", errors="ignore")
    path = os.path.join(dest_dir, v["base"] + ".mp4")
    return (path if os.path.exists(path) else ""), (r.stderr or "")[-300:].replace("\n", " ").replace("\t", " ")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--keep-old", action="store_true")
    args = ap.parse_args()
    cache = json.load(open(CACHE, encoding="utf8")) if os.path.exists(CACHE) else {}
    done = vi.manifest()
    plan = []
    for v in vi.videos():
        if v["dup"] or not v["yid"] or not v["path"] or v["old"] in done:
            continue
        vi.attach_seeds(v)
        plan.append(v)
    plan.sort(key=lambda v: (-(len(v["evo"]) + len(v["reveal"])), v["old"]))
    n = 0
    for v in plan:
        _, cur, _, dur = vi.probe(v["path"])
        best = best_height(v, cache)
        row = {"old": v["old"], "yid": v["yid"], "old_h": cur, "best_h": best, "when": time.strftime("%Y-%m-%d %H:%M")}
        if best < 0:
            row["status"] = "unavailable"
        elif best < MIN_H:
            row["status"] = "skip_below_720"
        elif best <= cur + 12:
            row["status"] = "already_best"
        else:
            path, err = download(v, os.path.join(vi.HQ_ROOT, v["folder"]))
            if not path:
                row["status"] = "failed " + err
            else:
                _, nh, _, nd = vi.probe(path)
                row["new"], row["new_h"] = path, nh
                if nh <= cur or (dur > 0 and abs(nd - dur) > max(5.0, dur * 0.05)):
                    row["status"] = "failed_check"
                else:
                    row["status"] = "done"
                    if not args.keep_old:
                        os.remove(os.path.join(vi.ROOT, v["old"]))
            n += 1
        write_row(row)
        print("%-50s %4s -> %4s  %s" % (v["old"], cur, row.get("new_h", best), row["status"][:60]), flush=True)
        if args.limit and n >= args.limit:
            break
    print("upgrade pass finished", flush=True)


if __name__ == "__main__":
    main()
