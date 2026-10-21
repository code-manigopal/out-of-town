# Next session: notes and open work (2026-10-21)

Pick up from here. Order of work suggested at the end.

## New decisions from the user (2026-10-21)

1. **The screenplay follows the user's changes.** When the user changes a story detail, update `docs/story/` (screenplay, story bible) and the prototype data to match, then re-export. Still flag anything that breaks a "story rule" in CLAUDE.md.
2. **Video call time:** Amma and Appa call at **7 pm Vellore time; it is 9:30 AM for Mani in Windsor** (Tuesday). Update the screenplay (Ep 1 Scene 2 says "10:40 pm their time"), the prototype `e1_call` narration ("7 pm their time"), scene times (`e1_apt` 08:10, `e1_call` 08:30), and the cold-open/apartment flow.
   - *Check with the user:* on Tuesday 3 Nov 2026 Windsor is on EST (DST ends 1 Nov), so 9:30 AM Windsor = **8:00 PM** in India; 7 PM in India would be 8:30 AM. Either move the day before 1 Nov, use 8 pm, or keep 7 pm / 9:30 AM as artistic licence.
3. **No browser-story narration text in the 3D game.** Prototype narration lines ("A small one-bedroom near the river…", "A graduation photo from the University of Windsor…") are stage directions for the browser version. In the video game the room shows these things; don't put them in a text box. Keep spoken lines, choices and Mani's inner voice; move descriptive text into inspect captions/journal only where useful.
4. **Storytelling UI to design (decide before building):**
   - **Phone on Tab:** brought up to screen focus; apps for objectives, messages (chat threads, e.g. Tess's texts), photos, maybe calls/voicemail. Diegetic, Mani's own phone.
   - **Objectives:** shown briefly in a top corner when they change and fade out smoothly after a few seconds; always checkable later (phone and/or journal).
   - **Journal (J):** stays for clues, people and deductions. Decide the split between phone (objectives, messages, photos) and journal (clues, notes).

## Consolidated issue list (from the 2026-10-21 play-test)

**A. Mani:** (A1) the jog/run looks funny; motion capture from a phone video (MediaPipe pose is installed) is the likely fix; (A2) hair reads as cards up close; (A3) side fidelity 0.63, held down by the sheet's backpack: decide whether he wears it; (A4) feet below the car floor and head at the roof when seated; (A5) hands float open in seated poses (call, driving); (A6) fitted model is local only until the user says "Mani is final". Fidelity now front 0.878, back 0.893 (`tools/likeness/run_fidelity.sh`).

**B. The car:** (B1) looks poor, especially the tail lights; (B2) steering wheel renders wrong; (B3) no interior camera after getting in (needs a real interior and a dash/radio view); (B4) very stiff ride; (B5) no wheel arches or engine bay.

**C. The world outside:** (C1) needs to be realistic: currently low-poly; use Road Generator, Terrain3D and Scatter (installed, unused); (C2) shop signs need designing; write image prompts (ask how many shops); (C3) graffiti placeholders until prompts 45–48 are generated; (C4) road-works barricades to block wrong turns. (C5) the four graffiti images are in (`game/environments/windsor/exterior/graffiti/graffiti_1..4.png`) but include their own brick wall and a ground strip: cut the paint out to alpha (or use them as whole wall panels) so they don't read as pasted squares.

**D. Traffic and pedestrians:** (D1) traffic drives through Mani; it should stop a few metres short and honk, with cars behind queueing and honking; (D2) parked cars not aligned to the kerb; (D3) pedestrians slide without walk animation; they need the shared skeleton and clips.

**E. Apartment and call:** (E1) done: all three real call stills are in `game/props/photos/call/`; (E2) call time (see decision 2); (E3) Amma and Appa face sheets saved but not wired in; (E4) shower tap and kitchen cabinets don't open; (E5) faint GI light leaks, a dark ceiling patch, brownish backsplash grout; (E6) interaction messages ("I need my car keys.", "Press E to start the engine") are hard-coded, not in story data; (E7) Tanglish placeholder voices are approximate; (E8) check that Nila's baby photo shows on the pin board (`game/props/photos/photo_nila_baby.png` is in place).

**F. Pipeline:** (F1) next builds: G3 county-road drive, G2 Tom Portons, Mani's inner-voice lines (`/story-check`); (F2) character sheets 20–38 (Walter onward) and new prompts for Harold, June, Priya, the two teens; (F3) Git LFS about 0.45 GB of 1 GB: commit final art only (pre-commit guard).

## Suggested order
1. Storytelling UI decisions (phone, objectives, journal) and removing narration text: they affect every scene.
2. Screenplay and prototype updates for the call time.
3. Traffic and pedestrians (D1, D3).
4. Car and interior camera (B1–B3), then Mani's seated pose (A4, A5).
5. Mani's run (A1).
6. Realism pass on the exterior (C1, C2, C4, D2).
7. Then G3 and G2.

## How to run
```bash
cd /Users/kamanika/Downloads/out-of-town && godot --path game
```
