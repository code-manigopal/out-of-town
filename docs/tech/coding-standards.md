# Coding standards

## GDScript
- Follow the official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).
- Files, folders, functions, variables: `snake_case` (`story_state.gd`, `add_clue()`).
- Node names and `class_name`: `PascalCase` (`DialoguePanel`).
- Constants and enum values: `CONSTANT_CASE`.
- Use static typing everywhere: `var trust: int = 0`, `func add_clue(id: String) -> void:`.
- Signals are named in the past tense: `clue_added`, `danger_changed`, `dialogue_finished`.
- Private members start with `_`.
- Global `class_name`s keep the `OOT` prefix: `OOTDialogueLine`, `OOTChoice`.
- Tabs for indentation.
- No dialogue or story text hard-coded in scripts or scenes; it comes from `res://data/story/*.json`.

## Asset organisation
Folders under `res://`, no prefix table:

| Folder | Contents |
| --- | --- |
| `characters/` | Character models, rigs, materials, one subfolder per character |
| `environments/` | Level geometry, modular kits, per-location assets |
| `props/` | Props |
| `vehicles/` | Cars, boat, floatplane, snowmobiles |
| `weapons/` | Revolver, rifles, grenades and so on |
| `animals/` | Snakes, frogs, wolves and so on |
| `vfx/` | Particles, shaders, fog and snow effects |
| `materials/` | Shared materials and textures |
| `audio/` | `music/`, `sfx/`, `vo_english/`, `vo_tanglish/` |
| `ui/` | Control scenes, themes, fonts (`ui/dialogue/` for dialogue) |
| `cinematics/` | AnimationPlayer cutscene scenes |
| `scenes/` | Levels and main scenes |
| `scripts/` | GDScript code by feature |
| `tests/` | Test scripts (`run_tests.gd`) |
| `data/story/` | Exported story JSON |

Asset names are `snake_case`, with a type suffix where it helps: `mani_body.glb`, `motel_wall_albedo.png`, `motel_wall_normal.png`, `lake_water.tres`, `radio_static.ogg`. Level scenes: `<part>_<place>.tscn`, e.g. `p1_mill.tscn`, `p2_the_burn.tscn`.

## Files
- Never hand-edit binary assets (`.glb`, `.png`, `.ogg`, `.blend`).
- `.tscn` and `.tres` are text and may be edited carefully; keep node paths and `ext_resource` ids intact, and open the project afterwards to check it loads.
- Commit `*.import` files next to their assets.
- Do not commit `.godot/` (see `.gitignore`).

## Git
- Branches: `main` (always opens), `feature/<short-name>`, `story/<short-name>` for canon changes.
- Small PRs; fill in the PR template; CI must pass.
- Commit messages: imperative, short ("Add suspicion meter to patrol AI").
- Binary assets go through Git LFS (`.gitattributes`). Lock binary files you're editing if you work with others: `git lfs lock <file>`.
