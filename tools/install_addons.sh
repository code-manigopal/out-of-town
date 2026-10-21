#!/usr/bin/env bash
# Installs the pinned Godot add-ons into game/addons/.
# Script-only add-ons are committed to the repo; the binary GDExtensions
# (Terrain3D, LimboAI) are gitignored and must be installed with this script
# on every new checkout and in CI. Re-running is safe.
#
#   tools/install_addons.sh            # binary GDExtensions only (default)
#   tools/install_addons.sh --all      # every add-on, e.g. to update a version
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADDONS="$ROOT/game/addons"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
UA="OutOfTown-dev"

# name | url | folder inside the archive that holds addons/<dir> | addons/<dir> | committed?
PINS=(
  "phantom_camera|https://github.com/ramokz/phantom-camera/archive/refs/tags/v0.11.0.3.zip|phantom-camera-0.11.0.3|phantom_camera|yes"
  "road_generator|https://github.com/TheDuckCow/godot-road-generator/archive/refs/tags/0.9.5.zip|godot-road-generator-0.9.5|road-generator|yes"
  "proton_scatter|https://github.com/HungryProton/scatter/archive/7198cc0007.zip|scatter-7198cc0007*|proton_scatter|yes"
  "gdunit4|https://github.com/godot-gdunit-labs/gdUnit4/archive/refs/tags/v6.2.2.zip|gdUnit4-6.2.2|gdUnit4|yes"
  "terrain_3d|https://github.com/TokisanGames/Terrain3D/releases/download/v1.0.2-stable/Terrain3D_v1.0.2-stable.zip|.|terrain_3d|no"
  "limboai|https://github.com/limbonaut/limboai/releases/download/v1.8.1/limboai%2Bv1.8.1.gdextension-4.6.zip|.|limboai|no"
)

mode="${1:-binary}"
mkdir -p "$ADDONS"
for pin in "${PINS[@]}"; do
  IFS='|' read -r name url inner dir committed <<<"$pin"
  if [[ "$mode" != "--all" && "$committed" == "yes" ]]; then continue; fi
  echo "== $name"
  curl -sfL -A "$UA" -o "$TMP/$name.zip" "$url"
  mkdir -p "$TMP/$name" && unzip -q "$TMP/$name.zip" -d "$TMP/$name"
  src="$(ls -d "$TMP/$name"/$inner 2>/dev/null | head -1)/addons/$dir"
  [[ -d "$src" ]] || src="$(find "$TMP/$name" -type d -path "*/addons/$dir" | head -1)"
  [[ -d "$src" ]] || { echo "addons/$dir not found in $name archive" >&2; exit 1; }
  rm -rf "$ADDONS/$dir" && cp -R "$src" "$ADDONS/$dir"
  echo "   -> game/addons/$dir"
done
