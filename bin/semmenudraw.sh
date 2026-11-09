#!/usr/bin/env bash
####################################################################
# semmenudraw: Clear screen drawing routine
####################################################################
source "$CONFDIR/bin/semtput.sh"
if [[ $PROGVERSION == *"beta"* ]]; then LOGO_PATH="$CONFDIR/art/sempliceicosmallbeta.png"; else LOGO_PATH="$CONFDIR/art/sempliceicosmall.png"; fi
if [[ -z $LOGOSIZE ]]; then LOGOSIZE="110x110"; fi; LOGOWIDTH="${LOGOSIZE%x*}"
if [[ -z $LOGOPOS ]]; then LOGOPOS=0; fi
clear; tput cup 0 0

function sixel_graphics {
tput cup 8 56
img2sixel "$CONFDIR/art/displayalbumart.jpg" 2>/dev/null										        # Display in-terminal as-is
}

# Checks whether the first FLAC has album art and prepares the display copy. The extracted art, its
# resized display copy and the audio details are cached: they are only worked out again when the
# folder, the first FLAC (or its modification time), the number of FLACs or the display size changes.
function check_art {
local f stamp key
f=$(find . -maxdepth 1 -type f -name "*.flac" | sort | head -n 1)
if [[ -z $f ]]; then ARTEMBEDDED=0; ARTCACHEKEY=""; return; fi
stamp=$(date -r "$f" +%s 2>/dev/null)
key="$PWD|$f|$stamp|$(find . -maxdepth 1 -type f -name "*.flac" | wc -l)|$ARTSIZE"
if [[ $key == "$ARTCACHEKEY" ]]; then return; fi                             # Nothing has changed: reuse everything from last time

rm -f "$CONFDIR/art/albumart.jpg" "$CONFDIR/art/displayalbumart.jpg" 2>/dev/null
if [[ $(metaflac --list --block-type=PICTURE "$f" 2>/dev/null | wc -l) -eq 0 ]]; then
  ARTEMBEDDED=0
else
  metaflac --export-picture-to="$CONFDIR/art/albumart.jpg" "$f" 2>/dev/null
  ARTEMBEDDED=1
  if [[ $CONVPROG == convert ]]; then
    convert -resize "${ARTSIZE}x${ARTSIZE}!" "$CONFDIR/art/albumart.jpg" "$CONFDIR/art/displayalbumart.jpg"
  else
    magick "$CONFDIR/art/albumart.jpg" -resize "${ARTSIZE}x${ARTSIZE}!" "$CONFDIR/art/displayalbumart.jpg"
  fi
fi
FILEDEPTH=$(metaflac --show-bps "$f" 2>/dev/null)
FILESAMPLE=$(metaflac --show-sample-rate "$f" 2>/dev/null)
FLACCOUNT=$(find . -maxdepth 1 -type f -name "*.flac" | wc -l)
ARTCACHEKEY=$key
}

function wordlogo { 
tput setaf $LOGO 
tput cup  8 54; echo "  ____                      _ _           "
tput cup  9 54; echo " / ___| ___ _ __ ___  _ __ | (_) ___ ___  "
tput cup 10 54; echo " \___ \/ _ \ '_ \` _ \| '_ \| | |/ __/ _ \ "
tput cup 11 54; echo "  ___)|  __/ | | | | | |_) | | | (4̲|  __/ "
tput cup 12 54; echo " |____/\___|_| |_| |_| .__/|_|_|\___\___| "
tput cup 13 54; echo "                     |_|                  "
}

function sixel_logo {
wordlogo                                                 
tput cup 14 60; tput setaf $SPINNER; echo -en "♬♪ "; tput setaf $INFOTEXT; echo -en "The Digital Music Manager"; tput setaf $SPINNER; echo -en " ♬♪"
tput cup 16 $LOGO_POSITION; img2sixel -w $LOGOWIDTH "$LOGO_PATH" 2>/dev/null; printf "%s\n"
}

function audio_data {
# Values are worked out (and cached) by check_art
tput setaf $DRAWLINES; tput cup 1 75; echo -en "Bitdepth    : "; tput setaf $INFOTEXT; echo -en "$FILEDEPTH bits"
tput setaf $DRAWLINES; tput cup 2 75; echo -en "Sample Rate : "; tput setaf $INFOTEXT; echo -en "$FILESAMPLE Hz"
if [[ $FLACCOUNT -eq 1 ]]; then
  tput setaf $DRAWLINES; tput cup 3 75; tput setaf $INFOTEXT; echo -e "Single FLAC"
else
  tput setaf $DRAWLINES; tput cup 3 75; tput setaf $INFOTEXT; echo -e "Multi FLAC"
fi
}

if [[ $1 == "short" ]]; then
  tput setaf $DRAWLINES; echo -e "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                   │
│                                                                                                   │
│                                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘"
elif  [[ $1 == "playing" ]]; then
  tput setaf $DRAWLINES; echo -e  "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                   │
│                                                                                                   │
│                                                                                                   │
├─────────────────────────────────────────────────┬─────────────────────────────────────────────────┤
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
├─────────────────────────────────────────────────┴─────────────────────────────────────────────────┤
│                                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘"
else
  tput setaf $DRAWLINES; echo  "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                   │
│                                                                                                   │
│                                                                                                   │
├───────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                   │
├─────────────────────────────────────────────────┬─────────────────────────────────────────────────┤
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
├─────────────────────────────────────────────────┴─────────────────────────────────────────────────┤
│                                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘"
fi

if ! [[ -f "$CONFDIR/art/sempliceicosmall.png" ]]; then
  if [[ $CONVPROG == convert ]]; then
    convert "$CONFDIR/art/sempliceico.png" -resize "$CONFLOGOSIZE" "$CONFDIR/art/sempliceicosmall.png" 2>/dev/null
  elif [[ $CONVPROG == magick ]]; then
    magick "$CONFDIR/art/sempliceico.png" -resize "$CONFLOGOSIZE" "$CONFDIR/art/sempliceicosmall.png" 2>/dev/null
  fi
fi

LOGO_POSITION=$((69 + $LOGOPOS ))

tput cup  1 4; tput setaf $SPINNER; echo -en "♬♪ "; tput setaf $LOGO; echo -en "Semplice: The Digital Music Manager"; tput setaf $SPINNER; echo -en " ♬♪"
tput cup  2 4; tput setaf $LOGO; echo "Copyright © Howard Rogers 2021-2026, Version $PROGVERSION"

check_art

if [[ $ARTEMBEDDED -eq 0 ]]; then 
  tput setaf $LOGO
  tput cup 8 54; echo -en "$Line1"
  tput cup 9 54; echo -en "$Line2"
  tput cup 10 54; echo -en "$Line3"
  tput cup 11 54; echo -en "$Line4"
  tput cup 12 54; echo -en "$Line5"
  tput cup 13 54; echo -en "$Line6"
  tput cup 14 54; echo -en "$Line7"
  tput cup 15 54; echo -en "$Line8"
  sixel_logo
 else
  sixel_graphics
  audio_data
fi