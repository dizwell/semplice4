#!/usr/bin/env bash
####################################################################
#
# semart: routine for prompting for an art image that is
# then embedded in the FLACs contained in a folder. Don't prompt
# if an embedded image is already present and the script is invoked
# as part of the all-in-one tagging process.
#
####################################################################
source "$CONFDIR/bin/semtput.sh"
source "$CONFDIR/bin/semspin.sh"
CURDIR=$(pwd); GOODART=0 ARTEMBEDDED=0

# Check the first FLAC for writeability
f=$(find "$(pwd)" -maxdepth 1 -name "*.flac" | sort | head -n 1)
if [[ -w $f ]]; then
  :
else
  dialog --title " Semplice Embedded Art " --msgbox "\\n\\nThere are files in this folder of FLACs that are not writeable, so we cannot continue.\\n\\nClick OK to return to the main menu." 12 70
  BREAKME=1
  return
fi

# Checks to see if there is already album art embedded or not
function check_art {
f=$(find . -name "*.flac" | sort | head -n 1)
if [[ $(metaflac --list --block-type=PICTURE "$f" | wc -l) -eq 0 ]]; then
  ARTEMBEDDED=0
else
  ARTEMBEDDED=1
fi
}

function replace_prompt {
dialog --backtitle "Semplice FLAC Tagging" --title " Replace existing embedded album art? " --yes-label " Replace with external art " --no-label " Keep existing albumart " --yesno "\nThe FLACs in this folder already have embedded album art, but the folder contains additional standalone art files. Do you wish to replace the existing embedded album art with one of these files?" 12 90
exitStatus=$?
# If they say 'no' (exit status=1), then we are NOT to replace existing artwork; otherwise, we are.
if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then
  REPLACEART=0
else
  REPLACEART=1
fi
}

function file_prompt {
ARTFILE=$(dialog --backtitle "Semplice FLAC Tagging"  --stdout --title " Pick a JPG or PNG album art file " --fselect "$CURDIR" 12 90)
exitStatus=$?
if [[ $exitStatus -eq 255 ]]; then smenuoptions tag; fi
if [[ $exitStatus -eq 1 ]]; then
  GOODART=0
elif [[ "${ARTFILE^^}" == *"JPG"* || "${ARTFILE^^}" == *"JPEG"* || "${ARTFILE^^}" == *"PNG"* ]]; then
  GOODART=1
else
  dialog --stdout --backtitle "Semplice Audio CD Ripping" --msgbox "Embedded album art needs to be supplied in JPG or PNG format only!" 8 80
fi
}

function apply_albumart {
# If the selected album art is not sRGB (CMYK, which displays strangely with libsixel, or greyscale, which
# would otherwise be skipped), convert it to sRGB. TrueColor stops ImageMagick storing a grey picture as Gray again.
if [[ $("$CONVPROG" identify -format "%[colorspace]" "$ARTFILE[0]" 2>/dev/null) != "sRGB" ]]; then
  "$CONVPROG" "$ARTFILE" -colorspace sRGB -type TrueColor "$ARTFILE" 2>/dev/null
fi

GOODIMG=$("$CONVPROG" identify "$ARTFILE" 2>/dev/null | grep sRGB | wc -l)
if [[ $GOODIMG -gt 0 ]]; then
  IFS=" "; read width height < <("$CONVPROG" identify -format "%w %h" "$ARTFILE" 2>/dev/null)
  if [[ $width -gt $height ]]; then BIGDIMENSION=$width; else BIGDIMENSION=$height; fi
  if [[ $BIGDIMENSION -ge 1400 ]]; then
    "$CONVPROG" "$ARTFILE" -quality 100 -resize 1400x1400\! /tmp/albumart.jpg 2>/dev/null   # Resize images if larger than 1400x1400, without maintaining aspect ratio
  elif [[ $BIGDIMENSION -ge 900 ]]; then
    "$CONVPROG" "$ARTFILE" -quality 100 -resize 900x900\! /tmp/albumart.jpg 2>/dev/null       # Resize images if larger than 900x900, without maintaining aspect ratio
  elif [[ $BIGDIMENSION -ge 500 ]]; then
    "$CONVPROG" "$ARTFILE" -quality 100 -resize 500x500\! /tmp/albumart.jpg 2>/dev/null       # Resize images if larger than 500x500, without maintaining aspect ratio
  else
    "$CONVPROG" "$ARTFILE" -quality 100 -resize ${BIGDIMENSION}x${BIGDIMENSION}\! /tmp/albumart.jpg 2>/dev/null       # No resizing of small images, but squaring it off, without maintaining aspect ratio
  fi
  MESSAGE="Applying album art. Please wait... "
  for f in *.flac; do
    metaflac --remove --block-type=PICTURE,PADDING --dont-use-padding "$f" >/dev/null 2>&1
    metaflac --import-picture-from="/tmp/albumart.jpg" "$f" >/dev/null 2>&1  & tput cup 25 4; echo -en "Applying album art to tracks. Please wait…  "; tput cup 25 18; spinner $!
  done
  IFS=$OLDIFS
  
  if [[ $DELETE_ART -eq 1 ]]; then              # semparse.sh always sets DELETE_ART to 0 or 1 
    check_art
    if [[ $ARTEMBEDDED -eq 1 ]]; then 
      rm -f "$ARTFILE" >/dev/null
    fi
  fi
fi
}

# Determining whether we already have embedded artwork is done by invoking check_art and setting ARTEMBEDDED
check_art

if [[ $ARTEMBEDDED -eq 1 ]]; then                         # And art work is already embedded
  replace_prompt                                      # So ask if they want to use one or the other
  if [[ $REPLACEART -eq 1 ]]; then                      # And if they say to replace, make it so
    file_prompt
    if [[ $GOODART -eq 1 ]]; then apply_albumart; fi      # So prompt to find a suitable art file
  fi
else                                                    # No embedded artwork
  file_prompt
  if [[ $GOODART -eq 1 ]]; then apply_albumart; fi      # So prompt to find a suitable art file
fi
