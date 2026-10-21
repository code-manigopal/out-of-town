"""Placeholder shop-sign pictures + the image-prompt file. Run with tools/.venv/bin/python.
  game/environments/windsor/exterior/signs/<shop_id>.png     placeholder typography (OFL Google Fonts in ../fonts/)
  docs/art/prompts-shop-signs.md                              one image prompt per shop (exact pixel size each)
The sign quad of a shop of width W is (W - 1.3) m x 0.9 m; 300 px per metre."""
import os
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", ".."))
OUT = os.path.join(ROOT, "game", "environments", "windsor", "exterior", "signs")
FONTS = os.path.join(HERE, "..", "fonts")
PXM = 300
SIGN_H_M = 0.9
# id, name, tagline, kit width (m), font, board colour, text colour, accent, what the sign looks like
SHOPS = [
 ("brindle_wick_cafe", "Brindle & Wick Café", "COFFEE  ·  TEA  ·  PASTRY", 8.0, "Pacifico-Regular.ttf", (0.16, 0.24, 0.2), (0.96, 0.92, 0.8), (0.85, 0.65, 0.3),
  "a deep forest-green painted wooden fascia with cream hand-lettered script and a small steaming-cup outline in gold leaf"),
 ("quill_books", "Quill Books", "NEW  ·  USED  ·  RARE", 7.0, "AbrilFatface-Regular.ttf", (0.1, 0.1, 0.13), (0.93, 0.82, 0.5), (0.93, 0.82, 0.5),
  "a black lacquered board with gold serif capitals and a thin gold border, a small quill-pen silhouette at the left end"),
 ("tamsins_bakery", "Tamsin's Bakery", "BREAD  ·  CAKES  ·  PIES", 9.0, "Lobster-Regular.ttf", (0.93, 0.86, 0.74), (0.62, 0.2, 0.18), (0.62, 0.2, 0.18),
  "a cream enamel sign with red-brown script lettering and a wheat-sheaf motif, a little chipped at one corner"),
 ("kellerman_dry_cleaning", "Kellerman Dry Cleaning", "CLEANERS  ·  ALTERATIONS", 7.5, "AlfaSlabOne-Regular.ttf", (0.12, 0.2, 0.36), (0.95, 0.95, 0.92), (0.8, 0.2, 0.2),
  "a navy backlit-plastic box sign with white slab-serif letters and a red underline, slightly dusty"),
 ("holloway_hardware", "Holloway Hardware", "TOOLS  ·  PAINT  ·  KEYS CUT", 7.0, "Rye-Regular.ttf", (0.55, 0.12, 0.1), (0.96, 0.9, 0.7), (0.96, 0.9, 0.7),
  "an old-fashioned red painted board with cream western-style letters and a small hammer-and-wrench icon, paint weathered at the edges"),
 ("nimbus_barber", "Nimbus Barber", "CUTS  ·  SHAVES  ·  SINCE 1974", 8.0, "BebasNeue-Regular.ttf", (0.9, 0.9, 0.88), (0.1, 0.12, 0.2), (0.75, 0.15, 0.15),
  "a white board with tall navy sans-serif capitals, a red-white-blue barber stripe at each end"),
 ("fernwood_florist", "Fernwood Florist", "FRESH FLOWERS DAILY", 7.5, "Limelight-Regular.ttf", (0.36, 0.45, 0.32), (0.98, 0.95, 0.9), (0.9, 0.6, 0.65),
  "a sage-green board with ivory art-deco lettering and a hand-painted fern and pink bloom at each end"),
 ("orchard_row_pharmacy", "Orchard Row Pharmacy", "PRESCRIPTIONS  ·  HEALTH  ·  BEAUTY", 9.0, "Righteous-Regular.ttf", (0.93, 0.93, 0.92), (0.1, 0.4, 0.28), (0.1, 0.4, 0.28),
  "a clean white box sign with green rounded capitals and a green cross-and-leaf symbol (generic, not any real chain)"),
 ("lakeshore_vinyl", "Lakeshore Vinyl & Records", "BUY  ·  SELL  ·  TRADE", 7.0, "Righteous-Regular.ttf", (0.1, 0.1, 0.12), (0.98, 0.78, 0.2), (0.9, 0.3, 0.2),
  "a black board with bright mustard-yellow retro lettering and a record-disc graphic, a little sun-faded"),
 ("halloran_and_sons_butcher", "Halloran & Sons Butcher", "QUALITY MEATS  ·  SINCE 1951", 7.5, "AbrilFatface-Regular.ttf", (0.42, 0.1, 0.12), (0.97, 0.92, 0.82), (0.97, 0.92, 0.82),
  "a burgundy painted board with cream serif lettering and a simple steer-head outline, painted in gold edging"),
 ("corner_slice_pizzeria", "Corner Slice Pizzeria", "BY THE SLICE  ·  OPEN LATE", 8.0, "Lobster-Regular.ttf", (0.8, 0.18, 0.12), (0.99, 0.95, 0.85), (0.99, 0.8, 0.2),
  "a red board with cream script lettering outlined in yellow and a pizza-slice picture, glossy and a little scuffed"),
 ("ironbridge_tailors", "Ironbridge Tailors", "SUITS  ·  ALTERATIONS  ·  REPAIRS", 9.0, "Limelight-Regular.ttf", (0.2, 0.2, 0.22), (0.9, 0.9, 0.86), (0.7, 0.6, 0.35),
  "a charcoal board with silver-white lettering and a thin brass border, a tape-measure line along the bottom edge"),
]

