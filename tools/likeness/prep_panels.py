"""Clean the cropped face panels for texture projection: remove the thin glasses frames / temple arm
(black top-hat line detection + Telea inpainting) and neutralise the teal lens reflection above the brows.

    tools/.venv/bin/python -I tools/likeness/prep_panels.py     (after landmarks.py)
"""
import os

import cv2
import numpy as np

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
D = os.path.join(REPO, "art_source/characters/mani/likeness")


def thin_dark(img, k):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    th = cv2.morphologyEx(gray, cv2.MORPH_BLACKHAT, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k)))
    return (th > 16).astype(np.uint8)


def clean(name, region, keep_boxes, k):
    img = cv2.imread(os.path.join(D, "panel_%s.png" % name))
    m = np.zeros(img.shape[:2], np.uint8)
    x0, y0, x1, y1 = region
    m[y0:y1, x0:x1] = thin_dark(img, k)[y0:y1, x0:x1]
    for bx0, by0, bx1, by1 in keep_boxes:
        m[by0:by1, bx0:bx1] = 0
    m = cv2.dilate(m, np.ones((5, 5), np.uint8))
    for bx0, by0, bx1, by1 in keep_boxes:
        m[by0:by1, bx0:bx1] = 0
    out = cv2.inpaint(img, m, 5, cv2.INPAINT_TELEA)
    return img, out, m


def main():
    # front: glasses cover y 345..445; keep the eyes themselves (they sit under the 3D eyeballs anyway)
    img, out, m = clean("front", (40, 340, 370, 452), [(112, 376, 175, 408), (225, 376, 292, 408)], 7)
    # lens reflection above the brows is teal: pull it back to a skin/brow tone
    hsv = cv2.cvtColor(out, cv2.COLOR_BGR2HSV).astype(np.float32)
    band = np.zeros(out.shape[:2], bool)
    band[340:376, 90:330] = True
    b, g, r = [out[..., i].astype(np.float32) for i in range(3)]
    teal = band & ((g + b) * 0.5 > r * 0.92)
    teal = cv2.dilate(teal.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & band
    lum = (0.114 * b + 0.587 * g + 0.299 * r)
    for i, (sk, tone) in enumerate(zip((0, 1, 2), (0.80, 1.0, 1.28))):
        pass
    fix = np.stack([lum * 0.70, lum * 0.88, lum * 1.12], -1)      # BGR brown-ish at the same luminance
    out[teal] = np.clip(fix[teal], 0, 255).astype(np.uint8)
    out = cv2.GaussianBlur(out, (3, 3), 0) * 0 + out
    cv2.imwrite(os.path.join(D, "clean_front.png"), out)
    cv2.imwrite(os.path.join(D, "mask_front.png"), m * 255)
    # profile: lens rim (x 35..65) and the temple arm running back to the ear
    img, out, m = clean("profile", (30, 340, 285, 440), [(60, 372, 100, 400)], 9)
    cv2.imwrite(os.path.join(D, "clean_profile.png"), out)
    cv2.imwrite(os.path.join(D, "mask_profile.png"), m * 255)
    # three-quarter panels (MediaPipe-based projection): crop from the sheet, same glasses-line removal
    sheet = cv2.imread(os.path.join(REPO, "docs/art/sheets/mani/mani_p1_face.png"))
    for name, box, region, keeps in (
            ("q34L", (411, 0, 849, 825), (15, 340, 345, 450), [(65, 368, 140, 406), (150, 368, 215, 406)]),
            ("q34R", (1253, 0, 1672, 825), (95, 340, 410, 450), [(225, 368, 295, 408), (315, 368, 380, 408)])):
        x0, y0, x1, y1 = box
        cv2.imwrite(os.path.join(D, "panel_%s.png" % name), sheet[y0:y1, x0:x1])
        img, out, m = clean(name, region, keeps, 7)
        cv2.imwrite(os.path.join(D, "clean_%s.png" % name), out)
        cv2.imwrite(os.path.join(D, "mask_%s.png" % name), m * 255)
    print("wrote clean_front/profile/q34L/q34R.png")


main()
