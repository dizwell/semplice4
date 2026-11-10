#!/usr/bin/env bash
####################################################################
#
# semmeta: routine for displaying existing metadata for all
# tracks in working folder
#
####################################################################
function list_metadata
{
rm -f "$CONFDIR/tmp/listmetadata.txt" >/dev/null
for f in *.flac; do
  echo "FLAC File: $f" >> "$CONFDIR/tmp/listmetadata.txt"
  echo "====================================================================================================" >> "$CONFDIR/tmp/listmetadata.txt"
  if [[ $(metaflac --list --block-type=PICTURE "$f" | wc -l) -eq 0 ]]; then
    echo "*** No album art detected ***" >> "$CONFDIR/tmp/listmetadata.txt"
  else
    echo "Good album art detected OK" >> "$CONFDIR/tmp/listmetadata.txt"
  fi
  metaflac $UTFCHARS --list --block-type=VORBIS_COMMENT "$f" >> "$CONFDIR/tmp/listmetadata.txt"
  echo "====================================================================================================" >> "$CONFDIR/tmp/listmetadata.txt"
done

# Bunch of deletions and substitutions to make the output look a bit nicer
# -------------------------------------------------------------------------
$SEDPROG -i '/METADATA/d' "$CONFDIR/tmp/listmetadata.txt"
$SEDPROG -i '/  length:/d' "$CONFDIR/tmp/listmetadata.txt"
$SEDPROG -i '/  type:/d' "$CONFDIR/tmp/listmetadata.txt"
$SEDPROG -i '/VORBIS_COMMENT/d' "$CONFDIR/tmp/listmetadata.txt"
$SEDPROG -i '/  is last:/d' "$CONFDIR/tmp/listmetadata.txt"
$SEDPROG -i '/  vendor string:/d' "$CONFDIR/tmp/listmetadata.txt"
$SEDPROG -i 's/comments:/Metadata Tags:/g' "$CONFDIR/tmp/listmetadata.txt"
$SEDPROG -i 's/comment\[/Tag \[:/g' "$CONFDIR/tmp/listmetadata.txt"

# Show the listing. The (otherwise unused) Help button is relabelled "Copy to Clipboard": pressing it copies the
# entire listing, then shows the listing again. OK closes it.
while true; do
  dialog --backtitle "Semplice FLAC Tagging" --title " Metadata used by FLACs in current working folder " --exit-label "OK" \
         --help-button --help-label " Copy to Clipboard " --textbox "$CONFDIR/tmp/listmetadata.txt" 20 90
  if [[ $? -eq 2 ]]; then
    copy_to_clipboard "$CONFDIR/tmp/listmetadata.txt"
    dialog --backtitle "Semplice FLAC Tagging" --title " Copied " --msgbox "\nThe entire metadata listing has been copied to the clipboard." 7 70
  else
    break
  fi
done
}

# copy_to_clipboard FILE: puts FILE's contents on the clipboard. On macOS, pbcopy is built in and always works.
# On Linux, use wl-copy (Wayland) or xclip (X11) if installed; otherwise fall back to the terminal's own clipboard
# escape sequence (OSC 52), which WezTerm understands.
function copy_to_clipboard
{
if [[ $(uname) == "Darwin" ]]; then
  pbcopy < "$1"
elif [[ -n $WAYLAND_DISPLAY ]] && command -v wl-copy >/dev/null 2>&1; then
  wl-copy < "$1"
elif [[ -n $DISPLAY ]] && command -v xclip >/dev/null 2>&1; then
  xclip -selection clipboard < "$1"
else
  printf '\033]52;c;%s\a' "$(base64 < "$1" | tr -d '\n')" > /dev/tty
fi
}

list_metadata
