#!/usr/bin/env bash
####################################################################
#
# semtags: routine for setting principal tags for whole album
# Note we use the set-tags-from-file here. That's because we're
# prompting for the tags in the right order, and hence the order
# of the tags in the text file is known.
#
####################################################################
BREAKME=0
source "$CONFDIR/bin/semtput.sh" 
source "$CONFDIR/bin/semspin.sh"

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

# Checks to see if there is already album art embedded or not
function check_art {
f=$(find . -name "*.flac" | sort | head -n 1)
if [[ $(metaflac --list --block-type=PICTURE "$f" | wc -l) -eq 0 ]]; then
  ARTEMBEDDED=0
else
  ARTEMBEDDED=1
fi
}

# Check the first FLAC for writeability
f=$(find "$(pwd)" -maxdepth 1 -name "*.flac" | sort | head -n 1)
if [[ -w $f ]]; then
  :
else
  dialog --title "Semplice Album Tags" --msgbox "\\n\\nEither this folder contains no FLACs at all; or it contains FLACs one or more of which is not writeable. We cannot continue at this time.\\n\\nClick OK to return to the main menu." 12 70
  BREAKME=1
  return
fi

[[ -z $2 ]] && set -- "$1" "meta"
source "$CONFDIR/txt/programvariables.txt"

dialog --backtitle "Semplice FLAC Tagging" --title " Pick a source for metadata prompts " --yes-label " Reuse previous submission " --no-label " Read existing metadata " --yesno "\n\nDo you want to edit the existing metadata, if there is any? Or would you prefer to re-use the same metadata you supplied the last time Semplice was used?" 10 90
exitStatus=$?

# If they say 'Read existing' (exit status=1) we read any existing metadata tag and use that
# If they say 'Reuse previous' (exist status=0), we fetch prior metadata from a text file
# If they hit escape (exit status=255), we return to the main menu
if [[ $exitStatus -eq 1 ]]; then
  READMETA=1; READPRIOR=0
elif [[ $exitStatus -eq 0 ]]; then
  READMETA=0; READPRIOR=1
elif [[ $exitStatus -eq 255 ]]; then
  BREAKME=1
fi

function album_prompt {
# If the metadata option has been taken, read metadata from first FLAC in folder and use that as prompts.
# If the prior submission option has been taken, read that prior submission and use that to prompt.

if [[ $READMETA -eq 1 ]]; then
  if [[ $GUESSME -eq 0 ]]; then
    f=$($FDPROG -g "*.flac" | sort | head -n 1)
    NEWCOMPOSER=$(metaflac $UTFCHARS --show-tag=Artist "$f" | $SEDPROG 's/.*=//g'); NEWCOMPOSER=${NEWCOMPOSER//[$'\t\r\n']}
    NEWCOMPOSITION=$(metaflac $UTFCHARS --show-tag=Album "$f" | $SEDPROG 's/.*=//g'); NEWCOMPOSITION=${NEWCOMPOSITION//[$'\t\r\n']}
    NEWPERFORMER=$(metaflac $UTFCHARS --show-tag=Performer "$f" | $SEDPROG 's/.*=//g'); NEWPERFORMER=${NEWPERFORMER//[$'\t\r\n']}
    NEWGENRE=$(metaflac $UTFCHARS --show-tag=Genre "$f" | $SEDPROG 's/.*=//g'); NEWGENRE=${NEWGENRE//[$'\t\r\n']}
    NEWYEAR=$(metaflac $UTFCHARS --show-tag=Date "$f" | $SEDPROG 's/.*=//g'); NEWYEAR=${NEWYEAR//[$'\t\r\n']}    
  else
    unset NEWCOMPOSER
    unset NEWCOMPOSITION
    unset NEWPERFORMER
    unset NEWGENRE
    unset NEWYEAR
  fi

  if [[ -z $NEWCOMPOSITION ]]; then  NEWCOMPOSITION=$(basename "$(pwd)"); fi

  # Guess the recording year and distinguished artist from the folder name,
  # assuming that the folder name is in extended composition name format (i.e, CompositionName (Artist - Year))
  # The code is looking for the last open bracket in the folder name as the string delimiter.
  # It then splits on hyphen. The first field is the distinguishing artist, the second is the year.
  # Both fields are whitespace-trimmed.

  if [[ -z $NEWYEAR ]]; then
    NEWYEAR=$(echo "$NEWCOMPOSITION" | awk -F "(" '{print $(NF)}' | awk -F '-' '{print $2}' | awk -F ")" '{print $1}' | awk '{$1=$1};1')
    if ! [[ $NEWYEAR =~ ^[0-9]+$ ]] ; then
      NEWYEAR=""
    fi
  fi

  if [[ -z $NEWPERFORMER ]]; then
    NEWPERFORMER=$(echo "$NEWCOMPOSITION" | awk -F "(" '{print $(NF)}' | awk -F '-' '{print $1}' | awk -F ")" '{print $1}' | awk '{$1=$1};1')
  fi

  if [[ -z $NEWGENRE ]]; then         # Convoluted guessing game for if NEWGENRE is blank
    case "${NEWCOMPOSITION^^}" in
      *SYMPHON* ) NEWGENRE="Symphonic";;
      *SINFONI* ) NEWGENRE="Symphonic";;
      *CONCERTO* ) NEWGENRE="Concerto";;
      *QUARTET* ) NEWGENRE="Quartet";;
      *SONATA* ) NEWGENRE="Chamber";;
      *PIANO* ) NEWGENRE="Keyboard";;
      *ORGAN* ) NEWGENRE="Keyboard";;
      *HARPSICHORD* ) NEWGENRE="Keyboard";;
      *INCIDENTAL* ) NEWGENRE="Film - Theatre - Radio";;
      *REQUIEM* ) NEWGENRE="Choral";;
      *MISSA* ) NEWGENRE="Choral";;
      *MASS* ) NEWGENRE="Choral";;
    esac
  fi
