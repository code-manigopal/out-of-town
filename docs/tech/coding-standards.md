# Coding standards

## C++
- Follow the [Epic C++ Coding Standard](https://dev.epicgames.com/documentation/en-us/unreal-engine/epic-cplusplus-coding-standard-for-unreal-engine).
- Prefix project types with `OOT`: `UOOTStorySubsystem`, `AOOTCharacter`, `FOOTDialogueLine`, `EOOTChannel`.
- Export macro: `OUTOFTOWN_API`. Log category: `LogOutOfTown`.
- Tabs for indentation, braces on their own line, `bIsSomething` for booleans.
- Expose to Blueprint with `UFUNCTION(BlueprintCallable/BlueprintPure, Category = "Story|...")`.
- No dialogue or story text hard-coded in C++ or Blueprints; it comes from DataTables.

## Asset naming
| Prefix | Asset type | Example |
| --- | --- | --- |
| `BP_` | Blueprint | `BP_Mani` |
| `SM_` | Static mesh | `SM_TomPortons_Cup` |
| `SK_` | Skeletal mesh | `SK_Victor` |
| `T_` | Texture | `T_Fog_Noise` |
| `M_` | Material | `M_LakeWater` |
| `MI_` | Material instance | `MI_LakeWater_Polluted` |
| `ABP_` | Animation Blueprint | `ABP_Mani` |
| `AM_` | Animation montage | `AM_Takedown` |
| `WBP_` | Widget Blueprint | `WBP_Subtitles` |
| `DT_` | DataTable | `DT_P1_Lines` |
| `DA_` | Data asset | `DA_Scene_e1_open` |
| `LS_` | Level sequence | `LS_P1E1_Voicemail` |
| `L_` | Level / map | `L_P1_Greyhaven` |
| `SC_` / `SW_` | Sound cue / wave | `SC_Radio_Static` |
| `NS_` | Niagara system | `NS_Snow` |

Map naming: `L_<Part>_<Place>`, e.g. `L_P1_Mill`, `L_P2_TheBurn`.

## Folders
Everything project-made lives under `Content/OutOfTown/` (see the folder tree). Marketplace and Megascans content stays in its own top-level folders and is not edited in place.

## Git
- Branches: `main` (always opens), `feature/<short-name>`, `story/<short-name>` for canon changes.
- Small PRs; fill in the PR template; CI must pass.
- Commit messages: imperative, short ("Add suspicion meter to patrol AI").
- Binary assets go through Git LFS (`.gitattributes`). Lock binary files you're editing if you work with others: `git lfs lock <file>`.
- Never commit `Binaries/`, `Intermediate/`, `Saved/`, `DerivedDataCache/`.
