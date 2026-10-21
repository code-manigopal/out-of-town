#!/usr/bin/env bash
# Creates tools/.venv (MediaPipe) and downloads the MediaPipe models into
# tools/likeness/models/. Both are gitignored. Models: Apache-2.0, from Google.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[[ -x "$ROOT/tools/.venv/bin/python" ]] || /opt/homebrew/bin/python3.12 -m venv "$ROOT/tools/.venv"
"$ROOT/tools/.venv/bin/pip" install -q mediapipe piper-tts
mkdir -p "$ROOT/tools/likeness/models"
cd "$ROOT/tools/likeness/models"
for u in face_landmarker/face_landmarker/float16/latest/face_landmarker.task \
         pose_landmarker/pose_landmarker_heavy/float16/latest/pose_landmarker_heavy.task; do
  [[ -f "$(basename "$u")" ]] || curl -sfL -O "https://storage.googleapis.com/mediapipe-models/$u"
done
mkdir -p "$ROOT/tools/voice/models" && cd "$ROOT/tools/voice/models"
V=https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/libritts_r/medium
for f in en_US-libritts_r-medium.onnx en_US-libritts_r-medium.onnx.json; do
  [[ -f "$f" ]] || curl -sfL -O "$V/$f"
done
echo "Python tools ready."