elif [[ $SOURCETAG == "text" ]]; then
  if [[ -f $CONFDIR/txt/prior.txt ]]; then
    NEWCOMPOSER=$(cat "$CONFDIR/txt/prior.txt" | $SEDPROG -n 1p | $SEDPROG 's/.*=//g')
    NEWCOMPOSITION=$(cat "$CONFDIR/txt/prior.txt" | $SEDPROG -n 3p | $SEDPROG 's/.*=//g')
    NEWGENRE=$(cat "$CONFDIR/txt/prior.txt" | $SEDPROG -n 4p | $SEDPROG 's/.*=//g')
    NEWPERFORMER=$(cat "$CONFDIR/txt/prior.txt" | $SEDPROG -n 5p | $SEDPROG 's/.*=//g')
    NEWYEAR=$(cat "$CONFDIR/txt/prior.txt" | $SEDPROG -n 6p | $SEDPROG 's/.*=//g')
  fi
fi

exec 3>&1
# Store data to $VALUES variable
VALUES=$(dialog --ok-label "Next Page" --extra-button --extra-label "  Auto-guess Tags  " \
  --backtitle "Semplice FLAC Tagging: Recording-wide metadata tag details (1 of 2)" \
  --title " Recording Details " \
  --form "" 12 90 0 \
    "Composer:"                1 1	"$NEWCOMPOSER"      1 24 65 256 \
    "Composition:"             2 1	"$NEWCOMPOSITION"  	2 24 65 256 \
    "Distinguishing Artist:"   3 1	"$NEWPERFORMER"  	3 24 65 256 \
    "Genre:"                   4 1	"$NEWGENRE"         4 24 30 30 \
    "Recording Year:"          5 1	"$NEWYEAR"          5 24 6 4 \
2>&1 1>&3)
exitStatus=$?
exec 3>&-

if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then             # They pressed ESC or Cancel: do nothing
  BREAKME=1
elif [[ $exitStatus -eq 3 ]]; then                                      # They pressed Auto-Guess
  BREAKME=0; GUESSME=1
  album_prompt
  GUESSME=0
