#!/usr/bin/env python3
"""Generate PLACEHOLDER voice-over for Part 1 with Kokoro-82M (Apache-2.0) + ffmpeg.

Run:  tools/.venv/bin/python -I tools/voice/gen_vo_kokoro.py [--force] [--ep 1]
Output: game/audio/vo_placeholder/p1/<line_id>.ogg and manifest.json (same format as the Piper script).
Needs espeak-ng (brew install espeak-ng) only for Kokoro's fallback G2P. Models cache in tools/voice/models/kokoro/.
Placeholder only. Never ship these files (see tools/voice/README.md).
"""
import argparse, hashlib, json, os, re, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
os.environ.setdefault("HF_HOME", os.path.join(HERE, "models", "kokoro"))
sys.path.insert(0, HERE)
import numpy as np, soundfile as sf, torch
import gen_placeholder_vo as base          # reuse channel filters, ffmpeg render chain, helpers
import tanglish

SCENES, OUT = base.SCENES, base.OUT
FILTER_VERSION = 2
SR = 24000
# (voice, speed, accent): accent 'h' = Hindi voice reading Tanglish phonemes (Indian accent), 'a'/'b' = US/UK English.
VOICES = {
    "MANI":   ("hm_psi", 1.0, "h"),
    "NILA":   ("hf_beta", 1.05, "h"),
    "AMMA":   ("hf_alpha", 0.95, "h"),
    "APPA":   ("hm_omega", 0.95, "h"),
    "VICTOR": ("am_onyx", 0.92, "a"),
    "RUTH":   ("bf_emma", 0.97, "b"),
    "TESS":   ("af_nicole", 1.0, "a"),
    "GUS":    ("am_fenrir", 0.95, "a"),
    "HAROLD": ("bm_george", 0.93, "b"),
    "JUNE":   ("af_sarah", 1.0, "a"),
    "PRIYA":  ("af_bella", 1.05, "a"),
    "MAN'S VOICE": ("bm_lewis", 0.88, "b"),
}
DEFAULT = ("am_adam", 1.0, "a")

_model = None; _pipes = {}; _packs = {}


def model():
    global _model
    if _model is None:
        from kokoro import KModel
        _model = KModel(repo_id="hexgrad/Kokoro-82M").eval()
    return _model


def pipe(lang):
    if lang not in _pipes:
        from kokoro import KPipeline
        _pipes[lang] = KPipeline(lang_code=lang, repo_id="hexgrad/Kokoro-82M", model=False)
    return _pipes[lang]


def lexicon(lang):
    g = pipe(lang).g2p
    lex = getattr(g, "lexicon", None)
    return set(getattr(lex, "golds", {})) | set(getattr(lex, "silvers", {})) if lex else set()


def phonemise(text, accent):
    g2p_lang = "a" if accent == "a" else "b"      # Hindi voices read English words with UK phonemes
    p = pipe(g2p_lang)
    lex = {w.lower() for w in lexicon(g2p_lang)}
    out = []
    for kind, val in tanglish.split_runs(text, lex):
        if kind == "en":
            ps, _ = p.g2p(val); out.append(ps)
        elif kind == "ta":
            out.append(val)
        else:
            out.append(val)
    ps = " ".join(out)
    ps = re.sub(r" ([,.!?;:…—])", r"\1", ps)
    vocab = model().vocab
    return "".join(c for c in ps if c in vocab)


def synth(text, voice, speed, accent, out_wav):
    ps = phonemise(text, accent)
    if voice not in _packs:
        _packs[voice] = pipe("a" if voice[0] == "a" else "b" if voice[0] == "b" else "h").load_voice(voice)
    pack = _packs[voice]
    chunks = [c.strip() for c in re.split(r"(?<=[.!?…—])\s+", ps) if c.strip()]
    wav = []
    m = model()
    for c in chunks:
        c = c[:500]
        with torch.no_grad():
            a = m(c, pack[len(c) - 1], speed, return_output=True).audio.numpy()
        wav += [a, np.zeros(int(SR * 0.12), dtype=np.float32)]
    sf.write(out_wav, np.concatenate(wav[:-1]), SR)
    return ps


def render(text, spec, kind, out_ogg):
    voice, speed, accent = spec
    with tempfile.TemporaryDirectory() as tmp:
        raw = os.path.join(tmp, "raw.wav")
        synth(text, voice, speed, accent, raw)
        return base.process(raw, kind, out_ogg)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--ep", type=int, default=1)
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    mpath = os.path.join(OUT, "manifest.json")
    old = json.load(open(mpath)).get("lines", {}) if os.path.exists(mpath) else {}
    scenes = json.load(open(SCENES))["scenes"]
    scenes = list(scenes.values()) if isinstance(scenes, dict) else scenes
    lines, made, skipped = {}, 0, 0
    for sc in scenes:
        if sc.get("ep") != args.ep:
            continue
        for i, ln in enumerate(sc.get("lines", [])):
            if ln.get("narration") or not ln.get("text") or ln.get("channel", "").upper() == "TEXT":
                continue
            channel, spk = ln.get("channel", ""), ln.get("speaker", "")
            lid = "%s_%03d" % (sc["id"], i)
            spec = VOICES.get(spk, DEFAULT)
            kind = base.kind_of(base.SCENE_CHANNEL.get(sc["id"], channel))
            text = base.clean_text(ln["text"])
            h = hashlib.sha1(("k%d|%s|%s|%s|%s" % (FILTER_VERSION, text, spec, kind, base.FILTER_VERSION)).encode()).hexdigest()[:16]
            path = os.path.join(OUT, lid + ".ogg")
            prev = old.get(lid)
            if not args.force and prev and prev.get("hash") == h and os.path.exists(path):
                lines[lid] = prev; skipped += 1; continue
            dur = render(text, spec, kind, path)
            lines[lid] = {"file": lid + ".ogg", "duration": round(dur, 3), "speaker": spk, "speaker_id": spec[0],
                          "channel": channel, "filter": kind, "hash": h}
            made += 1
            print("  %s  %s  %s  %.2fs" % (lid, spec[0], kind, dur), flush=True)
    for f in os.listdir(OUT):
        if f.endswith(".ogg") and f[:-4] not in lines:
            os.remove(os.path.join(OUT, f))
            lj = os.path.join(OUT, f[:-4] + ".lip.json")
            if os.path.exists(lj):
                os.remove(lj)
    json.dump({"placeholder": True, "model": "Kokoro-82M", "lines": lines}, open(mpath, "w"), indent=1, sort_keys=True)
    print("generated %d, unchanged %d, total %d" % (made, skipped, len(lines)))


if __name__ == "__main__":
    main()
