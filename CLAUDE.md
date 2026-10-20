# CLAUDE.md — Out of Town

Instructions for Claude Code working in this repository. Read this before making changes.

## Working rules (read first)

The goal is the best result for the fewest usage credits and tokens.

1. Delegate large, parallel, or search-heavy work to sub-agents (broad codebase sweeps, independent
   multi-file changes, long research). Do small, targeted edits directly. A sub-agent starts cold and
   re-reads context, so it costs more than it saves on a small task.
2. Give sub-agents the lightest model that can do the job: Haiku for simple lookups, searches, and
   mechanical edits; Sonnet for routine coding; the main model only for design and hard debugging.
3. Keep context lean: read only the parts of files you need, give sub-agents a self-contained brief,
   and ask them to return conclusions, not file dumps.
4. Run independent sub-agents in parallel: launch them all in one message, and never let two of them
   edit the same file. Shared files (config, catalogs, docs) are edited only by the main agent.
5. Each brief says: the goal, the files it may edit, what it must not touch (no commits, no secrets,
   no real external APIs), and what to return (changes made, test result, open questions, in a few lines).
6. The main agent checks every sub-agent's result itself, runs the full tests once at the end, and
   makes the single commit. A sub-agent's report is a claim, not proof.

## What this project is

**Out of Town** is a realistic, cinematic third-person thriller for PC (Steam), episodic like *Alan Wake* and with sandbox stealth/aggression like *Hitman*. Two parts are written (8 episodes each); a third is hooked.

- **Part 1 — Greyhaven:** Mani (29) drives from Windsor to a fog-bound lake town; his sister Nila (25), a radio host with a criminology degree, is missing. Victor Kessler runs a fentanyl lab and exotic-animal smuggling ring behind a closed paper mill. Five endings.
- **Part 2 — Red Lake:** Nila is dying of HX-7, a poison Hades (Mark Hayden) gave her. Mani and his wife Preethi drive five days north to take the cure from the Hades Mansion. Two playable characters; Nila guides them by radio.

## Sources of truth (in priority order)

1. `docs/story/` — **canon.** The screenplays decide names, events, dialogue, timeline. Do not contradict them. If code or design conflicts with canon, flag it; don't silently change the story.
2. `docs/design/game-design-document.md` — systems and mechanics.
3. `docs/tech/technical-design.md` — engine architecture and conventions.
4. `prototype/browser/` — the playable reference implementation of every scene, choice, puzzle and ending.

## Story rules that must never break

- **Names are fictional where real ones were replaced:** Auragle (Mani's ex-employer), Sri Valli Leathers in Ranipet (family business), Tom Portons (coffee chain), Greyhaven and Lake Merrow (fictional town), Northstar Biologics, Hayden Deep Mine, the Burn, the Hades Mansion, the Smoke. Real places (Windsor, Leamington, Sudbury, Wawa, White River, Thunder Bay, Ignace, Dryden, Ear Falls, Red Lake, Balmertown, Cochenour, McKenzie Island, Madsen, Starratt-Olsen) are backdrops only. **No crime ever happens at a real named business or institution.** Spirit Rock is sacred to the Oji-Cree: one respectful moment only, never a crime site.
- **Language:** Mani, Nila, Amma, Appa and Preethi speak **Tanglish** to each other. Every spoken line gets an English subtitle, including lines already in English. In data, Tanglish lines carry both `text` and `subtitle`.
- **Hades = Mark Hayden** — but Part 1 never connects the two on screen. In Part 1 Hades is only a silhouette in a long coat, a voice on the radio, and a codename. "Mark Hayden" appears only on paper (plaque, manifest, ledger) or in passing.
- **Every Part 1 ending** must leave: Nila alive and exposed to the lake water and the Pike Point bottles; Victor dead, shot by Hades; Hades escaped; the siblings home in Windsor.
- **Mani never takes a life in Part 1.** His last revolver round stays in the cylinder.
- **Guns in Part 2 are illegal**, bought from Rocco Delisle under the Ambassador Bridge; Nila plans the deal. Grenades are never bought, only taken from enemies.
- Ages: Mani 29 (Part 1) / 30 (Part 2), Nila 25 / 26, Preethi 27.

## Engine and code

- **Godot 4.7+, GDScript** with static typing. Project at `game/project.godot`. (Switched from Unreal Engine 5 on 2026-10-20; see `docs/tech/engine-decision.md`.)
- Follow the Godot style guide and `docs/tech/coding-standards.md`: snake_case files, folders, functions and variables; PascalCase node names and `class_name`; global `class_name`s use the `OOT` prefix (`OOTDialogueLine`).
- **Blender 5.2** (installed at `/opt/homebrew/bin/blender`) is the modelling tool: characters from the approved sheets in `docs/art/sheets/`, environments and props. Export glTF (`.glb`) into the matching `game/` folder; Blender source files (`.blend`) go in `art_source/` (Git LFS). Scripted work runs headless: `blender -b -P script.py`.
- Story state (flags, trust, danger, clues/proof, Nila's health) lives in the `StoryState` autoload (`res://scripts/story/story_state.gd`). Mirror the prototype's state model; don't invent a parallel one.
- Dialogue and scene data are read directly from `game/data/story/pN_scenes.json` by the `StoryDB` autoload. Don't hard-code dialogue in scenes or scripts.
- `.tscn` and `.tres` are text and may be edited carefully. **Never hand-edit binary assets** (`.glb`, textures, audio); they are tracked with Git LFS. Commit `*.import` files.
- Don't commit `game/.godot/` or export builds (see `.gitignore`).

## Game commands

```bash
godot --path game -e                                              # open the editor
godot --headless --path game --import                             # import assets; must finish without script errors
godot --headless --path game --script res://tests/run_tests.gd    # story/state tests (exit 1 on failure)
```

## Prototype commands

```bash
node tools/validate_prototype.js        # every scene link, condition and puzzle target must resolve (exit 1 on error)
node tools/export_story.js              # writes game/data/story/pN_scenes.json and data/story/pN_lines.csv, pN_choices.csv
cd prototype/browser && python3 -m http.server 8000
```

After changing anything under `prototype/browser/`, run the validator (it must report `errors 0`), then re-export the story and run the game tests.

## How to work here

- Keep changes small and targeted; don't rewrite working systems.
- Explain the approach before large changes, and ask before changing canon.
- When adding a scene, follow the existing data format (see `prototype/browser/p1e1.js`), give it an `ep`, `place` and `time`, and make sure it is reachable.
- When writing dialogue, keep each character's voice: Nila is quick, funny, sharp; Mani is careful and dry; Preethi is calm and precise; Victor is warm and menacing; Hades is soft, patient and never hurried.
- Current milestone: see `docs/production/roadmap.md`.
