"""Writes the PBR .tres materials the exterior kit is remapped to (OOTExteriorWorld._remap, by material name).
Run: python3 gen_materials.py"""
import os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", ".."))
MAT = os.path.join(ROOT, "game", "environments", "windsor", "exterior", "materials")
PH = "res://environments/windsor/exterior/textures/ph/"
TX = "res://environments/windsor/exterior/textures/"
# name: (set, ext, tint, uv scale, triplanar-world, normal_scale, extra)
T = {
 "Asphalt":      ("asphalt_02", "jpg", (0.92, 0.92, 0.94), 0.30, True, 1.0, ""),
 "LotAsphalt":   ("asphalt_01", "jpg", (1.05, 1.05, 1.05), 0.34, True, 1.0, ""),
 "Sidewalk":     ("brushed_concrete_04", "jpg", (1.2, 1.2, 1.18), 0.42, True, 1.0, ""),
 "AlleyConcrete":("brushed_concrete_03", "jpg", (1.1, 1.1, 1.08), 0.42, True, 1.0, ""),
 "Concrete":     ("brushed_concrete_03", "jpg", (1.25, 1.25, 1.22), 0.7, False, 1.0, ""),
 "Brick":        ("red_brick_03", "jpg", (1.0, 0.96, 0.94), 1.0, False, 1.2, ""),
 "BrickTan":     ("red_brick_03", "jpg", (1.5, 1.38, 1.15), 1.0, False, 1.2, ""),
 "BrickBrown":   ("red_bricks_04", "jpg", (0.82, 0.74, 0.7), 0.66, False, 1.2, ""),
 "Roof":         ("concrete_pavement_03", "jpg", (0.82, 0.82, 0.86), 0.9, False, 1.0, ""),
 "Siding":       ("white_planks_h", "jpg", (0.93, 0.9, 0.82), 1.0, False, 1.0, ""),
 "SidingBlue":   ("white_planks_h", "jpg", (0.58, 0.69, 0.78), 1.0, False, 1.0, ""),
 "SidingGreen":  ("white_planks_h", "jpg", (0.62, 0.72, 0.6), 1.0, False, 1.0, ""),
 "SidingGrey":   ("white_planks_h", "jpg", (0.66, 0.67, 0.7), 1.0, False, 1.0, ""),
 "Deck":         ("planks_brown_10", "jpg", (1.1, 1.05, 1.0), 1.0, False, 1.0, ""),
 "Fence":        ("weathered_planks", "jpg", (1.0, 0.96, 0.92), 1.0, False, 1.0, ""),
 "Grass":        ("sparse_grass", "jpg", (1.0, 1.2, 0.82), 0.16, True, 1.0, ""),
 "Bark":         ("bark_brown_01", "jpg", (0.8, 0.76, 0.72), 1.0, False, 1.2, ""),
}
def vec(v): return "Vector3(%g, %g, %g)" % (v, v, v)
def col(c): return "Color(%g, %g, %g, 1)" % c
def write(name, body, exts):
    lines = ["[gd_resource type=\"StandardMaterial3D\" load_steps=%d format=3]\n" % (len(exts) + 1)]
    for i, (path, typ) in enumerate(exts):
        lines.append("[ext_resource type=\"%s\" path=\"%s\" id=\"%d_t\"]" % (typ, path, i + 1))
    lines.append("\n[resource]\nresource_name = \"%s\"\n%s" % (name, body))
    open(os.path.join(MAT, name + ".tres"), "w").write("\n".join(lines) + "\n")
for name, (s, ext, tint, scale, tri, ns, extra) in T.items():
    exts = [(PH + "%s_diff.%s" % (s, ext), "Texture2D"), (PH + "%s_nor.%s" % (s, ext), "Texture2D"), (PH + "%s_rough.%s" % (s, ext), "Texture2D")]
    b = "albedo_color = %s\nalbedo_texture = ExtResource(\"1_t\")\nroughness = 1.0\nroughness_texture = ExtResource(\"3_t\")\n" % col(tint)
    b += "normal_enabled = true\nnormal_scale = %g\nnormal_texture = ExtResource(\"2_t\")\n" % ns
    b += "uv1_scale = %s\n" % vec(scale)
    if tri:
        b += "uv1_triplanar = true\nuv1_world_triplanar = true\n"
    b += "texture_filter = 5\n" + extra
    write(name, b, exts)
# leaf cards: alpha scissor, double sided, soft backlight
for name, tex, tint in (("LeafOrange", "leaf_orange", (1, 1, 1)), ("LeafYellow", "leaf_yellow", (1, 1, 1)),
                        ("LeafRust", "leaf_rust", (1, 1, 1)), ("LeafGreen", "leaf_green", (1, 1, 1))):
    b = ("transparency = 2\nalpha_scissor_threshold = 0.5\ncull_mode = 2\nalbedo_color = %s\nalbedo_texture = ExtResource(\"1_t\")\n"
         "roughness = 0.85\nsubsurf_scatter_enabled = false\nbacklight_enabled = true\nbacklight = Color(0.35, 0.25, 0.1, 1)\n"
         "texture_filter = 5\nshadow_to_opacity = false\n") % col(tint)
    write(name, b, [(TX + tex + ".png", "Texture2D")])
# road paint with a worn alpha mask
for name, c in (("LaneWhite", (0.85, 0.85, 0.82)), ("LaneYellow", (0.9, 0.7, 0.1))):
    b = ("transparency = 2\nalpha_scissor_threshold = 0.45\nalbedo_color = %s\nalbedo_texture = ExtResource(\"1_t\")\nroughness = 0.7\n"
         "uv1_scale = Vector3(0.5, 0.5, 0.5)\nuv1_triplanar = true\nuv1_world_triplanar = true\ntexture_filter = 5\n") % col(c)
    write(name, b, [(TX + "paint_c.png", "Texture2D")])
# rain puddles: soft irregular alpha blob, mirror-smooth
write("Puddle", ("transparency = 1\nalbedo_color = Color(1, 1, 1, 0.78)\nalbedo_texture = ExtResource(\"1_t\")\nmetallic_specular = 0.5\nroughness = 0.02\n"
                 "texture_filter = 5\n"), [(TX + "puddle_c.png", "Texture2D")])
write("OilStain", ("transparency = 1\nalbedo_color = Color(0.4, 0.4, 0.42, 0.55)\nalbedo_texture = ExtResource(\"1_t\")\nmetallic_specular = 0.25\nroughness = 0.35\n"
                   "texture_filter = 5\n"), [(TX + "puddle_c.png", "Texture2D")])
print("ok")
