#!/usr/bin/env bash
####################################################################
#
# semsacd: wrapper for ripping an SACD from a player on the
# network to an ISO file. Relies on the sacd_extract program
# written by EuFlo, whose website can be visited at:
# https://github.com/EuFlo/sacd-ripper
# Semplice's copies of sacd_extract are built from that source by
# src/build-sacd_extract.sh, one per platform, in exec/.
#
####################################################################
source "$CONFDIR/bin/semtput.sh" 
badip=1

if [[ $OSFAMILY == "MACOS" ]]; then
  IFACE=$(route get default 2>/dev/null | awk '/interface:/{print $2}')
  IP=$(ifconfig "$IFACE" | awk '/inet / {print $2}' | cut -d. -f1-3)
else
  IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<NF; i++) if ($i == "src") {print $(i+1); exit}}' | cut -d. -f1-3)   # Address of the default-route connection only
fi

if [[ -f $CONFDIR/txt/sacdip.txt ]]; then
  PROPOSEDIP=$(cat $CONFDIR/txt/sacdip.txt)
else
  PROPOSEDIP="$IP."
fi

if [[ -f $CONFDIR/txt/sacddir.txt ]]; then
  PROPOSEDDIR=$(cat $CONFDIR/txt/sacddir.txt)
else
  PROPOSEDDIR="$HOME/"
fi

function ip_prompt {
SACDIP=$(dialog --backtitle "Semplice SACD Ripping" --title " IP Address of your SACD Reader Device " --inputbox "\n\nEnter the IP address of your SACD Reader:" 12 80 "$PROPOSEDIP" 3>&1 1>&2 2>&3 3>&-)
exitStatus=$?                                        # 0 means user hit [OK] button. 1 means user hit [Cancel] button. 255 means user hit [Esc] key.
if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then
  SACDIP="999.0.0.0"
else
  echo "$SACDIP" > "$CONFDIR/txt/sacdip.txt"
fi
}

function rip_folder {
while :; do
RIPDIR=$(dialog --backtitle "Semplice SACD Ripping" --title " Please choose where to save your rips " --dselect "$PROPOSEDDIR" 12 80 3>&1 1>&2 2>&3 3>&- )
exitStatus=$?
if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then
  RIPDIR=""                                           # Cancel or Esc: no folder, so the rip will not go ahead
  break
else
  if [[ -d "$RIPDIR" ]]; then
    echo "$RIPDIR" > "$CONFDIR/txt/sacddir.txt"
    break
  fi
fi
done
}

function validate_ip {
ip=$1

if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  OIFS=$IFS
  IFS='.'
  ip=($ip)
  IFS=$OIFS
  [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
  badip=$?
fi
}

# SACDEXTRACT is sacd_extract-<macos|linux>-<arm64|x86_64>, set by semoscheck.sh
if [[ ! -x $SACDEXTRACT ]]; then
  dialog --stdout --backtitle "Semplice SACD Ripping" --title " SACD Ripper Missing " --msgbox "\nSemplice's SACD ripping program for this computer could not be found, so SACD ripping is not possible." 8 80
  return
fi
rip_folder
if [[ -z $RIPDIR ]]; then return; fi                  # Folder prompt cancelled: go back to the Ripping menu, creating nothing

# Sets up a permanent loop that persists until a valid IP address is provided
while [[ $badip -eq 1 ]]; do
  ip_prompt
  if [[ $SACDIP != "999.0.0.0" ]]; then
    validate_ip $SACDIP
    GOODIP=1
  else
    GOODIP=0
    break
  fi
done


if [[ $GOODIP -eq 1 ]]; then
  ping >/dev/null -c 1 "$SACDIP" ; ping_status=$?
  if [ $ping_status -eq 0 ]; then
    tput cup 25 4; echo -e "Invoking the SACD ripper in another terminal session..."
    if ! [[ -d "$RIPDIR"/SACD_ISORIPS ]]; then mkdir "$RIPDIR"/SACD_ISORIPS 2>/dev/null; fi 
    # The ripper runs in its own WezTerm window (all platforms), which stays open until Enter is pressed
    "${WEZTERM_EXECUTABLE:-wezterm}" start --always-new-process -- bash -c '"$0" -i "$1":2002 -I -z -2 -A -a -b -o "$2"; echo; read -rp "SACD ripping has finished. Press Enter to close this window. "' "$SACDEXTRACT" "$SACDIP" "$RIPDIR/SACD_ISORIPS" 2>/dev/null
  else
    dialog --stdout --backtitle "Semplice SACD Ripping" --title " Networking Error! " --msgbox "\nAn SACD player cannot be contacted at this IP address." 8 80
  fi
fi
