#!/usr/bin/env bash
####################################################################
#
# sembits: routine for renaming FLAC files so that they
# contain indications of their bit-depth and sampling rate
#
####################################################################
function bitrename {
for f in *.flac; do
  OLDFILENAME=${f%.*}
  BITDEPTH=$(metaflac $UTFCHARS --list "$f" | $GREPPROG bits-per-sample | awk '{print $2}')
  SAMPLERATE=$(metaflac $UTFCHARS --list "$f" | $GREPPROG sample_rate | awk '{print $2}')
  if ! [[ $OLDFILENAME == *"-$SAMPLERATE"* ]]; then                                       # Only rename if the file doesn't already have the bit/sample digits in it.
    NEWFILENAME="$OLDFILENAME-$BITDEPTH-$SAMPLERATE".flac
    mv "$f" "$NEWFILENAME"
  fi
  unset OLDFILENAME
  unset NEWFILENAME
done
}

bitrename
