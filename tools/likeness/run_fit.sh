#!/bin/bash
# Iterate the MediaPipe likeness fit: build -> render sheet views -> detect -> report error -> refit.
#   tools/likeness/run_fit.sh WORKDIR ITERATIONS [MU]
# WORKDIR holds views.json (orbit angles per view) and receives r0/, r1/, ... plus sheet_det.json.
set -e
cd "$(dirname "$0")/../.."
W=${1:?workdir}; N=${2:-2}; MU=${3:-0.4}
BL=/opt/homebrew/bin/blender; PY="tools/.venv/bin/python -I"
mkdir -p "$W"
[ -f "$W/sheet_det.json" ] || $PY tools/likeness/mp_detect.py sheet "$W/sheet_det.json" 2>&1 | tail -1
for i in $(seq 0 $N); do
  $BL -b -P tools/blender/build_mani.py -- --stage=40 --no-export > "$W/build_$i.log" 2>&1
  $BL -b "${STAGE:-$W/../w/stage2.blend}" -P tools/likeness/render_fit_views.py -- "$W/r$i" "$W/views.json" > /dev/null 2>&1
  $PY tools/likeness/mp_detect.py images "$W/r$i/det.json" front="$W/r$i/view_front.png" q34L="$W/r$i/view_q34L.png" q34R="$W/r$i/view_q34R.png" 2>&1 | tail -1
  echo "--- iteration $i (MediaPipe on render vs sheet)"
  $PY tools/likeness/mp_error.py "$W/sheet_det.json" "$W/r$i/det.json" "$W/err_$i.json"
  if [ "$i" -lt "$N" ]; then
    $BL -b -P tools/likeness/fit_face_mp.py -- "$W/sheet_det.json" "$W/r$i/det.json" "$W/r$i/cams.json" --mu=$MU 2>&1 | grep "fitmp"
  else
    $BL -b -P tools/likeness/fit_face_mp.py -- "$W/sheet_det.json" "$W/r$i/det.json" "$W/r$i/cams.json" --bind-only 2>&1 | grep "fitmp"
  fi
done
