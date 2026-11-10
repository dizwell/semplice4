#!/usr/bin/env bash
####################################################################
#
# semrip: routine for ripping a CD to WAV files on disk and
# converting them to FLAC. Note that the script is really just
# a wrapper for cdparanoia, which means your rips favour accuracy
# over speed, but there are no fancy features such as fetching
# (bad) metadata from the Internet, or for doing partial disk rips
# and so on. All you get is a simple, but accurate, whole-CD rip
# to a set of WAVs and then to FLACs.
#
# You do get a chance to break a single CD up into separate recordings
# but you must always rip the entire CD.
#
# After a rip, the script will verify the ripped files for
# consistency with the AccurateRip database, using Semplice's own
# checker, semarv, in the exec folder (on Linux and macOS alike,
# unless hyper-accurate ripping is in use)
#
####################################################################
source "$CONFDIR/bin/semtput.sh" 
CD_NOTPRESENT=1 NODEVICE=0 RIPCANCELLED=0
if [[ -n $SESSION_DEVICE ]]; then OPTICAL_DEVICE="$SESSION_DEVICE"; fi    # A drive picked this session (Ripping menu, option 2) overrides the configured default
if [[ -z $OPTICAL_DEVICE ]]; then OPTICAL_DEVICE=/dev/cdrom; fi
if [[ -z $DELETE_WAV ]]; then DELETE_WAV=1; fi
tput civis

function offset_confirm {
# Applies the hyper-accurate adjustment (if on) to whichever offset this rip is using, then shows it
# with Continue/Cancel. Expects DEVICE_OFFSET and OFFSETSOURCE to be set.
local hypernote=""
if [[ $RIPMODE == "fast" ]]; then FASTFLAG="-Z"; RIPMODETEXT="fast"; else FASTFLAG=""; RIPMODETEXT="safe"; fi   # Fast mode: cdparanoia reads once, without its error checking
if [[ $HYPER_ACCURATERIP -eq 1 ]]; then
  DEVICE_OFFSET=$((DEVICE_OFFSET - 30))
  hypernote="\n\nHyper-accurate reads are switched on, so it has been reduced by 30."
fi
dialog --stdout --backtitle "Semplice Audio CD Ripping" --title " Read offset " --yes-label "Continue" --no-label "Cancel" --yesno "\nRead offset: $DEVICE_OFFSET\n($OFFSETSOURCE)$hypernote\n\nRips will be performed with the command:\n\ncdparanoia -B $OPTICAL_DEVICE --never-skip=$READ_RETRIES ${FASTFLAG:+$FASTFLAG }-O $DEVICE_OFFSET" 15 76 || { RIPCANCELLED=1; return; }     # Cancel/Esc: stop before ripping
}

function cdrom_identify_macos {
  # macOS: the drive is found afresh on every rip (its /dev/rdiskN name can change), and the read
  # offset is always the configured one: there is no offsets-table lookup on macOS.
  DISK_ID=$(drutil status | $GREPPROG -o 'disk[0-9]*' | head -n 1)

  if [[ -n $DISK_ID ]]; then
    OPTICAL_DEVICE="/dev/r$DISK_ID"
    # Count only CD_DA entries: this ignores index 0 (CD_partition_scheme) and only counts audio tracks.
    TRACK_COUNT=$(diskutil list "$DISK_ID" | $GREPPROG "CD_DA" | wc -l | xargs)
  else
    dialog --stdout --backtitle "Semplice Audio CD Ripping" --title " Audio CD needs to be present " --msgbox "\nCD Ripping on a Mac needs the CD to be inserted before running this software!" 8 80
    RIPCANCELLED=1                                                         # No disc: stop here, rather than relying on later steps failing
    return
  fi

  DEVICE_OFFSET=${OPTICAL_OFFSET:-0}
  OFFSETSOURCE="the configured read offset"
  offset_confirm
}

