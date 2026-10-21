#!/bin/sh
# Synthesises the Episode 1 exit sequence sounds: car doors, trunk, ignition and engine loops, plus the Windsor city
# ambience bed. We make them, so they are CC0. Needs ffmpeg. Run from anywhere; writes next to this script (the
# ambience loop goes to game/audio/ambience/). Output: stereo Ogg Vorbis.
set -e
OUT="$(cd "$(dirname "$0")" && pwd)"
AMB="$(cd "$OUT/../../ambience" && pwd)"
ENC="-ac 2 -ar 44100 -c:a vorbis -strict -2 -b:a 96k"
SR=44100
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
syn() { # name duration expr [filters]  (writes a wav; norm encodes it)
  ffmpeg -y -loglevel error -f lavfi -i "aevalsrc='$3':d=$2:s=$SR" -af "${4:-anull},alimiter=limit=0.8" "$TMP/$1.wav"
}
norm() { # name peak_db [dir]: scale the wav so its peak is peak_db, encode once to Ogg Vorbis
  f="$TMP/$1.wav"
  m=$(ffmpeg -hide_banner -i "$f" -af volumedetect -f null - 2>&1 | sed -n 's/.*max_volume: \(-*[0-9.]*\) dB.*/\1/p')
  g=$(awk "BEGIN{print $2 - ($m)}")
  ffmpeg -y -loglevel error -i "$f" -af "volume=${g}dB" $ENC "${3:-$OUT}/$1.ogg"
}

# Car door open: latch click, a short hollow clack of the door leaving the seal.
syn car_door_open 0.45 "(random(0)*2-1)*exp(-420*t)*0.8 + 0.5*sin(2*PI*140*t)*exp(-38*(t-0.03))*gte(t,0.03) + 0.2*(random(1)*2-1)*exp(-60*(t-0.03))*gte(t,0.03)" "lowpass=f=2800,aecho=0.5:0.3:25:0.2"
# Car door close: the heavy 'chunk' of a door shutting on its seal plus the latch.
syn car_door_close 0.6 "0.95*sin(2*PI*85*t)*exp(-28*t) + 0.4*sin(2*PI*210*t)*exp(-45*t) + (random(0)*2-1)*0.5*exp(-90*t) + (random(1)*2-1)*0.45*exp(-500*(t-0.07))*gte(t,0.07)" "lowpass=f=3000,aecho=0.5:0.3:30:0.2,volume=1.2"
# Trunk release: latch pop and the lid rising on its struts (soft hiss, small thunk at the end).
syn trunk_open 0.9 "(random(0)*2-1)*exp(-380*t)*0.7 + 0.35*sin(2*PI*110*t)*exp(-30*(t-0.02))*gte(t,0.02) + 0.14*(random(1)*2-1)*sin(PI*min(max(t-0.1,0)/0.55,1))*between(t,0.1,0.65) + 0.4*sin(2*PI*70*(t-0.66))*exp(-35*(t-0.66))*gte(t,0.66)" "lowpass=f=3200,aecho=0.5:0.3:30:0.2"
# Trunk close: a deep boom and the latch catching.
syn trunk_close 0.7 "1.0*sin(2*PI*62*t)*exp(-20*t) + 0.5*sin(2*PI*150*t)*exp(-40*t) + (random(0)*2-1)*0.5*exp(-80*t) + (random(1)*2-1)*0.5*exp(-450*(t-0.1))*gte(t,0.1)" "lowpass=f=2600,aecho=0.5:0.3:35:0.25,volume=1.2"
# Ignition: the key turning (click) then the dash chime.
syn ignition_click 0.25 "(random(0)*2-1)*exp(-500*t)*0.7 + 0.5*sin(2*PI*900*t)*exp(-120*t) + (random(1)*2-1)*exp(-600*(t-0.12))*gte(t,0.12)*0.6" "highpass=f=300,lowpass=f=5000"
syn dash_chime 0.7 "0.3*(sin(2*PI*1320*t)*exp(-6*t)+0.5*sin(2*PI*1980*t)*exp(-8*t))*between(t,0,0.3) + 0.3*(sin(2*PI*990*t)*exp(-6*(t-0.3))+0.5*sin(2*PI*1485*t)*exp(-8*(t-0.3)))*gte(t,0.3)" "aecho=0.5:0.4:60:0.25"

