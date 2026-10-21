#!/usr/bin/env python3
"""Generate PLACEHOLDER voice-over for Part 1 Episode 1 with Piper TTS + ffmpeg.

Run:  tools/.venv/bin/python -I tools/voice/gen_placeholder_vo.py [--force] [--ep 1]
Output: game/audio/vo_placeholder/p1/<line_id>.ogg and manifest.json.
Placeholder only. Never ship these files (see tools/voice/README.md).
"""
import argparse, hashlib, json, os, re, subprocess, sys, tempfile, wave

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODEL = os.path.join(ROOT, "tools/voice/models/en_US-libritts_r-medium.onnx")
PIPER = os.path.join(ROOT, "tools/.venv/bin/piper")
SCENES = os.path.join(ROOT, "game/data/story/p1_scenes.json")
OUT = os.path.join(ROOT, "game/audio/vo_placeholder/p1")
FILTER_VERSION = 1  # bump to force regeneration when filters change

# LibriTTS-R speaker index per character (picked by measured pitch, see README).
VOICES = {
    "MANI": 286,      # ~127 Hz, young adult male
    "NILA": 154,      # ~188 Hz, young female
    "AMMA": 440,      # ~176 Hz, older female
    "APPA": 22,       # ~96 Hz, older male
    "VICTOR": 132,    # ~90 Hz, deep, warm
    "RUTH": 462,      # ~168 Hz, older female
    "TESS": 66,       # ~202 Hz, young female
    "GUS": 594,       # ~92 Hz, gruff male
    "HAROLD": 418,    # ~102 Hz, older male
    "JUNE": 242,      # ~175 Hz, adult female
    "PRIYA": 550,     # ~223 Hz, young female
    "MAN'S VOICE": 506,
}
DEFAULT_VOICE = 330   # generic male
# Scenes heard through a video call regardless of per-line channel.
SCENE_CHANNEL = {"e1_call": "VIDEO", "e1_call2": "VIDEO"}

HP_LP = "highpass=f=300,lowpass=f=3400"
FILTERS = {
    "phone": HP_LP + ",asoftclip=type=tanh:param=1.6",
    "video": "highpass=f=120,acompressor=threshold=-24dB:ratio=3:attack=5:release=80:makeup=2",
    "clean": "anull",
}
RADIO_STATIC = "anoisesrc=d={dur:.3f}:c=pink:a=0.012:r=22050,highpass=f=400,lowpass=f=4500"


def kind_of(channel: str) -> str:
    c = channel.upper()
    if "VIDEO" in c:
        return "video"
    if "RADIO" in c or "ON AIR" in c:
        return "radio"
    if "PHONE" in c or "V.O" in c or "VOICEMAIL" in c:
        return "phone"
    return "clean"


def clean_text(t: str) -> str:
    t = t.replace("*", "")
    t = re.sub(r"\[[^\]]*\]", "", t)
    return t.strip()


def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, **kw)
    if r.returncode != 0:
        sys.stderr.write(r.stderr.decode(errors="replace")[-800:])
        raise SystemExit("command failed: " + " ".join(cmd[:3]))
    return r


def wav_duration(path):
    with wave.open(path) as w:
        return w.getnframes() / float(w.getframerate())


def render(line_text, speaker_id, kind, out_ogg):
    with tempfile.TemporaryDirectory() as tmp:
        raw = os.path.join(tmp, "raw.wav")
        run([PIPER, "-m", MODEL, "-s", str(speaker_id), "-f", raw], input=line_text.encode("utf-8"))
        dur = wav_duration(raw)
        norm = "loudnorm=I=-21:LRA=9:TP=-4"
        limit = "alimiter=limit=0.8"
        if kind == "radio":
            fc = ("[0:a]%s,%s[v];%s[n];[v][n]amix=inputs=2:duration=first:normalize=0,%s,%s[o]"
                  % (HP_LP + ",asoftclip=type=tanh:param=1.3", "anull", RADIO_STATIC.format(dur=dur + 0.5),
                     norm, limit))
            cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-filter_complex", fc, "-map", "[o]"]
        else:
            fc = "%s,%s,%s" % (FILTERS[kind], norm, limit)
            cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-af", fc]
        # ffmpeg's native vorbis encoder only accepts stereo (no libvorbis here): dual-mono at 22.05 kHz.
        cmd += ["-ac", "2", "-ar", "22050", "-c:a", "vorbis", "-strict", "-2", "-b:a", "64k", out_ogg]
        run(cmd)
        out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", out_ogg],
                             capture_output=True, text=True).stdout.strip()
        return float(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--ep", type=int, default=1)
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    mpath = os.path.join(OUT, "manifest.json")
    old = {}
    if os.path.exists(mpath):
        old = json.load(open(mpath)).get("lines", {})
    data = json.load(open(SCENES))
    scenes = data["scenes"]
    scenes = list(scenes.values()) if isinstance(scenes, dict) else scenes
    lines, made, skipped = {}, 0, 0
    for sc in scenes:
        if sc.get("ep") != args.ep:
            continue
        for i, ln in enumerate(sc.get("lines", [])):
            if ln.get("narration") or not ln.get("text"):
                continue
            channel = ln.get("channel", "")
            if channel.upper() == "TEXT":
                continue
            lid = "%s_%03d" % (sc["id"], i)
            spk = ln.get("speaker", "")
            sid = VOICES.get(spk, DEFAULT_VOICE)
            kind = kind_of(SCENE_CHANNEL.get(sc["id"], channel))
            text = clean_text(ln["text"])
            h = hashlib.sha1(("%d|%s|%d|%s" % (FILTER_VERSION, text, sid, kind)).encode()).hexdigest()[:16]
            fname = lid + ".ogg"
            path = os.path.join(OUT, fname)
            prev = old.get(lid)
            if not args.force and prev and prev.get("hash") == h and os.path.exists(path):
                lines[lid] = prev
                skipped += 1
                continue
            dur = render(text, sid, kind, path)
            lines[lid] = {"file": fname, "duration": round(dur, 3), "speaker": spk, "speaker_id": sid,
                          "channel": channel, "filter": kind, "hash": h}
            made += 1
            print("  %s  %s  %.2fs" % (lid, kind, dur), flush=True)
    # drop stale files
    for f in os.listdir(OUT):
        if f.endswith(".ogg") and f[:-4] not in lines:
            os.remove(os.path.join(OUT, f))
            lj = os.path.join(OUT, f[:-4] + ".lip.json")
            if os.path.exists(lj):
                os.remove(lj)
    json.dump({"placeholder": True, "model": "en_US-libritts_r-medium", "lines": lines},
              open(mpath, "w"), indent=1, sort_keys=True)
    print("generated %d, unchanged %d, total %d" % (made, skipped, len(lines)))


if __name__ == "__main__":
    main()
