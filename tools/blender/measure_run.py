"""Run-cycle metrics from the `jog` action in the open blend:  blender -b X.blend -P measure_run.py [-- --clip=jog]"""
import math, sys, bpy, numpy as np
from mathutils import Vector
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
clip = next((a.split("=")[1] for a in args if a.startswith("--clip=")), "jog")
speed = float(next((a.split("=")[1] for a in args if a.startswith("--speed=")), "2.8"))
rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
act = bpy.data.actions[clip]
rig.animation_data_create(); rig.animation_data.action = act
sc = bpy.context.scene
f0, f1 = int(act.frame_range[0]), int(act.frame_range[1]); n = f1 - f0
def W(name, tail=False):
    pb = rig.pose.bones[name]; return rig.matrix_world @ (pb.tail if tail else pb.head)
def lowpts(s):
    pb = rig.pose.bones["foot_" + s]; bn = rig.data.bones["foot_" + s]
    heel_rest = bn.head_local + Vector((0, 0.08, -0.069))
    heel = rig.matrix_world @ (pb.matrix @ (bn.matrix_local.inverted() @ heel_rest))
    return heel, W("ball_" + s), W("ball_" + s, True)
rows = []
pts = []
for f in range(f0, f1):
    sc.frame_set(f); bpy.context.view_layer.update()
    r = {}
    for s in "lr":
        h, b0, b1 = lowpts(s)
        r["low" + s] = min(h.z, b0.z, b1.z); r["ball" + s] = b1 if b1.z < b0.z else b0; r["heel" + s] = h
        hip, kn, an = W("thigh_" + s), W("calf_" + s), W("calf_" + s, True)
        pass
        r["knee" + s] = math.degrees((kn - hip).angle(an - kn)); r["ank" + s] = an; r["hip" + s] = hip
    r["pel"] = W("pelvis"); r["neck"] = W("neck_01"); r["head"] = W("head"); r["sh"] = W("upperarm_l")
    for s in "lr":
        r["elb" + s] = math.degrees((W("lowerarm_" + s) - W("upperarm_" + s)).angle(W("hand_" + s) - W("lowerarm_" + s)))
        r["hand" + s] = W("hand_" + s)
    pts.append({s: dict(zip(("heel","ballh","ballt"), lowpts(s))) for s in "lr"})
    rows.append(r)
thr = 0.025
air = [all(r["low" + s] > thr for s in "lr") for r in rows]
print("[run] cycle %d frames = %.3f s -> %.0f steps/min; flight frames %d/%d = %.0f%% of cycle" % (n, n / 30, 120 * 30 / n, sum(air), n, 100 * sum(air) / n))
# stance slide per foot: for each of heel / ball-head / ball-tip, frames where that point is on the ground (z<thr) twice in a row
for s in "lr":
    st = [r["low" + s] < thr for r in rows]
    errs = []
    for key in ("heel", "ballh", "ballt"):
        for i in range(n):
            j = (i + 1) % n
            pi = pts[i][s][key]; pj = pts[j][s][key]
            if pi.z < thr and pj.z < thr:
                errs.append(abs((pj.y - pi.y) * 30 - speed))
    print("[run] foot %s ground-contact frames %d: slide mean %.3f max %.3f m/s (speed %.2f)" % (s, sum(st), np.mean(errs) if errs else -1, max(errs) if errs else -1, speed))
    kn = [r["knee" + s] for r in rows]
    sti = [i for i in range(n) if st[i]]
    if sti:
        mid = sti[len(sti) // 2]
        print("[run] foot %s knee: at strike %.0f, mid-stance %.0f, stance max %.0f, swing max %.0f, min %.0f" % (s, kn[sti[0]], kn[mid], max(kn[i] for i in sti), max(kn[i] for i in range(n) if not st[i]), min(kn)))
    # hip extension at toe-off: thigh angle from vertical behind
    th = [math.degrees(math.atan2(-(r["knee" + s].real if False else 0), 1)) for r in rows]
lean = [math.degrees(math.atan2(-(r["neck"].y - r["pel"].y), r["neck"].z - r["pel"].z)) for r in rows]
print("[run] trunk lean pelvis->neck mean %.1f deg (%.1f..%.1f)" % (np.mean(lean), min(lean), max(lean)))
leanA = [math.degrees(math.atan2(-(r["neck"].y - min(r["ankl"].y, r["ankr"].y)*0 - (r["ankl"].y + r["ankr"].y)/2), r["neck"].z - 0.07)) for r in rows]
hz = [r["head"].z for r in rows]; pz = [r["pel"].z for r in rows]
print("[run] head bob %.3f m, pelvis bob %.3f m, head lateral sway %.3f m" % (max(hz) - min(hz), max(pz) - min(pz), max(r["head"].x for r in rows) - min(r["head"].x for r in rows)))
# hip extension: angle of thigh behind vertical (max) and ahead (max)
for s in "l":
    ang = [math.degrees(math.atan2(r["knee" + s] * 0 + (r["ank" + s].y - r["hip" + s].y), r["hip" + s].z - r["ank" + s].z)) for r in rows]
    print("[run] leg (hip->ankle) angle from vertical, +behind: %.0f .. %.0f deg" % (min(ang), max(ang)))
for s in "lr":
    print("[run] elbow %s flexion %.0f..%.0f; hand x from midline %.2f..%.2f, hand fwd-back %.2f..%.2f (rel. shoulder)" % (s, min(r["elb" + s] for r in rows), max(r["elb" + s] for r in rows),
          min(abs(r["hand" + s].x) for r in rows), max(abs(r["hand" + s].x) for r in rows),
          min((r["hand" + s].y - r["sh"].y) for r in rows), max((r["hand" + s].y - r["sh"].y) for r in rows)))

for s in "lr":
    up = [r["hand" + s].z - r["sh"].z for r in rows]
    fw = [-(r["hand" + s].y - r["sh"].y) for r in rows]
    ch = [-(r["hand" + s].y - r["pel"].y) for r in rows]
    print("[run] hand %s height vs shoulder %.2f..%.2f m (chest ~ -0.15..-0.25); forward of shoulder max %.2f m; forward of pelvis max %.2f m" % (s, min(up), max(up), max(fw), max(ch)))
