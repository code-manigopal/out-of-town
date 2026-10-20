# CLAUDE.md — Out of Town

Instructions for Claude Code working in this repository. Read this before making changes.

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

- **Unreal Engine 5.5+**, C++ for systems, Blueprints for level scripting and UI. Project at `game/OutOfTown.uproject`.
- C++ classes use the `OOT` prefix (`UOOTStorySubsystem`, `FOOTDialogueLine`). Module API macro: `OUTOFTOWN_API`.
- Follow Epic's coding standard and the asset naming table in `docs/tech/coding-standards.md` (`BP_`, `SM_`, `SK_`, `T_`, `M_`, `MI_`, `ABP_`, `WBP_`, `DT_`, `LS_`, `L_`).
- Story state (flags, trust, danger, clues/proof) lives in `UOOTStorySubsystem` (a GameInstance subsystem). Mirror the prototype's state model; don't invent a parallel one.
- Dialogue and scene data come from DataTables built from `data/story/*.json`. Don't hard-code dialogue in Blueprints.
- **Never hand-edit `.uasset` or `.umap` files as text.** They are binary and tracked with Git LFS.
- Don't commit `Binaries/`, `Intermediate/`, `Saved/`, `DerivedDataCache/`, `.vs/` (see `.gitignore`).

## Build commands (Windows)

```bat
:: Generate project files
"%UE5_ROOT%\Engine\Build\BatchFiles\Build.bat" -projectfiles -project="%CD%\game\OutOfTown.uproject" -game -engine

:: Build the editor target
"%UE5_ROOT%\Engine\Build\BatchFiles\Build.bat" OutOfTownEditor Win64 Development -Project="%CD%\game\OutOfTown.uproject" -WaitMutex
```

## Prototype commands

```bash
node tools/validate_prototype.js        # every scene link, condition and puzzle target must resolve (exit 1 on error)
node tools/export_story.js              # writes data/story/pN_scenes.json, pN_lines.csv, pN_choices.csv
cd prototype/browser && python3 -m http.server 8000
```

After changing anything under `prototype/browser/`, run the validator. It must report `errors 0`.

## How to work here

- Keep changes small and targeted; don't rewrite working systems.
- Explain the approach before large changes, and ask before changing canon.
- When adding a scene, follow the existing data format (see `prototype/browser/p1e1.js`), give it an `ep`, `place` and `time`, and make sure it is reachable.
- When writing dialogue, keep each character's voice: Nila is quick, funny, sharp; Mani is careful and dry; Preethi is calm and precise; Victor is warm and menacing; Hades is soft, patient and never hurried.
- Current milestone: see `docs/production/roadmap.md`.
