#!/usr/bin/env bash
####################################################################
#
# semclean: routine for cleaning a set of tags without
# quitting the program. Same code as 'quit', but without the
# program terminating! Also, no corruption checking.
#
####################################################################
TRACKCOUNT=$(ls *.flac | wc -l)  NOPROCESS=0
source "$CONFDIR/bin/semparse.sh"
source "$CONFDIR/bin/semspin.sh"

ALBUMART=$CONFDIR/tmp/cleanart.jpg                                      # Initialise temporary work files
CUEFILE=$CONFDIR/tmp/cleancue.txt
TAGFILE=$CONFDIR/tmp/cleantag.txt
rm -f "$ALBUMART" 2>/dev/null
rm -f "$CUEFILE" 2>/dev/null

function clean_tags
{
COUNTFLAC=$(ls *.flac | wc -l)
if [ $COUNTFLAC -eq 0 ]; then return; fi

# Extract album art from the first Flac found
f=$(find "$(pwd)" -name "*.flac" | sort | head -n 1)
metaflac $UTFCHARS --export-picture-to="$ALBUMART" "$f" 2>/dev/null     # Suppressing errors in case they haven't added album art or a cuesheet and hence there's nothing to export

for f in *.flac; do
  BITDEPTH=$(metaflac --list "$f" | $GREPPROG -a bits-per-sample | awk '{print $2}')

  # Fetch existing metadata into variables.
  # ---------------------------------------------------------------------------------
  COMPOSER=$(metaflac $UTFCHARS --show-tag=Artist "$f" | $SEDPROG 's/.*=//g')
  ARTIST=$(metaflac $UTFCHARS --show-tag=Artist "$f" | $SEDPROG 's/.*=//g')
  ALBUM=$(metaflac $UTFCHARS --show-tag=Album "$f" | $SEDPROG 's/.*=//g')
  TRACKNUMBER=$(metaflac $UTFCHARS --show-tag=TRACKNUMBER "$f" | $SEDPROG 's/.*=//g')
  TITLE=$(metaflac $UTFCHARS --show-tag=Title "$f" | $SEDPROG 's/.*=//g')
  GENRE=$(metaflac $UTFCHARS --show-tag=Genre "$f" | $SEDPROG 's/.*=//g')
  COMMENT=$(metaflac $UTFCHARS --show-tag=Comment "$f" | $SEDPROG 's/.*=//g')
  PERFORMER=$(metaflac $UTFCHARS --show-tag=Performer "$f" | $SEDPROG 's/.*=//g')
  DESCRIPTION=$(metaflac $UTFCHARS --show-tag=Description "$f" | $SEDPROG 's/.*=//g')
  YEAR=$(metaflac $UTFCHARS --show-tag=Date "$f" | $SEDPROG 's/.*=//g')
  CUESHEET=$(metaflac $UTFCHARS --show-tag=CUESHEET "$f"  | $SEDPROG 's/.*=//g')
  RPG_REFERENCE=$(metaflac $UTFCHARS --show-tag=REPLAYGAIN_REFERENCE_LOUDNESS "$f" | $SEDPROG 's/.*=//g')
  RPG_TRACKPEAK=$(metaflac $UTFCHARS --show-tag=REPLAYGAIN_TRACK_PEAK "$f" | $SEDPROG 's/.*=//g')
  RPG_TRACKGAIN=$(metaflac $UTFCHARS --show-tag=REPLAYGAIN_TRACK_GAIN "$f" | $SEDPROG 's/.*=//g')
  RPG_ALBUMPEAK=$(metaflac $UTFCHARS --show-tag=REPLAYGAIN_ALBUM_PEAK "$f" | $SEDPROG 's/.*=//g')
  RPG_ALBUMGAIN=$(metaflac $UTFCHARS --show-tag=REPLAYGAIN_ALBUM_GAIN "$f" | $SEDPROG 's/.*=//g')

  if [[ ! -z "$CUESHEET" ]]; then
    echo "$CUESHEET" > "$CUEFILE"
  fi

  if [[ -z $COMMENT ]]; then                                            # Some tagging software swaps COMMENT and DESCRIPTION. We want to be consistent users of COMMENT, so swap them back if needed.
    if [[ ! -z $DESCRIPTION ]]; then
      tag=COMMENT;metaflac $UTFCHARS "--set-tag=$tag=$DESCRIPTION" "$f"
    fi
  fi

  if [[ $CUSTOMTAGS -eq 1 ]]; then
    CTVALUE1=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG1" "$f" | $SEDPROG 's/.*=//g')
    CTVALUE2=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG2" "$f" | $SEDPROG 's/.*=//g')
    CTVALUE3=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG3" "$f" | $SEDPROG 's/.*=//g')
    CTVALUE4=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG4" "$f" | $SEDPROG 's/.*=//g')
    CTVALUE5=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG5" "$f" | $SEDPROG 's/.*=//g')
    CTVALUE6=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG6" "$f" | $SEDPROG 's/.*=//g')
    CTVALUE7=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG7" "$f" | $SEDPROG 's/.*=//g')
    CTVALUE8=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG8" "$f" | $SEDPROG 's/.*=//g')
    CTVALUE9=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAG9" "$f" | $SEDPROG 's/.*=//g')
  fi

  # Part of cleaning is to do a hash comparison: newly-computed with built-in
  # ---------------------------------------------------------------------------------
  if [[ $BITDEPTH -eq 16 ]]; then
    MD5HASH=$(ffmpeg -i "$f" -c:a pcm_s16le -map 0:a -f md5 - 2>/dev/null | $SEDPROG 's/.*=//g')
  elif [[ $BITDEPTH -eq 24 ]]; then
    MD5HASH=$(ffmpeg -i "$f" -c:a pcm_s24le -map 0:a -f md5 - 2>/dev/null | $SEDPROG 's/.*=//g')
  fi
  
  # Read the Flac-computed MD5 Hash, too
  # ---------------------------------------------------------------------------------
  FLACHASH=$(metaflac --show-md5sum "$f")

  # If the Flac hash isn't the same as the one ffmpeg has calculated, prepare to warn and either try a fix or quit
  # ---------------------------------------------------------------------------------
  if [[ $MD5HASH != $FLACHASH ]]; then
    CORRUPTFLAC=1;
  else
    CORRUPTFLAC=0;
  fi

  # Now save the variables' values into a track-specific text file
  # ---------------------------------------------------------------------------------
  echo "COMPOSER=$COMPOSER" > "$TAGFILE"
  echo "ARTIST=$ARTIST" >> "$TAGFILE"
  echo "ALBUM=$ALBUM" >> "$TAGFILE"
  echo "TRACKNUMBER=$TRACKNUMBER" >> "$TAGFILE"
  echo "TITLE=$TITLE" >> "$TAGFILE"
  echo "GENRE=$GENRE" >> "$TAGFILE"
  echo "COMMENT=$COMMENT" >> "$TAGFILE"
  echo "PERFORMER=$PERFORMER" >> "$TAGFILE"
  echo "DATE=$YEAR" >> "$TAGFILE"
  echo "TAGDATE=$(date +%s)" >> "$TAGFILE"
  
  if [[ $METAVOL == "metadata" ]]; then
    echo "REPLAYGAIN_REFERENCE_LOUDNESS=$RPG_REFERENCE" >> "$TAGFILE"
    echo "REPLAYGAIN_TRACK_PEAK=$RPG_TRACKPEAK" >> "$TAGFILE"
    echo "REPLAYGAIN_TRACK_GAIN=$RPG_TRACKGAIN" >> "$TAGFILE"
    echo "REPLAYGAIN_ALBUM_PEAK=$RPG_ALBUMPEAK" >> "$TAGFILE"
    echo "REPLAYGAIN_ALBUM_GAIN=$RPG_ALBUMGAIN" >> "$TAGFILE"
  fi
  
  if [[ $CUSTOMTAGS -eq 1 ]]; then
    if ! [ -z "$CTVALUE1" ]; then echo -n "$CUSTOMTAG1=" >> "$TAGFILE"; echo "$CTVALUE1" >> "$TAGFILE"; fi
    if ! [ -z "$CTVALUE2" ]; then echo -n "$CUSTOMTAG2=" >> "$TAGFILE"; echo "$CTVALUE2" >> "$TAGFILE"; fi
    if ! [ -z "$CTVALUE3" ]; then echo -n "$CUSTOMTAG3=" >> "$TAGFILE"; echo "$CTVALUE3" >> "$TAGFILE"; fi
    if ! [ -z "$CTVALUE4" ]; then echo -n "$CUSTOMTAG4=" >> "$TAGFILE"; echo "$CTVALUE4" >> "$TAGFILE"; fi
    if ! [ -z "$CTVALUE5" ]; then echo -n "$CUSTOMTAG5=" >> "$TAGFILE"; echo "$CTVALUE5" >> "$TAGFILE"; fi
    if ! [ -z "$CTVALUE6" ]; then echo -n "$CUSTOMTAG6=" >> "$TAGFILE"; echo "$CTVALUE6" >> "$TAGFILE"; fi
    if ! [ -z "$CTVALUE7" ]; then echo -n "$CUSTOMTAG7=" >> "$TAGFILE"; echo "$CTVALUE7" >> "$TAGFILE"; fi
    if ! [ -z "$CTVALUE8" ]; then echo -n "$CUSTOMTAG8=" >> "$TAGFILE"; echo "$CTVALUE8" >> "$TAGFILE"; fi
    if ! [ -z "$CTVALUE9" ]; then echo -n "$CUSTOMTAG9=" >> "$TAGFILE"; echo "$CTVALUE9" >> "$TAGFILE"; fi
  fi

  # Now wipe all existing tags then re-load from the just-created text file
  # ---------------------------------------------------------------------------------
  metaflac $UTFCHARS --remove-all "$f"

  if [[ -f $TAGFILE ]]; then
    metaflac $UTFCHARS --import-tags-from="$TAGFILE" "$f"
  fi

  if [[ -f $CUEFILE ]]; then
    metaflac $UTFCHARS --set-tag-from-file=Cuesheet="$CUEFILE" "$f"
  fi

  if [[ -f $ALBUMART ]]; then
    metaflac $UTFCHARS --import-picture-from="$ALBUMART" "$f"
  fi
done
}

MESSAGE="Cleaning tags. Please wait…  "
clean_tags & spinner $!
