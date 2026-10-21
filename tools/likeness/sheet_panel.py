"""Cut one figure out of a turnaround sheet as a transparent-background PNG.

    tools/.venv/bin/python -I tools/likeness/sheet_panel.py SHEET.png INDEX OUT.png

Turnaround sheets show the same person four times on a plain background
(front, left side, back, three-quarter), but not evenly spaced. The background
colour is sampled from the corners, every pixel close to it becomes transparent,
and the figures are found as the four widest runs of occupied columns. INDEX is
0..3 from the left. The crop keeps the full sheet height so scale stays shared.
"""
import sys

import numpy as np
from PIL import Image

TOL = 22          # max per-channel distance from the background colour
MIN_GAP = 6       # empty columns that separate two figures


def main(sheet: str, index: int, out: str) -> None:
    rgb = np.asarray(Image.open(sheet).convert("RGB")).astype(np.int16)
    h, w, _ = rgb.shape
    corners = np.concatenate([rgb[:8, :8], rgb[:8, -8:], rgb[-8:, :8], rgb[-8:, -8:]]).reshape(-1, 3)
    bg = np.median(corners, axis=0)
    fg = np.abs(rgb - bg).max(axis=2) > TOL
    # Remove speckle: a column counts as occupied only with a few foreground pixels.
    cols = fg.sum(axis=0) > 3
    runs, start, gap = [], None, 0
    for x in range(w):
        if cols[x]:
            if start is None:
                start = x
            gap = 0
        elif start is not None:
            gap += 1
            if gap >= MIN_GAP:
                runs.append((start, x - gap + 1))
                start, gap = None, 0
    if start is not None:
        runs.append((start, w))
    runs = sorted(sorted(runs, key=lambda r: r[1] - r[0], reverse=True)[:4])
    if index >= len(runs):
        sys.exit(f"sheet_panel: found {len(runs)} figures, asked for index {index}")
    x0, x1 = runs[index]
    pad = 12
    x0, x1 = max(0, x0 - pad), min(w, x1 + pad)
    rgba = np.dstack([rgb, np.where(fg, 255, 0)]).astype(np.uint8)[:, x0:x1]
    Image.fromarray(rgba, "RGBA").save(out)
    print(f"figure {index}: columns {x0}-{x1} of {w}")


if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[2]), sys.argv[3])
