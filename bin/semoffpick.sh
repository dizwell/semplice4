#!/usr/bin/env bash
####################################################################
#
# semoffpick: Simple input form allowing user to specify
# a manual optical drive read offset, in the range -9999 to +9999
####################################################################
NEGVALUE=0

USROFFSET=$(dialog --backtitle "Semplice Audio CD Ripping" --title " Specify Optical Drive Read Offset " --inputbox "\n\nEnter a value from -9999 to +9999 as the read offset value to apply for this rip:" 12 90 3>&1 1>&2 2>&3 3>&-)
exitStatus=$?
if [[ $exitStatus -eq 1 ]]; then
  OPTICAL_OFFSET=0
else
  OPTICAL_OFFSET=$USROFFSET
fi


if [[ -z $OPTICAL_OFFSET ]]; then OPTICAL_OFFSET=0; fi                                        # If they cancel, set to 0
if [[ $OPTICAL_OFFSET == *"+"* ]]; then OPTICAL_OFFSET="${OPTICAL_OFFSET//+}"; fi         # If they supply a "+", strip it
if [[ $OPTICAL_OFFSET == *"-"* ]]; then OPTICAL_OFFSET="${OPTICAL_OFFSET//-}"; NEGVALUE=1; fi         # If they supply a "-", strip it, but make a note they've gone negative

if ! [[ -z $OPTICAL_OFFSET ]]; then
  if ! [[ $OPTICAL_OFFSET =~ ^[0-9]+$ ]] ; then                                             # If non-numeric characters are present, the default of 0 applies
    OPTICAL_OFFSET=0
  fi
fi

if [[ $NEGVALUE -eq 1 ]]; then OPTICAL_OFFSET=$((OPTICAL_OFFSET*-1)); fi


export $OPTICAL_OFFSET
