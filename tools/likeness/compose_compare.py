"""Side-by-side: sheet panels (top) vs renders (bottom).
   tools/.venv/bin/python -I tools/likeness/compose_compare.py OUT.png front=img q34L=img profile=img q34R=img [--lm=det.json]
Renders are cropped around the face with the same framing rule as the sheet (face centred, same face height)."""
import json, os, sys
from PIL import Image, ImageDraw
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHEET = Image.open(os.path.join(REPO, "docs/art/sheets/mani/mani_p1_face.png")).convert("RGB")
PANELS = {"front": (0, 0, 411, 825), "q34L": (411, 0, 849, 825), "profile": (849, 0, 1253, 825), "q34R": (1253, 0, 1672, 825)}
out, items = sys.argv[1], [a for a in sys.argv[2:] if "=" in a and not a.startswith("--")]
H = 825
tiles_top, tiles_bot = [], []
for it in items:
    k, p = it.split("=", 1)
    box = PANELS[k]
    tiles_top.append(SHEET.crop(box))
    im = Image.open(p).convert("RGB")
    # scale render so its face matches the panel: render face height ~ (chin-forehead) -> use fixed ratio found by eye
    sc = float(os.environ.get("RSCALE", "1.18"))
    w, h = im.size
    im = im.resize((int(w * sc), int(h * sc)))
    cx = int(im.width * 0.5 + float(os.environ.get("RDX", "0")) * sc)
    cy = int(im.height * float(os.environ.get("RCY", "0.50")))
    pw = box[2] - box[0]
    tiles_bot.append(im.crop((cx - pw // 2, cy - 420, cx - pw // 2 + pw, cy - 420 + H)))
W = sum(t.width for t in tiles_top)
canvas = Image.new("RGB", (W, H * 2), (80, 80, 80))
x = 0
for a, b in zip(tiles_top, tiles_bot):
    canvas.paste(a, (x, 0)); canvas.paste(b, (x, H)); x += a.width
canvas.save(out)
print("wrote", out)
