#!/usr/bin/env bash
####################################################################
#
# semxart: routine for extracting album art from the first
# FLAC in a folder and displaying it and/or saving it
#
####################################################################
OLDIFS=$IFS

function extract_art {
f=$(ls *.flac | head -1)
if ! [[ -z $f ]]; then
  CURDIR=$(pwd)
  ARTEXISTS=$(metaflac "$f" --list --block-type=PICTURE | wc -l)
  if ! [[ $ARTEXISTS -eq 0 ]]; then
    metaflac  --export-picture-to="$CURDIR/albumart.jpg" "$f"
    if [[ $DISPLAYONEXTRACT -eq 1 ]]; then
      IFS=" "; read width height < <("$CONVPROG" identify -format "%w %h" "$CURDIR/albumart.jpg" 2>/dev/null)           # If we are required to display the image, then if it's bigger than 500x500, halve its dimensions.
      if [[ $width -gt $height ]]; then BIGDIMENSION=$width; else BIGDIMENSION=$height; fi
      if [[ $BIGDIMENSION -ge 500 ]]; then
        "$CONVPROG" "$CURDIR/albumart.jpg" -resize 50% "$CURDIR/albumart_half.jpg" 2>/dev/null
        if [[ $(uname -a) == *"Darwin"* ]]; then
          qlmanage -p "$CURDIR/albumart_half.jpg" >/dev/null 2>&1
        else
          xdg-open "$CURDIR/albumart_half.jpg" >/dev/null 2>&1
        fi
      else
        if [[ $(uname -a) == *"Darwin"* ]]; then
          qlmanage -p "$CURDIR/albumart.jpg" >/dev/null 2>&1
        else      
          xdg-open "$CURDIR/albumart.jpg" >/dev/null 2>&1
        fi
      fi
      IFS=$OLDIFS
    fi
  else
    dialog --stdout --backtitle "Semplice FLAC Tagging" --msgbox "No album artwork is present in the first FLAC of the current folder, so nothing can be extracted." 8 80
  fi
fi
}

extract_art
