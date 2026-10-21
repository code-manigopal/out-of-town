# Episode 1 — County Roads: walkthrough design

The vertical slice (roadmap **M2**). Target length **35 minutes** for a first-time player who looks around, about 20 for a speedrun. Canon is `docs/story/part1-greyhaven-screenplay.md` (Episode 1, scenes 1–10); the prototype scenes are `e1_*` in `game/data/story/p1_scenes.json`. Nothing here changes the story. Items marked *(design)* are game-design choices that can change.

## 1. What this episode has to do

- **Teach the verbs** with zero threat: walk, look, inspect, journal, choose, accuse, drive, tune the radio.
- **Make the player love Nila** before they ever meet her: her voice, her things, her people.
- **Plant three shadows**: Victor's warmth, the cooler with something coiled inside, the man in the long coat at the far pump.
- **Go from daylight to fog.** The episode starts in a bright Windsor morning and ends in the dark motel lot with a voice on the radio. The light is the difficulty curve.

**Alan Wake rules we borrow** *(design)*: a guided path through hand-built spaces (not open world); light and darkness as the mood; diegetic media (radio, TV, phone) carrying story; an episode title card and an ending hook; small optional discoveries everywhere. **What we don't borrow in Ep 1**: combat, enemies, a flashlight fight. There is no fail state in Episode 1.

## 2. Player verbs

| Verb | Input | Ep 1 use |
| --- | --- | --- |
| Walk / jog | stick / WASD, hold to jog | Jog only outdoors *(design)*; walk indoors. No sprint. |
| Look | mouse / right stick | Over-the-shoulder camera. |
| Interact | one button (E / A) | Pick up, open, talk, sit in car. A soft dot appears on interactables within 2 m. |
| Inspect | interact on an inspectable | Object fills the screen; rotate it; a hotspot on it may add a clue. |
| Journal | Tab / View | Nila's-notebook-style clue list (Ep 1: Victor's card, the boot print, the caller notes). |
| Dialogue choice | 2–4 options | Spoken Tanglish/English line + intent subtitle; locked options show why. |
| Accuse | inside a mystery | Pick the culprit from the people in the room; wrong picks get a gentle "think again" and cost nothing. |
| Drive | throttle, brake, steer | Simple arcade handling; can't crash out of the game. |
| Radio | scroll / D-pad | Tune the car radio; 94.1 is a dial position. |
| Phone | hold Q / LB | Read texts when the car is stopped. |

## 3. Beat chart

| # | Beat | Prototype scenes | Space | Gameplay | Time | State |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Cold open: the voicemail | `e1_open` | black screen | Audio only, subtitles. Title card. | 1:00 | — |
| 2 | Packing | `e1_apt` | Mani's apartment | Free explore. Pack the sweets, diyas, gift radio (search puzzle). Optional inspects: whiteboard, graduation photo, Nila's broadcast photo. | 4:00 | — |
| 3 | Video call | `e1_call`, `e1_call2` | apartment, laptop | Laptop rings. Seated call with Amma and Appa. Honesty choice. Amma's Preethi line. | 3:00 | honesty flag |
| 4 | Drive 1: Essex County | `e1_road` | County Road 20 | Drive east past greenhouses. Text Tess at the first stop sign *(design)*. Radio stations. | 3:00 | — |
| 5 | Tom Portons 1: "The Decaf Problem" | `e1_tp1`, `e1_tp1p`, `e1_tp1acc`, `e1_tp1done`, `e1_tp1skip` | Tom Portons, CR 20 | Optional mystery (can skip). 4 clues → accuse June. Free fritter. | 5:00 | — |
| 6 | Drive 2: the text | `e1_shoulder` | north of Chatham | Sky greys out. Tess's text arrives; scripted pull-over on the shoulder, call goes to voicemail, then drive on. | 2:30 | — |
| 7 | Tom Portons 2: "The Missing Cooler" | `e1_tp2`, `e1_tp2b` | Highway 21 truck stop | Search the lot and restaurant; follow wet prints to the staff room; Victor joins. The cooler glimpse. | 5:00 | — |
| 8 | Victor | `e1_victor`, `e1_victor2` | truck stop, window table | Conversation. Truth or vague choice. Victor's phone call ("Mark"). The card goes to the journal. Exit: the long coat at the far pump. | 3:00 | Victor's card |
| 9 | Greyhaven at dusk | `e1_main`, `e1_station` | Main Street | Free walk in fog. Plaque, diner window (Tess waves), dark 94.1 sign, church bell ×6. | 3:00 | — |
| 10 | Ruth | `e1_ruth`, `e1_ruth2`, `e1_ruth2b` | Lakeview Motel office | Trust choice (+2 / +1 / +0). Key. | 2:30 | Ruth trust |
| 11 | The empty flat | `e1_flat`, `e1_tess`, `e1_tess2` | Nila's flat | Search: dead phone (charge it), cork board, suspension notice, rangoli with the boot print (photograph it). Tess arrives. | 4:00 | boot print clue |
| 12 | Cliffhanger: 94.1 | `e1_cliff`, `e1_end` | Mani's car, motel lot | Forced in-car camera. Tune to 94.1. 23:00. Nila's voice. The second voice. Red light blinks twice across the lake. | 2:00 | — |
| | | | | **Total** | **~38:00** | |

