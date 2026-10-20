# Engine decision: Godot 4.7 + GDScript

**Decision:** Godot 4.7 (Forward+ renderer), GDScript for all game code.

## Why
| Need | Godot 4.7 | Unreal Engine 5 | Unity 6 (HDRP) |
| --- | --- | --- | --- |
| Works well on a Mac (Apple Silicon) | Native editor, light, fast start | Heavy on Mac; long shader and build times | Good, HDRP is heavy |
| Cost | Free, MIT licence, no revenue share | Free until $1M gross, then 5% | Free tier / seats |
| Iteration speed | Seconds; scripts and scenes reload instantly | Slow compiles and shader builds | Moderate |
| Files Claude Code can edit | `.tscn`, `.tres`, `.gd` are text and diff well | `.uasset`/`.umap` are binary | Scenes are YAML, noisy diffs |
| Realistic look like *Alan Wake 2* / *Hitman* | Possible with effort: SDFGI/VoxelGI, volumetric fog, SSR | Lumen, Nanite, Virtual Shadow Maps out of the box | Possible with HDRP, more setup |
| Realistic humans | No MetaHuman; Character Creator 4 or Blender, imported as glTF | MetaHuman (free) | Third-party |
| Environments | Poly Haven, ambientCG, Fab (licence permitting) | Megascans, PCG | Asset Store |
| Cinematics | AnimationPlayer, cameras, `Marker`/call tracks | Sequencer, Movie Render Queue | Timeline |
| Language | GDScript (Python-like, quick to learn) | C++ + Blueprints | C# |

## Honest trade-offs
- **Gained:** a smooth Mac workflow, no royalty, very fast iteration, and a project that is almost all text, so Claude Code can write and review scenes, scripts and data directly.
- **Lost:** the out-of-the-box realism ceiling of Unreal (no MetaHuman, Nanite or Megascans). The realistic target in `docs/art/art-direction.md` stays; reaching it takes more lighting and asset work.

## Mitigation for the realistic look
Forward+ renderer; SDFGI or baked VoxelGI/LightmapGI for indirect light; volumetric fog (central to Greyhaven); careful lighting and colour grading per `docs/art/art-direction.md`; good photo-scanned assets from Poly Haven/ambientCG/Fab; tight, small levels instead of open worlds; film grain and depth of field used sparingly.

## Previous decision
Unreal Engine 5.5 (C++ plus Blueprints) was chosen first. We switched on 2026-10-20 because development happens on a Mac and Godot iterates faster. The Unreal skeleton is kept in git history (first commit `656f514`).

## Hardware guide
- Development: Apple Silicon Mac (M1 Pro or better, M2/M3 recommended), 16 GB RAM minimum (32 GB for big scenes), 100 GB free SSD.
- Export testing: a Windows 10/11 PC with an RTX 3060 or better (the Steam target), and optionally a Linux box or the Steam Deck for the Linux build.
- Godot 4.7 stable from godotengine.org; no IDE required (the built-in editor or VS Code with a GDScript extension).

## Risks
- **Realism ceiling:** test the look early with the vertical slice; keep the option of upgrading rendering as Godot improves.
- **Character pipeline:** no MetaHuman equivalent. Facial animation and lip-sync need a CC4 or Blender workflow and a shared skeleton so animations can be retargeted.
- **Large repo:** keep using Git LFS for binary assets (`.gitattributes`); do not commit `.godot/`.
- **Smaller ecosystem:** fewer ready-made stealth/combat systems; we build them in GDScript.
- **Learning curve:** start with the vertical slice in `docs/production/roadmap.md`, not the whole game.
