#!/usr/bin/env bash
####################################################################
#
# ablibsemmeta: routine for displaying existing metadata for all
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

dialog --backtitle "Semplice FLAC Tagging" --title " Metadata used by FLACs in current working folder " --exit-label "OK" --textbox "$CONFDIR/tmp/listmetadata.txt" 20 90
}

list_metadata
