#!/usr/bin/env bash
####################################################################
#
# semkeydisc: Configure AccurateRip. Works out the optical drive's
# read offset from ordinary audio CDs ("key discs") that are in the
# AccurateRip database, as EAC and dBpoweramp do.
#
# For each disc, a few seconds of up to four tracks are ripped at
# read offset 0, and semarv finds every offset at which a pressing
# of that disc stored in AccurateRip matches. Each such offset gets
# one vote from that disc. Votes are remembered per drive, so the
# work can be spread over several sessions. An offset is accepted
# once three different discs have voted for it; or, for a drive in
# AccurateRip's list of drives (Linux), once one disc votes for the
# listed offset.
#
####################################################################

KD_TITLE="Semplice AccurateRip Configuration"
KD_TMP="$CONFDIR/tmp/keydisc"

function kd_find_drive {
# Sets KD_DEV (the device to read) and KD_DRIVE (the drive's name). Returns 1 if there is no disc.
if [[ $OSFAMILY == "MACOS" ]]; then
  local disk_id
  disk_id=$(drutil status 2>/dev/null | $GREPPROG -o 'disk[0-9]*' | head -n 1)
  if [[ -z $disk_id ]]; then return 1; fi
  KD_DEV="/dev/r$disk_id"
  KD_DRIVE=$(drutil status 2>/dev/null | awk '/Vendor/ {getline; print; exit}' | xargs)
else
  KD_DEV="$OPTICAL_DEVICE"
  if ! cdparanoia -sQ -d "$KD_DEV" >/dev/null 2>&1; then return 1; fi
  KD_DRIVE=$(cdparanoia -vsQ -d "$KD_DEV" 2>&1 | awk -F: '/sensed/ {print $2}' | xargs)
fi
if [[ -z $KD_DRIVE ]]; then KD_DRIVE="Unknown drive"; fi
return 0
}

function kd_wait_for_disc {
# After the user says a disc is in: give the drive up to 30 seconds to spin it up and read it
local tries=0
dialog --backtitle "$KD_TITLE" --title " Configure AccurateRip " --infobox "\nWaiting for the disc to be ready..." 5 70
until kd_find_drive; do
  tries=$((tries+1))
  if [[ $tries -ge 15 ]]; then return 1; fi
  sleep 2
done
return 0
}

function kd_eject {
if [[ $OSFAMILY == "MACOS" ]]; then drutil eject >/dev/null 2>&1; else eject "$KD_DEV" >/dev/null 2>&1; fi
}

function kd_progress {
# $1 = percentage done, $2 = the step now in progress
echo "$1" | dialog --backtitle "$KD_TITLE" --title " Configure AccurateRip " --gauge "\nDrive: $KD_DRIVE\n\n$2" 10 70 0
}

function kd_ask_for_disc {
# $1 is a line saying what just happened (may be empty); $2 is "another" once a disc has been tried.
# Returns 1 if the user wants to stop.
local title=" Insert a key disc " what="an audio CD"
if [[ $2 == "another" ]]; then title=" Insert another key disc "; what="another audio CD"; fi
dialog --backtitle "$KD_TITLE" --title "$title" --yes-label "Continue" --no-label "Stop" --yesno "\n${1:+$1\n\n}Please insert $what, then choose Continue.\n\nNo special disc is needed: any ordinary commercial CD that is likely to be in the AccurateRip database will do. Home-made or very obscure discs are unlikely to work.\n\nIf you stop now, the discs tried so far are remembered for next time." 17 80
}

