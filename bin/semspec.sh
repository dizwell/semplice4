#!/usr/bin/env bash
####################################################################
#
# semspec: routine for displaying an audio spectrum
#
####################################################################
source "$CONFDIR/bin/semtput.sh" 
source "$CONFDIR/bin/semspin.sh"
rm -rf "$CONFDIR/tmp/spectrum.png" "$CONFDIR/tmp/spectrum.flac" 2>/dev/null

function basename {
  # Uses Bash built-in, so no call to external basename utility needed
  local path="${1%/}"
  echo "${path##*/}"    
}

function dirname {
  # Uses Bash built-in, so no call to external dirname utility needed
  local path="${1%/}"
  echo "${path%/*}"    
}

function check_diskspace {
FREESPACE=$(df -k "$CONFDIR/tmp" | grep / | awk '{print $4}')
FREESPACE=$((FREESPACE/1000000))
if [[ $FREESPACE -lt 15 ]]; then NOSPACE=1; else NOSPACE=0; fi
}

function check_writeok {
if [[ -w $CONFDIR/tmp ]]; then WRITEOK=1; else WRITEOK=0; fi
}

function create_filelist {
rm -f "$CONFDIR/tmp/spec-tracklist.txt" "$CONFDIR/tmp/spec-firsttrack.flac" 2>/dev/null

# As for SuperFLAC merging: ffmpeg's concat takes its decoding limits from the first track, so a later track encoded
# with larger FLAC blocks would lose its audio. In that case only, a temporary copy of track 1 is re-encoded at the
# largest block size found (the audio is unchanged) and joined in its place.
local FIRSTBLOCK=0 LARGESTBLOCK=0 MERGEFIRST="" BLOCK
for f in *.flac; do
  BLOCK=$(metaflac --show-max-blocksize "$f" 2>/dev/null || echo 0)
  [[ $FIRSTBLOCK -eq 0 ]] && FIRSTBLOCK=$BLOCK
  [[ $BLOCK -gt $LARGESTBLOCK ]] && LARGESTBLOCK=$BLOCK
done
if [[ $LARGESTBLOCK -gt $FIRSTBLOCK ]]; then
  for f in *.flac; do break; done                                    # The first track, in joining order
  "$FFMPEG" -nostdin -hide_banner -loglevel 0 -i "$f" -map 0:a -frame_size "$LARGESTBLOCK" -y "$CONFDIR/tmp/spec-firsttrack.flac"
  [[ -s $CONFDIR/tmp/spec-firsttrack.flac ]] && MERGEFIRST="$CONFDIR/tmp/spec-firsttrack.flac"
fi

for f in *.flac; do
  filename=$(basename "$f")
  albumdir=$(dirname "$(pwd)"/"$f")
  if [[ -n $MERGEFIRST ]]; then                                      # Track 1's re-encoded copy stands in for it
    echo "file +^+^+$MERGEFIRST+^+^+" >> "$CONFDIR/tmp/spec-tracklist.txt"; MERGEFIRST=""
  else
    echo "file +^+^+$(pwd)/$filename+^+^+" >> "$CONFDIR/tmp/spec-tracklist.txt"
  fi
done
$SEDPROG -i "s/'/'\\\''/g" "$CONFDIR/tmp/spec-tracklist.txt"  # Parse tracklist and replace "inner" single quotes with escaped version
$SEDPROG -i "s/+^+^+/'/g" "$CONFDIR/tmp/spec-tracklist.txt"   # Parse triple plusses and replace then with vanilla single quotes
}

function display_spectrum {
tput civis
create_filelist
MESSAGE="Frequency Analysis in progress... :"
"$FFMPEG" -nostdin -hide_banner -loglevel 0 -f concat -safe 0 -i "$CONFDIR/tmp/spec-tracklist.txt" -max_muxing_queue_size 900000 "$CONFDIR/tmp/spectrum.flac" & spinner
rm -f "$CONFDIR/tmp/spec-tracklist.txt" "$CONFDIR/tmp/spec-firsttrack.flac" 2>/dev/null

if [[ -f $CONFDIR/tmp/spectrum.flac ]]; then
  "$FFMPEG" -nostdin -hide_banner -loglevel 0 -i "$CONFDIR/tmp/spectrum.flac" -lavfi showspectrumpic=s=1024x1024 "$CONFDIR/tmp/spectrum.png"
  if [[ $(uname -a) == *"Darwin"* ]]; then
    qlmanage -p "$CONFDIR/tmp/spectrum.png" >/dev/null 2>&1
  else
    xdg-open "$CONFDIR/tmp/spectrum.png" >/dev/null 2>&1                 # Opens in the desktop's usual image viewer
  fi
fi
rm -rf "$CONFDIR/tmp/spectrum.flac" 2>/dev/null                    # The picture is kept until the next analysis: on Linux the viewer opens it after we return
tput cvvis
}

shopt -s nullglob; flac_count=(*.flac); shopt -u nullglob; FLACCOUNT=${#flac_count[@]}   # nullglob only for this count: left on, it breaks file counts elsewhere
check_diskspace
check_writeok

if [[ $NOSPACE -eq 0 && $WRITEOK -eq 1 && FLACCOUNT -ne 0 ]]; then
  display_spectrum
else
  if [[ $NOSPACE -eq 1 ]]; then
    dialog --stdout --backtitle "Semplice Frequency Analysis" --title " Insufficient Free Space " --msgbox "\nSemplice needs at least 15GB of free space in its working folder ($CONFDIR/tmp) to perform a spectrum analysis, but only $FREESPACE GB appear to be available. No frequency analysis can therefore be performed.\n\nPress OK to go back to the main menu." 12 80
  elif [[ $WRITEOK -eq  0 ]]; then
    dialog --stdout --backtitle "Semplice Frequency Analysis" --title " No write privileges " --msgbox "\nTo perform a spectrum analysis, Semplice needs to be able to write to its working folder ($CONFDIR/tmp), but that permission does not seem to be available. No frequency analysis can therefore be performed.\n\nPress OK to go back to the main menu." 12 80
  elif [[ $FLACCOUNT -eq 0 ]]; then
    dialog --stdout --backtitle "Semplice Spectrum Analysis" --title " No FLACs to analyse " --msgbox "\nNo FLAC files detected in current working directory, so no spectrum analysis is possible. \n\nPress OK to go back to the main menu." 12 80   
  fi
fi
