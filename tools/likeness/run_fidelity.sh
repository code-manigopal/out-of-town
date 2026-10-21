#!/usr/bin/env bash
# Measures a model against one panel of its approved turnaround sheet with the
# vendored blender-kiln fidelity check (tools/likeness/vendor/blender_kiln/, MIT).
#
#   tools/likeness/run_fidelity.sh --sheet docs/art/sheets/mani/mani_p1_turnaround.png \
#       --panel front|side|back --model game/characters/mani/mani.glb [--out DIR] [--joints 1]
#
# Turnaround sheets show four figures: front, left side, back, three-quarter.
# sheet_panel.py finds the figure and keys the plain background to transparency
# (the check needs alpha); it is then rendered under a CC0 studio HDRI. Prints the FIDELITY summary;
# writes overlay.png (red = sheet only, cyan = model only) and side_by_side.png.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SHEET="" PANEL="front" MODEL="" OUT="" JOINTS="0"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sheet) SHEET="$2"; shift 2 ;;
    --panel) PANEL="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --joints) JOINTS="$2"; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
[[ -f "$SHEET" && -f "$MODEL" ]] || { echo "need --sheet and --model files" >&2; exit 2; }
case "$PANEL" in
  front) INDEX=0 VIEW=front ;;
  side) INDEX=1 VIEW=left ;;
  back) INDEX=2 VIEW=back ;;
  *) echo "--panel is front, side or back" >&2; exit 2 ;;
esac
OUT="${OUT:-$(mktemp -d)/fidelity_$PANEL}"
mkdir -p "$OUT"

HDRI="$ROOT/tools/likeness/models/studio_small_09_1k.hdr"   # Poly Haven, CC0 (gitignored folder)
if [[ ! -f "$HDRI" ]]; then
  mkdir -p "$(dirname "$HDRI")"
  url=$(curl -s https://api.polyhaven.com/files/studio_small_09 | python3 -I -c "import json,sys; print(json.load(sys.stdin)['hdri']['1k']['hdr']['url'])")
  curl -sfL -o "$HDRI" "$url"
fi

REF="$OUT/reference_$PANEL.png"
"$ROOT/tools/.venv/bin/python" -I "$ROOT/tools/likeness/sheet_panel.py" "$SHEET" "$INDEX" "$REF"

blender -b --factory-startup --python-exit-code 1 \
  --python "$ROOT/tools/likeness/vendor/blender_kiln/fidelity_check.py" -- \
  --reference "$REF" --model "$MODEL" --hdri "$HDRI" --out "$OUT" \
  --view "$VIEW" --samples 32 --max-tris 100000 --joints "$JOINTS" > "$OUT/fidelity.log" 2>&1 || {
    tail -20 "$OUT/fidelity.log" >&2; exit 1; }
grep -A12 "silhouette IoU" "$OUT/fidelity.log"
grep "^FIDELITY " "$OUT/fidelity.log" | sed 's/^FIDELITY //' > "$OUT/fidelity.json"
echo "results: $OUT (overlay.png, side_by_side.png, fidelity.json)"
