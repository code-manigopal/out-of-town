# Out of Town

A cinematic, story-driven third-person thriller for PC, in the spirit of *Alan Wake* (atmosphere, episodic story, a light in the dark) and *Hitman* (stealth or aggression, disguises, sandbox levels). Planned for release on Steam.

Mani and his sister Nila came from Vellore, India, to build new lives in Canada. Every time they leave town, something is waiting for them.

| Part | Title | Setting | Status |
| --- | --- | --- | --- |
| 1 | **Out of Town: Greyhaven** | A fog-bound Ontario lake town. A drowned village, a drug lab, a smuggling ring, and the man who listens. | Screenplay done · browser prototype done |
| 2 | **Out of Town: Red Lake** | Five days north to a gold-mining town at the end of the road. A dying sister, a cure, the Hades Mansion. | Screenplay done · browser prototype done |
| 3 | *To be announced* | Robert Hayden. | Hook written |

## Repository map

```
out-of-town/
├── CLAUDE.md               Instructions for Claude Code (read first)
├── docs/
│   ├── story/              Canon: screenplays, story plan, story bible
│   ├── design/             Game design document, level and episode breakdowns
│   ├── tech/               Engine decision, technical design, coding standards
│   ├── art/                Art direction, character sheet prompts, asset list
│   └── production/         Roadmap and milestones
├── game/                   Unreal Engine 5 project (OutOfTown.uproject)
│   ├── Config/
│   ├── Source/OutOfTown/   C++ gameplay code (story state, dialogue types)
│   └── Content/OutOfTown/  Assets (tracked with Git LFS)
├── prototype/browser/      Playable HTML prototype of Parts 1 and 2 (the story reference build)
├── data/story/             Story data exported from the prototype, for import into the engine
├── tools/                  Validation and export scripts
└── .github/                Issue templates, PR template, CI
```

## Getting started

### 1. Clone with Git LFS

Game assets (`.uasset`, `.umap`, textures, audio, video) are stored with [Git LFS](https://git-lfs.com).

```bash
git lfs install
git clone <this-repo-url> out-of-town
cd out-of-town
git lfs pull
```

### 2. Play the prototype

The browser prototype is the playable reference for story, choices, puzzles and endings.

```bash
cd prototype/browser
python3 -m http.server 8000
# open http://localhost:8000
```

Validate every scene link and dynamic condition:

```bash
node tools/validate_prototype.js
```

### 3. Open the Unreal project

1. Install **Unreal Engine 5.5 or newer** from the Epic Games Launcher, and **Visual Studio 2022** with the "Game development with C++" workload.
2. Right-click `game/OutOfTown.uproject` → **Generate Visual Studio project files**.
3. Open `game/OutOfTown.sln`, build **Development Editor / Win64**, then run.
4. If you use a different engine version, change `EngineAssociation` in `OutOfTown.uproject` (or right-click → Switch Unreal Engine version).

See [`docs/tech/engine-decision.md`](docs/tech/engine-decision.md) for why Unreal Engine 5.

## Working with Claude Code

Open the repository root in Claude Code. It reads [`CLAUDE.md`](CLAUDE.md) automatically. Custom commands live in `.claude/commands/`:

| Command | What it does |
| --- | --- |
| `/story-check` | Checks a change against the canon in `docs/story/` (names, timeline, Tanglish and subtitles, Hades rules) |
| `/new-scene` | Adds a new scene to the prototype in the existing data format and validates it |
| `/export-story` | Exports prototype scenes to `data/story/*.json` for Unreal DataTables |

## Language

Family conversations (Mani, Nila, Amma, Appa, Preethi) are in **Tanglish**. Every line of dialogue in the game shows an English subtitle, English lines included.

## License

All rights reserved. See [`LICENSE.md`](LICENSE.md).
