#!/usr/bin/env bash
####################################################################
#
# semtrks: routine for setting per-track TITLE tags
#
####################################################################
# We count the FLACs in the present folder, and dynamically construct
# an input form that prompts for that many TITLE tags.
# Check the first FLAC for writeability
f=$(find "$(pwd)" -maxdepth 1 -name "*.flac" | sort | head -n 1)
if [[ -w $f ]]; then
  :
else
  dialog --title " Semplice Track Titles " --msgbox "\\n\\nThere are files in this folder of FLACs that are not writeable, so we cannot continue.\\n\\nClick OK to return to the main menu." 12 70
  BREAKME=1
  return
fi

function display_filleddialog {
ITEMS=$(ls *.flac | wc -l);
ls *.flac | sort > "$CONFDIR/tmp/flaclist.txt"
if [[ $ITEMS -le 10 ]]; then FORMHEIGHT=$((ITEMS+6)); else FORMHEIGHT=20; fi
unset ITEMSTRING
for ((i=1; i<=$ITEMS; i++)); do
  THISFLAC=$($SEDPROG "${i}q;d" "$CONFDIR/tmp/flaclist.txt")
  EXISTING_TITLE=$(metaflac $UTFCHARS "--show-tag=TITLE" "$THISFLAC"  | $SEDPROG -E 's/^[^=]+=//' )
  ITEMSTRING+=("Track $i  :" "$i" 1 "$EXISTING_TITLE" "$i" 15 65 256)
done

exec 3>&1
VALUES=$( 2>&1 1>&3 dialog --ok-label "Submit" --extra-button --extra-label "  Clear All Track Data  " \
      --backtitle "Semplice FLAC Tagging: Track-specific metadata (1 of 1)" \
      --title " Track TITLE tags " \
      --form "" $FORMHEIGHT 95 0 \
      "${ITEMSTRING[@]}"
)
exitStatus=$?
exec 3>&-
}

function display_emptydialog {
clear
ITEMS=$(ls *.flac | wc -l);
ls *.flac | sort > "$CONFDIR/tmp/flaclist.txt"
if [[ $ITEMS -le 10 ]]; then FORMHEIGHT=$((ITEMS+6)); else FORMHEIGHT=20; fi
unset ITEMSTRING
for ((i=1; i<=$ITEMS; i++)); do
  THISFLAC=$($SEDPROG "${i}q;d" "$CONFDIR/tmp/flaclist.txt")
  EXISTING_TITLE=""
  ITEMSTRING+=("Track $i  :" "$i" 1 "$EXISTING_TITLE" "$i" 15 65 256)
done
exec 3>&1
VALUES=$( 2>&1 1>&3 dialog --ok-label "Submit" --extra-button --extra-label "  Clear All Track Data  " \
      --backtitle "Semplice FLAC Tagging" \
      --title " Specify each track's TITLE tag details " \
      --form "" $FORMHEIGHT 95 0 \
      "${ITEMSTRING[@]}"
)
exitStatus=$?
exec 3>&-
# On macOS, if there are accented characters, they need to be forced to be 'composed Unicode'
# rather than 'decomposed'.
if [[ $(uname -a) == *"Darwin"* ]] && command -v uconv >/dev/null 2>&1; then
  VALUES=$(echo "$VALUES" | uconv -x any-nfc)
fi
}

function evaluate_response {
if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then                                 # They pressed ESC or Cancel: do nothing
  BREAKME=1
elif  [[ $exitStatus -eq 3 ]]; then                                                     # They cleared the form: re-display completely blank
  BREAKME=0
  rm -f "$CONFDIR/tmp/tracklists.txt" 2>/dev/null
  display_emptydialog
  echo "$VALUES" > "$CONFDIR/tmp/tracklists.txt"
  tag_writes
else                                                                                    # They submitted proper track metadata
  BREAKME=0
  rm -f "$CONFDIR/tmp/tracklists.txt" 2>/dev/null
  echo "$VALUES" > "$CONFDIR/tmp/tracklists.txt"
  tag_writes
fi
}

function tag_writes {
LINECOUNT=1
for f in *.flac; do
  TITLE=$($SEDPROG "${LINECOUNT}q;d" "$CONFDIR/tmp/tracklists.txt")
  TITLE=${TITLE//.../…}	# Replace multiple dots with proper elipses.
  TITLE=${TITLE//../…}
  metaflac $UTFCHARS "--remove-tag=TITLE" "$f"
  metaflac $UTFCHARS "--set-tag=TITLE=$TITLE" "$f"
  FILETITLE=$(tr '~#%&<>:"/\|?*' '_' <<< "$TITLE") # This makes sure we save files with NTFS-safe file names. The TITLE tag is unchanged, so full punctuation allowed there, but not in filenames on disk
  FIXEDTRACK="${LINECOUNT#0}"    # Note that if presented with a 2-digit number starting with 0, printf will assume octal number. 08 and 09 will therefore result in errors.
                                # By stripping the leading zero at this point, we make printf work in decimal, which means 08 and 09 will be fine.
  NEWFILENAME="$(printf "%02d" $FIXEDTRACK)"\ -\ "$FILETITLE.flac"
  if [[ $f != "$NEWFILENAME" ]]; then
    mv -f "$f" "$NEWFILENAME" 2>/dev/null # We then put the leading zero back at this point.
  fi
  if [[ $NEWFILENAME == *".."* ]]; then
    mv "${NEWFILENAME}" "${NEWFILENAME//.../…}" 2>/dev/null; NEWFILENAME="${NEWFILENAME//.../…}"         # Change multiple full stops into proper ellipsis character. This is the three dot version...
    mv "${NEWFILENAME}" "${NEWFILENAME//../…}" 2>/dev/null; NEWFILENAME="${NEWFILENAME//../…}"           # ...and this is the two-dot one.
    mv "${NEWFILENAME}" "${NEWFILENAME//…flac/.flac}"                                                    # But a filename cannot end 'ellipsisflac'. If it does, make it plain 'dot flac'
  fi
  LINECOUNT=$((LINECOUNT+1))
done

for f in *.flac; do                                                                                      # Second loop required, because filename changes caused by the first would invalidate file renaming here
  OLDFILENAME=${f%.*}
  BITDEPTH=$(metaflac $UTFCHARS --list "$f" | $GREPPROG -a bits-per-sample | awk '{print $2}')
  SAMPLERATE=$(metaflac $UTFCHARS --list "$f" | $GREPPROG -a sample_rate | awk '{print $2}')
  if ! [[ $OLDFILENAME == *"-$SAMPLERATE"* ]]; then                                                    # Only rename if the file doesn't already have the bit/sample digits in it
    if [[ $NAMEBITS -eq 1 ]]; then                                                                         # And only rename if the configuration file says to do so
      NEWFILENAME="$OLDFILENAME-$BITDEPTH-$SAMPLERATE".flac
      mv "$f" "$NEWFILENAME"
    fi
  fi
done

if [[ $AUTOMODE -eq 1 ]]; then
  if [[ $BREAKME -eq 0 ]]; then
    source "$CONFDIR/bin/semclean.sh"
  fi
fi
}

if [[ $BREAKME -eq 0 ]]; then
  rm -f "$CONFDIR/tmp/tracklists.txt" 2>/dev/null                                                         # Clear out prior tagging runs
  display_filleddialog
  evaluate_response
fi
