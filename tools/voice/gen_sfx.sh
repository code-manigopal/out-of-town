#!/bin/sh
# Synthesises the small CC0 (we make it) sounds for the apartment. Run from anywhere.
# Needs ffmpeg. Output is dual-mono Ogg Vorbis (ffmpeg's native encoder only does stereo).
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SFX="$ROOT/game/audio/sfx"; AMB="$ROOT/game/audio/ambience"
mkdir -p "$SFX" "$AMB"
ENC="-ac 2 -ar 44100 -c:a vorbis -strict -2 -b:a 96k"

# Laptop video-call ring: two-tone chirp (880/1175 Hz), two rings then a pause, 3.2 s loop.
ffmpeg -y -loglevel error -f lavfi -i "aevalsrc='0.35*(sin(2*PI*880*t)+0.5*sin(2*PI*1760*t))*between(mod(t,1.6),0,0.22)+0.35*(sin(2*PI*1175*t)+0.5*sin(2*PI*2350*t))*between(mod(t,1.6),0.26,0.48)':d=3.2:s=44100" \
  -af "lowpass=f=5000,aecho=0.6:0.5:60:0.25,afade=t=out:st=3.1:d=0.1,volume=2.2,alimiter=limit=0.7" $ENC "$SFX/laptop_ring.ogg"

# Apartment on a weekday morning: low room tone + faint distant traffic swells, 24 s loop.
ffmpeg -y -loglevel error \
  -f lavfi -i "anoisesrc=d=24:c=brown:a=0.5:r=44100" \
  -f lavfi -i "anoisesrc=d=24:c=pink:a=0.5:r=44100" \
  -f lavfi -i "aevalsrc='0.02*sin(2*PI*50*t)+0.01*sin(2*PI*100*t)':d=24:s=44100" \
  -filter_complex "[0:a]lowpass=f=180,volume=0.5[room];[1:a]bandpass=f=350:w=300,lowpass=f=700,volume='0.05+0.05*sin(2*PI*t/6)+0.04*sin(2*PI*t/9.5)':eval=frame[traffic];[room][traffic][2:a]amix=inputs=3:normalize=0,afade=t=in:d=0.05,afade=t=out:st=23.95:d=0.05,volume=0.8,alimiter=limit=0.5[o]" \
  -map "[o]" $ENC "$AMB/apartment_morning.ogg"
echo done