function cdrom_config {
# Has a physical optical device been specified? Use it if so
# to let CD Paranoia work out the details of what CD-ROM device we're using
# ----------------------------------------------------------------------------------------------
if [[ $OSFAMILY == "MACOS" ]]; then
  VALID_DEVICE=$(cdparanoia -v -Q -d "$OPTICAL_DEVICE" 2>&1 | $GREPPROG stat | wc -l)
else
  VALID_DEVICE=$(cdparanoia -vsQ -d $OPTICAL_DEVICE 2>&1 | $GREPPROG stat | wc -l)
fi

if [[ $VALID_DEVICE -eq 0 ]]; then
  if [[ $OSFAMILY != "MACOS" ]]; then 
    DEVICENAME=$(cdparanoia -vsQ -d $OPTICAL_DEVICE 2>&1 | awk -F: '/sensed/ {print $2}')
    DEVICENAME=$(echo $DEVICENAME | $SEDPROG 's/^[   ]*//;s/[    ]*$//')
    CD_NOTPRESENT=$(cdparanoia -vsQ -d $OPTICAL_DEVICE 2>&1 | $GREPPROG "Unable to open disc" | wc -l)  
  fi
else
  dialog --stdout --backtitle "Semplice Audio CD Ripping" --msgbox "The configuration file mentions a device that doesn't appear to exist. Quitting in the meantime." 8 80
  NODEVICE=1
fi

if [[ -z $DEVICENAME ]]; then
  DEVICENAME="Unknown Device"
fi

if [[ $NODEVICE -eq 1 ]]; then return; fi

# Read offset (Linux): a drive picked this session with Ripping option 2 brings its own offset. Otherwise
# the configured drive's offset is looked up in the offsets list, falling back to the configured offset.
if [[ -n $SESSION_DEVICE ]]; then
  DEVICE_OFFSET=$SESSION_OFFSET
  OFFSETSOURCE="set for this drive with Ripping option 2"
else
  DEVICE_OFFSET=$(lookup_drive_offset "$OPTICAL_DEVICE")
  if [[ -n $DEVICE_OFFSET ]]; then
    OFFSETSOURCE="listed for your drive, $DEVICENAME"
  else
    DEVICE_OFFSET=${OPTICAL_OFFSET:-0}
    OFFSETSOURCE="the configured read offset: your drive is not in the offsets list"
  fi
fi
offset_confirm
}

function rip_folder_failed {
# Called when a rip folder cannot be created or entered: say so, and make sure nothing more is ripped
RIPCANCELLED=1
dialog --stdout --backtitle "Semplice Audio CD Ripping" --title " Cannot use the rip folder " --msgbox "\nSemplice could not create or open this folder:\n\n$1\n\nRipping has stopped. Check that the disk has space and that the folder can be written to." 12 80
}

