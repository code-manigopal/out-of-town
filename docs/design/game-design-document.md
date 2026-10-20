# Game Design Document — Out of Town

## 1. Vision
A realistic, cinematic third-person thriller about an ordinary man (and later his wife) pulled into something much bigger every time they leave town. **Alan Wake** for atmosphere, episodic structure and dread. **Hitman** for sandbox levels where stealth and aggression are both valid. Grounded: no superpowers, no ghosts confirmed.

## 2. Pillars
1. **Family first.** Every scene is about getting someone home. The Tanglish family voice is the heart.
2. **Think before you shoot.** Mani is an analyst; investigation and puzzles are as important as combat. In Part 1 he never kills.
3. **Small towns, big shadows.** Real Ontario backdrops, fictional crimes, fog and snow.
4. **Choices that stick.** Trust, proof and danger carry across episodes and decide endings.
5. **Episodic cliffhangers.** Eight ~40-minute episodes per part, each ending on a hook.

## 3. Target
- PC (Windows), Steam. Controller and keyboard/mouse.
- 3D runtime: about 5 to 6 hours per part (browser prototype is 3.5 to 4).
- Rating target: Mature (violence, drugs, language).

## 4. Core loop
Explore → talk → investigate (find clues) → solve (puzzle) → set piece (stealth / chase / fight / dive) → choice → cliffhanger.

## 5. Systems
All state mirrors the browser prototype (`prototype/browser/engine.js`) and lives in the `StoryState` autoload.

| System | Rules |
| --- | --- |
| **Flags** | Named booleans set by choices and events. Gate dialogue, choices and endings. |
| **Trust** | Per character, −3 to +3. Changed by choices. Gates allies' help and endings. |
| **Danger** | 0 to 5. How much the town (Part 1) or Kane's men (Part 2) notice you. Raises patrols, changes dialogue. |
| **Journal** | Clues and proofs. Proof count decides the Part 1 broadcast quality and endings. |
| **Nila's health** | Part 2 only, 0 to 100. Falls every episode; low values change her radio lines and the ending scene. |
| **Choices** | Timed or untimed. Locked choices show why ("Needs: the ledger"). Some are one-time. |
| **Saves** | Auto-save at every scene; manual checkpoints at episode starts. Failing a set piece restarts it, never an ending. |

