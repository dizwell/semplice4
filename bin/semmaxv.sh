#!/usr/bin/env bash
####################################################################
#
# semmaxv: routine for analysing FLACs for possible
# non-distorting volume boosts and applying them if asked.
#
####################################################################
CANBEBOOSTED=0 DELETESOURCE=0 BOOSTPERFORMED=0
source "$CONFDIR/bin/semtput.sh" 
source "$CONFDIR/bin/semspin.sh"

is_numeric() {
  [[ $1 =~ ^-?[0-9]+([.][0-9]+)?$ ]]
}

function perform_volumeanalysis {
tput civis; tput cup 25 1; printf $LINEDRAW2%.0s {1..101}; MESSAGE="Analysing each of the FLACs in turn…  "; tput cup 25 4;
declare -A peak_volumes
# Loop through each FLAC in turn. Analyse its peak volume level. Add to text file.
# Then sort the file such that the first item has the lowest peak volume number:
# That is the track which can take the least volume boost, so is the benchmark
# for the maximum volume boost that can be applied to all the files.

>volumes.txt
for f in *.flac; do
  # ffmpeg reports e.g. "max_volume: -3.2 dB". Take the number after "max_volume:" and drop any minus sign, so
  # "-3.2" becomes 3.2 (the headroom available). A full-volume track may be reported as "0.0" or "-0.0": either way it gives 0.
  MAXV=$("$FFMPEG" -i "$f" -af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 | $GREPPROG -a 'max_volume:' | \
         awk '{ for (i = 1; i < NF; i++) if ($i == "max_volume:") { v = $(i+1); sub(/^[-+]/, "", v); print v; exit } }')

  # If nothing could be read at all, treat the file as having no headroom: that safely prevents any boost
  if ! is_numeric "$MAXV"; then MAXV=0; fi
  
  if is_numeric "$MAXV"; then
    # If a file is 0.5dB close to 0, it's pointless analysing further, so quit scanning
    if (( $(echo "scale=4; $MAXV <= 0.5" | bc -l) )); then
      echo "$f | 0" >> volumes.txt
      break
    fi
    echo "$f | $MAXV" >> volumes.txt
  fi
done  & spinner $!

CANDIDATE_FILE=$(sort -n -t "|" -k 2 volumes.txt | head -1 | awk -F '|' '{print$1}')
CANDIDATE_BOOST=$(sort -n -t "|" -k 2 volumes.txt | head -1 | awk -F '|' '{print$2}')
if (( $(echo "scale=4; $CANDIDATE_BOOST > 8.0" | bc -l) )); then CANDIDATE_BOOST=8; fi    # If potential volume boost is enormous, artificially cap it to a sane, lesser amount

# The scenarios are:
# 1) There are no contents in the volumes.txt file for some reason
# 2) There are contents, but the maximum possible boost is only 0.5dB or less
# 3) There are contents and candidates and a good boost is possible

if [[ -z $CANDIDATE_BOOST ]]; then
  BOOSTPERFORMED=0; CANBEBOOSTED=0
  dialog --stdout --backtitle "Semplice FLAC Volume Boosting" --msgbox "\\nNo files can be volume boosted." 11 80
elif (( $(echo "scale=4; $CANDIDATE_BOOST <= 0.5" | bc -l) )); then
  BOOSTPERFORMED=0; CANBEBOOSTED=0
  dialog --stdout --backtitle "Semplice FLAC Volume Boosting" --msgbox "\\nNo significant volume boost can be applied to this set of files." 11 80
elif (( $(echo "scale=4; $CANDIDATE_BOOST > 0.5" | bc -l) )); then
  CANDIDATE_BOOST=$(echo "scale=4; $CANDIDATE_BOOST-0.5" | bc)                           # Knocking off ½dB from the adjustment, just to be certain we don't propose to distort
  if (( $(echo "scale=4; $CANDIDATE_BOOST < 1" | bc -l) )); then
    DISPCANDIDATE_BOOST="+0$CANDIDATE_BOOST"
  else
    DISPCANDIDATE_BOOST="+$CANDIDATE_BOOST"
  fi
  dialog --backtitle "Semplice FLAC Volume Boosting" --title " Non-distorting Volume Boost Possible " --yes-label " Go ahead and boost " --no-label " Quit without boosting " --yesno "\nThe loudest FLAC in this folder is: \n\n  $CANDIDATE_FILE\n\nThat and all other FLACs in this folder can be safely volume-boosted by $DISPCANDIDATE_BOOST dB.\n\nDo you want to apply that volume boost or not?" 13 95
  exitStatus=$?   # 0 means user hit [yes] button. 1 means user hit [no] button. 255 means user hit [Esc] key.
  if [[ $exitStatus -eq 0 ]]; then CANBEBOOSTED=1; fi
  if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then CANBEBOOSTED=0; fi
fi
}