else                                                                  # They made a normal submit of the tags
  BREAKME=0
  # Separate out the response into individual tag values
  NEWCOMPOSER=$(echo "$VALUES" | $SEDPROG -n 1p)
  NEWCOMPOSITION=$(echo "$VALUES" | $SEDPROG -n 2p)
  NEWPERFORMER=$(echo "$VALUES" | $SEDPROG -n 3p)
  NEWGENRE=$(echo "$VALUES" | $SEDPROG -n 4p)
  NEWYEAR=$(echo "$VALUES" | $SEDPROG -n 5p)
  
  # On macOS, if there are accented characters, they need to be forced to be 'composed Unicode'
  # rather than 'decomposed'.
  if [[ $(uname -a) == *"Darwin"* ]] && command -v uconv >/dev/null 2>&1; then
    NEWCOMPOSER=$(echo "$NEWCOMPOSER" | uconv -x any-nfc)
    NEWCOMPOSITION=$(echo "$NEWCOMPOSITION" | uconv -x any-nfc)
    NEWPERFORMER=$(echo "$NEWPERFORMER" | uconv -x any-nfc)
    NEWGENRE=$(echo "$NEWGENRE" | uconv -x any-nfc)
  fi

  # Write the separate values out into a text file
  TAGFILE="$CONFDIR/tmp/tagfile.txt"
  echo -n "COMPOSER=" > "$TAGFILE"; echo "$NEWCOMPOSER" >> "$TAGFILE"
  echo -n "ARTIST=" >> "$TAGFILE"; echo "$NEWCOMPOSER" >> "$TAGFILE"
  echo -n "ALBUM=" >> "$TAGFILE"; echo "$NEWCOMPOSITION" >> "$TAGFILE"
  echo -n "GENRE=" >> "$TAGFILE"; echo "$NEWGENRE" >> "$TAGFILE"
  echo -n "PERFORMER=" >> "$TAGFILE"; echo "$NEWPERFORMER" >> "$TAGFILE"
  echo -n "DATE=" >> "$TAGFILE"; echo "$NEWYEAR" >> "$TAGFILE"
  echo -n "TAGDATE=" >> "$TAGFILE"; echo "$(date +%s)" >> "$TAGFILE"
  cp "$TAGFILE" "$CONFDIR/txt/prior.txt"
fi
}

function performers_prompt {	
if [[ $BREAKME -eq 0 ]]; then
  tput cvvis
  if [[ $READMETA -eq 1 ]]; then
    f=$(find "$(pwd)" -name "*.flac" | sort | head -n 1)
    METACOMMENT=$(metaflac $UTFCHARS --show-tag=Comment "$f" | $SEDPROG 's/.*=//g')
    if [[ -z $METACOMMENT ]]; then METACOMMENT="No existing metadata found. Supply your own (ctrl+U to clear this message)."; fi
    COMMENTPROMPT="$METACOMMENT"
  elif [[ $READPRIOR -eq 1 ]]; then
    TEXTCOMMENT=$(cat "$CONFDIR/tmp/performers.text")
    COMMENTPROMPT="$TEXTCOMMENT"
  elif [[ $exitStatus -eq 255 ]]; then
    BREAKME=1
  fi

  if [[ $BREAKME -eq 0 ]]; then
    echo "$COMMENTPROMPT" > "$CONFDIR/tmp/commentprompt.txt"
    # And finally, display the tag text in a prompt for them to either accept as-is or
    # knock into shape as they desire. Their text output from this dialog gets written to
    # the performers.txt file
    dialog --ok-label "Submit" --backtitle "Semplice FLAC Tagging: Recording-wide metadata tag details (2 of 2)" --title " Performer Details " --editbox "$CONFDIR/tmp/commentprompt.txt" 12 90 2>"$CONFDIR/tmp/performers.text"
    exitStatus=$?
    if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then
      BREAKME=1
    else
      # The new performers.txt file contents are then loaded into a COMMENTS variable for
      # actual writing of the tags, done later
      COMMENTS=$(flatten_lines < "$CONFDIR/tmp/performers.text")     # One line only: line breaks become single spaces
      
      # On macOS, if there are accented characters, they need to be forced to be 'composed Unicode'
      # rather than 'decomposed'.
      if [[ $(uname -a) == *"Darwin"* ]] && command -v uconv >/dev/null 2>&1; then
        COMMENTS=$(echo "$COMMENTS" | uconv -x any-nfc)
      fi      
    fi
  fi
fi
}

