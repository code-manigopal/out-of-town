# Engine decision: Unreal Engine 5

**Decision:** Unreal Engine 5.5 or newer, C++ plus Blueprints.

## Why
| Need | Unreal Engine 5 | Unity 6 (HDRP) | Godot 4 |
| --- | --- | --- | --- |
| Realistic look like *Alan Wake 2* / *Hitman* | Lumen GI, Nanite, Virtual Shadow Maps, volumetric fog out of the box | Possible with HDRP, more setup | Not at this level yet |
| Realistic humans | **MetaHuman** (free) + MetaHuman Animator from an iPhone | Third-party | Third-party |
| Environments | Quixel Megascans free with UE, PCG for forests | Asset Store | Manual |
| Cinematics | Sequencer, Movie Render Queue | Timeline | Basic |
| Third-person stealth/shooter base | Third Person template, Motion Matching, GAS | Starter assets | Manual |
| Language | C++ (close to Java/C#) + Blueprints | C# (easiest for you) | GDScript / C# |
| Cost | Free until $1M gross revenue, then 5% | Free tier / seats | Free |

Unity would be easier to code (C#), but the target look and realistic people point to Unreal. Your Java/C# background transfers to UE C++ well, and Claude Code can write most of the boilerplate.

## Hardware guide
- GPU: RTX 3060 12 GB minimum for development, RTX 4070 or better recommended.
- 32 GB RAM (64 GB for big forest levels), NVMe SSD with 300 GB free.
- Windows 10/11, Visual Studio 2022 with "Game development with C++".

## Risks
- Large repo size: use Git LFS (set up in `.gitattributes`) and keep raw source art outside the repo if it gets big.
- C++ build times: keep gameplay code in one module until it hurts.
- Learning curve: start with the vertical slice in `docs/production/roadmap.md`, not the whole game.