### Narration
- **No narrator.** No third-person voice; Mani does not narrate. Story comes from five layers: Nila's voice (voicemail, broadcasts, memos, tapes; Lighthouse in Part 2), Mani's inner voice (inspect lines and deductions only), the world (notes, plaques, photos, papers), the journal (Mani's short notes and current goal), and the episode frame (place/time cards, title, "Previously on", cliffhanger).
- **Mani's inner voice:** one or two dry sentences, English by default and Tanglish about family, italic subtitles with no speaker frame, channel `thought` in the story data. It reacts to what the player inspects or connects; it never explains the plot or solves a puzzle. In Part 2, Nila does the deductions on the radio and his inner voice gets rarer.
- **"Previously on":** Part 1 replays real lines through radio static; Part 2 is a Lighthouse recap.
- Details and Ep 1 examples: `docs/design/ep01-county-roads.md`, sections 11–12.

### Dialogue and subtitles
- Speaker, channel (in person, radio, phone, voicemail, on air, tape) and English subtitle on every line.
- Radio lines are processed (band-pass, static) and shown with a radio icon. Part 2 radio call signs: LIGHTHOUSE, ANNA, ANNI.
- Choice wheel with a short spoken line and a subtitle describing intent.

### Investigation
- Inspect mode: examine objects, rotate them, find hidden details (photo backs, labels, serials).
- Evidence board in the journal: link clues to unlock deductions (Nila's criminology voice comments).
- Puzzle types from the prototype: **code**, **pick**, **multi-select**, **order**, **search**, **radio tune**. Each becomes a diegetic 3D interaction (keypad, radio dial, filing cabinet, map pins).

### Radio
- Part 1: Nila's ham broadcasts at 7.185 MHz, the Listener's voice, the jamming.
- Part 2: always-on radio link to Nila. She gives routes, profiles enemies, warns of patrols. Signal drops in mines and deep forest.

### Stealth and aggression (Hitman-like)
- Every combat space can be crossed quietly or loudly. The prototype's turn-based "stealth / aggressive" fights become real-time.
- **Stealth:** crouch, cover, distractions (throw objects, radio noise), non-lethal takedowns (Part 1 only option for Mani), hide bodies, suspicion meters on enemies, disguises in Part 2 (Northstar coveralls, Kane's men's parkas).
- **Aggressive:** cover shooting, weapon swap (M4 / shotgun / Desert Eagle), grenades taken from enemies, limited ammo and medkits in the car trunk.
- Part 2 co-op split: player switches between Mani and Preethi; Preethi is the marksman and medic.
- Part 1: Mani gets a revolver in Ep 5 and never kills. Fights are escapes, shoves, distractions.

### Atmosphere (Alan Wake-like)
- Light and dark: fog, sodium lamps, flashlights, flares, headlights.
- The watcher in the long coat appears at the edge of the frame in every Part 1 episode.
- Weather as a character: fog in Greyhaven, snow and −30 °C in Red Lake (cold affects stamina and aim if exposed too long).

## 6. Camera and controls
- Third-person over-the-shoulder, cinematic camera in key scenes (AnimationPlayer cutscenes).
- Driving sections in Part 1 Ep 1 and Part 2 Ep 1–2: simple third-person car, radio in the car, stops at Tom Portons.
- Walk, jog, crouch; no sprint-everywhere. Interactions on one button.

## 7. Episode and level list

### Part 1 — Greyhaven
| Ep | Title | Main spaces | Set piece |
| --- | --- | --- | --- |
| 1 | County Roads | Windsor apartment, Highway 3 / county roads, two Tom Portons, Lakeview Motel | Night arrival, empty flat |
| 2 | Dead Air | Nila's flat, sheriff's office, 94.1 FM station, diner | Station break-in for the tape |
| 3 | Low Water | Marsh house, docks, water tower | Night boat to the mill pier |
| 4 | The Mill | Merrow Paper Mill: pulping hall lab, boiler house animals | Stealth through the mill |
| 5 | The Badge | Clinic, deputy's house, sheriff's office | The drawer, first gun |
| 6 | Old Merrow | St. Brendan's, the dam, the drowned village | The dive |
| 7 | Pike Point | Jonah's tower and shed | Finding Nila; tower climb |
| 8 | Daybreak | Pike Point, the lake, Greyhaven | Siege, broadcast, Victor's death |

### Part 2 — Red Lake
| Ep | Title | Main spaces | Set piece |
| --- | --- | --- | --- |
| 1 | Lighthouse | Windsor hospital, under the Ambassador Bridge, shops, Greyhaven mill ruins, Sudbury, Wawa | Gun buy; the mill at night |
| 2 | Highway 17 | White River, Thunder Bay, Dryden, Highway 105 | First grenade case from Kane's truck |
| 3 | Gold Country | Northern Star Motel, hospital (backdrop), Heritage Centre, Balmertown | Mineral sample puzzle |
| 4 | The Ice Road | Cochenour, McKenzie Island, ice road | Night crossing |
| 5 | Hayden Deep | Madsen, Hayden Deep Mine (fictional) | Infiltration, the lab |
| 6 | Starratt-Olsen | Ghost town, floatplane | Ambush and rescue |
| 7 | The Burn | 400 km² private forest | Stealth/aggressive split fight; Kane dies |
| 8 | The Hades Mansion | Mansion, conservatories, enclosures, the Smoke | Animals, three-vial puzzle, Hades |

## 8. Endings
- Part 1: Daybreak, Out of the Fog, Wrong Hands, Silent Water, Lamplight (hidden). See `docs/story/part1-greyhaven-screenplay.md`.
- Part 2: one ending plus variations by trust, proof and Nila's health. Pongal epilogue, Part 3 hook.
- Endings carry over: Part 1's ending sets Part 2 starting details (file kept or traded, Ivy already known, mill guarded or not).

## 9. Accessibility
Subtitles always on by default (size, background), colour-blind safe UI, hold/toggle options, skippable timed choices, difficulty for combat separate from puzzles, remappable controls.
