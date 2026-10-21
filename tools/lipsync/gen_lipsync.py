#!/usr/bin/env python3
"""Run Rhubarb Lip Sync (phonetic recogniser) on the placeholder VO.

Run:  tools/.venv/bin/python -I tools/lipsync/gen_lipsync.py [--force]
Reads  game/audio/vo_placeholder/p1/<line_id>.ogg
Writes game/audio/vo_placeholder/p1/<line_id>.lip.json  (mouthCues A-H, X)
Skips lines whose .ogg has not changed since the cue file was written (hash stored in the json).
"""
import argparse, hashlib, json, os, subprocess, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
VO = os.path.join(ROOT, "game/audio/vo_placeholder/p1")
RHUBARB = os.environ.get("RHUBARB") or os.path.expanduser(
    "~/Applications/Tools/Rhubarb-Lip-Sync-1.14.0-macOS/rhubarb")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    if not os.path.exists(RHUBARB):
        sys.exit("Rhubarb not found at %s (set RHUBARB=...)" % RHUBARB)
    made = skipped = 0
    for f in sorted(os.listdir(VO)):
        if not f.endswith(".ogg"):
            continue
        lid = f[:-4]
        src = os.path.join(VO, f)
        out = os.path.join(VO, lid + ".lip.json")
        h = hashlib.sha1(open(src, "rb").read()).hexdigest()[:16]
        if not args.force and os.path.exists(out):
            try:
                if json.load(open(out)).get("source_hash") == h:
                    skipped += 1
                    continue
            except ValueError:
                pass
        with tempfile.TemporaryDirectory() as tmp:
            wav = os.path.join(tmp, "in.wav")
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-ac", "1", "-ar", "16000", wav], check=True)
            r = subprocess.run([RHUBARB, "--recognizer", "phonetic", "-f", "json", "--machineReadable", "-q", wav],
                               capture_output=True, text=True)
            if r.returncode != 0:
                sys.stderr.write(r.stderr[-500:])
                sys.exit("rhubarb failed on " + f)
            data = json.loads(r.stdout)
        res = {"line_id": lid, "source_hash": h, "duration": data["metadata"]["duration"],
               "mouthCues": data["mouthCues"]}
        json.dump(res, open(out, "w"), indent=0)
        made += 1
    print("lip-sync: generated %d, unchanged %d" % (made, skipped))


if __name__ == "__main__":
    main()
