#!/bin/sh
# Synthesises the traffic sounds: two-tone car horns (short and long, two pitches) and a brake squeal. We make them, so
# they are CC0. Needs ffmpeg. Writes next to this script: horn_a_short/long.ogg, horn_b_short/long.ogg, brake_squeal.ogg.
set -e
OUT="$(cd "$(dirname "$0")" && pwd)"
ENC="-ac 2 -ar 44100 -c:a vorbis -strict -2 -b:a 96k"
SR=44100
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# a sawtooth-ish tone of frequency f: sum of the first six harmonics
saw() { echo "(sin(2*PI*$1*t)+0.5*sin(2*PI*2*$1*t+0.3)+0.33*sin(2*PI*3*$1*t+0.7)+0.25*sin(2*PI*4*$1*t+1.1)+0.2*sin(2*PI*5*$1*t+0.2)+0.16*sin(2*PI*6*$1*t+0.9))"; }
horn() { # name duration f1 f2 : two tones, 12 ms attack, 40 ms release, slight buzz
  d=$2
  ffmpeg -y -loglevel error -f lavfi -i "aevalsrc='0.3*($(saw $3)+$(saw $4))*(1+0.06*sin(2*PI*93*t))*min(t/0.012,1)*min((${d}-t)/0.04,1)':d=$d:s=$SR" \
    -af "highpass=f=180,lowpass=f=3600,aecho=0.6:0.3:35:0.18,alimiter=limit=0.8" "$TMP/$1.wav"
}
norm() {
  f="$TMP/$1.wav"
  m=$(ffmpeg -hide_banner -i "$f" -af volumedetect -f null - 2>&1 | sed -n 's/.*max_volume: \(-*[0-9.]*\) dB.*/\1/p')
  g=$(awk "BEGIN{print $2 - ($m)}")
  ffmpeg -y -loglevel error -i "$f" -af "volume=${g}dB" $ENC "$OUT/$1.ogg"
}
horn horn_a_short 0.32 415 523
horn horn_a_long 1.3 415 523
horn horn_b_short 0.28 370 466
horn horn_b_long 1.15 370 466
# Brake squeal: a gliding high whine plus a little noise, 0.8 s.
ffmpeg -y -loglevel error -f lavfi -i "aevalsrc='0.22*sin(2*PI*(2300-500*t)*t)*(1+0.3*sin(2*PI*37*t))*min(t/0.1,1)*min((0.8-t)/0.25,1)':d=0.8:s=$SR" \
  -f lavfi -i "anoisesrc=d=0.8:c=white:a=0.2:r=$SR" \
  -filter_complex "[1:a]bandpass=f=3000:w=2500,volume=0.25[n];[0:a][n]amix=inputs=2:normalize=0,afade=t=out:d=0.3:st=0.5,alimiter=limit=0.7[o]" -map "[o]" "$TMP/brake_squeal.wav"
norm horn_a_short -8; norm horn_a_long -8; norm horn_b_short -8; norm horn_b_long -8; norm brake_squeal -16
echo done
