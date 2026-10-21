# Tools and add-ons

Everything here is free. MIT/CC0/Apache items may ship in the game; GPL/AGPL tools are only used during development and are never shipped. Installed 2026-10-20 on the dev Mac.

## Godot add-ons (`game/addons/`)

| Add-on | Version | Licence | Use | In git? |
| --- | --- | --- | --- | --- |
| [Phantom Camera](https://github.com/ramokz/phantom-camera) | v0.11.0.3 | MIT | Third-person follow camera, locked-off dread shots, cutscene camera blends. Needs the `PhantomCameraManager` autoload (set in `project.godot`). | yes |
| [Road Generator](https://github.com/TheDuckCow/godot-road-generator) | 0.9.5 | MIT | County Road 20, Highway 17 and town streets | yes |
| [Proton Scatter](https://github.com/HungryProton/scatter) | main @ 7198cc0007 | MIT | Scattering trees, rocks, fences and greenhouses | yes |
| [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) | v6.2.2 | MIT | Unit-test framework (our current runner is `tests/run_tests.gd`) | yes |
| [Terrain3D](https://github.com/TokisanGames/Terrain3D) | v1.0.2-stable | MIT | Terrain: farmland, lakeshore, the Burn | **no** (binary) |
| [LimboAI](https://github.com/limbonaut/limboai) | v1.8.1 (GDExtension for 4.6+) | MIT | Behaviour trees and state machines for stealth AI | **no** (binary) |

The two binary GDExtensions are gitignored to stay inside GitHub's free Git LFS quota (1 GB). Install them on every new checkout, and CI does the same:

```bash
tools/install_addons.sh          # binary add-ons only
tools/install_addons.sh --all    # reinstall every pinned add-on (to update a version, edit the pins in the script)
```

Project settings: **Jolt Physics** is the 3D physics engine; Godot's own `.blend` import is off (`filesystem/import/blender/enabled=false`) because we always export `.glb` from Blender ourselves.

**Later:** [GodotSteam](https://github.com/GodotSteam/GodotSteam) (MIT) for achievements and cloud saves, at milestone M4/M6 once there is a Steam app id.

## Desktop and pipeline tools

| Tool | Version | Licence | Where | Use |
| --- | --- | --- | --- | --- |
| Godot | 4.7.2 | MIT | `brew install --cask godot` | Engine |
| Blender | 5.2 LTS | GPL (tool) | `/opt/homebrew/bin/blender` | Modelling, rigging, animation; scripted with `blender -b -P` |
| MPFB 2 | 2.0.18 | GPL add-on; CC0 output from CC0 assets | Blender extension | Realistic base bodies (see `technical-design.md`) |
| MakeHuman system assets | CC0 pack | CC0 | MPFB user data | Bodies, eyes, brows, base clothes |
| Material Maker | 1.7 | MIT | `brew install --cask material-maker` | Procedural PBR materials (wet asphalt, rust, concrete) |
| Audacity | 4.0.1 | GPL (tool) | `brew install --cask audacity` | Voice and sound editing |
| Rhubarb Lip Sync | 1.14.0 | MIT | `~/Applications/Tools/Rhubarb-Lip-Sync-1.14.0-macOS/rhubarb` | Mouth shapes from voice audio; use `--recognizer phonetic` for Tanglish |
| MediaPipe | 1.1.1 | Apache-2.0 | `tools/.venv` (Python 3.12, gitignored) | Face landmarks for likeness fitting; Pose for motion capture from phone video |
| ffmpeg | 9.0.2 | LGPL/GPL (tool) | `brew install ffmpeg` | Audio filters (phone, radio, video call), encoding to Ogg |
| Piper TTS | 1.8.0 | GPL-3.0 (tool) | `tools/.venv` (`pip install piper-tts`) | **Placeholder** voice lines for timing; never shipped |
| Kokoro | 0.9.4 (model Kokoro-82M) | Apache-2.0 | `tools/.venv` + `tools/voice/models/kokoro/` (gitignored, ~319 MB) | **Default placeholder VO**; Hindi voices + `tools/voice/tanglish.py` phonemes for the Tamil family, English voices for others; never final VO |
| espeak-ng | latest | GPL (tool) | `brew install espeak-ng` | Fallback phonemes for Kokoro |
| Piper voice LibriTTS-R medium | — | CC BY 4.0 (dataset) | `tools/voice/models/` (gitignored, ~79 MB) | Multi-speaker placeholder voices, one speaker id per character |

Recreate the Python environment and download the MediaPipe models (`face_landmarker.task` 3.8 MB, `pose_landmarker_heavy.task` 30.7 MB, Apache-2.0) into `tools/likeness/models/`:

```bash
tools/setup_python_tools.sh
```

## Asset sources

- Sound effects: [Kenney](https://kenney.nl) Impact Sounds and Interface Sounds (CC0), in `game/audio/sfx/kenney/` with `SOURCES.md`.

- Textures: [Poly Haven](https://polyhaven.com) (CC0), [ambientCG](https://ambientcg.com) (CC0). Record each download in a `SOURCES.md` next to the files.
- Sounds: [Freesound](https://freesound.org), **CC0 filter only**.
- Never use assets whose licence forbids commercial use or use outside a specific engine.