function perform_rip {
unset STARTARRAY
unset FOLDERNUMS

# First check a CD is in the drive and prompt until one is...
# ----------------------------------------------------------------------------------------------
sleep 1

if [[ $OSFAMILY != "MACOS" ]]; then
  while [ $CD_NOTPRESENT -eq 1 ]; do
    dialog --stdout --backtitle "Semplice Audio CD Ripping" --msgbox "No audio CD has been detected. Insert one, or Ctrl+C to quit." 8 80
    CD_NOTPRESENT=$(cdparanoia -vsQ -d $OPTICAL_DEVICE 2>&1 | $GREPPROG "Unable to open disc" | wc -l)
    sleep 1
  done
fi

# The code that does the actual ripping
# ----------------------------------------------------------------------------------------------
if [[ $OSFAMILY != "MACOS" ]]; then
  TRACKTOTAL=$(cdparanoia -d $OPTICAL_DEVICE -sQ |& grep -P "^\s+\d+\." | wc -l)      # First obtain a count of the number of tracks on the CD
else
  TRACKTOTAL=$TRACK_COUNT
fi

# We now display all tracks to the user and ask which ones mark the start of new recordings
# -----------------------------------------------------------------------------------------
if [[ $TRACKTOTAL -le 10 ]]; then FORMHEIGHT=$((TRACKTOTAL+8)); else FORMHEIGHT=18; fi
unset ITEMSTRING

for ((i=1; i<=$TRACKTOTAL; i++)); do
  ITEMSTRING+=("$i" "Track $i" "OFF")
done
exec 3>&1
VALUES=$( 2>&1 1>&3 dialog --ok-label "Submit" \
      --backtitle "Semplice FLAC Tagging" \
      --title " Select the tracks that mark the *start* of new recordings " \
      --checklist "" $FORMHEIGHT 80 $FORMHEIGHT \
      "${ITEMSTRING[@]}"
)
exitStatus=$?
if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then                   # They've pressed Cancel (1) or ESC (255): return to main menu
  unset TRACKTOTAL; unset FORMHEIGHT; unset ITEMSTRING
  smenuoptions rip
fi
exec 3>&-

if [[ -z $VALUES ]]; then                                                   # If they've not selected any track to be the start of a recording, we treat Track 1 as it and do a whole-CD rip into
  echo "1"  > "$CONFDIR/tmp/trackrange.txt"                                 # the one sub-folder.
else
  echo "$VALUES" > "$CONFDIR/tmp/trackrange.txt"                            # Otherwise, the trackrange.txt file will contain a string ("1 4 7 8 13" for example) which we will need to parse to
fi                                                                          # create start and stop points for multiple rips into separate sub-folders

# If they haven't cancelled, create the necessary rip folder
# -----------------------------------------------------------------------------------------
THISRIP_FOLDER="$RIPROOT/SempliceMusicRip-$($DATEPROG '+%Y-%m-%d')"

if ! mkdir -p "$THISRIP_FOLDER" 2>/dev/null || ! [[ -w $THISRIP_FOLDER ]]; then
  rip_folder_failed "$THISRIP_FOLDER"; return
fi

ORIG_DIR=$(pwd)

# Now we have to parse the user input and turn it into a set of rip ranges. If they've said
# new recordings start on track numbers 1, 5 and 8, for example, we need to rip 1-4,
# 5-7 and 8 to the total number of tracks on the CD
# -----------------------------------------------------------------------------------------
STARTARRAY=($(cat $CONFDIR/tmp/trackrange.txt))                            # Create an array of start-stop track ranges
COUNTOFRECORDS=${#STARTARRAY[@]}                                           # Count total number of elements in array, so we know how many times to loop
FOLDERCOUNT=$(find "$THISRIP_FOLDER"/* -maxdepth 0 -type d 2>/dev/null | wc -l)

if [[ $FOLDERCOUNT -gt 0 ]]; then
  FOLDERNUMS=("$THISRIP_FOLDER"/*)                                         # Fill an array with the names of sub-folders, now we know they exist
  FOLDERNUMS="${FOLDERNUMS[-1]##*/}"                                       # obtain the folder with the largest number
  FOLDERNUMS=${FOLDERNUMS: -2}                                             # return its last two digits
  if [[ ${FOLDERNUMS:0:1} -eq 0 ]]; then                                     # convert 07 for example into plain '7'; 2 digit numbers are left alone
    FOLDERNUMS=${FOLDERNUMS:1:1}
  fi
  COUNTER=$((FOLDERNUMS+1));                                               # Start counting from one more than the last folder found
else
  COUNTER=1                                                                # Since there are no sub-folders, just start counting at 1
fi

# Now we iterate through the rip ranges, creating appropriate sub-folders to house each of them
# -----------------------------------------------------------------------------------------
rm -rf /tmp/rip.log
for ((index=0; index < ${#STARTARRAY[@]}; index++)); do
  printf -v TWODIGITCOUNT "%02d" $COUNTER                                 # turn single digit counts into two-digit ones for folder-naming purposes
  NEXTSTART=${STARTARRAY[$index+1]}                                       # Find the start track of the next recording
  TRACKLIMIT=$((NEXTSTART - 1))                                           # Take 1 off that next recording's start track to get the ending for *this* recording
  if [ $TRACKLIMIT -eq -1 ]; then TRACKLIMIT=$TRACKTOTAL; fi              # Special case: the last recording has a -1 finish, so if we see -1, set it to the total track count to get the actual last track number
  TRACKRANGE="${STARTARRAY[$index]}-$TRACKLIMIT"                          # The TRACKRANGE is now a string (eg 1-4) that defines a contiguous range of tracks to rip
  THISRECFOLDER="RIP_$TWODIGITCOUNT"

  if ! mkdir -p "$THISRIP_FOLDER/$THISRECFOLDER" 2>/dev/null || ! cd "$THISRIP_FOLDER/$THISRECFOLDER" 2>/dev/null; then
    rip_folder_failed "$THISRIP_FOLDER/$THISRECFOLDER"; cd "$ORIG_DIR"; return
  fi

  # Now we rip...
  # --------------
  tput civis
  
  if [[ $OSFAMILY != "MACOS" ]]; then  
    tput cup 25 0; cdparanoia -B "$TRACKRANGE" -e -d $OPTICAL_DEVICE --never-skip=$READ_RETRIES $FASTFLAG -O "$DEVICE_OFFSET" 1>/tmp/rip.log 2>&1 &
  elif [[ $OSFAMILY == "MACOS" ]]; then 
    tput cup 25 0; cdparanoia -B "$TRACKRANGE" -e -d "$OPTICAL_DEVICE" --never-skip=$READ_RETRIES $FASTFLAG -O "$DEVICE_OFFSET" 1>/tmp/rip.log 2>&1 &  
  fi
  
  while [[ $(cat /tmp/rip.log | $GREPPROG Done | wc -l) -eq 0 ]]; do
    # Some pretty messy code to get a percentage complete for 'progress bar' purposes.
    # The logic here is that "cdparanoia -sQ" quickly tells you a total number of FRAMES on the CD
    # You multiply that number by 1176 to derive a total number of SAMPLES on the CD.
    # The log file produced during the rip outputs which SAMPLE the rip has got to.
    # You can therefore legitimately divide the current sample number by the total sample number
    # to derive a 'percentage complete'.
    if [[ $OSFAMILY != "MACOS" ]]; then
      DENOM=$(cdparanoia -sQ -d $OPTICAL_DEVICE 2>&1 | $GREPPROG TOTAL | awk '{print $2}')    # Gets total number of FRAMES
    elif [[ $OSFAMILY == "MACOS" ]]; then
      DENOM=$(cdparanoia -Q -d "$OPTICAL_DEVICE" 2>&1 | $GREPPROG TOTAL | awk '{print $2}')    # Gets total number of FRAMES   
    fi
    DENOM=$((DENOM*1176))                                                                   # Gets total number of SAMPLES
    COUNT=$(tail -1 /tmp/rip.log | $GREPPROG [read] | awk -F'@' '{print $2}')               # Inspects the log file to determine current sample being read
    PCT=$(echo "scale=2; $COUNT/$DENOM*100" | bc -l)                                        # Divides current sample number by total sample number to derive percent complete

    # Percentages passed to dialog's Guage tool need to be integers, which is what {var%.*} achieves
    echo ${PCT%.*} | dialog --backtitle "Semplice Audio CD Ripping" --gauge "Using device: $OPTICAL_DEVICE [$DEVICENAME] \nRipping to: $THISRIP_FOLDER \nUsing read offset: $DEVICE_OFFSET, read-retries: $READ_RETRIES, $RIPMODETEXT mode \n \nReading audio sample: $COUNT/$DENOM" 10 70 0
    sleep 1
    tput cup 25 0
  done
  COUNTER=$((COUNTER+1))
  echo 100 | dialog --backtitle "Semplice Audio CD Ripping" --gauge "Using device: $OPTICAL_DEVICE [$DEVICENAME] \nRipping to: $THISRIP_FOLDER \nUsing read offset: $DEVICE_OFFSET, read-retries: $READ_RETRIES, $RIPMODETEXT mode \n \nReading audio sample: $COUNT/$DENOM" 10 70 0

  # Before converting to FLAC, we copy all WAVs to the rip folder, to enable later AccurateRip verification check
  # ------------------------------------------------------------------------------------------------------------
  cp *.wav "$CONFDIR/rip"
  convert_to_flac
  rm -f track00.flac >/dev/null 2>/dev/null                       # Some CDs begin with a 'zero-th' track of silence. Remove it.
done
tput cvvis
}

function convert_to_flac {
# Allow for normal audio CD, hi-res and bonkers, if they insist!
# ----------------------------------------------------------------------------------------------
if [[ -z $FLAC_QUALITY ]]; then
  FLAC_QUALITY=standard
fi

if [[ $FLAC_QUALITY == "standard" ]]; then
  BITDEPTH="-sample_fmt s16 -ar 44100"
  BITS="16"
  RES_TEXT="standard resolution"
elif [[ $FLAC_QUALITY == "high" ]]; then
  BITDEPTH="-sample_fmt s32 -ar 88200"
  BITS="24"
  RES_TEXT="high resolution"
elif [[ $FLAC_QUALITY == "extreme" ]]; then
  BITDEPTH="-sample_fmt s32 -ar 176400"
  BITS="24"
  RES_TEXT="extreme resolution"
fi
tput cup 22 4; echo "Now converting ripped files to $RES_TEXT FLACs...                        "
$FDPROG -j 4 -d 1 -t f -e "wav" -x ffmpeg -hide_banner -loglevel 0 -i "{}" $BITDEPTH -y "{.}-$BITS.flac"

# Now delete the source WAVs, if configured to do so
# ----------------------------------------------------------------------------------------------
if [[ $DELETE_WAV -eq 1 ]]; then
  $FDPROG -j 4 -d 1 -t f -e "wav" -x rm -rf {} \;
fi
}

function semarv_path {
# Prints the path of the AccurateRip checker (semarv) built for this computer, if there is one
local bin
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)              bin="semarv-macsilicon" ;;
  Darwin-x86_64)             bin="semarv-macintel" ;;
  Linux-aarch64|Linux-armv7l) bin="semarv_arm" ;;
  Linux-x86_64)              bin="semarv" ;;
esac
if [[ -n $bin && -x "$CONFDIR/exec/$bin" ]]; then echo "$CONFDIR/exec/$bin"; fi
}

