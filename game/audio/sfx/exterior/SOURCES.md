# Sources - exterior sound effects

Everything here is synthesised with ffmpeg by the scripts next to it, so it is ours and CC0.

| files | script |
|---|---|
| car_door_open/close, trunk_open/close, ignition_click, dash_chime, engine_start/idle/run, traffic_car_loop; `../../ambience/city_morning.ogg` | `gen_exterior_sfx.sh` |
| horn_a_short, horn_a_long, horn_b_short, horn_b_long (two-tone car horns, ~0.3 s and ~1.2 s), brake_squeal | `gen_traffic_sfx.sh` |

SFXMint (https://sfxmint.com, CC0) was checked for a real car horn and brake squeal, but its pages are script-rendered with no stable
direct download links from the command line, so the horns and the brake squeal were synthesised instead (sawtooth-ish two-tone sums at
415/523 Hz and 370/466 Hz, 12 ms attack, 93 Hz buzz; the squeal is a gliding 2.3 kHz whine plus band-passed noise). Replace the files
with SFXMint/Kenney CC0 recordings of the same names and list them here if wanted.
