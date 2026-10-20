# game/ — Unreal Engine 5 project

`OutOfTown.uproject` is a C++ project for **Unreal Engine 5.5+**.

## First open

1. Right-click `OutOfTown.uproject` → **Generate Visual Studio project files**.
2. Open `OutOfTown.sln`, build **Development Editor | Win64**, press F5.
3. The editor creates any missing default config and engine content on first launch.

## What's here

| Path | Contents |
| --- | --- |
| `Source/OutOfTown/Story/OOTStorySubsystem` | Story state: flags, trust, danger, clues, Nila's health |
| `Source/OutOfTown/Story/OOTDialogueTypes.h` | DataTable row types for dialogue lines and choices |
| `Content/OutOfTown/` | Asset folders (empty, tracked with Git LFS) |

## Importing story data

1. Run `node tools/export_story.js` from the repo root.
2. In the editor, import `data/story/p1_lines.csv` as a DataTable using row struct `FOOTDialogueLine`, and `p1_choices.csv` using `FOOTChoice`. Same for Part 2.
3. Save as `Content/OutOfTown/Data/Dialogue/DT_P1_Lines` and so on.
