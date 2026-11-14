#!/usr/bin/env bash
####################################################################
#
# semfunctions: functions shared by Semplice's scripts. Loaded once,
# at start-up, by semplice4.sh (as Giocoso's giofunctions.sh is).
#
####################################################################

# flatten_lines: reads text on stdin and returns it as a single line. Each line break becomes
# one space; spaces either side of a join are trimmed so words never abut and never double up;
# blank lines and carriage returns are dropped.
function flatten_lines {
awk '{ sub(/\r$/, ""); sub(/^[ \t]+/, ""); sub(/[ \t]+$/, "")
       if ($0 == "") next
       out = (n++ ? out " " : "") $0 }
     END { printf "%s", out }'
}

# to_nfc: on macOS, converts text read from standard input into 'composed' Unicode (NFC), so
# an accented letter is stored as one character rather than a letter plus a separate accent mark.
# Typed text on macOS can arrive decomposed. Elsewhere, or if uconv is missing, text passes through unchanged.
function to_nfc {
if [[ $(uname) == "Darwin" ]] && command -v uconv >/dev/null 2>&1; then
  uconv -x any-nfc
else
  cat
fi
}

# bits_suffix FILE: prints the "-<bit depth>-<sample rate>" suffix for FILE (e.g. "-24-96000"),
# or nothing if FLAC can't report them. grep -a, because metaflac's listing can include binary picture data.
function bits_suffix {
local listing depth rate
listing=$(metaflac --list "$1" 2>/dev/null)
depth=$($GREPPROG -a -m1 "bits-per-sample" <<< "$listing" | awk '{print $2}')
rate=$($GREPPROG -a -m1 "sample_rate" <<< "$listing" | awk '{print $2}')
if [[ -n $depth && -n $rate ]]; then echo "-$depth-$rate"; fi
}

# add_bits_to_names: if NAMEBITS is set, adds the bits_suffix to every FLAC name in the current
# folder that doesn't already end with it. Used by track tagging and Quit.
function add_bits_to_names {
local f suffix
if [[ $NAMEBITS -ne 1 ]]; then return; fi
for f in *.flac; do
  [[ -f $f ]] || continue
  suffix=$(bits_suffix "$f")
  if [[ -n $suffix && ${f%.flac} != *"$suffix" ]]; then
    mv -- "$f" "${f%.flac}$suffix.flac"
  fi
done
}

# warn_corrupt: semclean.sh lists every FLAC whose audio MD5 does not match its stored checksum;
# this shows that list, if there is one. Used by K (all menus) and by Quit.
function warn_corrupt {
local LIST="$CONFDIR/tmp/corruptflacs.txt" FILE MSG
if [[ -s $LIST ]]; then
  FILE=$(head -n 1 "$LIST")                      # Only the first damaged file is named
  if [[ $(find . -maxdepth 1 -type f -name "*.flac" | wc -l) -gt 1 ]]; then
    MSG="Corruption has definitely been detected in this file, but it may be present in other FLACs in this folder. Please restore from backup before re-checking the files."
  else
    MSG="Corruption has definitely been detected in this file. Please restore from backup before re-checking the file."
  fi
  dialog --stdout --backtitle "Semplice Tag Cleaning" --title " Possibly Corrupt Files Detected! " --msgbox "\nAt least one of the FLACs in this folder has an MD5 checksum mismatch, indicating internal corruption:\n\n$FILE\n\n$MSG" 14 80
fi
warn_nomd5                                         # Then any FLACs that have no checksum at all
}

# warn_nomd5: semclean.sh lists every FLAC whose stored checksum is all zeros (never recorded). Says so,
# naming the first, and offers to add the checksums by re-encoding those files in place.
function warn_nomd5 {
local LIST="$CONFDIR/tmp/nomd5flacs.txt" FILE
if [[ -s $LIST ]]; then
  FILE=$(head -n 1 "$LIST")
  if dialog --stdout --backtitle "Semplice Tag Cleaning" --title " FLACs Without Checksums Detected! " --yesno "\nAt least one of the FLACs in this folder has no internal checksum, which is regarded as an error:\n\n$FILE\n\nWould you like to add the missing checksums now? Any tags and artwork will be preserved and absolutely no alteration to the music stream data will be made." 14 80; then
    MESSAGE="Adding checksums. Please wait…  "
    add_checksums & spinner $!
  fi
fi
}

# add_checksums: re-encodes each FLAC listed in nomd5flacs.txt to FLAC, which records a fresh checksum, then
# copies its tags and artwork across. A file is replaced only if the new one has a checksum and the same length.
function add_checksums {
local f TMP
while IFS= read -r f; do
  [[ -f $f ]] || continue
  TMP="${f%.flac}.md5fix.tmp"
  rm -f "$TMP"
  if flac --silent -f -8 "$f" -o "$TMP" 2>/dev/null \
     && [[ $(metaflac --show-md5sum "$TMP") != "00000000000000000000000000000000" ]] \
     && [[ $(metaflac --show-total-samples "$TMP") == "$(metaflac --show-total-samples "$f")" ]]; then
    metaflac $UTFCHARS --remove-all-tags "$TMP"
    metaflac $UTFCHARS --export-tags-to=- "$f" | metaflac $UTFCHARS --import-tags-from=- "$TMP"
    metaflac --remove --block-type=PICTURE "$TMP" 2>/dev/null
    if metaflac --export-picture-to="$CONFDIR/tmp/md5fixart" "$f" 2>/dev/null; then
      metaflac --import-picture-from="$CONFDIR/tmp/md5fixart" "$TMP"
      rm -f "$CONFDIR/tmp/md5fixart"
    fi
    mv -f "$TMP" "$f"
  else
    rm -f "$TMP"
  fi
done < "$CONFDIR/tmp/nomd5flacs.txt"
}

# get_tag NAME FILE: prints the value of tag NAME in FILE as a single line. Only the leading
# "NAME=" is removed, so values containing '=' survive intact. Repeated tags and multi-line
# values are joined with single spaces (see flatten_lines). Not for CUESHEET, which must keep
# its line breaks.
function get_tag {
metaflac $UTFCHARS --show-tag="$1" "$2" 2>/dev/null | awk -v pre="$1=" '
  { if (tolower(substr($0, 1, length(pre))) == tolower(pre)) $0 = substr($0, length(pre) + 1); print }' | flatten_lines
}

# lookup_drive_offset DEVICE: prints the read offset listed in cddriveoffsets.csv for the drive at
# DEVICE (as identified by cdparanoia), or nothing if the drive is not listed. Linux only.
function lookup_drive_offset {
local driveid
if ! [[ -f "$CONFDIR/txt/cddriveoffsets.csv" ]]; then
  wget --quiet https://raw.githubusercontent.com/dizwell/semplice4/main/txt/cddriveoffsets.csv -O "$CONFDIR/txt/cddriveoffsets.csv"
fi
driveid=$(cdparanoia -vsQ -d "$1" 2>&1 | awk -F: '/sensed/ {print $2}' | awk '{print $--NF}')
if [[ -z $driveid ]]; then return; fi
$GREPPROG -Rnw "$CONFDIR/txt/cddriveoffsets.csv" -e "$driveid" | awk -F '|' '{print $2; exit;}'
}