function kd_test_disc {
# Rips the key stretches of this disc and asks semarv which offsets they point to.
# Sets KD_RESULT to semarv's RESULT line.
rm -rf "$KD_TMP"; mkdir -p "$KD_TMP"
cdparanoia -Q -d "$KD_DEV" 2>&1 | $GREPPROG -E '^[[:space:]]+[0-9]+\.' | $SEDPROG 's/\.//' | awk '{print $1, $2, $4}' > "$KD_TMP/tracks.txt"
if ! [[ -s "$KD_TMP/tracks.txt" ]]; then KD_RESULT="RESULT: ERROR the disc's track list could not be read"; return; fi

local trk len beg keys=() todo=() ndone=0 key
while read -r trk len beg; do                                          # Up to four tracks long enough to hold sectors 350 to 550
  [[ ${#todo[@]} -ge 4 ]] && break
  [[ $len -ge 600 ]] && todo+=("$trk")
done < "$KD_TMP/tracks.txt"
if [[ ${#todo[@]} -eq 0 ]]; then KD_RESULT="RESULT: ERROR it has no track long enough to use"; return; fi

for trk in "${todo[@]}"; do
  kd_progress $((ndone * 100 / (${#todo[@]} + 1))) "Reading track $trk ($((ndone + 1)) of ${#todo[@]})..."
  key="$KD_TMP/key$(printf '%02d' "$trk").wav"
  cdparanoia -O 0 -d "$KD_DEV" "${trk}[00:04.50]-${trk}[00:07.25]" "$key" >/dev/null 2>&1
  [[ -s "$key" ]] && keys+=("$key")
  ndone=$((ndone + 1))
done
if [[ ${#keys[@]} -eq 0 ]]; then KD_RESULT="RESULT: ERROR no part of the disc could be read"; return; fi

kd_progress $((ndone * 100 / (${#todo[@]} + 1))) "Checking against the AccurateRip database..."
KD_RESULT=$("$SEMARV" --offset "$KD_TMP/tracks.txt" "${keys[@]}" 2>&1 | $GREPPROG -a '^RESULT:' | tail -1)
}

function kd_count_votes {
# Prints "<votes> <offset>" for every offset in the votes file, most votes first
awk '{for (i = 2; i <= NF; i++) v[$i+0]++} END {for (o in v) print v[o], o}' "$KD_VOTES" 2>/dev/null | sort -k1,1nr -k2,2n
}

function kd_save_offset {
# $1 = offset found, $2 = how it was found
local shown
if [[ $1 -gt 0 ]]; then shown="+$1"; else shown="$1"; fi
dialog --backtitle "$KD_TITLE" --title " Read offset found " --yes-label "Save" --no-label "Don't save" --yesno "\nYour drive's read offset is $shown samples ($2).\n\nDo you want to save it as your configured read offset?" 12 80
if [[ $? -eq 0 ]]; then
  CONFFILE="$CONFDIR/txt/semplice.conf"
  if $GREPPROG -q '^OPTICAL_OFFSET=' "$CONFFILE"; then
    $SEDPROG -i "s/^OPTICAL_OFFSET=.*/OPTICAL_OFFSET=$1/" "$CONFFILE"
  else
    echo "OPTICAL_OFFSET=$1" >> "$CONFFILE"
  fi
  OPTICAL_OFFSET=$1
  dialog --backtitle "$KD_TITLE" --msgbox "\nThe read offset $shown has been saved." 8 60
fi
rm -f "$KD_VOTES"                                                      # Done with this drive's votes either way
}

# Actual Program Code to do stuff starts here...
# ==============================================================================================
if ! [[ -x $SEMARV ]]; then
  dialog --backtitle "$KD_TITLE" --msgbox "\nSemplice's AccurateRip program (semarv) isn't available for this computer, so AccurateRip can't be configured." 9 80
  return
fi

KD_MSG=""
if ! kd_find_drive; then
  kd_ask_for_disc "" || return
  if ! kd_wait_for_disc; then
    dialog --backtitle "$KD_TITLE" --msgbox "\nNo disc could be read in the optical drive. Please try again." 8 70
    return
  fi
fi

while true; do
  # Votes are kept per drive, named after the drive (only letters, digits and dashes in the file name)
  KD_VOTES="$CONFDIR/txt/arvotes-$(echo "$KD_DRIVE" | tr -c 'A-Za-z0-9\n' '-' | tr -s '-').txt"
  KD_LISTED=""
  if [[ $OSFAMILY != "MACOS" ]]; then KD_LISTED=$(lookup_drive_offset "$KD_DEV" | tr -d '+ '); fi

  tput civis
  kd_test_disc
  KD_OFFSETS=""
  case "$KD_RESULT" in
    "RESULT: OFFSETS "*)
      KD_LINE=${KD_RESULT#RESULT: OFFSETS }
      KD_DISCID=${KD_LINE%% *}; KD_OFFSETS=${KD_LINE#* }
      touch "$KD_VOTES"
      $GREPPROG -v "^$KD_DISCID " "$KD_VOTES" > "$KD_VOTES.new"; mv "$KD_VOTES.new" "$KD_VOTES"     # One vote per disc, however often it's tried
      echo "$KD_DISCID $KD_OFFSETS" >> "$KD_VOTES"
      KD_MSG="That disc was useful, but more discs are needed to be sure of the offset." ;;
    "RESULT: NOTINDB")
      KD_MSG="That disc isn't in the AccurateRip database, so it can't be used." ;;
    "RESULT: NOMATCH")
      KD_MSG="That disc is in the AccurateRip database, but your copy doesn't match any version stored there, so it can't be used." ;;
    *)
      KD_MSG="That disc couldn't be used: ${KD_RESULT#RESULT: ERROR }." ;;
  esac

  # A listed drive needs just one disc that agrees with the list
  if [[ -n $KD_LISTED && -n $KD_OFFSETS ]]; then
    for o in $KD_OFFSETS; do
      if [[ $((o)) -eq $((KD_LISTED)) ]]; then
        kd_eject; kd_save_offset "$((KD_LISTED))" "confirmed by a key disc"; return
      fi
    done
  fi

  # Otherwise, three discs must agree
  read -r KD_TOPVOTES KD_TOP <<< "$(kd_count_votes | head -n 1)"
  if [[ -n $KD_TOPVOTES && $KD_TOPVOTES -ge 3 ]]; then
    kd_eject; kd_save_offset "$KD_TOP" "$KD_TOPVOTES key discs agree"; return
  fi

  kd_eject
  kd_ask_for_disc "$KD_MSG" another || return
  if ! kd_wait_for_disc; then
    dialog --backtitle "$KD_TITLE" --msgbox "\nNo disc could be read in the optical drive. The discs tried so far are remembered for next time." 9 70
    return
  fi
done
