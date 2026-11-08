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
f=$(ls *.flac | head -1)
if ! [[ -z $f ]]; then
  CUESHEET=$(metaflac $UTFCHARS --show-tag=Cuesheet "$f" | $SEDPROG 's/.*=//g')
fi

# If a cuesheet exists, open it in an editor and then delete the original and replace
# -----------------------------------------------------------------------------------------
if ! [[ -z $CUESHEET ]]; then
  echo "$CUESHEET" > "$CONFDIR/tmp/tmp_cuesheet.txt"
  tput cvvis
  if [[ $OSFAMILY == "MACOS" ]]; then
    if command -v wezterm >/dev/null 2>&1; then
      wezterm start -- "$EDITOR" "$CONFDIR/tmp/tmp_cuesheet.txt" 2>/dev/null
    else
      xterm -xrm 'XTerm*selectToClipboard: true' -b 16 -bg black -fg white -geometry 103x35 +dc -tn xterm-256color -e "$EDITOR" "$CONFDIR/tmp/tmp_cuesheet.txt"
    fi
  else     
    xterm -xrm 'XTerm*selectToClipboard: true' -b 16 -bg black -fg white -geometry 103x35 -fa 'Luxi Mono:style=Regular' -fs 11 +dc -tn xterm-256color -e "$EDITOR" "$CONFDIR/tmp/tmp_cuesheet.txt"
  fi
else
  dialog --stdout --backtitle "Semplice FLAC Tagging" --title " Error! " --msgbox "\nThere is no embedded cuesheet to edit here!" 8 80
fi
}

cuesheet_edit
metaflac --remove-tag=CUESHEET "$f"
metaflac $UTFCHARS --set-tag-from-file=CUESHEET="$CONFDIR/tmp/tmp_cuesheet.txt" "$f"
rm -rf "$CONFDIR/tmp/tmp_cuesheet.txt"