**Time skips** between beats use a short black card with place and time, in the same style as the prototype (*"County Road 20, Essex County — 09:05"*).

## 4. Spaces (greybox specs)

All sizes in metres. Greybox with CSG boxes in Godot first, final art later. Each space is its own Godot scene under `res://scenes/p1/e1/`.

### 4.1 Mani's apartment, Windsor — `apartment.tscn`
- **Size:** one-bedroom, about 7 × 8 m: entry, living + kitchenette, bedroom, bathroom (door closed).
- **Layout:** front door → living room with the counter on the right (sweets box, diyas packet, gift radio) → laptop on a small desk by the window → bedroom with the open duffel on the bed. Whiteboard on the living-room wall, photos on a shelf.
- **Flow:** the duffel is the "packing" target; carrying each item to it fills a slot. When all three are packed, the laptop rings; the call can't start before that. *(design)* If the ringing laptop is left unanswered for 90 s, the call starts by itself (Amma doesn't give up).
- **Light:** bright 09:05 November sun through blinds, cool white. The safest room in the game: remember this light at the end.

### 4.2 County roads — `road_cr20.tscn`, `road_chatham.tscn`
- **Shape:** not open world. Each drive is a 2–3 km road strip with gentle curves, built with a Path3D road and repeating roadside sets (greenhouses, silos, fences, then forest). The car can leave the road onto a soft shoulder; invisible rails stop it going further.
- **Drive 1:** flat farmland, greenhouses glittering, a hawk on a fence post *(set dressing)*. Ends at a Tom Portons sign: drive into the lot trigger.
- **Drive 2:** farmland turns to forest; the sky clouds over across the drive (animated sun → overcast). The text arrives at 60 % of the strip; the car slows by itself onto the gravel shoulder; the player calls Nila from the phone; voicemail; control returns.
- **Radio:** 3 fictional stations + static + 94.1 (silent in daylight). Stations play music/ads with no story content *(design; lines to be written and story-checked)*.

### 4.3 Tom Portons, County Road 20 — `tp_cr20.tscn`
- **Size:** about 16 × 12 m: counter and menu boards along the back, 8 tables, window booths, TV with a hockey rerun, drive-thru screen behind the counter, washrooms (closed).
- **NPCs:** Harold (counter), Priya (cashier), June (window table with newspaper), 3–4 ambient customers.
- **Mystery layout:** receipts on the counter (clue 1); drive-thru log on the screen behind the counter, reachable by asking Priya (clue 2); Harold's phone with the cat case on his table (clue 3); June by the window (clue 4). Accuse from a "talk to" menu once 3+ clues are found.
- **Skip:** walking back to the car without engaging takes the `e1_tp1skip` path.
- **Look:** red-and-cream fictional brand, warm fluorescent, steam from coffee urns.

