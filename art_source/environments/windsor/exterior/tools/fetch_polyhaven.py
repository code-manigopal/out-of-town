"""Downloads the CC0 Poly Haven maps used by the Windsor exterior (1K only). Run: python3 fetch_polyhaven.py
Writes game/environments/windsor/exterior/textures/ph/ and the sky; see SOURCES.md there."""
import json, os, sys, urllib.request
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", ".."))
OUT = os.path.join(ROOT, "game", "environments", "windsor", "exterior", "textures", "ph")
SKY = os.path.join(ROOT, "game", "environments", "windsor", "exterior", "sky")
os.makedirs(OUT, exist_ok=True); os.makedirs(SKY, exist_ok=True)
TEX = ["asphalt_02", "asphalt_01", "brushed_concrete_04", "brushed_concrete_03", "concrete_pavement_03", "red_brick_03", "red_bricks_04",
       "white_planks_clean", "sparse_grass", "bark_brown_01", "weathered_planks", "planks_brown_10"]
def get(url, dst):
    if os.path.exists(dst): return os.path.getsize(dst)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    data = urllib.request.urlopen(req, timeout=60).read()
    open(dst, "wb").write(data); return len(data)
total = 0
for t in TEX:
    f = json.load(urllib.request.urlopen(urllib.request.Request("https://api.polyhaven.com/files/" + t, headers={"User-Agent": "Mozilla/5.0"})))
    for key, tag in (("Diffuse", "diff"), ("nor_gl", "nor"), ("Rough", "rough")):
        if key not in f: print("missing", t, key); continue
        fmt = "jpg" if "jpg" in f[key]["1k"] else list(f[key]["1k"].keys())[0]
        info = f[key]["1k"][fmt]
        n = get(info["url"], os.path.join(OUT, "%s_%s.%s" % (t, tag, fmt)))
        total += n; print(t, tag, n)
n = get("https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/1k/kloofendal_28d_misty_puresky_1k.hdr", os.path.join(SKY, "kloofendal_28d_misty_puresky_1k.hdr"))
total += n
print("total MB", total / 1e6)
