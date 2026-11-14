#!/usr/bin/env bash
####################################################################
#
# semcuee: routine for editing an embedded cuesheet
#
####################################################################
source "$CONFDIR/bin/semtput.sh" 
unset CUESHEET
rm -f "$CONFDIR/tmp/tmp_cuesheet.txt"

function cuesheet_edit {

# First, extract the cuesheet to a working file, assuming one exists
# -----------------------------------------------------------------------------------------
f=$(ls *.flac 2>/dev/null | head -1)
if ! [[ -z $f ]]; then
  CUESHEET=$(metaflac $UTFCHARS --show-tag=CUESHEET "$f")
  CUESHEET="${CUESHEET#*=}"                       # Strip only the leading CUESHEET=, so lines containing '=' survive intact
fi

# If a cuesheet exists, open it in an editor and then delete the original and replace
# -----------------------------------------------------------------------------------------
if ! [[ -z $CUESHEET ]]; then
  echo "$CUESHEET" > "$CONFDIR/tmp/tmp_cuesheet.txt"
  tput cvvis
  "${WEZTERM_EXECUTABLE:-wezterm}" start --always-new-process -- "$EDITOR" "$CONFDIR/tmp/tmp_cuesheet.txt" 2>/dev/null    # Separate window; waits until it is closed
else
  dialog --stdout --backtitle "Semplice FLAC Tagging" --title " Error! " --msgbox "\nThere is no embedded cuesheet to edit here!" 8 80
fi
}

cuesheet_edit
if [[ -f $CONFDIR/tmp/tmp_cuesheet.txt ]]; then   # Only save if a cuesheet was found and opened for editing
  metaflac --remove-tag=CUESHEET "$f"
  metaflac $UTFCHARS --set-tag-from-file=CUESHEET="$CONFDIR/tmp/tmp_cuesheet.txt" "$f"
  rm -f "$CONFDIR/tmp/tmp_cuesheet.txt"
fi
