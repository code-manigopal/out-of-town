#!/bin/sh
# Synthesises the apartment's interaction sounds (doors, fridge, taps, flush, keys). We make them, so they are CC0.
# Needs ffmpeg. Run from anywhere; writes next to this script. Output: dual-mono-ish stereo Ogg Vorbis.
set -e
OUT="$(cd "$(dirname "$0")" && pwd)"
ENC="-ac 2 -ar 44100 -c:a vorbis -strict -2 -b:a 96k"
SR=44100
syn() { # name duration expr [filters]
  ffmpeg -y -loglevel error -f lavfi -i "aevalsrc='$3':d=$2:s=$SR" -af "${4:-anull},alimiter=limit=0.8" $ENC "$OUT/$1.ogg"
}

# Door opening: latch click then a low wooden creak that rises in pitch.
syn door_open 0.75 "(random(0)*2-1)*exp(-260*t)*0.7 + 0.22*(sin(2*PI*(130*t+150*t*t))+0.55*sin(4*PI*(130*t+150*t*t))+0.3*sin(6*PI*(130*t+150*t*t)))*sin(PI*min(t/0.6,1))*(0.65+0.35*sin(2*PI*23*t))*between(t,0.04,0.7)" "lowpass=f=2600,highpass=f=80,aecho=0.5:0.4:35:0.2"

# Door closing: short creak, then the slab meets the frame (thud) and the latch clicks.
syn door_close 0.8 "0.18*(sin(2*PI*(260*t-150*t*t))+0.5*sin(4*PI*(260*t-150*t*t)))*sin(PI*min(t/0.4,1))*between(t,0,0.4)*(0.7+0.3*sin(2*PI*19*t)) + 0.9*sin(2*PI*70*(t-0.42))*exp(-30*(t-0.42))*gte(t,0.42) + (random(0)*2-1)*exp(-400*(t-0.47))*0.6*gte(t,0.47)" "lowpass=f=2400,aecho=0.5:0.4:30:0.2"

# Locked door: the handle rattles against the latch.
syn door_locked 0.45 "(random(0)*2-1)*(exp(-150*t)+0.8*exp(-150*(t-0.09))*gte(t,0.09)+0.6*exp(-150*(t-0.19))*gte(t,0.19))*0.6 + 0.5*sin(2*PI*95*t)*exp(-25*t)" "bandpass=f=1800:w=2500,volume=2"

# Fridge door opening: the magnetic seal lets go (soft pop plus a short airy sweep).
syn fridge_open 0.5 "(random(0)*2-1)*0.5*sin(PI*min(t/0.25,1))*between(t,0,0.25)*(1-t*2) + 0.7*sin(2*PI*(200-300*t)*t)*exp(-30*t)" "bandpass=f=900:w=1800,lowpass=f=3500,volume=1.6"
# Fridge door closing: dull thud and the seal catching.
syn fridge_close 0.5 "0.95*sin(2*PI*60*t)*exp(-22*t) + (random(0)*2-1)*0.45*exp(-70*(t-0.03))*gte(t,0.03) + 0.3*sin(2*PI*180*t)*exp(-40*t)" "lowpass=f=1600,volume=1.4"

# Fridge compressor hum: 50 Hz and harmonics (whole cycles, so the 4 s loop is seamless) plus a faint rattle.
ffmpeg -y -loglevel error -f lavfi -i "aevalsrc='0.35*sin(2*PI*50*t)+0.18*sin(2*PI*100*t)+0.09*sin(2*PI*150*t)+0.04*sin(2*PI*250*t)':d=4:s=$SR" \
  -f lavfi -i "anoisesrc=d=4:c=brown:a=0.5:r=$SR" \
  -filter_complex "[1:a]lowpass=f=300,volume=0.35[n];[0:a][n]amix=inputs=2:normalize=0,volume=0.7,alimiter=limit=0.6[o]" -map "[o]" $ENC "$OUT/fridge_hum.ogg"

# Running tap water: bright noise with a gentle burble (4 s loop, whole cycles of the modulation).
ffmpeg -y -loglevel error -f lavfi -i "anoisesrc=d=4:c=pink:a=0.9:r=$SR" \
  -af "highpass=f=500,lowpass=f=7000,bandpass=f=2800:w=4000,volume='0.55+0.12*sin(2*PI*2.5*t)+0.08*sin(2*PI*6*t)':eval=frame,volume=2.4,alimiter=limit=0.7" $ENC "$OUT/water_loop.ogg"

# Tap lever squeak.
syn tap_squeak 0.18 "0.35*sin(2*PI*(1700*t+3500*t*t))*sin(PI*t/0.18)+0.1*(random(0)*2-1)*sin(PI*t/0.18)" "highpass=f=900"

# Toilet flush: rush of water, swirl and gurgle, then the tank refilling.
ffmpeg -y -loglevel error -f lavfi -i "anoisesrc=d=7:c=pink:a=0.9:r=$SR" \
  -f lavfi -i "aevalsrc='0.35*sin(2*PI*(95+12*sin(2*PI*5*t))*t)*(between(t,2.6,4.2))*sin(PI*(t-2.6)/1.6)':d=7:s=$SR" \
  -filter_complex "[0:a]bandpass=f=1400:w=2600,volume='if(lt(t,0.5),t/0.5,if(lt(t,3.0),1,if(lt(t,4.4),1-(t-3.0)/1.4*0.8,0.2*exp(-(t-4.4)*0.6)+0.05)))*1.3':eval=frame[w];[w][1:a]amix=inputs=2:normalize=0,afade=t=out:st=6.4:d=0.6,alimiter=limit=0.75[o]" -map "[o]" $ENC "$OUT/flush.ogg"

# Car keys picked up: a few bright metallic pings.
syn keys_jingle 0.6 "0.25*(sin(2*PI*3100*t)+0.6*sin(2*PI*4650*t))*exp(-22*t) + 0.2*(sin(2*PI*3700*t)+0.5*sin(2*PI*5300*t))*exp(-24*(t-0.07))*gte(t,0.07) + 0.2*(sin(2*PI*2900*t)+0.6*sin(2*PI*4200*t))*exp(-20*(t-0.15))*gte(t,0.15) + 0.15*(sin(2*PI*3400*t))*exp(-26*(t-0.26))*gte(t,0.26)" "highpass=f=1500,aecho=0.6:0.4:40:0.2"

# Normalise each file's peak (dB) so the levels are sensible without per-sound guesswork.
norm() { # file peak_db
  f="$OUT/$1.ogg"
  m=$(ffmpeg -hide_banner -i "$f" -af volumedetect -f null - 2>&1 | sed -n 's/.*max_volume: \(-*[0-9.]*\) dB.*/\1/p')
  g=$(awk "BEGIN{print $2 - ($m)}")
  ffmpeg -y -loglevel error -i "$f" -af "volume=${g}dB" $ENC "$f.tmp.ogg" && mv "$f.tmp.ogg" "$f"
}
norm door_open -6; norm door_close -4; norm door_locked -8; norm fridge_open -8; norm fridge_close -4
norm water_loop -12; norm keys_jingle -8; norm flush -6; norm tap_squeak -10; norm fridge_hum -10
echo done