# Engine start: starter cranking (a ~11 Hz pulsing whine), then the engine catches and settles into the idle.
syn engine_start 2.4 "if(lt(t,1.0), 0.45*sin(2*PI*(95+8*sin(2*PI*11*t))*t)*(0.55+0.45*sin(2*PI*11*t))*(0.8+0.2*sin(2*PI*3*t)) + 0.18*(random(0)*2-1)*(0.5+0.5*sin(2*PI*11*t)), 0) + if(gte(t,1.0), (0.5*sin(2*PI*(12+14*min(max((t-1.0)/0.5,0),1))*t*2) + 0.3*sin(2*PI*(12+14*min(max((t-1.0)/0.5,0),1))*t*4) + 0.18*sin(2*PI*(12+14*min(max((t-1.0)/0.5,0),1))*t*6) + 0.1*sin(2*PI*(12+14*min(max((t-1.0)/0.5,0),1))*t*9))*(0.3+0.7*min(max((t-1.0)/0.15,0),1))*(1+0.35*exp(-6*(t-1.15))*gte(t,1.15)) , 0)" "lowpass=f=1800,highpass=f=40,aecho=0.5:0.3:25:0.15"
# Engine idle (loop, 2 s): ~800 rpm four-cylinder firing at 25 Hz plus harmonics, a slow wobble. Integer cycles => seamless.
syn engine_idle 2 "0.30*sin(2*PI*25*t) + 0.34*sin(2*PI*50*t+0.6) + 0.22*sin(2*PI*75*t+1.3) + 0.16*sin(2*PI*100*t+2.1) + 0.10*sin(2*PI*150*t+0.4) + 0.06*sin(2*PI*225*t+1.0) + 0.05*sin(2*PI*8*t)*sin(2*PI*50*t) + 0.04*sin(2*PI*1*t)*sin(2*PI*75*t)" "lowpass=f=900,highpass=f=30"
# Engine running (loop, 2 s): ~3000 rpm base, pitch-shifted by speed in game. Integer cycles => seamless.
syn engine_run 2 "0.26*sin(2*PI*50*t) + 0.32*sin(2*PI*100*t+0.6) + 0.26*sin(2*PI*150*t+1.3) + 0.2*sin(2*PI*200*t+2.1) + 0.12*sin(2*PI*300*t+0.4) + 0.07*sin(2*PI*450*t+1.0) + 0.04*sin(2*PI*600*t+0.3) + 0.04*sin(2*PI*4*t)*sin(2*PI*100*t)" "lowpass=f=2200,highpass=f=50"
# Traffic car loop (3D, doppler): engine + road noise, quieter and duller than the hero car.
ffmpeg -y -loglevel error -f lavfi -i "aevalsrc='0.22*sin(2*PI*40*t)+0.24*sin(2*PI*80*t+0.6)+0.18*sin(2*PI*120*t+1.3)+0.1*sin(2*PI*160*t+2.1)+0.05*sin(2*PI*240*t)':d=2:s=$SR" \
  -f lavfi -i "anoisesrc=d=2:c=pink:a=0.5:r=$SR" \
  -filter_complex "[1:a]bandpass=f=1200:w=1800,volume=0.5[n];[0:a][n]amix=inputs=2:normalize=0,lowpass=f=1800,alimiter=limit=0.7[o]" -map "[o]" "$TMP/traffic_car_loop.wav"

norm car_door_open -8; norm car_door_close -3; norm trunk_open -8; norm trunk_close -3; norm ignition_click -9; norm dash_chime -14
norm engine_start -4; norm engine_idle -8; norm engine_run -8; norm traffic_car_loop -10

# City ambience: low traffic rumble (brown), tyre hiss (pink band), a handful of passing cars (swelling noise bursts),
# a distant siren-less hum of the street and a few sparrows. 14 s with the tail crossfaded into the head so it loops.
T=14
X=2
ffmpeg -y -loglevel error \
  -f lavfi -i "anoisesrc=d=$((T+X)):c=brown:a=0.9:r=$SR" \
  -f lavfi -i "anoisesrc=d=$((T+X)):c=pink:a=0.5:r=$SR" \
  -f lavfi -i "aevalsrc='(random(7)*2-1)*(exp(-pow((t-2.2)/0.7,2))+0.8*exp(-pow((t-5.6)/0.9,2))+0.9*exp(-pow((t-8.4)/0.6,2))+exp(-pow((t-11.3)/0.8,2))+0.7*exp(-pow((t-14.4)/0.6,2)))':d=$((T+X)):s=$SR" \
  -f lavfi -i "aevalsrc='0.5*sin(2*PI*(3200+700*sin(2*PI*9*t))*t)*(between(t,3.1,3.18)+between(t,3.23,3.3)+between(t,3.36,3.44)) + 0.4*sin(2*PI*(4100+500*sin(2*PI*7*t))*t)*(between(t,9.7,9.77)+between(t,9.82,9.9)) + 0.45*sin(2*PI*(3600+600*sin(2*PI*8*t))*t)*(between(t,6.2,6.27)+between(t,6.33,6.4)+between(t,6.47,6.54)+between(t,6.6,6.66))':d=$((T+X)):s=$SR" \
  -filter_complex "[0:a]lowpass=f=220,volume=1.2[r];[1:a]bandpass=f=2200:w=3500,volume=0.16[h];[2:a]bandpass=f=700:w=900,volume=0.55[p];[3:a]highpass=f=2500,volume=0.05[b];[r][h][p][b]amix=inputs=4:normalize=0,volume=1.4[m];[m]asplit[m1][m2];[m1]atrim=0:$X,asetpts=PTS-STARTPTS,afade=t=in:d=$X[hd];[m2]atrim=$T:$((T+X)),asetpts=PTS-STARTPTS,afade=t=out:d=$X[tl];[hd][tl]amix=inputs=2:normalize=0[xf];[m]atrim=$X:$T,asetpts=PTS-STARTPTS[body];[xf][body]concat=n=2:v=0:a=1,alimiter=limit=0.7[o]" \
  -map "[o]" "$TMP/city_morning.wav"
norm city_morning -9 "$AMB"
echo done
