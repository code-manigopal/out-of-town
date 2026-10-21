"""Signed face modifiers used by the likeness fit (shared by fit_face.py and build_mani.py).

Each variable is (name, positive stems, negative stems, lo, hi). A value v >= 0 loads the positive
target(s) at weight v, v < 0 loads the negative target(s) at weight -v. Stems are MPFB target file stems
(tools/likeness/fit_face.py checks they exist). "{s}" expands to the l-/r- pair so both sides move together.
"""


def _lr(stem):
    return ["l-" + stem, "r-" + stem]


FACE_VARS = [
    # head volume
    ("head_width", ["head-scale-horiz-incr"], ["head-scale-horiz-decr"], -1, 1),
    ("head_height", ["head-scale-vert-incr"], ["head-scale-vert-decr"], -1, 1),
    ("head_depth", ["head-scale-depth-incr"], ["head-scale-depth-decr"], -1, 1),
    ("head_back_depth", ["head-back-scale-depth-incr"], ["head-back-scale-depth-decr"], -1, 1),
    ("head_fat", ["head-fat-incr"], ["head-fat-decr"], -1, 1),
    # nose
    ("nose_width1", ["nose-width1-incr"], ["nose-width1-decr"], -1, 1),
    ("nose_width2", ["nose-width2-incr"], ["nose-width2-decr"], -1, 1),
    ("nose_width3", ["nose-width3-incr"], ["nose-width3-decr"], -1, 1),
    ("nose_flaring", ["nose-flaring-incr"], ["nose-flaring-decr"], -1, 1),
    ("nose_height", ["nose-scale-vert-incr"], ["nose-scale-vert-decr"], -1, 1),
    ("nose_depth", ["nose-scale-depth-incr"], ["nose-scale-depth-decr"], -1, 1),
    ("nose_point", ["nose-point-up"], ["nose-point-down"], -1, 1),
    ("nose_base", ["nose-base-up"], ["nose-base-down"], -1, 1),
    ("nose_trans_v", ["nose-trans-up"], ["nose-trans-down"], -1, 1),
    # mouth
    ("mouth_width", ["mouth-scale-horiz-incr"], ["mouth-scale-horiz-decr"], -1, 1),
    ("mouth_height", ["mouth-scale-vert-incr"], ["mouth-scale-vert-decr"], -1, 1),
    ("mouth_trans_v", ["mouth-trans-up"], ["mouth-trans-down"], -1, 1),
    ("mouth_trans_d", ["mouth-trans-forward"], ["mouth-trans-backward"], -1, 1),
    ("upperlip_height", ["mouth-upperlip-height-incr"], ["mouth-upperlip-height-decr"], -1, 1),
    ("lowerlip_height", ["mouth-lowerlip-height-incr"], ["mouth-lowerlip-height-decr"], -1, 1),
    ("upperlip_volume", ["mouth-upperlip-volume-incr"], ["mouth-upperlip-volume-decr"], -1, 1),
    ("lowerlip_volume", ["mouth-lowerlip-volume-incr"], ["mouth-lowerlip-volume-decr"], -1, 1),
    ("mouth_angles", ["mouth-angles-up"], ["mouth-angles-down"], -1, 1),
    # chin / jaw
    ("chin_height", ["chin-height-incr"], ["chin-height-decr"], -1, 1),
    ("chin_width", ["chin-width-incr"], ["chin-width-decr"], -1, 1),
    ("chin_prominent", ["chin-prominent-incr"], ["chin-prominent-decr"], -1, 1),
    ("chin_prognathism", ["chin-prognathism-incr"], ["chin-prognathism-decr"], -1, 1),
    ("jaw_drop", ["chin-jaw-drop-incr"], ["chin-jaw-drop-decr"], -1, 1),
    ("chin_bones", ["chin-bones-incr"], ["chin-bones-decr"], -1, 1),
    # eyes (both sides together)
    ("eye_scale", _lr("eye-scale-incr"), _lr("eye-scale-decr"), -1, 1),
    ("eye_trans_v", _lr("eye-trans-up"), _lr("eye-trans-down"), -1, 1),
    ("eye_trans_h", _lr("eye-trans-out"), _lr("eye-trans-in"), -0.6, 0.6),
    ("eye_height", _lr("eye-height2-incr"), _lr("eye-height2-decr"), -1, 1),
    # cheeks / forehead
    ("cheek_bones", _lr("cheek-bones-incr"), _lr("cheek-bones-decr"), -1, 1),
    ("cheek_volume", _lr("cheek-volume-incr"), _lr("cheek-volume-decr"), -1, 1),
    ("forehead_height", ["forehead-scale-vert-incr"], ["forehead-scale-vert-decr"], -1, 1),
    ("forehead_depth", ["forehead-trans-forward"], ["forehead-trans-backward"], -1, 1),
    ("forehead_temple", ["forehead-temple-incr"], ["forehead-temple-decr"], -1, 1),
    # extra shape controls for the MediaPipe fit
    ("head_round", ["head-round"], [], 0, 1),
    ("head_oval", ["head-oval"], [], 0, 1),
    ("head_rect", ["head-rectangular"], [], 0, 1),
    ("head_square", ["head-square"], [], 0, 1),
    ("head_tri", ["head-triangular"], [], 0, 1),
    ("head_invtri", ["head-invertedtriangular"], [], 0, 1),
    ("head_angle", ["head-angle-out"], ["head-angle-in"], -1, 1),
    ("cheek_inner", _lr("cheek-inner-incr"), _lr("cheek-inner-decr"), -1, 1),
    ("cheek_trans_v", _lr("cheek-trans-up"), _lr("cheek-trans-down"), -1, 1),
    ("chin_triangle", ["chin-triangle"], [], 0, 1),
    ("nose_hump", ["nose-hump-incr"], ["nose-hump-decr"], -1, 1),
    ("nose_greek", ["nose-greek-incr"], ["nose-greek-decr"], -1, 1),
    ("nose_curve", ["nose-curve-convex"], ["nose-curve-concave"], -1, 1),
    ("nose_scale_h", ["nose-scale-horiz-incr"], ["nose-scale-horiz-decr"], -1, 1),
    ("nostril_width", ["nose-nostrils-width-incr"], ["nose-nostrils-width-decr"], -1, 1),
    ("nose_volume", ["nose-volume-incr"], ["nose-volume-decr"], -1, 1),
    ("eye_height1", _lr("eye-height1-incr"), _lr("eye-height1-decr"), -1, 1),
    ("eye_height3", _lr("eye-height3-incr"), _lr("eye-height3-decr"), -1, 1),
    ("eye_push1", _lr("eye-push1-out"), _lr("eye-push1-in"), -1, 1),
    ("eye_push2", _lr("eye-push2-out"), _lr("eye-push2-in"), -1, 1),
    ("eye_corner1", _lr("eye-corner1-up"), _lr("eye-corner1-down"), -1, 1),
    ("brow_v", ["eyebrows-trans-up"], ["eyebrows-trans-down"], -1, 1),
    ("brow_d", ["eyebrows-trans-forward"], ["eyebrows-trans-backward"], -1, 1),
    ("brow_angle", ["eyebrows-angle-up"], ["eyebrows-angle-down"], -1, 1),
    ("mouth_depth", ["mouth-scale-depth-incr"], ["mouth-scale-depth-decr"], -1, 1),
    ("philtrum", ["mouth-philtrum-volume-incr"], ["mouth-philtrum-volume-decr"], -1, 1),
    ("forehead_nubian", ["forehead-nubian-incr"], ["forehead-nubian-decr"], -1, 1),
    # ears
    ("ear_scale", _lr("ear-scale-incr"), _lr("ear-scale-decr"), -1, 1),
    ("ear_trans_v", _lr("ear-trans-up"), _lr("ear-trans-down"), -1, 1),
    ("ear_trans_d", _lr("ear-trans-forward"), _lr("ear-trans-backward"), -0.7, 0.7),
    ("ear_wing", _lr("ear-wing-incr"), _lr("ear-wing-decr"), -1, 1),
]

# not fitted (no landmarks): the tired-eyes / brow look from the earlier hand pass
FIXED_TARGETS = [("l-eye-bag-incr", 0.35), ("r-eye-bag-incr", 0.35)]


def expand(values):
    """{var: value} -> [(stem, weight)] for TargetService.load_target."""
    out = []
    for name, pos, neg, lo, hi in FACE_VARS:
        v = float(values.get(name, 0.0))
        if abs(v) < 1e-3:
            continue
        for s in (pos if v > 0 else neg):
            out.append((s, abs(v)))
    return out + list(FIXED_TARGETS)
