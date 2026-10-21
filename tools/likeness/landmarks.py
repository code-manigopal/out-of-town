"""Extract 2D face landmarks from the Mani face sheet (docs/art/sheets/mani/mani_p1_face.png).

    tools/.venv/bin/python -I tools/likeness/landmarks.py [--model path/to/face_landmarker.task] [--grid]

Crops the front and profile panels (saved to art_source/characters/mani/likeness/panel_*.png) and
tries, in order:
  1. MediaPipe Tasks FaceLandmarker (needs a face_landmarker.task model: --model, $FACE_LANDMARKER_MODEL,
     or a .task file found in the pip package);
  2. the legacy mediapipe.solutions.face_mesh API (removed from mediapipe >= 0.10.2x / 1.x);
  3. the hand-annotated landmark set in tools/likeness/manual_landmarks.json (named points read off the
     panels with --grid overlays), used when no detector can run offline.
The result is written to art_source/characters/mani/likeness/sheet_landmarks.json (panel pixel coordinates,
origin top-left) together with the source used. Existing "mapping" (landmark -> MPFB vertex) and "fit"
keys written by tools/likeness/fit_face.py are preserved.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHEET = os.path.join(REPO, "docs/art/sheets/mani/mani_p1_face.png")
OUT_DIR = os.path.join(REPO, "art_source/characters/mani/likeness")
OUT_JSON = os.path.join(OUT_DIR, "sheet_landmarks.json")
MANUAL = os.path.join(REPO, "tools/likeness/manual_landmarks.json")
# panel boxes (x0, y0, x1, y1) in the 1672x941 sheet: front view, profile view (subject faces image-left)
PANELS = {"front": (0, 0, 411, 825), "profile": (849, 0, 1253, 825)}


def crop_panels():
    os.makedirs(OUT_DIR, exist_ok=True)
    im = Image.open(SHEET).convert("RGB")
    out = {}
    for name, box in PANELS.items():
        c = im.crop(box)
        c.save(os.path.join(OUT_DIR, "panel_%s.png" % name))
        out[name] = c
    return out


def find_model(arg):
    cands = [arg, os.environ.get("FACE_LANDMARKER_MODEL")]
    try:
        import mediapipe
        root = os.path.dirname(mediapipe.__file__)
        for dp, _, fs in os.walk(root):
            cands += [os.path.join(dp, f) for f in fs if f.endswith(".task")]
    except Exception:
        pass
    return next((c for c in cands if c and os.path.isfile(c)), None)


def run_tasks(panels, model):
    import mediapipe as mp
    from mediapipe.tasks import python as mpt
    from mediapipe.tasks.python import vision
    opts = vision.FaceLandmarkerOptions(base_options=mpt.BaseOptions(model_asset_path=model), num_faces=1)
    det = vision.FaceLandmarker.create_from_options(opts)
    res = {}
    for name, im in panels.items():
        arr = np.ascontiguousarray(np.array(im))
        r = det.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=arr))
        if not r.face_landmarks:
            return None
        w, h = im.size
        res[name] = {str(i): [p.x * w, p.y * h] for i, p in enumerate(r.face_landmarks[0])}
    return res


def run_legacy(panels):
    import mediapipe as mp
    if not hasattr(mp, "solutions"):
        return None
    fm = mp.solutions.face_mesh.FaceMesh(static_image_mode=True, max_num_faces=1, refine_landmarks=True)
    res = {}
    for name, im in panels.items():
        r = fm.process(np.array(im))
        if not r.multi_face_landmarks:
            return None
        w, h = im.size
        res[name] = {str(i): [p.x * w, p.y * h] for i, p in enumerate(r.multi_face_landmarks[0].landmark)}
    return res


def draw_grid(panels):
    for name, im in panels.items():
        big = im.resize((im.width * 2, im.height * 2), Image.LANCZOS)
        d = ImageDraw.Draw(big)
        for x in range(0, im.width, 20):
            d.line([(x * 2, 0), (x * 2, big.height)], fill=(255, 255, 0) if x % 100 == 0 else (90, 90, 90), width=1)
            if x % 100 == 0:
                d.text((x * 2 + 2, 2), str(x), fill=(255, 255, 0))
        for y in range(0, im.height, 20):
            d.line([(0, y * 2), (big.width, y * 2)], fill=(255, 255, 0) if y % 100 == 0 else (90, 90, 90), width=1)
            if y % 100 == 0:
                d.text((2, y * 2 + 2), str(y), fill=(255, 255, 0))
        big.save(os.path.join(OUT_DIR, "grid_%s.png" % name))


def draw_points(panels, pts):
    for name, im in panels.items():
        big = im.resize((im.width * 2, im.height * 2), Image.LANCZOS)
        d = ImageDraw.Draw(big)
        for k, (x, y) in pts[name].items():
            d.ellipse([x * 2 - 3, y * 2 - 3, x * 2 + 3, y * 2 + 3], outline=(255, 40, 40))
            d.text((x * 2 + 5, y * 2 - 5), k, fill=(255, 255, 0))
        big.save(os.path.join(OUT_DIR, "check_%s.png" % name))


def main():
    args = sys.argv[1:]
    panels = crop_panels()
    if "--grid" in args:
        draw_grid(panels)
    model = args[args.index("--model") + 1] if "--model" in args else None
    model = find_model(model)
    result, source = None, None
    if model:
        try:
            result, source = run_tasks(panels, model), "mediapipe-tasks:" + os.path.basename(model)
        except Exception as e:  # noqa
            print("tasks API failed:", e)
    if result is None:
        try:
            result = run_legacy(panels)
            source = "mediapipe-legacy-face_mesh"
        except Exception as e:  # noqa
            print("legacy API failed:", e)
    if result is None:
        print("MediaPipe unavailable offline (no face_landmarker.task bundled, mediapipe.solutions removed);"
              " using the hand-annotated set %s" % MANUAL)
        result = json.load(open(MANUAL))
        source = "manual annotation (named points)"
    data = json.load(open(OUT_JSON)) if os.path.isfile(OUT_JSON) else {}
    data.update({"source": source, "panels": {k: list(v) for k, v in PANELS.items()}, "points": result})
    json.dump(data, open(OUT_JSON, "w"), indent=1)
    draw_points(panels, result)
    print("wrote", OUT_JSON, source, {k: len(v) for k, v in result.items()})


if __name__ == "__main__":
    main()