function perform_volumeboost {
f=$(find "$(pwd)" -maxdepth 1 -name "*.flac" | sort | head -n 1)
BITDEPTH=$(metaflac $UTFCHARS --list "$f" | $GREPPROG -a bits-per-sample | awk '{print $2}')
SAMPLERATE=$(metaflac $UTFCHARS --list "$f" | $GREPPROG -a sample_rate | awk '{print $2}')

if [[ $CANBEBOOSTED -eq 1 ]]; then                                                                           # Has permission to volume-boost been acquired?
  MESSAGE="Performing a volume boost of "$DISPCANDIDATE_BOOST"dB…  "
  BOOSTPERFORMED=1
  for f in *.flac; do
    [[ $f == *"-dB-"* ]] && continue                                                            # Only process files which are not already volume-boosted.

    # We are about to use ffmpeg to re-encode FLAC files. However, ffmpeg scrambles the
    # COMMENT tag: the COMMENT tag becomes a tag called 'DESCRIPTION'! So keep this file's
    # own COMMENT, and put it back into this file's boosted copy straight afterwards
    # Notes may be in COMMENT, DESCRIPTION or both (other taggers, or an earlier ffmpeg re-encode, use DESCRIPTION):
    # carry them all across as COMMENT, merged with a single space as cleaning does
    ORIGCOMMENT=$(get_tag COMMENT "$f")
    ORIGDESC=$(get_tag DESCRIPTION "$f")
    if [[ -n $ORIGDESC && $ORIGDESC != "$ORIGCOMMENT" ]]; then
      if [[ -z $ORIGCOMMENT ]]; then ORIGCOMMENT="$ORIGDESC"; else ORIGCOMMENT="$ORIGCOMMENT $ORIGDESC"; fi
    fi
    BOOSTED="+$CANDIDATE_BOOST-dB-$f"                                                           # e.g. "+3.5-dB-01 - Allegro.flac"

    if [ $BITDEPTH -eq 24 ]; then
      "$FFMPEG" -y -i "$f" -sample_fmt s32 -ar $SAMPLERATE -filter:a "volume='$CANDIDATE_BOOST'dB" "$BOOSTED" 2>/dev/null & spinner $!
    else
      "$FFMPEG" -y -i "$f" -sample_fmt s16 -ar $SAMPLERATE -filter:a "volume='$CANDIDATE_BOOST'dB" "$BOOSTED" 2>/dev/null & spinner $!
    fi

    metaflac $UTFCHARS --remove-tag=COMMENT --remove-tag=DESCRIPTION "$BOOSTED"                 # Remove ffmpeg's spurious DESCRIPTION (and any COMMENT)...
    if [[ -n $ORIGCOMMENT ]]; then
      metaflac $UTFCHARS "--set-tag=COMMENT=$ORIGCOMMENT" "$BOOSTED"                            # ...then restore this file's own COMMENT
    fi
  done
fi
}