function verify_rip {
# Checks the rip against the AccurateRip database, using Semplice's own checker (semarv) on the
# WAVs cdparanoia produced. Works on Linux and macOS alike. The full report goes to ripaccuracy.txt.
tput cup 22 4; echo "Now verifying the rip against the AccurateRip database...                         "
cd "$CONFDIR/rip"
"$SEMARV" track*.wav > ripaccuracy.txt 2>&1
RESULT=$($GREPPROG -a '^RESULT:' ripaccuracy.txt | tail -1)
case "$RESULT" in
  "RESULT: MATCH "*)
    dialog --stdout --backtitle "Semplice Audio CD Ripping" --msgbox "This rip appears good: every track matches the AccurateRip database (lowest confidence = ${RESULT##* })." 8 80 ;;
  "RESULT: PARTIAL "*)
    dialog --stdout --backtitle "Semplice Audio CD Ripping" --msgbox "Only ${RESULT##* } tracks match the AccurateRip database. Please review $CONFDIR/rip/ripaccuracy.txt to see which." 8 80 ;;
  "RESULT: NOMATCH")
    dialog --stdout --backtitle "Semplice Audio CD Ripping" --msgbox "This CD is in the AccurateRip database, but none of its tracks match. The rip may contain errors, or the drive's read offset may be wrong. See $CONFDIR/rip/ripaccuracy.txt." 9 80 ;;
  "RESULT: NOTINDB")
    dialog --stdout --backtitle "Semplice Audio CD Ripping" --msgbox "This CD is NOT in the AccurateRip database, so no confidence can be given to the rip (but it's probably OK)." 8 80 ;;
  *)
    dialog --stdout --backtitle "Semplice Audio CD Ripping" --msgbox "The AccurateRip check could not be done: ${RESULT#RESULT: ERROR }" 8 80 ;;
