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
# The choice is a per-session override held in SESSION_DEVICE: it is never written to semplice.conf, and
# re-reading the configuration (which resets OPTICAL_DEVICE to the configured default) does not touch it.
if [[ $exitStatus -eq 0 && -n $device_name ]]; then
  export SESSION_DEVICE="$device_name"
fi
