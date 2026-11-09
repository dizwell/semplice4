#!/usr/bin/env bash
####################################################################
#
# semdevpick: Lists ROM-type devices (i.e., optical drives and
# similar) and allows the user to pick one to perform rips with.
#
####################################################################

DEVLIST=""; COUNTER=16

# On macOS the rip finds the drive itself (via drutil), so there is nothing to pick
if [[ $OSFAMILY == "MACOS" ]]; then
  dialog --stdout --backtitle "Semplice Audio CD Ripping" --title " Optical drive " --msgbox "\nOn macOS, Semplice detects your optical drive automatically each time you rip, so there is no drive to specify here." 9 70
  return
fi

for i in $(lsblk -dn -o NAME,TYPE | $GREPPROG 'rom' | awk '{print $1}'); do
  DEVID="/dev/$i"
  DEVDESC=$(cdparanoia -vsQ -d $DEVID 2>&1 | awk -F: '/sensed/ {print $2}'); DEVDESC=$(echo "$DEVDESC" | xargs); DEVDESC=${DEVDESC// /_}
  DEVLIST="$DEVLIST $DEVID $DEVDESC off"
done

device_name=$(dialog --backtitle "Semplice Audio CD Ripping" --radiolist "Pick the optical device you want to use:" 15 90 0 $DEVLIST 3>&1 1>&2 2>&3 3>&- )
exitStatus=$?

# Only change the drive if one was actually chosen: Cancel, Esc, or OK with nothing selected leave it as it was.
if ! [[ $exitStatus -eq 0 && -n $device_name ]]; then return; fi

# Find the chosen drive's read offset: look it up, or ask for it if the drive isn't in the offsets list
newoffset=$(lookup_drive_offset "$device_name")
if [[ -n $newoffset ]]; then
  dialog --stdout --backtitle "Semplice Audio CD Ripping" --title " Optical drive " --msgbox "\nRips will use $device_name, with its listed read offset of $newoffset." 8 76
else
  while true; do
    newoffset=$(dialog --stdout --backtitle "Semplice Audio CD Ripping" --title " Read offset for $device_name " --inputbox "\nThis drive is not in the offsets list. Enter its read offset (a whole number, which may be negative, e.g. 6 or -52):" 11 76)
    if [[ $? -ne 0 ]]; then return; fi                                        # Cancel/Esc: leave drive and offset as they were
    newoffset="${newoffset//[[:space:]]/}"; newoffset="${newoffset#+}"
    if [[ $newoffset =~ ^-?[0-9]{1,4}$ ]]; then                               # Accept e.g. 6, +6, -52, 006; otherwise ask again
      if [[ $newoffset == -* ]]; then newoffset=$(( -10#${newoffset#-} )); else newoffset=$(( 10#$newoffset )); fi
      break
    fi
  done
fi

# A per-session override, held apart from the configured values: never written to semplice.conf
export SESSION_DEVICE="$device_name"
export SESSION_OFFSET="$newoffset"
