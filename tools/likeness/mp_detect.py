"""MediaPipe FaceLandmarker (478 points) on the Mani face sheet panels and on renders of the 3D head.

    tools/.venv/bin/python -I tools/likeness/mp_detect.py sheet  OUT.json
    tools/.venv/bin/python -I tools/likeness/mp_detect.py images OUT.json name=path.png [name=path.png ...]

Output json: {name: {"ok": bool, "pts": [[x, y] * 478] (pixels of the ORIGINAL image / sheet),
                     "yaw": deg, "pitch": deg, "roll": deg, "size": [w, h]}}
Sheet panels (x ranges of the 1672x941 sheet): front 0..411, q34L 411..849, profile 849..1253, q34R 1253..1672.
Yaw sign (MediaPipe): negative = the face turns toward image-left.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image

import mediapipe as mp
from mediapipe.tasks.python import vision, BaseOptions

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODEL = os.path.join(REPO, "tools/likeness/models/face_landmarker.task")
SHEET = os.path.join(REPO, "docs/art/sheets/mani/mani_p1_face.png")
PANELS = {"front": (0, 0, 411, 825), "q34L": (411, 0, 849, 825), "profile": (849, 0, 1253, 825), "q34R": (1253, 0, 1672, 825)}


def make_detector():
    return vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=MODEL), num_faces=1, output_facial_transformation_matrixes=True,
        min_face_detection_confidence=0.2, min_face_presence_confidence=0.2))


def euler(M):
    M = np.array(M)
    R = M[:3, :3] / np.cbrt(abs(np.linalg.det(M[:3, :3])))
    return (math.degrees(math.atan2(-R[2, 0], math.hypot(R[2, 1], R[2, 2]))),
            math.degrees(math.atan2(R[2, 1], R[2, 2])), math.degrees(math.atan2(R[1, 0], R[0, 0])))


def detect(det, im, offset=(0, 0)):
    arr = np.ascontiguousarray(np.array(im.convert("RGB")))
    r = det.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=arr))
    if not r.face_landmarks:
        return {"ok": False}
    w, h = im.size
    yaw, pitch, roll = euler(r.facial_transformation_matrixes[0])
    return {"ok": True, "pts": [[p.x * w + offset[0], p.y * h + offset[1]] for p in r.face_landmarks[0]],
            "yaw": yaw, "pitch": pitch, "roll": roll, "size": [w, h]}


def main():
    mode, out = sys.argv[1], sys.argv[2]
    det = make_detector()
    res = {}
    if mode == "sheet":
        im = Image.open(SHEET).convert("RGB")
        for name, box in PANELS.items():
            res[name] = detect(det, im.crop(box), offset=box[:2])
            res[name]["box"] = list(box)
    else:
        for item in sys.argv[3:]:
            name, path = item.split("=", 1)
            res[name] = detect(det, Image.open(path))
    json.dump(res, open(out, "w"))
    print({k: (v["ok"], round(v.get("yaw", 0), 1)) for k, v in res.items()})


if __name__ == "__main__":
    main()
