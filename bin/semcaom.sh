#!/usr/bin/env bash
####################################################################
#
# semcaom: routine for merging per-track FLACs into single
# whole-composition FLACs
#
####################################################################
CUMPLAYLENGTH=0; COUNTER=1
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

function axiom_check {
# Axiom 1: There are 8 necessary tags: make sure they're all set to something!
FIRST_TIME=1
NUM='^[0-9]+$'
AXIOM_ERRORS=0
for f in *.flac; do
  COMPOSER=$(get_tag Composer "$f")
  ARTIST=$(get_tag Artist "$f")
  PERFORMER=$(get_tag Performer "$f")
  ALBUM=$(get_tag Album "$f")
  GENRE=$(get_tag Genre "$f")
  COMMENT=$(get_tag Comment "$f")
  TRACKNUMBER=$(get_tag TRACKNUMBER "$f")
  YEAR=$(get_tag Date "$f")
  TITLE=$(get_tag Title "$f")

  if [[ -z $COMPOSER || -z $ARTIST || -z $PERFORMER || -z $ALBUM || -z $GENRE || -z $COMMENT || -z $TRACKNUMBER || -z $TITLE ]]; then
    if [[ -z $COMPOSER ]]; then
        dialog --stdout --backtitle "Semplice SuperFLAC Creation" --title " Axiom 1 Violation! " --msgbox "\nThe COMPOSER tag is missing. A SuperFLAC cannot be created from tracks which don't match the Axioms of Classical Tagging.\n\nSee: https://bbritten.com/articles/axioms\n\nFile affected: $f" 15 80
    elif [[ -z $ARTIST ]]; then
        dialog --stdout --backtitle "Semplice SuperFLAC Creation" --title " Axiom 1 Violation! " --msgbox "\nThe ARTIST tag is missing. A SuperFLAC cannot be created from tracks which don't match the Axioms of Classical Tagging.\n\nSee: https://bbritten.com/articles/axioms\n\nFile affected: $f" 15 80
    elif [[ -z $PERFORMER ]]; then
        dialog --stdout --backtitle "Semplice SuperFLAC Creation" --title " Axiom 1 Violation! " --msgbox "\nThe PERFORMER tag is missing. A SuperFLAC cannot be created from tracks which don't match the Axioms of Classical Tagging.\n\nSee: https://bbritten.com/articles/axioms\n\nFile affected: $f" 15 80
    elif [[ -z $ALBUM ]]; then
        dialog --stdout --backtitle "Semplice SuperFLAC Creation" --title " Axiom 1 Violation! " --msgbox "\nThe ALBUM tag is missing. A SuperFLAC cannot be created from tracks which don't match the Axioms of Classical Tagging.\n\nSee: https://bbritten.com/articles/axioms\n\nFile affected: $f" 15 80
    elif [[ -z $GENRE ]]; then
        dialog --stdout --backtitle "Semplice SuperFLAC Creation" --title " Axiom 1 Violation! " --msgbox "\nThe GENRE tag is missing. A SuperFLAC cannot be created from tracks which don't match the Axioms of Classical Tagging.\n\nSee: https://bbritten.com/articles/axioms\n\nFile affected: $f" 15 80
    elif [[ -z $COMMENT ]]; then
        dialog --stdout --backtitle "Semplice SuperFLAC Creation" --title " Axiom 1 Violation! " --msgbox "\nThe COMMENT tag is missing. A SuperFLAC cannot be created from tracks which don't match the Axioms of Classical Tagging.\n\nSee: https://bbritten.com/articles/axioms\n\nFile affected: $f" 15 80
    elif [[ -z $TRACKNUMBER ]]; then
        dialog --stdout --backtitle "Semplice SuperFLAC Creation" --title " Axiom 1 Violation! " --msgbox "\nThe TRACKNUMBER tag is missing. A SuperFLAC cannot be created from tracks which don't match the Axioms of Classical Tagging.\n\nSee: https://bbritten.com/articles/axioms\n\nFile affected: $f" 15 80
    elif [[ -z $TITLE ]]; then
        dialog --stdout --backtitle "Semplice SuperFLAC Creation" --title " Axiom 1 Violation! " --msgbox "\nThe TITLE tag is missing. A SuperFLAC cannot be created from tracks which don't match the Axioms of Classical Tagging.\n\nSee: https://bbritten.com/articles/axioms\n\nFile affected: $f" 15 80
    fi
    ((AXIOM_ERRORS++))
  fi
  if [[ $AXIOM_ERRORS -ne 0 ]]; then break; fi

# Axiom 2: ARTIST must equal COMPOSER
  if [[ ! $COMPOSER == $ARTIST ]]; then
    dialog --stdout --backtitle "Semplice SuperFLAC Creation" --title " Axiom 2 Violation! " --msgbox "\nThe ARTIST and COMPOSER tags need to be identical. A SuperFLAC cannot be created from tracks which don't match the Axioms of Classical Tagging.\n\nSee: https://bbritten.com/articles/axioms\n\nFile affected: $f" 15 80
    ((AXIOM_ERRORS++))
  fi
  if [[ $AXIOM_ERRORS -ne 0 ]]; then break; fi

# Axiom 7: YEAR must equal recording year, not some sort of calendar date. That means it must be purely numeric and only four digits long
  if ! [[ $YEAR =~ $NUM ]]; then
    dialog --stdout --backtitle "Semplice SuperFLAC Creation" --title " Axiom 7 Violation! " --msgbox "\nThe YEAR tag needs to be a 4-digit year. A SuperFLAC cannot be created from tracks which don't match the Axioms of Classical Tagging.\n\nSee: https://bbritten.com/articles/axioms\n\nFile affected: $f" 15 80
    ((AXIOM_ERRORS++))
  fi

  if ! [[ ${#YEAR} -eq 4 ]]; then
    dialog --stdout --backtitle "Semplice SuperFLAC Creation" --title " Axiom 7 Violation! " --msgbox "\nThe YEAR tag needs to be a 4-digit year. A SuperFLAC cannot be created from tracks which don't match the Axioms of Classical Tagging.\n\nSee: https://bbritten.com/articles/axioms\n\nFile affected: $f" 15 80
    ((AXIOM_ERRORS++))
  fi
  if [[ $AXIOM_ERRORS -ne 0 ]]; then break; fi

# Axiom 9 (implied): Track numbers must all be purely numeric and the first track must have track number 1.
  if ! [[ $TRACKNUMBER =~ $NUM ]]; then
    dialog --stdout --backtitle "Semplice SuperFLAC Creation" --title " Axiom 9 Violation! " --msgbox "\nThe TRACKNUMBER tag needs to be strictly numeric, starting at 1: no hashes, slashes or punctuation allowed. A SuperFLAC cannot be created from tracks which don't match the Axioms of Classical Tagging.\n\nSee: https://bbritten.com/articles/axioms\n\nFile affected: $f" 15 80
    ((AXIOM_ERRORS++))
  fi

  if ! [[ $TRACKNUMBER -eq 1 ]] && [[ $FIRST_TIME -eq 1 ]]; then
    dialog --stdout --backtitle "Semplice SuperFLAC Creation" --title " Axiom 9 Violation! " --msgbox "\nThe TRACKNUMBER tags needs to start at 1. A SuperFLAC cannot be created from tracks which don't match the Axioms of Classical Tagging.\n\nSee: https://bbritten.com/articles/axioms\n\nFile affected: $f" 15 80
    ((AXIOM_ERRORS++))
  fi
  if [[ $AXIOM_ERRORS -ne 0 ]]; then break; fi

# Axiom 16: there needs to be album art, at least in the first FLAC in the folder
  if [[ $FIRST_TIME -eq 1 ]]; then
    if [[ $(metaflac --list --block-type=PICTURE "$f" | wc -l) -eq 0 ]]; then
      dialog --stdout --backtitle "Semplice SuperFLAC Creation" --title " Axiom 16 Violation! " --msgbox "\nThere is no embedded albumart, but there needs to be, at least in the first FLAC in the working folder. A SuperFLAC cannot be created from tracks which don't match the Axioms of Classical Tagging.\n\nSee: https://bbritten.com/articles/axioms\n\nFile affected: $f" 15 80
      ((AXIOM_ERRORS++))
    fi
  fi
  if [[ $AXIOM_ERRORS -ne 0 ]]; then break; fi
  FIRST_TIME=0
done
}

function cao_merge {
COUNTFLAC=$(ls *.flac 2>/dev/null | wc -l)
# Make sure we're in a folder containing more than one FLAC first!
if [[ $COUNTFLAC -le 1 ]]; then
  dialog --stdout --backtitle "Semplice FLAC Merging" --msgbox "There are insufficient FLACs in the current working folder to create a SuperFLAC. Change your working folder before trying again. \n\nClick OK to return to the main program menu." 8 80
  return
fi

# Cuesheets cannot have more than 99 entries, so make sure there are
# fewer than 99 FLACs in the working folder
if [[ $COUNTFLAC -gt 99 ]]; then
  dialog --stdout --backtitle "Semplice FLAC Merging" --msgbox "Technical restrictions on cuesheets mean that SuperFLACs cannot be created when more than 99 'per track' FLACs exist in the same folder. \n\nClick OK to return to the main program menu." 8 80
  return
fi

# Check to see first FLAC has metadata for album, otherwise we can't proceed, because
# we can't create a new file with no name, and the merge proces always creates a SuperFLAC
# with a name matching 'album' name. So 'ALBUM' is required at a minimum to be not null.
# ------------------------------------------------------------------------------------------
g=$(find . -name "*.flac" | sort | head -n 1)
ALBUM=$(get_tag Album "$g")
BITDEPTH=$(metaflac --list "$g" | $GREPPROG -a bits-per-sample | awk '{print $2}')
SAMPLERATE=$(metaflac --list "$g" | $GREPPROG sample_rate | awk '{print $2}')

if [[ -z $ALBUM ]]; then
  dialog --stdout --backtitle "Semplice FLAC Merging" --msgbox "The first track in this folder has not been tagged with a composition name. \nSemplice cannot create un-named SuperFLACs. \n\nClick OK to return to the main program menu." 8 80
  return
fi

# Get track lengths
# ------------------------------------------------------------------------------------------
rm -rf "$CONFDIR/tmp/cao-files.txt"
for f in *.flac; do
  PLAYLENGTH=$(ffprobe -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)
  track_durations+=("$PLAYLENGTH")
  CUMPLAYLENGTH=$(echo "scale=5; $CUMPLAYLENGTH + $PLAYLENGTH" | bc -l)     # This is the cumulative total of playable seconds

  # Get the integer number of minutes this represents
  PLAYMINS=$(echo "$CUMPLAYLENGTH/60" | bc -l | awk '{print int($1)}')

  # Now determine the seconds that are left, if the PLAYMINS are taken away
  PLAYSECS=$((PLAYMINS*60))
  PLAYSECS=$(echo "$CUMPLAYLENGTH - $PLAYSECS" | bc -l | awk '{print int($1)}')

  # And finally determine the fractional seconds and multiply them by 75 (because fractionals in cuesheets are frames, not decimal seconds)
  PLAYFRAC=$(((PLAYMINS*60) + PLAYSECS))
  PLAYFRAC=$(echo "$CUMPLAYLENGTH - $PLAYFRAC" | bc -l)
  PLAYFRAC=$(echo "$PLAYFRAC * 0.75" | bc -l)
  PLAYFRAC=$(echo "$PLAYFRAC * 100" | bc -l| awk '{print int($1)}')

  # Now put it all together as a string
  PLAYFRAC=$(printf "%02d\n" $PLAYFRAC)
  PLAYSECS=$(printf "%02d\n" $PLAYSECS)

  DISPLAYLENGTH="$(printf "%02d" $PLAYMINS):$PLAYSECS:$PLAYFRAC"         # Cuesheet times are mm:ss:ff, minutes zero-padded
  track_lengths+=("$DISPLAYLENGTH")
  echo "$f" >> "/$CONFDIR/tmp/cao-files.txt"
done

# Get metadata from first FLAC file in folder
# ------------------------------------------------------------------------------------------
f=$(find "$(pwd)" -name "*.flac" | sort | head -n 1)
COMPOSER=$(get_tag Artist "$f")
ARTIST=$(get_tag Artist "$f")
YEAR=$(get_tag Date "$f")
ALBUM=$(get_tag Album "$f")
TRACKNUMBER=$(get_tag TRACKNUMBER "$f")
TITLE=$(get_tag Title "$f")
GENRE=$(get_tag Genre "$f")
COMMENT=$(get_tag Comment "$f")
PERFORMER=$(get_tag Performer "$f")
DESCRIPTION=$(get_tag Description "$f")
NOTES=$(get_tag Notes "$f")
BITDEPTH=$(metaflac $UTFCHARS --list "$f" | $GREPPROG bits-per-sample | awk '{print $2}')
SAMPLERATE=$(metaflac $UTFCHARS --list "$f" | $GREPPROG sample_rate | awk '{print $2}')
RPG_REFERENCE=$(get_tag REPLAYGAIN_REFERENCE_LOUDNESS "$f")
RPG_ALBUMPEAK=$(get_tag REPLAYGAIN_ALBUM_PEAK "$f")
RPG_ALBUMGAIN=$(get_tag REPLAYGAIN_ALBUM_GAIN "$f")
RPG_TRACKPEAK=$RPG_ALBUMPEAK
RPG_TRACKGAIN=$RPG_ALBUMGAIN

if [[ $CUSTOMTAGS -eq 1 ]]; then
  CUSTOMTAGVALUE1=$(get_tag "$CUSTOMTAG1" "$f")
  CUSTOMTAGVALUE2=$(get_tag "$CUSTOMTAG2" "$f")
  CUSTOMTAGVALUE3=$(get_tag "$CUSTOMTAG3" "$f")
  CUSTOMTAGVALUE4=$(get_tag "$CUSTOMTAG4" "$f")
  CUSTOMTAGVALUE5=$(get_tag "$CUSTOMTAG5" "$f")
  CUSTOMTAGVALUE6=$(get_tag "$CUSTOMTAG6" "$f")
  CUSTOMTAGVALUE7=$(get_tag "$CUSTOMTAG7" "$f")
  CUSTOMTAGVALUE8=$(get_tag "$CUSTOMTAG8" "$f")
  CUSTOMTAGVALUE9=$(get_tag "$CUSTOMTAG9" "$f")
fi

SAFEALBUMNAME=$(tr '~#%&<>:"/\|?*' '_' <<< "$ALBUM") # Make physical file names NTFS-safe
PLAINFLACNAME="$SAFEALBUMNAME.flac"
FILENAME="$SAFEALBUMNAME-superflac.flac"
metaflac $UTFCHARS --export-picture-to="albumart.jpg" "$f" >/dev/null 2>&1

if [[ -f $FILENAME ]]; then			# If the merge would produce a file with the same name as something that already exists, quit.
  dialog --stdout --backtitle "Semplice FLAC Merging" --msgbox "A file already exists with the same name that the newly-created SuperFLAC would acquire: Semplice cannot continue at this time. \n\nClick OK to return to the main program menu." 8 80
  return
fi

# Clean filename to remove two or three dots from file names: they break ffmpeg.
# ------------------------------------------------------------------------------------------
for f in *.flac; do
  if [ "${f}" != "${f//.../…}" ]; then
    # Fetch existing metadata into variables
    TITLE="$(get_tag Title "$f")"
    TITLE="${TITLE//.../…}"
    TITLE="${TITLE//../…}"
    metaflac $UTFCHARS --remove-tag="Title" "$f"
    metaflac $UTFCHARS "--set-tag=Title=$TITLE" "$f"
    mv "${f}" "${f//.../…}"
  fi
done

for f in *.flac; do
  if [ "${f}" != "${f//../…}" ]; then
    TITLE="$(get_tag Title "$f")"
    TITLE="${TITLE//.../…}"
    TITLE="${TITLE//../…}"
    metaflac $UTFCHARS --remove-tag="Title" "$f"
    metaflac $UTFCHARS "--set-tag=Title=$TITLE" "$f"
    mv "${f}" "${f//../…}"
  fi
done

# But if the stripping results in filenames ending 'ellipsisflac', we need to
# insert back a dot before the flac extension.
# ------------------------------------------------------------------------------------------
for f in *; do
  if [[ $f == *"…flac"* ]]; then
    mv "${f}" "${f/…flac/….flac}"
  fi
done

# Straight apostrophes in file names are left alone: the concatenation list below escapes them for ffmpeg.

# Now create the cuesheet...
# ------------------------------------------------------------------------------------------
echo "REM durations:" ${track_durations[@]/#/#}> cuesheet.cue
echo "TITLE \"$ALBUM\"" >> cuesheet.cue
echo "ARTIST \"$ARTIST\"" >> cuesheet.cue
echo "PERFORMER \"$COMMENT\"" >> cuesheet.cue
echo "FILE \"$PLAINFLACNAME\" WAVE" >> cuesheet.cue

for f in *.flac; do
  TITLE=$(get_tag Title "$f")

  if [[ "$TITLE" == *".."* ]]; then
    TITLE="${TITLE//../…}"                                # Metadata two consecutive dots get replaced by proper ellipsis
  fi

  if [[ "$TITLE" == *"..."* ]]; then
    TITLE="${TITLE//.../…}"                               # Metadata three consecutive dots get replaced by proper ellipsis
  fi

  if [[ $COUNTER -eq 1 ]]; then
    INDEXMARK="00:00:00"
  else
    INDEXMARK=$(echo ${track_lengths[$((COUNTER-2))]})
  fi

  echo "  TRACK $(printf "%02d" $COUNTER) AUDIO" >> cuesheet.cue
  echo "    TITLE \"$TITLE\"" >> cuesheet.cue
  echo "    INDEX 01 $INDEXMARK" >> cuesheet.cue
  COUNTER=$((COUNTER+1))
done

# And concatenate the music. Note that the problem here is that the path might contain
# single quotes (eg. Overture from 'Othello'). However, the list of files to be concatenated
# all needs to be contained within a set of single quotes too. So how to differentiate "our"
# single quotes from the ones inside the path? We don't use "outer" single quotes but triple
# plusses. Then, we sed the triple plusses into being single quotes later on. Clumsy, but
# avoids a lot of parsing hassles.
# ------------------------------------------------------------------------------------------
rm -f "$CONFDIR/tmp/cao-tracklist.txt" 2>/dev/null
for f in *.flac; do
  filename=$(basename "$f")
  albumdir=$(dirname "$(pwd)"/"$f")
  echo "file +^+^+$(pwd)/$filename+^+^+" >> "$CONFDIR/tmp/cao-tracklist.txt"
done

$SEDPROG -i "s/'/'\\\''/g" "$CONFDIR/tmp/cao-tracklist.txt" 2>/dev/null         # Parse tracklist and replace "inner" single quotes with escaped version
$SEDPROG -i "s/+^+^+/'/g" "$CONFDIR/tmp/cao-tracklist.txt"                      # Parse triple plusses and replace then with vanilla single quotes

MESSAGE="Merging files…   "
ffmpeg -hide_banner -loglevel 0 -f concat -safe 0 -i "$CONFDIR/tmp/cao-tracklist.txt" -max_muxing_queue_size 900000 "$FILENAME" & spinner $!
rm -f "$CONFDIR/tmp/cao-tracklist.txt" 2>/dev/null

# And restore the metadata...
# ------------------------------------------------------------------------------------------
TRACKNUMBER=$(printf "%02d" $TRACKNUMBER)             # Makes single-digit tracks 2 digit ones with a leading zero
FILENAME="${FILENAME//\[/\\[}"                        # If the filename contains square brackets, we have to escape them in the search term
FILENAME="${FILENAME//\]/\\]}"                        # for 'find' to be able to find them. If not, the resulting super-FLAC won't get tagged up

f=$(find "$(pwd)" -maxdepth 1 -name "$FILENAME")      # Only look in current directory, not in any folders that may be hanging off this one
metaflac $UTFCHARS --set-tag="Composer=$ARTIST" "$f"
metaflac $UTFCHARS --set-tag="Artist=$ARTIST" "$f"
metaflac $UTFCHARS --set-tag="Album=$ALBUM" "$f"
metaflac $UTFCHARS --set-tag="TRACKNUMBER=$TRACKNUMBER" "$f"
metaflac $UTFCHARS --set-tag="Title=$ALBUM" "$f"
metaflac $UTFCHARS --set-tag="Genre=$GENRE" "$f"
metaflac $UTFCHARS --set-tag="Comment=$COMMENT" "$f"
metaflac $UTFCHARS --set-tag="Performer=$PERFORMER" "$f"
metaflac $UTFCHARS --set-tag="Date=$YEAR" "$f"
metaflac $UTFCHARS --set-tag="Notes=$NOTES" "$f"

if [[ -n $RPG_ALBUMGAIN && ${METAVOL^^} == "METADATA" ]]; then
  metaflac $UTFCHARS --set-tag="REPLAYGAIN_REFERENCE_LOUDNESS=$RPG_REFERENCE" "$f"
  metaflac $UTFCHARS --set-tag="REPLAYGAIN_ALBUM_PEAK=$RPG_ALBUMPEAK" "$f"
  metaflac $UTFCHARS --set-tag="REPLAYGAIN_ALBUM_GAIN=$RPG_ALBUMGAIN" "$f"
  metaflac $UTFCHARS --set-tag="REPLAYGAIN_TRACK_PEAK=$RPG_TRACKPEAK" "$f"
  metaflac $UTFCHARS --set-tag="REPLAYGAIN_TRACK_GAIN=$RPG_TRACKGAIN" "$f"
fi

metaflac $UTFCHARS --remove-tag="Encoder" "$f"
metaflac $UTFCHARS --import-picture-from="albumart.jpg" "$f"

if [[ $CUSTOMTAGS -eq 1 ]]; then
  for ((ct=1; ct<=9; ct++)); do                                       # Only copy custom tags that are in use and have a value
    CTNAME="CUSTOMTAG$ct"; CTVAL="CUSTOMTAGVALUE$ct"
    if [[ -n ${!CTNAME} && ${!CTNAME} != "XqXXqXX" && -n ${!CTVAL} ]]; then
      metaflac $UTFCHARS --set-tag="${!CTNAME}=${!CTVAL}" "$f"
    fi
  done
fi

# Finally, embed the cuesheet and tidy up
# ------------------------------------------------------------------------------------------
if [[ $FILENAME == *"\["* ]]; then
  FILENAME=$(echo "$FILENAME" | $SEDPROG 's/\\\[/[/g')   # Remove escape characters that might have been required to make find work
  FILENAME=$(echo "$FILENAME" | $SEDPROG 's/\\]/]/g')    # Remove escape characters that might have been required to make find work
fi
metaflac $UTFCHARS --set-tag-from-file=CUESHEET="cuesheet.cue" "$FILENAME"

rm -f "albumart.jpg"
rm "cuesheet.cue"

# Offer to delete the individual FLAC files, leaving only the SuperFLAC
# ------------------------------------------------------------------------------------------
rm -rf "/$CONFDIR/tmp/cao-files.txt"
find . -maxdepth 1 -type f -name '*.flac' ! -name '*superflac*' | sort > "/$CONFDIR/tmp/cao-files.txt"
$SEDPROG -i 's/.\///g' "/$CONFDIR/tmp/cao-files.txt"     # Bit of trimming to remove leading periods and slashes.

if [ $(ls *superflac* | wc -l) -ge 1 ]; then			# If, for any reason, a superflac is not generated, then don't delete the source files!
  if [[ $AUTODELETE -eq 0 ]]; then
    dialog --backtitle "Semplice FLAC Merging" --title " Do you want to delete the per-track FLACs listed here? " --extra-button --extra-label "No" --ok-label "Yes" --textbox "$CONFDIR/tmp/cao-files.txt" 16 90
    exitStatus=$?
    if [[ $exitStatus -eq 255 || $exitStatus -eq 3 ]]; then break; fi     # Don't do anything if they hit ESC to cancel, or answer 'No'
    if [[ $exitStatus -eq 0 ]]; then                                          # True if they've taken the 'Yes' option
      find . -maxdepth 1 -type f -name '*.flac' ! -name '*superflac*' -exec rm -- '{}' +
    fi
  elif [[ $AUTODELETE -eq 1 ]]; then
    find . -maxdepth 1 -type f -name '*.flac' ! -name '*superflac*' -exec rm -- '{}' +
  fi
fi

# Now rename the superflac to not be called a SuperFLAC! And tidy up.
# ------------------------------------------------------------------------------------------
mv "$FILENAME" "$SAFEALBUMNAME.flac"
if [[ $NAMEBITS -eq 1 ]]; then
  if ! [[ "$SAFEALBUMNAME" == *"-$SAMPLERATE"* ]]; then
    NEWFLACNAME="$SAFEALBUMNAME-$BITDEPTH-$SAMPLERATE".flac
    mv "$SAFEALBUMNAME".flac "$NEWFLACNAME"
  fi
fi

rm -rf "/$CONFDIR/cao-files.txt"

tput cvvis
}

unset track_durations
axiom_check
if [[ $AXIOM_ERRORS -eq 0 ]]; then
  cao_merge
  source "$CONFDIR/bin/semclean.sh"
fi
