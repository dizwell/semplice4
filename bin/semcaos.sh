#!/usr/bin/env bash
####################################################################
#
# semcaos: routine for splitting a single-file SuperFLAC into
# a bunch of separate per-track FLACs. If the cuesheet is external,
# embed it. If it's embedded already, just use that to split the
# file.
#
####################################################################
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

function split_superflac {
# The principle is: if there's an internal cuesheet, use that
# If there's no internal cuesheet, but an external one, use that
# And if there's both internal and external cuesheets, prompt
# -----------------------------------------------------------------------------------------
COUNTCUE=$(ls *.cue 2>/dev/null | wc -l)
COUNTFLAC=$(ls *.flac 2>/dev/null | wc -l)
f=$(find "$(pwd)" -maxdepth 1 -name "*.flac" | sort | head -n 1)

if [[ $COUNTFLAC -eq 0 ]]; then
  dialog --stdout --backtitle "Semplice FLAC Splitting" --msgbox "There is no FLAC file in the working folder, so there is nothing to split.\n\nClick OK to return to the main program menu." 10 80
  return
fi

if [[ $COUNTFLAC -gt 1 ]]; then
  dialog --stdout --backtitle "Semplice FLAC Splitting" --msgbox "There needs to be only a single FLAC file present in the working folder. Semplice cannot proceed \n\nClick OK to return to the main program menu." 10 80
  return
fi

CUESHEET=$(metaflac $UTFCHARS --show-tag=CUESHEET "$f"); CUESHEET="${CUESHEET#*=}"
if [[ -z $CUESHEET ]]; then
  EMBEDDEDCUECOUNT=0
else
  EMBEDDEDCUECOUNT=1
fi

if [[ $COUNTCUE -gt 1 ]]; then
  dialog --stdout --backtitle "Semplice FLAC Splitting" --msgbox "There is more than one .cue file in the working folder. Semplice needs at most one, so it knows which to use.\n\nClick OK to return to the main program menu." 10 80
  return
fi

if [[ $COUNTCUE -eq 0 && $EMBEDDEDCUECOUNT -eq 0 ]]; then
  dialog --stdout --backtitle "Semplice FLAC Splitting" --msgbox "No cuesheet found: the FLAC has none embedded in it, and there is no .cue file in the working folder. A cuesheet is needed to know where each track starts.\n\nClick OK to return to the main program menu." 11 80
  return
fi

if [[ $COUNTCUE -eq 1 && $EMBEDDEDCUECOUNT -eq 1 ]]; then
  dialog --backtitle "Semplice FLAC Splitting" --title " What splitting mechanism to use? " --yes-label " Use the Embedded Cuesheet " --no-label " Use the External Cuesheet " --yesno "\nThere is both an external cuesheet present in the working folder AND an embedded one, inside the FLAC you're splitting: you can choose to use only one or the other as the basis of the SuperFLAC split. \n\nDo you want to use the embedded cuesheet or the external one as the basis of this split?" 12 80
    exitStatus=$?
    if [[ $exitStatus -eq 0 ]]; then USEEMBEDDED=1; fi
    if [[ $exitStatus -eq 1 ]]; then USEEMBEDDED=0; fi
    if [[ $exitStatus -eq 255 ]]; then return; fi                      # Esc cancels the split
elif [[ $COUNTCUE -eq 1 && $EMBEDDEDCUECOUNT -eq 0 ]]; then
  USEEMBEDDED=0
elif [[ $COUNTCUE -eq 0 && $EMBEDDEDCUECOUNT -eq 1 ]]; then
  USEEMBEDDED=1
fi

if [[ $USEEMBEDDED -eq 1 ]]; then
  cao_split
else
  cao_external
fi
}