### 4.4 Tom Portons, Highway 21 truck stop — `tp_hwy21.tscn`
- **Size:** restaurant about 14 × 10 m + staff room 4 × 4 m + outdoor lot about 40 × 30 m with 4 gas pumps.
- **Outdoor:** rain. Gus's *MERROW PALLETS & SUPPLY* box truck parked by the door, cab door open. Mani's car. **The far pump** (pump 4) with the black car and the man in the long coat (the Hades silhouette model).
- **Mystery layout:** wet sneaker prints from the truck cab around the side to the back door (clue 1, decals that glisten); staff room door ajar with two teens on break (clue 2); a soaked, bulging backpack (clue 3). Victor rises from the window table when the player reaches clue 2.
- **The glimpse:** a short scripted close-up. Victor lifts the lid an inch: heat pack, a ventilated box, something coiled. Lid shuts. Never show more.
- **The long coat:** visible only when Mani walks out of the front door. He stands facing the restaurant; if the camera lingers 3 s or the player walks toward him, a truck passes between and the car is gone *(design)*. Never reachable.

### 4.5 Greyhaven, Main Street — `greyhaven_main.tscn`
- **Shape:** one street about 150 m long running down to the lake, with fog banks rolling in from the water.
- **Landmarks in order:** the town sign, a shuttered hardware store, the Merrow Diner (lit, Tess in the window), the dark 94.1 FM brick building, three sodium streetlights, the lakeside plaque (*OLD MERROW, 1842–1978…*), and in the distance the St. Brendan's spire and the water tower on the hill.
- **The bell:** St. Brendan's rings six times as the player arrives, with no service.
- **Exit:** the Lakeview Motel sign (two dead letters) at the end of the street.
- **Light:** 17:40 dusk, blue-grey, sodium orange pools. The fog is the first real "Alan Wake" moment: give the player a locked-off wide shot of the street as they step out of the car.

### 4.6 Lakeview Motel — `lakeview_motel.tscn`
- **Office:** about 5 × 4 m. Desk, scanner murmuring, shotgun leaning within reach, key board, a stuffed pike on the wall *(it is smashed in a later episode)*.
- **Exterior:** an L-shaped two-storey motel, gravel lot with Nila's car and Mani's car, back stairs up to the flat, the lake and fog behind.
- **Ruth:** seated, doesn't look up until Mani says who he is.

### 4.7 Nila's flat — `nila_flat.tscn`
- **Size:** two-bedroom above the motel, about 8 × 7 m: entry, living/kitchen, Nila's room, Tess's room (closed), bathroom.
- **Search spots:** the rangoli by the door with the boot print (inspect → photograph → journal); the dead phone on the kitchen table (carry to a charger; locked); the cork board of caller notes (read each note); the suspension notice in the centre of the board.
- **Dressing:** half-strung fairy lights, old radio-station posters, a ham radio desk *(empty: her radio bag is gone)*.
- **Tess** enters breathless after the second search spot is found.
- **Light:** Mani switches lamps on as he goes; the flat gets warmer as you search it, then Tess leaves and it feels too big.

### 4.8 Cliffhanger, the car — reuses `lakeview_motel.tscn`
- **Camera:** forced interior, passenger-side, Mani lit by the dash. The gift radio in wrapping on the passenger seat.
- **Interaction:** the only input is the radio dial. 94.1 is dead air until the clock hits 23:00, then the scripted broadcast plays.
- **The red light:** across the lake through the windshield, blinks twice, goes dark. Cut to black. "END OF EPISODE 1."

## 5. Camera and presentation

