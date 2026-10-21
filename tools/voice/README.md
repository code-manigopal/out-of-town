# Placeholder voice and sound

**Placeholder voice-over is never shipped.** It exists so scenes can be paced, subtitled and
lip-synced before real actors are cast. Final VO (Tanglish and English) will be recorded and
will replace everything in `game/audio/vo_placeholder/`. Remove that folder from export presets.

Model: Piper `en_US-libritts_r-medium` (multi-speaker LibriTTS-R, CC BY 4.0) in `tools/voice/models/`.
It is an English voice, so Tanglish lines are read with English phonetics: good enough for timing, wrong for sound.

## Regenerate VO (Part 1, Episode 1)

```bash
tools/.venv/bin/python -I tools/voice/gen_placeholder_vo.py          # only changed lines
tools/.venv/bin/python -I tools/voice/gen_placeholder_vo.py --force  # everything
tools/.venv/bin/python -I tools/lipsync/gen_lipsync.py               # Rhubarb mouth cues (A-H, X)
tools/voice/gen_sfx.sh                                               # laptop ring + apartment room tone
godot --headless --path game --import
```

The script reads `game/data/story/p1_scenes.json` (run `node tools/export_story.js` first if the story changed).
Every non-narration, non-`TEXT` line of Episode 1 is spoken, filtered by channel, and written to
`game/audio/vo_placeholder/p1/<line_id>.ogg` (line id = `<scene>_<NNN>`, the Name column of `data/story/p1_lines.csv`),
plus `manifest.json` (file, duration, speaker, speaker id, channel, filter, hash). A line is skipped when the hash of
text + speaker + filter is unchanged. Rhubarb needs no network; set `RHUBARB=` if it is not at
`~/Applications/Tools/Rhubarb-Lip-Sync-1.14.0-macOS/rhubarb`.

Files are dual-mono Ogg Vorbis at 22.05 kHz (this ffmpeg only has the native Vorbis encoder, which requires stereo).

## Channel filters

| Channel | Filter |
| --- | --- |
| `V.O.`, `ON PHONE`, voicemail | 300-3400 Hz band-pass + tanh saturation |
| `RADIO`, `ON RADIO`, `ON AIR` | band-pass + softer saturation + pink-noise static bed |
| video call (scenes `e1_call`, `e1_call2`) | 120 Hz high-pass + light compression |
| in person | clean |

All lines are loudness-normalised (about -19 LUFS, peaks below -4 dBFS).

## Voice table (LibriTTS-R speaker index)

Picked by measured pitch; there is no gender/age metadata, so these are rough fits. Change `VOICES` in the script and re-run.

| Character | Speaker | ~Pitch | Intent |
| --- | --- | --- | --- |
| MANI | 286 | 127 Hz | young adult male |
| NILA | 154 | 188 Hz | young woman |
| AMMA | 440 | 176 Hz | older woman |
| APPA | 22 | 96 Hz | older man |
| VICTOR | 132 | 90 Hz | deep, warm |
| RUTH | 462 | 168 Hz | older woman |
| TESS | 66 | 202 Hz | young woman |
| GUS | 594 | 92 Hz | gruff man |
| HAROLD | 418 | 102 Hz | older man |
| JUNE | 242 | 175 Hz | adult woman |
| PRIYA | 550 | 223 Hz | young woman |
| MAN'S VOICE | 506 | 115 Hz | radio caller |
| others | 330 | 119 Hz | generic male default |

## In the game

- `res://default_bus_layout.tres`: Master, VO, SFX, Ambience, Music, UI. Ambience and Music carry a compressor side-chained to VO, so they duck under speech.
- `OOTVoiceLines` (`scripts/audio/oot_vo.gd`): `get_stream(line_id)`, `get_lip_cues(line_id)`, `mouth_at(cues, t)`. Missing audio returns null / empty.
- `OOTDialogueBox` plays the line's VO on the VO bus when it appears, stops it on advance, emits `voice_requested(line_id, has_audio)`. Subtitles are unchanged.
- `OOTFootsteps.pick(surface)` returns a random Kenney footstep stream; not yet wired into the player.
- Tests: `godot --headless --path game --script res://tests/run_audio_tests.gd`.
