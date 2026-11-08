#!/usr/bin/env bash
####################################################################
#
# ablibsemquit: routine for exiting, with or without tag cleaning
# Note that the aim is to ensure only a specific set of tags, stored
# in a specific order, are preserved after cleaning. This means the
# cleaning code is a bit laborious, crafting things in a particular
# way, rather than using metaflac's built-in export-to-file and
# import-from-file capabilities. That would not allow us to have'
# quite the degree of control over tagging (without a lot of sed
# work to knock the export file into shape, anyway).
#
####################################################################
source "$CONFDIR/bin/ablibsemspin.sh" 
source "$CONFDIR/bin/ablibsemtput.sh" 
source "$CONFDIR/bin/ablibsemparse.sh" 
TRACKCOUNT=$(ls *.flac | wc -l)  NOPROCESS=0

source "$CONFDIR/bin/ablibsemspin.sh"

ALBUMART=$CONFDIR/tmp/cleanart.jpg                                      # Initialise temporary work files
CUEFILE=$CONFDIR/tmp/cleancue.txt
TAGFILE=$CONFDIR/tmp/cleantag.txt
rm -f "$ALBUMART" 2>/dev/null
rm -f "$CUEFILE" 2>/dev/null

function nice_exit {
# Clean up any temporary working files that may have been produced
clear
rm -f "$CONFDIR/tmp/"*.txt 2>/dev/null
tput sgr0
tput cvvis
exit 0
}

function clean_tags
{
COUNTFLAC=$(ls *.flac | wc -l)
if [[ $COUNTFLAC -eq 0 ]]; then return; fi
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

  if [[ ! -z $CUESHEET ]]; then
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
  echo -n "COMPOSER=" > "$TAGFILE"; echo "$COMPOSER" >> "$TAGFILE"
  echo -n "ARTIST=" >> "$TAGFILE"; echo "$ARTIST" >> "$TAGFILE"
  echo -n "ALBUM=" >> "$TAGFILE"; echo "$ALBUM" >> "$TAGFILE"
  echo -n "TRACKNUMBER=" >> "$TAGFILE"; echo "$TRACKNUMBER" >> "$TAGFILE"
  echo -n "TITLE=" >> "$TAGFILE"; echo "$TITLE" >> "$TAGFILE"
  echo -n "GENRE=" >> "$TAGFILE"; echo "$GENRE" >> "$TAGFILE"
  echo -n "COMMENT=" >> "$TAGFILE"; echo "$COMMENT" >> "$TAGFILE"
  echo -n "PERFORMER=" >> "$TAGFILE"; echo "$PERFORMER" >> "$TAGFILE"
  echo -n "DATE=" >> "$TAGFILE"; echo "$YEAR" >> "$TAGFILE"
  echo -n "TAGDATE=" >> "$TAGFILE"; echo "$(date +%s)" >> "$TAGFILE"

  if [[ $CUSTOMTAGS -eq 1 ]]; then
    if [[ $CTVALUE1 != "XqXXqXX" ]]; then echo -n "$CUSTOMTAG1=" >> "$TAGFILE"; echo "$CTVALUE1" >> "$TAGFILE"; fi
    if [[ $CTVALUE2 != "XqXXqXX" ]]; then echo -n "$CUSTOMTAG2=" >> "$TAGFILE"; echo "$CTVALUE2" >> "$TAGFILE"; fi
    if [[ $CTVALUE3 != "XqXXqXX" ]]; then echo -n "$CUSTOMTAG3=" >> "$TAGFILE"; echo "$CTVALUE3" >> "$TAGFILE"; fi
    if [[ $CTVALUE4 != "XqXXqXX" ]]; then echo -n "$CUSTOMTAG4=" >> "$TAGFILE"; echo "$CTVALUE4" >> "$TAGFILE"; fi
    if [[ $CTVALUE5 != "XqXXqXX" ]]; then echo -n "$CUSTOMTAG5=" >> "$TAGFILE"; echo "$CTVALUE5" >> "$TAGFILE"; fi
    if [[ $CTVALUE6 != "XqXXqXX" ]]; then echo -n "$CUSTOMTAG6=" >> "$TAGFILE"; echo "$CTVALUE6" >> "$TAGFILE"; fi
    if [[ $CTVALUE7 != "XqXXqXX" ]]; then echo -n "$CUSTOMTAG7=" >> "$TAGFILE"; echo "$CTVALUE7" >> "$TAGFILE"; fi
    if [[ $CTVALUE8 != "XqXXqXX" ]]; then echo -n "$CUSTOMTAG8=" >> "$TAGFILE"; echo "$CTVALUE8" >> "$TAGFILE"; fi
    if [[ $CTVALUE9 != "XqXXqXX" ]]; then echo -n "$CUSTOMTAG9=" >> "$TAGFILE"; echo "$CTVALUE9" >> "$TAGFILE"; fi
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

if [[ $CORRUPTFLAC -eq 1 ]]; then
  dialog --stdout --backtitle "Semplice Digital Music Manager" --title " Possibly Corrupt Files Detected! " --msgbox "\nOne or more files has been detected to have an MD5 Checksum mismatch. \n\nCheck your backups to resolve!" 10 80
  NOPROCESS=1
fi
}

function clean_up {
# Add bitdepth and sampling rate to files, if NAMEBITS is set
for f in *.flac; do                                                                                      # Second loop required, because filename changes caused by the first would invalidate file renaming here
  BITDEPTH=$(metaflac $UTFCHARS --list "$f" | $GREPPROG bits-per-sample | awk '{print $2}')
  SAMPLERATE=$(metaflac $UTFCHARS --list "$f" | $GREPPROG sample_rate | awk '{print $2}')
  OLDFILENAME="${f%.*}"
  if ! [[ $f == *"-$SAMPLERATE"* ]]; then                                                    # Only rename if the file doesn't already have the bit/sample digits in it
    if [[ $NAMEBITS -eq 1 ]]; then                                                                         # And only rename if the configuration file says to do so
      NEWFILENAME="$OLDFILENAME-$BITDEPTH-$SAMPLERATE".flac
      mv "$f" "$NEWFILENAME"
    fi
  fi
done

rm -f "$CONFDIR/tmp/cleanart.jpg" 2>/dev/null
rm -f "$CONFDIR/tmp/cleancue.txt" 2>/dev/null
rm -f "$CONFDIR/tmp/cleantag.txt" 2>/dev/null
if [ $countflac -gt 0 ]; then
  dialog --stdout --backtitle "Semplice Digital Music Manager" --title " Quitting Semplice! " --msgbox "\nAll metadata tags have been cleaned.\n\nThank you for using Semplice!" 10 80
fi
}

if [[ $1 == "clean" ]]; then
  countflac=$(find . -maxdepth 1 -type f -name "*.flac" | wc -l)
  if [[ $countflac -gt 0 ]]; then
    MESSAGE="Cleaning tags on exit. Please wait…  "
    clean_tags & spinner $!
    clean_up
  fi
fi

nice_exit