- **Default:** over-the-shoulder, right shoulder, about 2.2 m behind; pulls closer indoors.
- **Conversations:** two-shot that cuts to over-the-shoulder singles on each speaker; choices appear bottom-centre. Subtitles always on for spoken lines, with the speaker name and a channel icon (phone, radio, voicemail).
- **Locked-off dread shots** *(design)*: first look at Main Street in fog; the flat doorway with the smudged rangoli; the far pump.
- **Driving:** chase camera, with a dashboard camera when the phone or radio is used.
- **Episode frame:** title card at the start; "Previously on" is skipped for Ep 1; "END OF EPISODE 1" at the end.

## 6. Lighting and weather arc

| Beat | Time | Light | Weather |
| --- | --- | --- | --- |
| Apartment | 09:05–09:35 | bright cool sun | clear |
| Drive 1, Tom Portons 1 | 10:10–11:06 | high morning sun | clear, cold |
| Drive 2 | 12:10 | sun → overcast | clouding over |
| Truck stop | 14:20 | flat grey | rain |
| Main Street | 17:40 | dusk, sodium orange | fog rolling in |
| Motel, flat | 18:00–18:47 | warm interiors, black windows | dense fog |
| Car | 22:58 | dash light only | fog, the red light |

## 7. Systems to build for Ep 1 (in order)

1. **Player controller** (CharacterBody3D, walk/jog, OTS camera).
2. **Interaction and inspect** (raycast, prompt dot, inspect view with rotation and hotspots).
3. **Story hooks in 3D:** a `StoryTrigger` node that starts a prototype scene id through `OOTStoryRunner` (already built), and listens for scene ends.
4. **Dialogue presentation** in 3D (the existing dialogue test UI, restyled, plus camera shots).
5. **Search and accuse puzzles** mapped to the prototype's `search` and `pick` puzzle data.
6. **Journal** (reads `StoryState` clues).
7. **Phone UI** (texts, calling to voicemail).
8. **Car** (VehicleBody3D, arcade tuning, enter/exit, radio dial).
9. **Time-skip cards and scene loading** between spaces.
10. **Episode title and end cards.**

Saves follow the GDD: auto-save at every scene start.

## 8. Assets for Ep 1

- **Characters (sheets done):** Mani, Nila (photos only), Victor, Ruth, Gus, Tess, Hades silhouette, Midas (glimpse only).
- **Characters still needing sheets:** Amma and Appa (laptop video), Harold, June, Priya, two teens, 6–8 ambient customers *(new prompts needed; minor, can be lower detail)*.
- **Vehicles:** Mani's grey sedan (hero, with interior), Gus's box truck, the black tinted car, 3–4 background cars and trucks.
- **Key props:** sweets box, diyas packet, gift-wrapped ham radio, duffel, laptop, whiteboard, photos, receipts, drive-thru screen, cat phone case, blue cooler, ventilated box, Victor's business card, the plaque, the scanner, shotgun, motel key, Nila's phone, cork board and caller notes, suspension notice, rangoli with boot print, fairy lights, car radio.
- **Audio:** the voicemail, Nila's broadcast and the second voice (radio-processed), the bell, scanner chatter, diner and coffee-shop ambience, rain, fog/lake ambience, radio static.

## 9. Greybox milestones

| Step | Done when |
| --- | --- |
| **G1** Apartment | Walk, inspect, pack three items, video call plays from `e1_call` with the honesty choice saved. |
| **G2** Tom Portons 1 | Decaf mystery playable with clues and accuse; skip path works. |
| **G3** Drives | Both road strips drivable; text and pull-over scripted; radio works. |
| **G4** Truck stop | Cooler mystery, Victor scenes, the long coat at the far pump. |
| **G5** Greyhaven | Main Street, motel office (Ruth trust), flat search, cliffhanger. |
| **G6** Full run | Start to "END OF EPISODE 1" in one session with saves, 30–40 minutes. |

## 10. Design decisions (2026-10-20)

