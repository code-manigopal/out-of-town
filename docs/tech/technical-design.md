# Technical design

## Project layout
- `game/OutOfTown.uproject` — single runtime module `OutOfTown`.
- `game/Source/OutOfTown/` — C++ by feature folder:

| Folder | Contents (now / planned) |
| --- | --- |
| `Story/` | `UOOTStorySubsystem` (state), `OOTDialogueTypes.h` (DataTable rows) — **exists** |
| `Dialogue/` | Dialogue player component, subtitle widget data, radio audio processing — planned |
| `Investigation/` | Inspectable component, journal, evidence board, puzzle base class — planned |
| `Characters/` | `AOOTCharacter` base, Mani/Preethi, AI enemies — planned |
| `Stealth/` | Perception, suspicion meter, disguises, takedowns — planned |
| `Combat/` | Weapons, ammo, grenades, health, medkits — planned |
| `Save/` | `UOOTSaveGame`, checkpoint system — planned |
| `UI/` | CommonUI widgets base classes — planned |

## Story data pipeline
```
prototype/browser/*.js  ──node tools/export_story.js──▶  data/story/*.json + *.csv  ──import──▶  DT_P1_Lines, DT_P1_Choices …
```
1. The browser prototype is the reference implementation of every scene.
2. `tools/export_story.js` writes, per part:
   - `pN_scenes.json`: every scene with place, time, lines, choices, puzzle, combat, episode-end, ending. Runtime-computed values are marked `dynamic`.
   - `pN_lines.csv` → DataTable of `FOOTDialogueLine`.
   - `pN_choices.csv` → DataTable of `FOOTChoice`.
3. Dynamic logic (conditions, effects, computed targets) is implemented in C++/Blueprint by reading the matching JS in the prototype.
4. Later: a `UOOTSceneAsset` (Primary Data Asset) per scene, or a dialogue plugin, if DataTables become limiting.

## Story state
`UOOTStorySubsystem` (GameInstance subsystem) holds part id, flags, trust, danger, clues, Nila's health. It broadcasts `OnClueAdded` and `OnDangerChanged` for UI. A save game serialises this struct plus current scene and level.

## Localisation
- All player-facing text is `FText` in DataTables (gatherable by the Localization Dashboard).
- Spoken language: Tanglish (family) and English (others). Subtitles in English first; more languages later.
- Voice-over folders: `Audio/VO_Tanglish`, `Audio/VO_English`.

## Rendering defaults
Lumen GI and reflections, Virtual Shadow Maps, Nanite, DX12 (see `game/Config/DefaultEngine.ini`). Volumetric fog for Greyhaven; snow and breath VFX for Red Lake.

## Testing
- `node tools/validate_prototype.js` in CI on every push and PR (`.github/workflows/prototype-check.yml`).
- Later: UE automation tests for the story subsystem (`Story.*`), run from the editor's Session Frontend.