function auto_tracknums {
TRACKNO=1
for f in *.flac; do
  metaflac "--remove-tag=TRACKNUMBER" "$f"
  metaflac "--set-tag=TRACKNUMBER=$TRACKNO" "$f"
  FIXEDTRACK="${TRACKNO#0}"		# 2-digit numbers with leading zeroes causing problems for printf. This fixes that.

  TRACKTITLE=$(metaflac $UTFCHARS --show-tag=Title "$f" | $SEDPROG 's/.*=//g')
  if [[ -z $TRACKTITLE ]]; then
    TRACKTITLE="Track $FIXEDTRACK"
  fi

  FILETITLE=$(tr '~#%&<>:"/\|?*' '_' <<< "$TRACKTITLE") # Make file names NTFS-safe
  mv -f "$f" "$(printf "%02d" $FIXEDTRACK)"\ -\ "$FILETITLE.flac" 2>/dev/null
  TRACKNO=$((TRACKNO+1))
done
}

function auto_albumart {
COUNTART=0
COUNTJPG=$(ls *.jpg 2>/dev/null | wc -l); COUNTPNG=$(ls *.png 2>/dev/null | wc -l); COUNTJPEG=$(ls *.jpeg 2>/dev/null | wc -l);  COUNTART=$((COUNTJPG+COUNTPNG+COUNTJPEG))
if [[ $COUNTART -gt 0 ]]; then
  # We have some album art present. Check it's good, resize it if so, then tag the FLACs with it. Use JPGs in preference to PNGs
  # There are several scenarios:

  if [[ $COUNTJPG -gt 0 && $COUNTPNG -eq 0 && $COUNTJPEG -eq 0 ]]; then ARTXTENSION="jpg"; fi      # Only a JPG        - JPG wins
  if [[ $COUNTJPG -eq 0 && $COUNTPNG -gt 0 && $COUNTJPEG -eq 0 ]]; then ARTXTENSION="png"; fi      # Only a PNG        - PNG wins
  if [[ $COUNTJPG -eq 0 && $COUNTPNG -eq 0 && $COUNTJPEG -gt 0 ]]; then ARTXTENSION="jpeg"; fi     # Only a JPEG       - JPEG wins
  if [[ $COUNTJPG -gt 0 && $COUNTPNG -gt 0 && $COUNTJPEG -eq 0 ]]; then ARTXTENSION="jpg"; fi      # A PNG and a JPG   - JPG wins
  if [[ $COUNTJPG -eq 0 && $COUNTPNG -gt 0 && $COUNTJPEG -gt 0 ]]; then ARTXTENSION="jpeg"; fi     # A PNG and a JPEG  - JPEG wins
  if [[ $COUNTJPG -gt 0 && $COUNTPNG -eq 0 && $COUNTJPEG -gt 0 ]]; then ARTXTENSION="jpg"; fi      # A JPG and a JPEG  - JPG wins
  if [[ $COUNTJPG -gt 0 && $COUNTPNG -eq 0 && $COUNTJPEG -gt 0 ]]; then ARTXTENSION="jpg"; fi      # One of everything - JPG wins
  if [[ $COUNTJPG -gt 0 && $COUNTPNG -gt 0 && $COUNTJPEG -gt 0 ]]; then ARTXTENSION="jpg"; fi      # One of everything - JPG wins
  ARTWORK=$(ls *.$ARTXTENSION | head -1)

  # If the selected album art is internally CMYK, convert it to sRGB, because CYMK files produce weird output with libsixel
  BADIMG=$(identify "$ARTWORK" 2>/dev/null | grep CMYK | wc -l)
  if [[ $BADIMG -ne 0 ]]; then
    if [[ $CONVPROG == "convert" ]]; then
      convert "$ARTWORK" -colorspace sRGB "$ARTWORK"
    elif [[ $CONVPROG == "magick" ]]; then
      magick "$ARTWORK" -colorspace sRGB "$ARTWORK"
    fi
  fi

  GOODIMG=$(identify "$ARTWORK" 2>/dev/null | grep sRGB | wc -l)

  # Determine image size and adjust as needed
  if [[ $GOODIMG -gt 0 ]]; then
    IFS=" "; read width height < <(identify -format "%w %h" "$ARTWORK")
    if [[ $width -gt $height ]]; then BIGDIMENSION=$width; else BIGDIMENSION=$height; fi
    if [ $BIGDIMENSION -ge 1400 ]; then
      if [[ $CONVPROG == "convert" ]]; then convert "$ARTWORK" -quality 100 -resize 1400x1400\! /tmp/albumart.jpg; elif [ $CONVPROG == "magick" ]; then magick "$ARTWORK" -quality 100 -resize 1400x1400\! /tmp/albumart.jpg; fi                                      # Resize images if larger than 1400x1400, without maintaining aspect ratio
    elif [[ $BIGDIMENSION -ge 900 ]]; then
      if [[ $CONVPROG == "convert" ]]; then convert "$ARTWORK" -quality 100 -resize 900x900\! /tmp/albumart.jpg; elif [ $CONVPROG == "magick" ]; then magick "$ARTWORK" -quality 100 -resize 900x900\! /tmp/albumart.jpg; fi                                          # Resize images if larger than 900x900, without maintaining aspect ratio
    elif [[ $BIGDIMENSION -ge 500 ]]; then
      if [[ $CONVPROG == "convert" ]]; then convert "$ARTWORK" -quality 100 -resize 500x500\! /tmp/albumart.jpg; elif [ $CONVPROG == "magick" ]; then magick "$ARTWORK" -quality 100 -resize 500x500\! /tmp/albumart.jpg; fi                                          # Resize images if larger than 900x900, without maintaining aspect ratio
    else
      if [[ $CONVPROG == "convert" ]]; then convert "$ARTWORK" -quality 100 -resize ${BIGDIMENSION}x${BIGDIMENSION}\! /tmp/albumart.jpg; elif [ $CONVPROG == "magick" ]; then magick "$ARTWORK" -quality 100 -resize ${BIGDIMENSION}x${BIGDIMENSION}\! /tmp/albumart.jpg; fi  # No resizing of small images, but squaring it off, without maintaining aspect ratio
    fi

    for f in *.flac; do
      metaflac --remove --block-type=PICTURE,PADDING --dont-use-padding "$f" >/dev/null 2>&1
      metaflac --import-picture-from="/tmp/albumart.jpg" "$f" >/dev/null 2>&1
    done

    IFS=$OLDIFS
    if ! [[ -z $DELETE_ART ]] && [[ $DELETE_ART -eq 1 ]]; then
      check_art
      if [[ $ARTEMBEDDED -eq 1 ]]; then 
        rm -f "$ARTWORK" 2>/dev/null
      fi
    fi
  fi
fi
}