1. **Driving: manual with auto-cruise.** The player steers and controls speed; while the phone or the radio is open, the car holds its lane and speed.
2. **Minor characters: mix.** Proper face and turnaround sheets for Harold, June and Priya; a shared base body with face and clothing variants for the two teens and the ambient customers.
3. **Narration: no narrator.** No third-person voice and Mani does not narrate. The story is carried by five layers (section 11). Mani's inner voice is adopted as one of them.

## 11. Narration (decided 2026-10-20)

There is **no narrator**. Five layers carry the story, each with one job:

1. **Nila's voice is the closest thing to a narrator** (Part 1: the voicemail, *After Hours* broadcasts, voice memos, tapes; Part 2: Lighthouse on the radio).
2. **Mani's inner voice notices; it never tells the story** (see below).
3. **The world tells the backstory:** caller notes, plaques, photos, ledgers, manifests. "Mark Hayden" appears only on paper in Part 1.
4. **The journal keeps the player oriented:** Mani's short notes hold the current goal and clues.
5. **The episode frame:** place and time cards, title card, "Previously on" (Part 1: a radio-dial montage of real lines from earlier scenes through static, no new writing; Part 2: Lighthouse recaps on the radio, in character), the cliffhanger and "END OF EPISODE".

## 12. Mani's inner voice (adopted)

Alan Wake narrates his own story. Mani doesn't narrate; he **notices**. His inner voice is short, dry, and only ever reacts to what the player is looking at or has just worked out. It never tells the story, never explains feelings, never says more than the screenplay knows.

**When it plays**
- **Inspect:** one line when an object is inspected for the first time (optional objects only get one line; key clues can get a second on a closer look).
- **Pattern moments:** when two clues in the journal connect, the screen dims slightly, the two clues link on the journal page, and Mani says the deduction. This is how mysteries unlock their accuse step. It fits his canon line: "I'm a data guy. It's just logs."
- **Afterthoughts:** rarely, a line a beat after a scene ends, when canon gives him a realisation (e.g. Victor knowing his name).

**How it sounds and looks**
- Close, quiet voice-over, no radio processing. Subtitle in italics with no speaker frame, so it reads as thought, not speech.
- **English by default** (his working, analytical voice); **Tanglish when the thought is about family**, with an English subtitle as always.
- One sentence, two at most. Never a question to the player. Never a hint that solves the puzzle outright.
- In Part 1 the deduction voice is Mani's. In Part 2, Nila takes over deductions on the radio with her criminology voice (as in the GDD evidence board), and Mani's inner voice gets rarer.

**Example lines for Episode 1** *(draft, to be story-checked)*

| Trigger | Line | Subtitle |
| --- | --- | --- |
| Inspect the job whiteboard | Eleven applications. Two callbacks. One Thursday. | (same) |
| Inspect the graduation photo | Amma azhudhaanga. Appa azhala-nu nadichaar. | Amma cried. Appa pretended he didn't. |
| Inspect Nila's broadcast photo | First night on air. She called me after, couldn't stop talking. | (same) |
| Pattern: receipts + drive-thru log | Two orders, same name, two minutes apart. Someone orders ahead of him. | (same) |
| Pattern: cat profile picture + Harold's phone case | Same cat. Someone who shares his phone. | (same) |
| Inspect the wet prints | Sneakers. Small. Not Gus. | (same) |
| Afterthought, leaving the staff room | Bait doesn't need a heat pack. | (same) |
| Afterthought, back in the car | I never told him my name. (beat) It was on the cup. | (same) |
| Inspect the rangoli boot print | Too big for Tess. Too big for Nila. | (same) |
| Inspect the suspension notice | "Sponsor complaints." Nila doesn't get complaints. She gets callers. | (same) |

**Cost:** about 40–60 short lines per episode, all new writing, which need a `/story-check` pass and VO in two languages. They live in the story data like every other line (a new channel, `thought`), not hard-coded.
