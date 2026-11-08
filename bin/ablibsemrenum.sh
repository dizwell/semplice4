#!/usr/bin/env bash
####################################################################
#
# ablibsemrenum: routine for renumbering tracks from a specified
# starting point. Files are renamed to match, using the track
# title as well as the new track number, if it exists.
#
####################################################################
# Check the first FLAC for writeability
f=$(find "$(pwd)" -maxdepth 1 -name "*.flac" | sort | head -n 1)
if [[ -w $f ]]; then
  :
else
  dialog --title " Semplice Track Renumbering " --msgbox "\\n\\nThere are files in this folder of FLACs that are not writeable, so we cannot continue.\\n\\nClick OK to return to the main menu." 12 70
  BREAKME=1
  return
fi

USRNUM=$(dialog --backtitle "Semplice FLAC Tagging" --title " Renumbering tracks " --inputbox "\n\nEnter a starting track number, between 1 and 99:" 12 90 3>&1 1>&2 2>&3 3>&-)
exitStatus=$?
if [[ $exitStatus -eq 1 ]]; then
  RENUM_START=1
else
  RENUM_START=$USRNUM
fi

if [[ -z $RENUM_START ]]; then RENUM_START=1; fi                                 # If they cancel, set to 0
if [[ $RENUM_START == *"+"* ]]; then RENUM_START="${RENUM_START//+}"; fi         # If they supply a "+", strip it
if [[ $RENUM_START == *"-"* ]]; then RENUM_START="${RENUM_START//-}"; fi         # If they supply a "-", strip it

if ! [[ -z $RENUM_START ]]; then
  if ! [[ $RENUM_START =~ ^[0-9]+$ ]] ; then                                     # If non-numeric characters are present, the default of 1 applies
    RENUM_START=1
  fi
fi

TRACKNO=$RENUM_START

for f in *.flac; do
  tag=TRACKNUMBER;metaflac $UTFCHARS "--remove-tag=$tag" "$f"
  tag=TRACKNUMBER;metaflac $UTFCHARS "--set-tag=$tag=$TRACKNO" "$f"

  TRACKTITLE=$(metaflac $UTFCHARS --show-tag=Title "$f" | $SEDPROG 's/.*=//g')
  if [[ -z $TRACKTITLE ]]; then
    TRACKTITLE="track"
  fi

  FIXEDTRACK="${TRACKNO#0}"		# 2-digit numbers with leading zeroes causing problems for printf. This fixes that.
  FILETITLE=$(tr '~#%&<>:"/\|?*' '_' <<< "$TRACKTITLE") # Make file names NTFS-safe
  mv -f "$f" "$(printf "%02d" $FIXEDTRACK)"\ -\ "$FILETITLE.flac" 2>/dev/null
  TRACKNO=$((TRACKNO+1))
done