function perform_cleanup {
if [[ $BOOSTPERFORMED -eq 1 ]]; then                                   # Ditto! Don't even offer to delete anything if you haven't actually volume-boosted something
  dialog --backtitle "Semplice FLAC Volume Boosting" --title " Do you want to delete the original FLACs? " --yesno "\nVolume boosting is complete. Do you wish to now delete the original FLACs?" 9 80
  exitStatus=$?
  if [[ $exitStatus -eq 0 ]]; then DELETESOURCE=1; fi
  if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then DELETESOURCE=0; fi
fi

if [[ $DELETESOURCE -eq 1 && $BOOSTPERFORMED -eq 1 ]]; then
  find . -maxdepth 1 -type f -name "*.flac" ! -name '+*-dB-*' -exec rm -f {} \;  # deletes the source files because they don't include a -dB- prefix.
  for f in *-dB-*.flac; do
    mv "$f" "${f#*-dB-}"                                              # removes the dB prefix from the new files, leaving them named as the old source ones were
  done
fi
}

function perform_replaygain {
tput civis; tput cup 25 1; printf $LINEDRAW2%.0s {1..101}; MESSAGE="Analysing the folder of FLACs…  "; tput cup 25 4	
metaflac --add-replay-gain *.flac 2>/dev/null & spinner $!

# Report the result: the album gain is the same in every FLAC, so read it from the first one
f=$(ls *.flac 2>/dev/null | head -1)
ALBUMGAIN=$(get_tag REPLAYGAIN_ALBUM_GAIN "$f")
if [[ -n $ALBUMGAIN ]]; then
  dialog --stdout --backtitle "Semplice FLAC Volume Boosting" --title " Metadata Volume Boost Applied " --msgbox "\nMetadata volume boost successfully applied.\n\nThe calculated album gain is: $ALBUMGAIN\n\nClick OK to return to the main program menu." 11 80
else
  dialog --stdout --backtitle "Semplice FLAC Volume Boosting" --title " Metadata Volume Boost Failed " --msgbox "\nThe ReplayGain metadata could not be added, so no volume boost has been applied.\n\nClick OK to return to the main program menu." 10 80
fi
}

# Executable code starts here!
# -----------------------------------------------------
if [ "$METAVOL" = "real" ]; then
    DEFAULT="yes"
	XTRATXT="(i.e., physical alteration of the FLACs)"
else
    DEFAULT="no"
	XTRATXT="(i.e., adding ReplayGain metadata to the FLACs)"
fi

dialog \
    --backtitle "Semplice Volume Boosting" \
    --title " Volume Boost Method " \
    --default-button "$DEFAULT" \
    --yes-label " Real (Physical)" \
    --no-label " Metadata (ReplayGain) " \
    --yesno "\nThe currently configured default volume boosting mechanism is '$METAVOL' $XTRATXT.\n\nDo you wish to use this option now, or adopt the alternative method instead?\n\nYou can also press ESC to cancel without volume boosting at all." 14 90
case $? in
    0) BOOSTTYPE="real" ;;
    1) BOOSTTYPE="metadata" ;;
  255) BOOSTTYPE="cancel";;
esac

if [[ $BOOSTTYPE == "real" ]]; then
  perform_volumeanalysis

  if [[ $CANBEBOOSTED -eq 1 ]]; then
    perform_volumeboost;
  fi
  perform_cleanup
  if [[ $BOOSTPERFORMED -eq 1 ]]; then
    dialog --stdout --backtitle "Semplice FLAC Volume Boosting" --msgbox "All FLACs have been volume-boosted: \n\nClick OK to return to the main program menu." 8 80
  else
    dialog --stdout --backtitle "Semplice FLAC Volume Boosting" --msgbox "No files have been modified: \n\nClick OK to return to the main program menu." 8 80
  fi
  rm -f volumes.txt >/dev/null
elif [[ $BOOSTTYPE == "metadata" ]]; then							#We will add REPLAYGAIN metadata instead of doing a physical volume boost
  perform_replaygain
else
  dialog --backtitle "Semplice Volume Boosting" --title " Volume Boosting Cancelled " --msgbox "\nYou pressed ESC, so no volume boosting has been performed.\n\nClick OK to return to the main menu." 8 80
  return	
fi