function cao_external {
# Before embedding the cuesheet, we need to strip it of Carriage Return end-of-line markers,
# if any are present.
# -----------------------------------------------------------------------------------------
c=$(ls *.cue)
$SEDPROG -i 's/\r$//g' "$c"

# Time to embed the cuesheet (we really only ever split using embedded cuesheets!)
# -----------------------------------------------------------------------------------------
f=$(ls *.flac)
c=$(ls *.cue)
metaflac --remove-tag=CUESHEET "$f"
metaflac --set-tag-from-file=CUESHEET="$c" "$f"

# And finally, a cut-down version of the clean_filenames function, which simply
# ensures the FLAC we're about to split contains no character combinations which
# would break ffmpeg.
# -----------------------------------------------------------------------------------------
if [[ ${f} != ${f//.../…} ]]; then
  mv "${f}" "${f//.../…}"
fi

if [[ ${f} != ${f//../…} ]]; then
  mv "${f}" "${f//../…}"
fi

if [[ $f == *"…flac"* ]]; then
  mv "${f}" "${f/…flac/….flac}"
fi


# If the cuesheet is now embedded, the file can be split as normal: invoke cao_split
# -----------------------------------------------------------------------------------------
f=$(ls *.flac)      # repeated from above, because the clean filenames business may have changed the names of the FLAC and CUE we're dealing with.
c=$(ls *.cue)
CUESHEET=$(metaflac $UTFCHARS --show-tag=Cuesheet "$f"); CUESHEET="${CUESHEET#*=}"      # If it contains a cuesheet, start reading the cuesheet
if [[ ! -z "$CUESHEET" ]]; then
  cao_split
else
  dialog --stdout --backtitle "Semplice FLAC Splitting" --msgbox "Semplice has been unable to parse the external cuesheet correctly. Please check it for line endings, syntax errors or foreign characters and correct any issues with those before re-trying." 10 80
  return
fi
}

function cao_split {
# Declare two needed arrays
# -----------------------------------------------------------------------------------------
TrackStarts=()
TrackEnds=()

# Find the first FLAC file and test for a CUESHEET
# -----------------------------------------------------------------------------------------
f=$(find "$(pwd)" -maxdepth 1 -name "*.flac" | sort | head -n 1)
if [[ -z $f ]]; then
  dialog --stdout --backtitle "Semplice FLAC Splitting" --msgbox "There are no FLAC files in this folder that can be split!" 10 80
  return
fi

origfile=$(basename "$f")
countflacs=$(ls *.flac | wc -l)

if [[ $countflacs -gt 1 ]]; then
  dialog --stdout --backtitle "Semplice FLAC Splitting" --msgbox "There needs to be a FLAC file present in the working folder, plus a cuesheet. There needs to be only one of each type of file in the working folder. One of these conditions is not being met at present! \n\nClick OK to return to the main program menu." 10 80
  return
fi

CUESHEET=$(metaflac $UTFCHARS --show-tag=CUESHEET "$f"); CUESHEET="${CUESHEET#*=}"
if [[ -z $CUESHEET ]]; then
  dialog --stdout --backtitle "Semplice FLAC Splitting" --msgbox "There needs to be a FLAC file present in the working folder, plus a cuesheet. There needs to be only one of each type of file in the working folder. One of these conditions is not being met at present! \n\nClick OK to return to the main program menu." 10 80
  return
else
  # Save the albumart and cuesheet
  metaflac $UTFCHARS --export-picture-to="albumart" "$f" 2>/dev/null
  filename="${f%%.flac}"
  CUEFILE="$filename.cue"
  echo "$CUESHEET" > "$CUEFILE"

  # Fetch existing metadata into variables
  COMPOSER=$(get_tag Artist "$f")
  ARTIST=$(get_tag Artist "$f")
  ALBUM=$(get_tag Album "$f")
  GENRE=$(get_tag Genre "$f")
  DATE=$(get_tag Date "$f")
  COMMENT=$(get_tag Comment "$f")
  NOTES=$(get_tag Notes "$f")
  PERFORMER=$(get_tag Performer "$f")

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

fi

# Extract tracks from cuesheet and their start times. Write only that data to indexfile.txt
# -----------------------------------------------------------------------------------------
cat "$CUEFILE" | $GREPPROG "INDEX 01" | $SEDPROG 's/INDEX 01//' | $SEDPROG 's/ //g' > indexfile.txt

# Loop through indexfile.txt. Create array of start times.
# -----------------------------------------------------------------------------------------
counter=$(cat indexfile.txt | wc -l)
maxtracks=$counter

while IFS= read -r line; do
  TRACKNO=$counter
  STARTSEC=$(echo $line | awk -F: '{ printf "%.6f", ($1 * 60) + $2 + ($3 / 75) }')
  TrackStarts+=($STARTSEC)
  counter=$((counter+1))
done < "indexfile.txt"

# Now iterate through the array to get track durations.
# -----------------------------------------------------------------------------------------
counter=0
for x in "${TrackStarts[@]}"
do
  TRACKDURATION=$(echo ${TrackStarts[$counter+1]} - ${TrackStarts[$counter]} | bc)
  if [[ $TRACKDURATION == *"-"* ]]; then TRACKDURATION=86400; fi
  TrackEnds+=($TRACKDURATION)
  counter=$((counter+1))
done

# And now you have start times and durations, split the flac file accordingly
# -----------------------------------------------------------------------------------------
counter=0
MESSAGE="Splitting masterfile asunder…   "
mkdir split 2>/dev/null
for x in "${TrackStarts[@]}"
do
  if [[ $counter -lt 9 ]]; then
    "$FFMPEG" -hide_banner -loglevel 0 -i "$f" -max_muxing_queue_size 900000 -vn -ss ${TrackStarts[$counter]} -t ${TrackEnds[$counter]} split/track0$((counter+1)).flac 2>/dev/null
  else
    "$FFMPEG" -hide_banner -loglevel 0 -i "$f" -max_muxing_queue_size 900000 -vn -ss ${TrackStarts[$counter]} -t ${TrackEnds[$counter]} split/track$((counter+1)).flac  2>/dev/null
  fi
  counter=$((counter+1))
  done & spinner
rm indexfile.txt

# Now re-tag the split-out files
# -----------------------------------------------------------------------------------------
counter=1
for g in split/*.flac; do
  if [[ $g != $origfile ]]; then    
    metaflac $UTFCHARS --remove-all "$g"
    tracknum=$(cueprint -n "$counter" "$CUEFILE" 2>/dev/null | $GREPPROG "track number" | awk -F ":" '{print $2}' | xargs)
    if [[ -z $tracknum ]]; then tracknum=$counter; fi
    tracknum=$(printf "%02g" $tracknum)     # Track numbers should be zero-padded if less than 10.
    tracktitle="$(cueprint -n "$counter" "$CUEFILE"  2>/dev/null | $GREPPROG "title")"
    if [[ -z $tracktitle ]]; then tracktitle="track$counter"; fi
    tracktitle="${tracktitle#*title:}"		# Remove the 'title:' bit from the front of the retrieved text for track title
    tracktitle="$(printf '%s\n' "$tracktitle" | $SEDPROG 's/^[[:space:]]*//; s/[[:space:]]*$//')"  # Trim spaces and tabs at front and end of title (quoted, so a '*' in a title is never expanded)
    tag=TRACKNUMBER;metaflac $UTFCHARS "--set-tag=$tag=$tracknum" "$g"
    tag=TITLE;metaflac $UTFCHARS "--set-tag=$tag=$tracktitle" "$g"
    tag=COMPOSER;metaflac $UTFCHARS "--set-tag=$tag=$COMPOSER" "$g"
    tag=ARTIST;metaflac $UTFCHARS "--set-tag=$tag=$ARTIST" "$g"
    tag=ALBUM;metaflac $UTFCHARS "--set-tag=$tag=$ALBUM" "$g"
    tag=GENRE;metaflac $UTFCHARS "--set-tag=$tag=$GENRE" "$g"
    tag=DATE;metaflac $UTFCHARS "--set-tag=$tag=$DATE" "$g"
    tag=COMMENT;metaflac $UTFCHARS "--set-tag=$tag=$COMMENT" "$g"
	tag=NOTES;metaflac $UTFCHARS "--set-tag=$tag=$NOTES" "$g"
    tag=PERFORMER;metaflac $UTFCHARS "--set-tag=$tag=$PERFORMER" "$g"
    if [ -f albumart ]; then metaflac $UTFCHARS --import-picture-from="albumart" "$g"; fi

    if [[ $CUSTOMTAGS -eq 1 ]]; then
      for ((ct=1; ct<=9; ct++)); do                                       # Only copy custom tags that are in use and have a value
        CTNAME="CUSTOMTAG$ct"; CTVAL="CUSTOMTAGVALUE$ct"
        if [[ -n ${!CTNAME} && ${!CTNAME} != "XqXXqXX" && -n ${!CTVAL} ]]; then
          metaflac $UTFCHARS --set-tag="${!CTNAME}=${!CTVAL}" "$g"
        fi
      done
    fi

    counter=$((counter+1))

    # Whilst tags can contain forbidden characters, physical file names need to be NTFS-safe. Even Linux users might use Windows servers or USB disks formatted with NTFS for easy device sharing!
    tracktitle="$(tr "~#%&<>:\"/\|?*" "_" <<< "$tracktitle")"     # Straight apostrophes are allowed (NTFS accepts them)
    mv "$g" split/"$tracknum - $tracktitle".flac
  fi
done
rm -f albumart; rm -f "$CUEFILE"
SPLITDONE=1                                                            # The split actually happened


}

SPLITDONE=0
split_superflac
if [[ $SPLITDONE -eq 1 ]]; then                                        # Only claim success if the split actually happened
  dialog --stdout --backtitle "Semplice FLAC Splitting" --msgbox "SuperFLAC work has been completed!" 10 80
fi