function apply_tags {
for f in *.flac; do
  # Now iterate through all FLACs, removing all existing tags (except Album Art), then re-load from the text file
  # and the user-input performers details
  metaflac $UTFCHARS --remove-tag=Composer "$f" 2>/dev/null
  metaflac $UTFCHARS --remove-tag=Artist "$f" 2>/dev/null
  metaflac $UTFCHARS --remove-tag=Album "$f" 2>/dev/null
  metaflac $UTFCHARS --remove-tag=Genre "$f" 2>/dev/null
  metaflac $UTFCHARS --remove-tag=Performer "$f" 2>/dev/null
  metaflac $UTFCHARS --remove-tag=Date "$f" 2>/dev/null
  metaflac $UTFCHARS --remove-tag=Tagdate "$f" 2>/dev/null
  metaflac $UTFCHARS --remove-tag=Comment "$f" 2>/dev/null
  metaflac $UTFCHARS --import-tags-from="$TAGFILE" "$f"
  metaflac $UTFCHARS --set-tag=COMMENT="$COMMENTS" "$f"
done
rm -f "$TAGFILE" 2>/dev/null
}

function customtags_prompt {
unset CUSTOMSTRING
g=$(find "$(pwd)" -name "*.flac" | sort | head -n 1)
for ((i=1; i<=9; i++)); do
  REF="CUSTOMTAG$i"
  CUSTOMTAGNAME="${!REF}"
  EXISTINGCUSTOMDATA=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAGNAME" "$g" | $SEDPROG 's/.*=//g')   # Get existing data if any, for display purposes
  CUSTOMTAGNAME="${CUSTOMTAGNAME//_/ }"
  if ! [ "$CUSTOMTAGNAME" == "XqXXqXX" ]; then
    CUSTOMSTRING+=("$i. $CUSTOMTAGNAME:" "$i" 1 "$EXISTINGCUSTOMDATA" "$i" 22 65 256)
  fi
done
exec 3>&1
VALUES=$( 2>&1 1>&3 dialog --ok-label "Submit" \
      --backtitle "Semplice FLAC Tagging" \
      --title " Supply Custom Tag Metadata " \
      --form "Custom Tags" 18 95 0 \
      "${CUSTOMSTRING[@]}"
)
exitStatus=$?
exec 3>&-
if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then
  BREAKME=1
else
  echo "$VALUES" > "$CONFDIR/tmp/customtags.txt"

  for f in *.flac; do
    if [[ $CUSTOMTAGS -eq 1 ]]; then
      metaflac $UTFCHARS --remove-tag="$CUSTOMTAG1" "$f" 2>/dev/null
      metaflac $UTFCHARS --remove-tag="$CUSTOMTAG2" "$f" 2>/dev/null
      metaflac $UTFCHARS --remove-tag="$CUSTOMTAG3" "$f" 2>/dev/null
      metaflac $UTFCHARS --remove-tag="$CUSTOMTAG4" "$f" 2>/dev/null
      metaflac $UTFCHARS --remove-tag="$CUSTOMTAG5" "$f" 2>/dev/null
      metaflac $UTFCHARS --remove-tag="$CUSTOMTAG6" "$f" 2>/dev/null
      metaflac $UTFCHARS --remove-tag="$CUSTOMTAG7" "$f" 2>/dev/null
      metaflac $UTFCHARS --remove-tag="$CUSTOMTAG8" "$f" 2>/dev/null
      metaflac $UTFCHARS --remove-tag="$CUSTOMTAG9" "$f" 2>/dev/null
    fi

    for ((t=1; t<=9; t++)); do
      TAGVALUE=$($SEDPROG "${t}q;d" $CONFDIR/tmp/customtags.txt)
      if ! [[ -z $TAGVALUE ]]; then
        REF="CUSTOMTAG$t"
        CUSTOMTAGNAME="${!REF}"
        metaflac $UTFCHARS --set-tag="$CUSTOMTAGNAME"="$TAGVALUE" "$f"
      fi
    done
  done
fi
}

if [[ $2 == "prev" ]]; then SOURCETAG=text; elif  [ $2 == "meta" ]; then SOURCETAG=meta; fi
if [[ $BREAKME -eq 0 ]]; then album_prompt; fi                       # Prompt for album-wide tags (such as composer, composition etc)
if [[ $BREAKME -eq 0 ]]; then performers_prompt; fi                  # Prompt for album-wide performing artist (i.e., COMMENT tag) details
if [[ $BREAKME -eq 0 ]]; then
  MESSAGE="Processing metadata for tracks in this folder. Please wait…  "
  apply_tags & spinner $!            # Apply the tags we just prompted for
  if [[ $1 == "auto" ]]; then
    auto_tracknums                   # Auto-renumber tracks starting at 1 (not user-definable)
    MESSAGE="Applying album art to tracks. Please wait…  "
    auto_albumart & spinner $!       # Auto-apply any single JPG or PNG found in the working folder
  fi
fi
if [[ $BREAKME -eq 0 ]]; then
  if [[ $CUSTOMTAGS -eq 1 ]]; then
    customtags_prompt                # If they've said to use custom tags, prompt for them
  fi
fi
unset BREAKME