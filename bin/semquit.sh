#!/usr/bin/env bash
####################################################################
#
# semquit: routine for exiting, with or without tag cleaning.
# The cleaning itself is done by semclean.sh (the same code the K
# menu option uses). Quitting with post-processing adds a warning
# about any files with checksum mismatches, and renames files to
# include bit-depth and sample rate if NAMEBITS is set.
#
####################################################################
source "$CONFDIR/bin/semspin.sh"
source "$CONFDIR/bin/semtput.sh"

function nice_exit {
# Clean up any temporary working files that may have been produced
clear
rm -f "$CONFDIR/tmp/"*.txt 2>/dev/null
tput sgr0
tput cvvis
exit 0
}

function warn_corrupt {
# semclean.sh lists every FLAC whose audio MD5 does not match its stored checksum
local LIST="$CONFDIR/tmp/corruptflacs.txt" FILES COUNT
if [[ -s $LIST ]]; then
  COUNT=$(wc -l < "$LIST" | xargs)
  FILES=$(head -n 8 "$LIST")
  if [[ $COUNT -gt 8 ]]; then FILES="$FILES\n...and $((COUNT-8)) more"; fi
  dialog --stdout --backtitle "Semplice Digital Music Manager" --title " Possibly Corrupt Files Detected! " --msgbox "\nThese files have an MD5 checksum mismatch:\n\n$FILES\n\nCheck your backups to resolve!" 18 80
fi
}

function rename_bits {
# Add bitdepth and sampling rate to file names, if NAMEBITS is set
for f in *.flac; do
  BITDEPTH=$(metaflac $UTFCHARS --list "$f" | $GREPPROG bits-per-sample | awk '{print $2}')
  SAMPLERATE=$(metaflac $UTFCHARS --list "$f" | $GREPPROG sample_rate | awk '{print $2}')
  OLDFILENAME="${f%.*}"
  if ! [[ $f == *"-$SAMPLERATE"* ]]; then                                     # Only rename if the file doesn't already have the bit/sample digits in it
    if [[ $NAMEBITS -eq 1 ]]; then                                            # And only rename if the configuration file says to do so
      NEWFILENAME="$OLDFILENAME-$BITDEPTH-$SAMPLERATE".flac
      mv "$f" "$NEWFILENAME"
    fi
  fi
done
}

if [[ $1 == "clean" ]]; then
  countflac=$(find . -maxdepth 1 -type f -name "*.flac" | wc -l)
  if [[ $countflac -gt 0 ]]; then
    source "$CONFDIR/bin/semclean.sh"                                         # The same cleaning as the K menu option
    warn_corrupt
    rename_bits
    rm -f "$CONFDIR/tmp/cleanart.jpg" "$CONFDIR/tmp/cleancue.txt" "$CONFDIR/tmp/cleantag.txt" 2>/dev/null
    dialog --stdout --backtitle "Semplice Digital Music Manager" --title " Quitting Semplice! " --msgbox "\nAll metadata tags have been cleaned.\n\nThank you for using Semplice!" 10 80
  fi
fi

nice_exit
