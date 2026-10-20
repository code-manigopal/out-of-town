# Technical design

## Project layout
- `game/project.godot` — Godot 4.7 project, GDScript only.
- `game/scripts/` — code by feature folder:

| Folder | Contents (now / planned) |
| --- | --- |
| `scripts/story/` | `story_state.gd` (autoload `StoryState`), `story_db.gd` (autoload `StoryDB`), `OOTDialogueLine` and other data classes |
| `scripts/dialogue/` | Dialogue player, subtitle data, radio audio processing — planned |
| `scripts/investigation/` | Inspectable node, journal, evidence board, puzzle base class — planned |
| `scripts/characters/` | Character base (`CharacterBody3D`), Mani/Preethi, AI enemies — planned |
| `scripts/stealth/` | Perception, suspicion meter, disguises, takedowns — planned |
| `scripts/combat/` | Weapons, ammo, grenades, health, medkits — planned |
| `scripts/save/` | Save and checkpoint helpers — planned |
| `ui/` | Control scenes and themes (`ui/dialogue/dialogue_test.tscn` is the dialogue test scene) |

Gameplay is built from scenes and nodes: one scene per character, level, prop and UI panel, with a script on the root node. Nodes talk through signals, not hard references.

## Story data pipeline
```
prototype/browser/*.js  ──node tools/export_story.js──▶  game/data/story/pN_scenes.json   (read by the game)
                                                         data/story/pN_lines.csv, pN_choices.csv   (spreadsheets / VO script only)
```
1. The browser prototype is the reference implementation of every scene.
2. `tools/export_story.js` writes, per part:
   - `game/data/story/pN_scenes.json`: every scene with place, time, lines, choices, puzzle, combat, episode-end, ending. Runtime-computed values are marked `dynamic`.
   - `data/story/pN_lines.csv` and `pN_choices.csv`: for spreadsheets and the VO script, not loaded by the game.
3. `StoryDB` reads `res://data/story/pN_scenes.json` directly. There is no import step.
4. Dynamic logic (conditions, effects, computed targets) is implemented in GDScript by reading the matching JS in the prototype.
5. Later: one `Resource` (`.tres`) per scene, or a dialogue plugin, if JSON becomes limiting.

## Asset pipeline (Blender → Godot)

- **Tool:** Blender 5.2 LTS, installed on the dev Mac (`/opt/homebrew/bin/blender`). Claude Code can drive it headless with Python: `blender -b -P tools/blender/<script>.py`.
- **Source files:** `.blend` files live in `art_source/<area>/` (Git LFS), mirroring the `game/` folders (e.g. `art_source/characters/mani/mani.blend`).
- **References:** approved character sheets in `docs/art/sheets/<character>/` are loaded as orthographic reference images (front, side, back) at real height (e.g. Mani 1.75 m).
- **Units and orientation:** metres, 1 unit = 1 m, +Y up in Godot (Blender's +Z up is converted by the glTF exporter). Model fronts point −Y in Blender, which exports as **+Z in Godot** (the glTF standard); rotate instances to face where they need to. Origins sit at the bottom centre (floor contact); wall-mounted pieces have their origin at their own bottom edge.
- **Export:** glTF binary (`.glb`) with applied transforms, into the matching `game/` folder (e.g. `game/characters/mani/mani.glb`). Commit the generated `.import` file.
- **Characters:** one shared humanoid skeleton for every character so animations retarget; mesh LODs for crowds.
- **Greybox first:** levels are blocked out with CSG in Godot, then replaced piece by piece with Blender assets.

## Story state
`StoryState` (autoload, `res://scripts/story/story_state.gd`) holds part id, flags, trust, danger, clues/proof and Nila's health. It mirrors the browser prototype's state model; do not invent a parallel one. It emits `clue_added` and `danger_changed` signals for UI. Saves are JSON written to `user://save_<slot>.json` containing this state plus the current scene and level.

## Engine systems
| Need | Godot approach |
| --- | --- |
| Level scripting | Scenes + nodes, signals, `Area3D` triggers, GDScript |
| Player and enemy movement | `CharacterBody3D` |
| Character animation | `AnimationTree` with state machine and blend spaces; locomotion clips shared via a common skeleton |
| Cinematics and cutscenes | `AnimationPlayer` (camera, character, audio, method-call tracks) |
| AI navigation | `NavigationServer3D` / `NavigationAgent3D`; perception via `Area3D` and raycasts |
| Abilities and stats | Plain GDScript components and `Resource` data, no framework |
| UI | `Control` nodes with themes |
| VFX | `GPUParticles3D`, shaders, `FogVolume` |
| Audio | Audio buses (radio, phone and tape get effect buses) |

## Localisation
- All player-facing text lives in the JSON data and is shown via Godot's translation system (`tr()` / CSV or PO files) when more languages are added.
- Spoken language: Tanglish (family) and English (others). Every line has an English subtitle. Subtitles in English first; more languages later.
- Voice-over folders: `res://audio/vo_tanglish/`, `res://audio/vo_english/`.

## Rendering defaults
Forward+ renderer, SDFGI or VoxelGI for global illumination, volumetric fog for Greyhaven, shadow-mapped directional and spot lights, SSR and SSAO. Snow and breath VFX for Red Lake. See `docs/tech/engine-decision.md` for the realism plan.

## Testing
- `node tools/validate_prototype.js` in CI on every push and PR (`.github/workflows/prototype-check.yml`).
- Game tests: `godot --headless --path game --script res://tests/run_tests.gd` (story state, scene data links, saves).
