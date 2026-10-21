# Placeholder voice and sound

**Placeholder voice-over is never shipped.** It exists so scenes can be paced, subtitled and
lip-synced before real actors are cast. Final VO (Tanglish and English) will be recorded and
will replace everything in `game/audio/vo_placeholder/`. Remove that folder from export presets.

Engine (default): **Kokoro-82M** (`hexgrad/Kokoro-82M`, Apache-2.0 weights and voices, `kokoro` pip package Apache-2.0), cached in
`tools/voice/models/kokoro/` (gitignored). `espeak-ng` (GPL, dev tool only) is used for fallback phonemes.
The old Piper backend (`gen_placeholder_vo.py`, LibriTTS-R, CC BY 4.0) still works and supplies the shared filter/encode chain.
Dedicated per-character voice models may replace Kokoro later.

## Regenerate VO (Part 1, Episode 1)

```bash
brew install espeak-ng
tools/.venv/bin/pip install kokoro soundfile
tools/.venv/bin/python -m spacy download en_core_web_sm   # misaki fetches this itself on first run if missing
tools/.venv/bin/python -I tools/voice/gen_vo_kokoro.py          # only changed lines (add --force for all)
tools/.venv/bin/python -I tools/lipsync/gen_lipsync.py --force  # Rhubarb mouth cues (A-H, X)
tools/voice/gen_sfx.sh                                          # laptop ring + apartment room tone
godot --headless --path game --import
```

(`gen_placeholder_vo.py` is the Piper fallback with the same outputs.) The model downloads from Hugging Face on first run.

The script reads `game/data/story/p1_scenes.json` (run `node tools/export_story.js` first if the story changed).
Every non-narration, non-`TEXT` line of Episode 1 is spoken, filtered by channel, and written to
`game/audio/vo_placeholder/p1/<line_id>.ogg` (line id = `<scene>_<NNN>`), plus `manifest.json`
(file, duration, speaker, voice id, channel, filter, hash). Unchanged lines are skipped by hash. Rhubarb needs no network;
set `RHUBARB=` if it is not at `~/Applications/Tools/Rhubarb-Lip-Sync-1.14.0-macOS/rhubarb`.
If Godot reports a freshly generated file as failing to load, delete its `.ogg.import` (`valid=false`) and re-import.

Files are dual-mono Ogg Vorbis at 22.05 kHz (this ffmpeg only has the native Vorbis encoder, which requires stereo).

## Tanglish handling

Kokoro's G2P mangles romanised Tamil ("dhaan" becomes "dihaan"). `tanglish.py` detects Tamil words (explicit list plus any
lowercase word unknown to the English lexicon) and converts them with spelling rules to Kokoro phonemes (dental d/t, retroflex
`ɻ`, long `ɑː`, `ʧ` and so on); English words and punctuation still use Kokoro's English G2P. Add new Tamil words to
`TAMIL` / `NAMES` in `tanglish.py`. The family (Mani, Nila, Amma, Appa) uses Kokoro's **Hindi voices**, which give an Indian
accent; they keep the same voice on pure-English lines so each character keeps one timbre. Comparison: Piper reads Tamil words with
English spelling rules; Kokoro English voices with the phoneme conversion pronounce the words correctly but sound American/British;
the Hindi voices sound closest to the intended accent. This was judged by phoneme output, not by ear: please listen to the
comparison clips and swap voices in `VOICES` if you disagree.

## Channel filters

| Channel | Filter |
| --- | --- |
| `V.O.`, `ON PHONE`, voicemail | 300-3400 Hz band-pass + tanh saturation |
| `RADIO`, `ON RADIO`, `ON AIR` | band-pass + softer saturation + pink-noise static bed |
| video call (scenes `e1_call`, `e1_call2`) | 120 Hz high-pass + light compression |
| in person | clean |

All lines are loudness-normalised (about -19 LUFS, peaks below -4 dBFS).

## Voice table (Kokoro voice, speed)

| Character | Voice | Speed | Intent |
| --- | --- | --- | --- |
| MANI | hm_psi (Hindi male) | 1.0 | young adult, Indian accent |
| NILA | hf_beta (Hindi female) | 1.05 | quick, young woman |
| AMMA | hf_alpha (Hindi female) | 0.95 | older woman, slower |
| APPA | hm_omega (Hindi male) | 0.95 | older man, deeper |
| VICTOR | am_onyx (US male) | 0.92 | deep, warm, slightly menacing |
| RUTH | bf_emma (UK female) | 0.97 | older woman |
| TESS | af_nicole (US female) | 1.0 | young woman |
| GUS | am_fenrir (US male) | 0.95 | gruff |
| HAROLD | bm_george (UK male) | 0.93 | older man |
| JUNE | af_sarah (US female) | 1.0 | adult woman |
| PRIYA | af_bella (US female) | 1.05 | young woman |
| MAN'S VOICE (Hades) | bm_lewis (UK male) | 0.88 | soft, patient, unhurried |
| others | am_adam | 1.0 | generic male |

## In the game

- `res://default_bus_layout.tres`: Master, VO, SFX, Ambience, Music, UI. Ambience and Music carry a compressor side-chained to VO, so they duck under speech.
- `OOTVoiceLines` (`scripts/audio/oot_vo.gd`): `get_stream(line_id)`, `get_lip_cues(line_id)`, `mouth_at(cues, t)`. Missing audio returns null / empty.
- `OOTDialogueBox` plays the line's VO on the VO bus when it appears, stops it on advance, emits `voice_requested(line_id, has_audio)`. Subtitles are unchanged.
- `OOTFootsteps.pick(surface)` returns a random Kenney footstep stream; not yet wired into the player.
- Tests: `godot --headless --path game --script res://tests/run_audio_tests.gd`.