esac
rm -f "$CONFDIR/rip"/*.wav 2>/dev/null
}

# Actual Program Code to do stuff starts here...
# ==============================================================================================
# The rip folder must already exist and be writable: check before anything else happens
if ! [[ -d $RIPROOT ]]; then
  RIPPROBLEM="does not exist"
elif ! [[ -w $RIPROOT ]]; then
  RIPPROBLEM="exists, but cannot be written to"            # Covers ordinary permissions and macOS locked (uchg) folders
fi
if [[ -n $RIPPROBLEM ]]; then
  dialog --stdout --backtitle "Semplice Audio CD Ripping" --title " Rip folder problem " --msgbox "\nThe rip folder:\n\n$RIPROOT\n\n$RIPPROBLEM. Please choose a different rip folder in the configuration (Miscellaneous menu, option 1). Nothing has been ripped." 13 80
  unset RIPPROBLEM; tput cvvis; return
fi

if [[ $OSFAMILY == "MACOS" ]]; then
  cdrom_identify_macos
else
  cdrom_config
fi

if [[ $NODEVICE -eq 0 && $RIPCANCELLED -eq 0 ]]; then
  perform_rip
  if [[ $RIPCANCELLED -eq 1 ]]; then tput cvvis; return; fi               # The rip folder could not be used: back to the Ripping menu
  convert_to_flac

  # If hyper-accurate rips are switched on, then there's no point comparing this rip with
  # anything in the AccurateRip database. Only do the comparison if hyper_accurate is off AND
  # Semplice's AccurateRip checker (semarv) exists for this computer
  # ----------------------------------------------------------------------------------------------
  if [[ $HYPER_ACCURATERIP -eq 0 ]]; then
    SEMARV=$(semarv_path)
    if [[ -n $SEMARV ]]; then
      verify_rip
      echo "" >> "$CONFDIR/rip/ripaccuracy.txt"
      echo "Ripping done with command: cdparanoia -B -e -d $OPTICAL_DEVICE --never-skip=$READ_RETRIES $FASTFLAG -O $DEVICE_OFFSET" >> "$CONFDIR/rip/ripaccuracy.txt"
    else
      dialog --stdout --backtitle "Semplice Audio CD Ripping" --msgbox "Semplice's AccurateRip checker (semarv) is missing for this computer, so this rip cannot be verified in the AccurateRip database." 8 80
    fi
  fi
  rm -f "$CONFDIR/rip"/*.wav 2>/dev/null
  if [[ $OSFAMILY != "MACOS" ]]; then eject $OPTICAL_DEVICE; fi        # macOS ejects with drutil, below
fi
if [[ -n $ORIG_DIR ]]; then cd "$ORIG_DIR"; fi                            # ORIG_DIR is only set once a rip gets going; a cancelled rip never changed folder
if [[ $OSFAMILY == "MACOS" && $RIPCANCELLED -eq 0 ]]; then drutil eject; fi   # drutil only exists on macOS; a cancelled rip leaves the disc in
tput cvvis
