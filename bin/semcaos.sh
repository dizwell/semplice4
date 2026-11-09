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
source "$CONFDIR/bin/semparse.sh"

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

if [[ $COUNTFLAC -gt 1 ]]; then
  dialog --stdout --backtitle "Semplice FLAC Splitting" --msgbox "There needs to be only a single FLAC file present in the working folder. Semplice cannot proceed \n\nClick OK to return to the main program menu." 10 80
  return
fi

CUESHEET=$(metaflac $UTFCHARS --show-tag=CUESHEET "$f"  | $SEDPROG 's/.*=//g')
if [[ -z $CUESHEET ]]; then
  EMBEDDEDCUECOUNT=0
else
  EMBEDDEDCUECOUNT=1
fi

if [[ $COUNTCUE -eq 1 && $EMBEDDEDCUECOUNT -eq 1 ]]; then
  dialog --backtitle "Semplice FLAC Splitting" --title " What splitting mechanism to use? " --yes-label " Use the Embedded Cuesheet " --no-label " Use the External Cuesheet " --yesno "\nThere is both an external cuesheet present in the working folder AND an embedded one, inside the FLAC you're splitting: you can choose to use only one or the other as the basis of the SuperFLAC split. \n\nDo you want to use the embedded cuesheet or the external one as the basis of this split?" 12 80
    exitStatus=$?
    if [[ $exitStatus -eq 0 ]]; then USEEMBEDDED=1; fi
    if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then USEEMBEDDED=0; fi
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

if [[ ${f} != ${f//\'/’} ]]; then
  mv "${f}" "${f//\'/’}"
fi

# If the cuesheet is now embedded, the file can be split as normal: invoke cao_split
# -----------------------------------------------------------------------------------------
f=$(ls *.flac)      # repeated from above, because the clean filenames business may have changed the names of the FLAC and CUE we're dealing with.
c=$(ls *.cue)
CUESHEET=$(metaflac $UTFCHARS --show-tag=Cuesheet "$f" | $SEDPROG 's/.*=//g')      # If it contains a cuesheet, start reading the cuesheet
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

CUESHEET=$(metaflac $UTFCHARS --show-tag=CUESHEET "$f"  | $SEDPROG 's/.*=//g')
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
  COMPOSER=$(metaflac $UTFCHARS --show-tag=Artist "$f" | $SEDPROG 's/.*=//g')
  ARTIST=$(metaflac $UTFCHARS --show-tag=Artist "$f" | $SEDPROG 's/.*=//g')
  ALBUM=$(metaflac $UTFCHARS --show-tag=Album "$f" | $SEDPROG 's/.*=//g')
  GENRE=$(metaflac $UTFCHARS --show-tag=Genre "$f" | $SEDPROG 's/.*=//g')
  DATE=$(metaflac $UTFCHARS --show-tag=Date "$f" | $SEDPROG 's/.*=//g')
  COMMENT=$(metaflac $UTFCHARS --show-tag=Comment "$f" | $SEDPROG 's/.*=//g')
  NOTES=$(metaflac $UTFCHARS --show-tag=Notes "$f" | $SEDPROG 's/.*=//g')
  PERFORMER=$(metaflac $UTFCHARS --show-tag=Performer "$f" | $SEDPROG 's/.*=//g')

  if [[ $CUSTOMTAGS -eq 1 ]]; then
    CUSTOMTAGVALUE1=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG1" "$f" | $SEDPROG 's/.*=//g')
    CUSTOMTAGVALUE2=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG2" "$f" | $SEDPROG 's/.*=//g')
    CUSTOMTAGVALUE3=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG3" "$f" | $SEDPROG 's/.*=//g')
    CUSTOMTAGVALUE4=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG4" "$f" | $SEDPROG 's/.*=//g')
    CUSTOMTAGVALUE5=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG5" "$f" | $SEDPROG 's/.*=//g')
    CUSTOMTAGVALUE6=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG6" "$f" | $SEDPROG 's/.*=//g')
    CUSTOMTAGVALUE7=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG7" "$f" | $SEDPROG 's/.*=//g')
    CUSTOMTAGVALUE8=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG8" "$f" | $SEDPROG 's/.*=//g')
    CUSTOMTAGVALUE9=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG9" "$f" | $SEDPROG 's/.*=//g')
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
    ffmpeg -hide_banner -loglevel 0 -i "$f" -max_muxing_queue_size 900000 -vn -vsync 0 -ss ${TrackStarts[$counter]} -t ${TrackEnds[$counter]} split/track0$((counter+1)).flac 2>/dev/null
  else
    ffmpeg -hide_banner -loglevel 0 -i "$f" -max_muxing_queue_size 900000 -vn -vsync 0 -ss ${TrackStarts[$counter]} -t ${TrackEnds[$counter]} split/track$((counter+1)).flac  2>/dev/null
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
    tracktitle="$(echo $tracktitle | $SEDPROG 's/^ *//g')"  # Trim whitespace at front of title
    tracktitle="$(echo $tracktitle | $SEDPROG 's/ *$//g')"  # Trim whitespace at end of title
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
      metaflac $UTFCHARS --set-tag="$CUSTOMTAG1=$CUSTOMTAGVALUE1" "$g"
      metaflac $UTFCHARS --set-tag="$CUSTOMTAG2=$CUSTOMTAGVALUE2" "$g"
      metaflac $UTFCHARS --set-tag="$CUSTOMTAG3=$CUSTOMTAGVALUE3" "$g"
      metaflac $UTFCHARS --set-tag="$CUSTOMTAG4=$CUSTOMTAGVALUE4" "$g"
      metaflac $UTFCHARS --set-tag="$CUSTOMTAG5=$CUSTOMTAGVALUE5" "$g"
      metaflac $UTFCHARS --set-tag="$CUSTOMTAG6=$CUSTOMTAGVALUE6" "$g"
      metaflac $UTFCHARS --set-tag="$CUSTOMTAG7=$CUSTOMTAGVALUE7" "$g"
      metaflac $UTFCHARS --set-tag="$CUSTOMTAG8=$CUSTOMTAGVALUE8" "$g"
      metaflac $UTFCHARS --set-tag="$CUSTOMTAG9=$CUSTOMTAGVALUE9" "$g"
    fi

    counter=$((counter+1))

    # Whilst tags can contain forbidden characters, physical file names need to be NTFS-safe. Even Linux users might use Windows servers or USB disks formatted with NTFS for easy device sharing!
    tracktitle="$(tr "'~#%&<>:\"/\|?*" "_" <<< "$tracktitle")"
    mv "$g" split/"$tracknum - $tracktitle".flac
  fi
done
rm -f albumart; rm -f "$CUEFILE"

if [[ $AUTODELETE_SOURCE_POST_SPLIT == "yes" ]]; then
  rm -f "$f"
fi

}

split_superflac
dialog --stdout --backtitle "Semplice FLAC Splitting" --msgbox "SuperFLAC work has been completed!" 10 80
