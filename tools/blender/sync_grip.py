"""Copy the fitted carry offsets (art_source/characters/mani/grip.json) into game/scripts/player/player.gd.
    python3 tools/blender/sync_grip.py
"""
import json
import os

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
g = json.load(open(os.path.join(REPO, "art_source/characters/mani/grip.json")))
p = os.path.join(REPO, "game/scripts/player/player.gd")
s = open(p).read()
a = s.index("const CARRY_ITEMS")
b = s.index("}\n", s.index('"radio"', a)) + 2
lines = ["const CARRY_ITEMS: Dictionary = {"]
for k in ("sweets", "diyas", "radio"):
    o, yaw = g[k]["offset_body"], g[k]["yaw"]
    rot = "Vector3.ZERO" if yaw == 0 else "Vector3(0, %d, 0)" % yaw
    lines.append('\t"%s": {"offset": Vector3(%s, %s, %s), "rot": %s, "clip": "carry_%s"},' % (k, o[0], o[1], o[2], rot, k))
lines.append("}\n")
s = s[:a] + "\n".join(lines) + s[b:]
o = g["sweets"]["offset_body"]
import re
s = re.sub(r'const CARRY_DEFAULT: Dictionary = \{"offset": Vector3\([^)]*\)', 'const CARRY_DEFAULT: Dictionary = {"offset": Vector3(%s, %s, %s)' % tuple(o), s)
open(p, "w").write(s)
print("synced", {k: v["offset_body"] for k, v in g.items()})