def sign_px(width_m):
    return int(round((width_m - 1.3) * PXM)), int(round(SIGN_H_M * PXM))

def c8(c): return tuple(int(v * 255) for v in c)

def render(row):
    sid, name, tag, w, font, bg, fg, acc, _ = row
    W, H = sign_px(w)
    im = Image.new("RGB", (W, H), c8(bg))
    d = ImageDraw.Draw(im)
    d.rectangle([6, 6, W - 7, H - 7], outline=c8(acc), width=5)
    d.rectangle([16, 16, W - 17, H - 17], outline=c8(acc), width=2)
    size = int(H * 0.56)
    f = ImageFont.truetype(os.path.join(FONTS, font), size)
    while d.textlength(name, font=f) > W * 0.86 and size > 20:
        size -= 4
        f = ImageFont.truetype(os.path.join(FONTS, font), size)
    tw = d.textlength(name, font=f)
    bb = d.textbbox((0, 0), name, font=f)
    ty = (H * 0.46) - (bb[1] + bb[3]) / 2
    d.text(((W - tw) / 2, ty), name, font=f, fill=c8(fg))
    tf = ImageFont.truetype(os.path.join(FONTS, "BebasNeue-Regular.ttf"), int(H * 0.15))
    ttw = d.textlength(tag, font=tf)
    d.text(((W - ttw) / 2, H * 0.80), tag, font=tf, fill=c8(acc))
    im.save(os.path.join(OUT, sid + ".png"), optimize=True)

def prompts():
    L = ["# Shop-sign image prompts (Windsor main street)", "",
         "Twelve storefront signs for the shops across the street from Mani's building (Episode 1 exit sequence). Each sign is a",
         "flat picture shown on a quad above the shop's awning (`game/environments/windsor/exterior/signs/<shop_id>.png`); the",
         "placeholder typography in those files is replaced by your image. All shop names are invented; **no real brands, logos,",
         "trademarks or chain styling**.", "",
         "How to use: generate at the widest ratio your tool allows (21:9 or 3:1), front-on and flat to the camera with the sign",
         "board filling the whole frame, then crop and resize to the **exact pixel size** below (the sign is 300 px per metre,",
         "so a 6.7 m board is 2010 px wide) and save as `<shop_id>.png`. Opaque PNG, sRGB. Keep letters well inside the frame (about 7%",
         "margin) so the board edges can show.", "",
         "Common style line (append to every prompt): *photorealistic, orthographic front view, flat evenly lit, early-November",
         "overcast morning light, subtle weathering, realistic material texture (paint, enamel, brushed metal or lacquered wood),",
         "sharp legible lettering, no people, no cars, no reflections of buildings, no watermark, no real brand or logo.*", ""]
    for n, row in enumerate(SHOPS, 1):
        sid, name, tag, w, font, bg, fg, acc, desc = row
        W, H = sign_px(w)
        L += ["## %d. %s" % (n, name), "",
              "- File: `%s.png`, **%d x %d px** (%.1f m x %.1f m board, aspect %.2f:1); shop frontage %.1f m" % (sid, W, H, W / PXM, H / PXM, W / H, w),
              "- Placeholder font: %s" % font.split("-")[0],
              "- Prompt: Photorealistic storefront fascia sign, flat front-on view, a sign board reading \"%s\" with the smaller line \"%s\", %s. "
              "The board fills the entire frame edge to edge, a thin painted border inset from the edges, lettering centred with generous margins, "
              "aged but cared-for paintwork, soft overcast daylight, no logos or trademarks of real companies." % (name, tag.title() if False else tag, desc), ""]
    return "\n".join(L)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for r in SHOPS:
        render(r)
        print(r[0], sign_px(r[3]))
    open(os.path.join(ROOT, "docs", "art", "prompts-shop-signs.md"), "w").write(prompts() + "\n")
