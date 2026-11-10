#!/usr/bin/env bash
####################################################################
#
# semclean: routine for cleaning a set of tags. Used directly by
# the K menu option and by semquit.sh when quitting with
# post-processing, so there is only one copy of the cleaning code.
# Any file whose audio MD5 does not match the checksum stored in
# the FLAC is listed in $CONFDIR/tmp/corruptflacs.txt; it is up to
# the caller whether to warn about it (semquit.sh does).
#
####################################################################
TRACKCOUNT=$(ls *.flac | wc -l)  NOPROCESS=0
source "$CONFDIR/bin/semspin.sh"

ALBUMART=$CONFDIR/tmp/cleanart.jpg                                      # Initialise temporary work files
CUEFILE=$CONFDIR/tmp/cleancue.txt
TAGFILE=$CONFDIR/tmp/cleantag.txt
CORRUPTLIST=$CONFDIR/tmp/corruptflacs.txt
rm -f "$ALBUMART" 2>/dev/null
rm -f "$CUEFILE" 2>/dev/null
rm -f "$CORRUPTLIST" 2>/dev/null

function clean_tags
{
COUNTFLAC=$(ls *.flac | wc -l)
if [ $COUNTFLAC -eq 0 ]; then return; fi

# Extract album art from the first Flac found
f=$(find "$(pwd)" -name "*.flac" | sort | head -n 1)
metaflac $UTFCHARS --export-picture-to="$ALBUMART" "$f" 2>/dev/null     # Suppressing errors in case they haven't added album art or a cuesheet and hence there's nothing to export

for f in *.flac; do
  rm -f "$CUEFILE" 2>/dev/null                                          # Start each file afresh: a cuesheet must only ever go back into the file it came from
  BITDEPTH=$(metaflac --list "$f" | $GREPPROG -a bits-per-sample | awk '{print $2}')

  # Fetch existing metadata into variables.
  # ---------------------------------------------------------------------------------
  COMPOSER=$(get_tag Artist "$f")
  ARTIST=$(get_tag Artist "$f")
  ALBUM=$(get_tag Album "$f")
  TRACKNUMBER=$(get_tag TRACKNUMBER "$f")
  TITLE=$(get_tag Title "$f")
  GENRE=$(get_tag Genre "$f")
  COMMENT=$(get_tag Comment "$f")
  PERFORMER=$(get_tag Performer "$f")
  DESCRIPTION=$(get_tag Description "$f")
  YEAR=$(get_tag Date "$f")
  CUESHEET=$(metaflac $UTFCHARS --show-tag=CUESHEET "$f"); CUESHEET="${CUESHEET#*=}"     # Strip only the leading CUESHEET=: a cuesheet keeps its line breaks
  RPG_REFERENCE=$(get_tag REPLAYGAIN_REFERENCE_LOUDNESS "$f")
  RPG_TRACKPEAK=$(get_tag REPLAYGAIN_TRACK_PEAK "$f")
  RPG_TRACKGAIN=$(get_tag REPLAYGAIN_TRACK_GAIN "$f")
  RPG_ALBUMPEAK=$(get_tag REPLAYGAIN_ALBUM_PEAK "$f")
  RPG_ALBUMGAIN=$(get_tag REPLAYGAIN_ALBUM_GAIN "$f")

  if [[ ! -z "$CUESHEET" ]]; then
    echo "$CUESHEET" > "$CUEFILE"
  fi

  if [[ -z $COMMENT && -n $DESCRIPTION ]]; then                         # Some tagging software uses DESCRIPTION instead of COMMENT. We want to be consistent users of COMMENT,
    COMMENT="$DESCRIPTION"                                              # so carry the text across: it is then written back as COMMENT when the tags are rebuilt below
  fi

  if [[ $CUSTOMTAGS -eq 1 ]]; then
    CTVALUE1=$(get_tag "$CUSTOMTAG1" "$f")
    CTVALUE2=$(get_tag "$CUSTOMTAG2" "$f")
    CTVALUE3=$(get_tag "$CUSTOMTAG3" "$f")
    CTVALUE4=$(get_tag "$CUSTOMTAG4" "$f")
    CTVALUE5=$(get_tag "$CUSTOMTAG5" "$f")
    CTVALUE6=$(get_tag "$CUSTOMTAG6" "$f")
    CTVALUE7=$(get_tag "$CUSTOMTAG7" "$f")
    CTVALUE8=$(get_tag "$CUSTOMTAG8" "$f")
    CTVALUE9=$(get_tag "$CUSTOMTAG9" "$f")
  fi

  # Part of cleaning is to do a hash comparison: newly-computed with built-in
  # ---------------------------------------------------------------------------------
  MD5HASH=""                                                            # Reset per file, so one file's hash can never be compared with another's
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
  # Only compare when a hash was actually computed (16- and 24-bit files). Every mismatch is
  # recorded, not just the last one.
  if [[ -n $MD5HASH && $MD5HASH != "$FLACHASH" ]]; then
    echo "$f" >> "$CORRUPTLIST"
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

  # On macOS, convert every tag (and any cuesheet) into composed Unicode, so older files with
  # 'decomposed' accented characters are tidied up whenever they are cleaned
  # ---------------------------------------------------------------------------------
  if [[ $(uname) == "Darwin" ]]; then
    to_nfc < "$TAGFILE" > "$TAGFILE.nfc" && mv -f "$TAGFILE.nfc" "$TAGFILE"
    if [[ -f $CUEFILE ]]; then to_nfc < "$CUEFILE" > "$CUEFILE.nfc" && mv -f "$CUEFILE.nfc" "$CUEFILE"; fi
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
