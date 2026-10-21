# Vendored: blender-kiln `fidelity_check.py`

- Source: https://github.com/elithril/blender-kiln, `plugin/tools/fidelity_check.py`, commit `4b170be2756d87d0d5a1b8e7aebef5fd61c7f771` (2026-10-12).
- Licence: MIT, Copyright (c) 2026 Nicolas Dolphens. See `LICENSE` in this folder (must stay with the file).
- Local change (marked in the code): `--joints 0` skips the per-joint close-up renders.
- Only this script is used. The rest of blender-kiln (plugin, Blender MCP server, AI generation routes) is **not** installed.

Use it through `tools/likeness/run_fidelity.sh`, which prepares the reference (transparent background) and the studio light.
