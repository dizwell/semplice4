#!/usr/bin/env bash
####################################################################
#
# semdevpick: Lists ROM-type devices (i.e., optical drives and
# similar) and allows the user to pick one to perform rips with.
#
####################################################################

DEVLIST=""; COUNTER=16

for i in $(lsblk -dn -o NAME,TYPE | $GREPPROG 'rom' | awk '{print $1}'); do
  DEVID="/dev/$i"
  DEVDESC=$(cdparanoia -vsQ -d $DEVID 2>&1 | awk -F: '/sensed/ {print $2}'); DEVDESC=$(echo "$DEVDESC" | xargs); DEVDESC=${DEVDESC// /_}
  DEVLIST="$DEVLIST $DEVID $DEVDESC off"
done

device_name=$(dialog --backtitle "Semplice Audio CD Ripping" --radiolist "Pick the optical device you want to use:" 15 90 0 $DEVLIST 3>&1 1>&2 2>&3 3>&- )
exitStatus=$?
if [[ $exitStatus -eq 1 ]]; then
  GOODDEV=0
else
  USEDEVICE="$device_name"; GOODDEV=1
fi

export OPTICAL_DEVICE="$device_name"
