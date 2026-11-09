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
# consistency with the AccurateRip database, using the
# trackverify option found in the audiotools package (so long as you're
# not running on macOS or using hyper-accurate ripping)
#
####################################################################
source "$CONFDIR/bin/semtput.sh" 
source "$CONFDIR/bin/semparse.sh" 
CD_NOTPRESENT=1 NODEVICE=0 RIPCANCELLED=0
if [[ -n $SESSION_DEVICE ]]; then OPTICAL_DEVICE="$SESSION_DEVICE"; fi    # A drive picked this session (Ripping menu, option 2) overrides the configured default
if [[ -z $OPTICAL_DEVICE ]]; then OPTICAL_DEVICE=/dev/cdrom; fi
if [[ -z $DELETE_WAV ]]; then DELETE_WAV=1; fi
tput civis

function cdrom_identify_macos {
  # 1. Identify the disk ID
  DISK_ID=$(drutil status | $GREPPROG -o 'disk[0-9]*' | head -n 1)

  if [[ -n $DISK_ID ]]; then
    OPTICAL_DEVICE="/dev/r$DISK_ID"
    DEVICENAME=$(drutil status | awk 'NR==2 { $1=""; $NF=""; print $0 }' | xargs)
    
    if [[ $DEVICENAME != "SuperDrive" ]]; then
      # There should be a list of devices and read-offsets. Obtain it if not.
      # ----------------------------------------------------------------------------------------------
      if ! [[ -f "$CONFDIR/txt/cddriveoffsets.csv" ]]; then
        wget --quiet https://bbritten.com/software/semplice/cddriveoffsets.csv -O "$CONFDIR/txt/cddriveoffsets.csv"
      fi
      # Now see if the attached drive appears in the list of offsets
      DERIVED_OFFSET=$($GREPPROG -Rnw "$CONFDIR/txt/cddriveoffsets.csv" -e "$DEVICENAME" | awk -F '|' '{print $2; exit;}')
      if [[ -z $DERIVED_OFFSET ]]; then AUTOSET_OFFSET=0; else AUTOSET_OFFSET=1; fi
    fi
    
    # 2. Count only CD_DA entries
    # This ignores index 0 (CD_partition_scheme) and only counts audio tracks.
    TRACK_COUNT=$(diskutil list "$DISK_ID" | $GREPPROG "CD_DA" | wc -l | xargs)
  else
    dialog --stdout --backtitle "Semplice Audio CD Ripping" --title " Audio CD needs to be present " --msgbox "\nCD Ripping on a Mac needs the CD to be inserted before running this software!" 8 80
    return
  fi
  
  # 3. Read the configured offset and use it, or set it to a default of 0 and warn
  if [[ -z $DERIVED_OFFSET ]] && [[ -z $OPTICAL_OFFSET ]]; then 
    DEVICE_OFFSET=0
    dialog --stdout --backtitle "Semplice Audio CD Ripping" --title " Using a default read offset " --yes-label "Continue" --no-label "Cancel" --yesno "\nAuto-detection of a read offset has failed and you haven't configured one either. A fallback read offset of 0 will be used, but this probably won't be correct.\n\nRips will therefore be performed with the command:\n\ncdparanoia -B $OPTICAL_DEVICE --never-skip=$READ_RETRIES -O $DEVICE_OFFSET" 12 70 || { RIPCANCELLED=1; return; }     # Cancel/Esc: stop before ripping
  elif [[ -z $DERIVED_OFFSET ]] && ! [[ -z $OPTICAL_OFFSET ]]; then 
    DEVICE_OFFSET=$OPTICAL_OFFSET
    dialog --stdout --backtitle "Semplice Audio CD Ripping" --title " Using a configured read offset " --yes-label "Continue" --no-label "Cancel" --yesno "\nAuto-detection of a read offset has failed but you've manually configured one (of $DEVICE_OFFSET) in the persistent configuration file.\n\nRips will therefore be performed with the command:\n\ncdparanoia -B $OPTICAL_DEVICE --never-skip=$READ_RETRIES -O $DEVICE_OFFSET" 12 70 || { RIPCANCELLED=1; return; }     # Cancel/Esc: stop before ripping
  elif [[ ! -z $DERIVED_OFFSET ]] && [[ $AUTOSET_OFFSET -eq 1 ]]; then
    DEVICE_OFFSET=$DERIVED_OFFSET
    dialog --stdout --backtitle "Semplice Audio CD Ripping" --title " Using autodetected read offset " --yes-label "Continue" --no-label "Cancel" --yesno "\nYour optical drive has been detected automatically to have \na read offset of: $DEVICE_OFFSET.\n\nRips will therefore be performed with the command: \ncdparanoia -B $OPTICAL_DEVICE --never-skip=$READ_RETRIES -O $DEVICE_OFFSET" 12 70 || { RIPCANCELLED=1; return; }     # Cancel/Esc: stop before ripping
  fi
  
  # 4. Use Hyperaccurate Rip if configured
  if [[ $HYPER_ACCURATERIP -eq 1 ]]; then
    DEVICE_OFFSET=$(($DEVICE_OFFSET - 30))
    dialog --stdout --backtitle "Semplice Audio CD Ripping" --yes-label "Continue" --no-label "Cancel" --yesno "You have enabled hyper-accurate reads, so that will be adjusted to be: $DEVICE_OFFSET. \nRips will therefore be performed with the command: \ncdparanoia -B $OPTICAL_DEVICE --never-skip=$READ_RETRIES -O $DEVICE_OFFSET" 10 80 || { RIPCANCELLED=1; return; }     # Cancel/Esc: stop before ripping
  fi  
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
  if [[ $OS_FAMILY != "MACOS" ]]; then 
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

# Is there a configured read-offset? Use it if so.
if ! [[ -z $OPTICAL_OFFSET ]]; then
  DEVICE_OFFSET=$OPTICAL_OFFSET
  dialog --stdout --backtitle "Semplice Audio CD Ripping" --yes-label "Continue" --no-label "Cancel" --yesno "You have manually configured a read offset of: $DEVICE_OFFSET. \nRips will therefore be performed with the command: \ncdparanoia -B $OPTICAL_DEVICE --never-skip=$READ_RETRIES -O $DEVICE_OFFSET" 10 80 || { RIPCANCELLED=1; return; }     # Cancel/Esc: stop before ripping
else
  # There should be a list of devices and read-offsets. Obtain it if not.
  # ----------------------------------------------------------------------------------------------
  if ! [[ -f $CONFDIR/txt/cddriveoffsets.csv ]]; then
    wget --quiet https://bbritten.com/software/semplice/cddriveoffsets.csv -O "$CONFDIR/txt/cddriveoffsets.csv"
  fi

  # Now find a match for the detected drive within the list of devices
  # ----------------------------------------------------------------------------------------------
  if [[ $OS_FAMILY != "MACOS" ]]; then 
    DEVICEID=$(cdparanoia -vsQ -d $OPTICAL_DEVICE 2>&1 | awk -F: '/sensed/ {print $2}' | awk '{print $--NF}')
    DEVICE_OFFSET=$($GREPPROG -Rnw "$CONFDIR/txt/cddriveoffsets.csv" -e "$DEVICEID" | awk -F '|' '{print $2; exit;}')
  fi
  
  if [[ -z $DEVICE_OFFSET ]]; then
    echo "  An accurate read offset for your optical disk drive cannot be determined."
    echo "  Specify your own read offset if you know it: "
    read USEROFFSET
    if [[ -z $USEROFFSET ]]; then
      DEVICE_OFFSET=0
      dialog --stdout --backtitle "Semplice Audio CD Ripping" --yes-label "Continue" --no-label "Cancel" --yesno "Setting the drive offset to 0, but this probably won't be correct." 10 80 || { RIPCANCELLED=1; return; }     # Cancel/Esc: stop before ripping
    else
      DEVICE_OFFSET=$USEROFFSET
      echo "  Setting the drive offset to $USEROFFSET"
      echo ""
      echo "  Rips will therefore be performed with the command:"
      echo "  cdparanoia -B $OPTICAL_DEVICE --never-skip=$READ_RETRIES -O $DEVICE_OFFSET"
    fi
  else
    if [[ $HYPER_ACCURATERIP -eq 1 ]]; then
      DEVICE_OFFSET=$(($DEVICE_OFFSET - 30))
      dialog --stdout --backtitle "Semplice Audio CD Ripping" --yes-label "Continue" --no-label "Cancel" --yesno "You have enabled hyper-accurate reads, so that will be adjusted to be: $DEVICE_OFFSET. \nRips will therefore be performed with the command: \ncdparanoia -B $OPTICAL_DEVICE --never-skip=$READ_RETRIES -O $DEVICE_OFFSET" 10 80 || { RIPCANCELLED=1; return; }     # Cancel/Esc: stop before ripping
    fi
  fi
fi
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
    tput cup 25 0; cdparanoia -B "$TRACKRANGE" -e -d $OPTICAL_DEVICE --never-skip=$READ_RETRIES -O "$DEVICE_OFFSET" 1>/tmp/rip.log 2>&1 &
  elif [[ $OSFAMILY == "MACOS" ]]; then 
    tput cup 25 0; cdparanoia -B "$TRACKRANGE" -e -d "$OPTICAL_DEVICE" --never-skip=$READ_RETRIES -O "$DEVICE_OFFSET" 1>/tmp/rip.log 2>&1 &  
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
    echo ${PCT%.*} | dialog --backtitle "Semplice Audio CD Ripping" --gauge "Using device: $OPTICAL_DEVICE [$DEVICENAME] \nRipping to: $THISRIP_FOLDER \nUsing read offset: $DEVICE_OFFSET and read-retries: $READ_RETRIES \n \nReading audio sample: $COUNT/$DENOM" 10 70 0
    sleep 1
    tput cup 25 0
  done
  COUNTER=$((COUNTER+1))
  echo 100 | dialog --backtitle "Semplice Audio CD Ripping" --gauge "Using device: $OPTICAL_DEVICE [$DEVICENAME] \nRipping to: $THISRIP_FOLDER \nUsing read offset: $DEVICE_OFFSET and read-retries: $READ_RETRIES \n \nReading audio sample: $COUNT/$DENOM" 10 70 0

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

function verify_flac {
tput cup 22 4; echo "Now verifying the ripped FLACs...                                                  "
cd "$CONFDIR/rip"
$FDPROG -j 4 -d 1 -t f -e "wav" -x ffmpeg -hide_banner -loglevel 0 -i "{}" -sample_fmt s16 -ar 44100 -y "{.}-16.flac"
trackverify 2>/dev/null -j $(nproc) -R *.flac > ripaccuracy.txt

if [[ -f $CONFDIR/rip/ripaccuracy.txt ]]; then            # Does the file exist
  if [[ -s $CONFDIR/rip/ripaccuracy.txt ]]; then          # If it does, is it empty: only do other stuff if not (i.e., there are some results from trackverify)
    DISCHIT=$(cat ripaccuracy.txt | $GREPPROG found | wc -l)

    # Various text messages indicate failure to identify the disk
    NOMATCH=$(cat ripaccuracy.txt | $GREPPROG "no match in database" | wc -l)
    NODISC=$(cat ripaccuracy.txt | $GREPPROG "disc not in database" | wc -l)

    if [[ $((NOMATCH+NODISC)) -gt 0 ]]; then
      DISCMISS=1
    else
      DISCMISS=0
    fi

    if [[ $DISCHIT -gt 1 ]]; then
      # A lot of palaver to determine the *lowest* confidence rating contained in the accuracy log,
      # since it can vary per-track (and hence, per line of the log file). Thus, we start by
      # setting CONFIDENCE to an absurdly high value, iterate through the lines of the log and if
      # the confidence shown on each line is *lower* than that, CONFIDENCE is set to be that new, lower
      # value. Keep going and by the end of the log, CONFIDENCE will be the lowest value encountered.
      CONFIDENCE=999999
      while read l; do
      if [[  ${l:0:1} == "[" ]]; then
        NEWCONFIDENCE=$(echo "$l" | awk -F ":" '{print $2}' | cut -d "(" -f2-); NEWCONFIDENCE=${NEWCONFIDENCE::-1}
        NEWCONFIDENCE=$(echo $NEWCONFIDENCE | awk '{print $2}')
        if [[ $NEWCONFIDENCE -lt $CONFIDENCE ]]; then
          CONFIDENCE=$NEWCONFIDENCE
        fi
      fi
      done <ripaccuracy.txt
      echo $CONFIDENCE
      dialog --stdout --backtitle "Semplice Audio CD Ripping" --msgbox "This rip appears good (Confidence = $CONFIDENCE)." 8 80
    elif [[ $DISCMISS -eq 1 ]]; then
      dialog --stdout --backtitle "Semplice Audio CD Ripping" --msgbox "This CD is NOT in the AccurateRip database, so no confidence can be given to the rip (but it's probably OK)." 8 80
    else
      dialog --stdout --backtitle "Semplice Audio CD Ripping" --msgbox "Please review the $HOME/.local/share/semplice2/rip/ripaccuracy.txt file to see whether this rip was OK." 8 80
    fi
  fi
fi
rm -f "$CONFDIR/rip"/*.wav 2>/dev/null
rm -f "$CONFDIR/rip"/*.flac 2>/dev/null
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
  # the trackverify utility has been installed and we're not running on macOS
  # ----------------------------------------------------------------------------------------------
  if [[ $OSFAMILY != "MACOS" ]]; then
    if [[ $HYPER_ACCURATERIP -eq 0 ]]; then
      if command -v trackverify &> /dev/null
      then
        verify_flac
      else
        dialog --stdout --backtitle "Semplice Audio CD Ripping" --msgbox "Since the 'trackverify' program has not been installed, Semplice cannot verify this rip in the AccurateRip database." 8 80
      fi
    fi
    echo "" >> ripaccuracy.txt
    echo "Ripping done with command: cdparanoia -B -e -d $OPTICAL_DEVICE --never-skip=$READ_RETRIES -O $DEVICE_OFFSET" >> ripaccuracy.txt
    eject $OPTICAL_DEVICE
  else
    drutil eject
  fi
fi
cd "$ORIG_DIR"
if [[ $OSFAMILY == "MACOS" && $RIPCANCELLED -eq 0 ]]; then drutil eject; fi   # drutil only exists on macOS; a cancelled rip leaves the disc in
tput cvvis
