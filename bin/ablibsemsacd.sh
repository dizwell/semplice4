#!/usr/bin/env bash
####################################################################
#
# ablibsemsacd: wrapper for ripping an SACD from a player on the
# network to an ISO file. Relies on the sacd_extract program
# written by EuFlo, whose website can be visited at:
# https://github.com/EuFlo/sacd-ripper
# The version of sacd_extract included as part of the Semplice
# binaries was current as at March 16th 2024.
#
####################################################################
source "$CONFDIR/bin/ablibsemtput.sh" 
badip=1  CONFDIR="$HOME/.local/share/semplice2"  CPUARCH=$(uname -m)
chmod +x "$CONFDIR/exec/sacd_extract"
chmod +x "$CONFDIR/exec/sacd_extract_arm"
chmod +x "$CONFDIR/exec/sacd_extract-macintel"
chmod +x "$CONFDIR/exec/sacd_extract-macsilicon"

if [[ $OSFAMILY == "MACOS" ]]; then
  IFACE=$(route get default 2>/dev/null | awk '/interface:/{print $2}')
  IP=$(ifconfig "$IFACE" | awk '/inet / {print $2}' | cut -d. -f1-3)
else
  IP=$(ip a | grep -v grep | grep inet | grep -v 127 | grep -v inet6 | awk '{print $2}' | cut -d. -f1-3)
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

function determine_ripper {
if [[ $OSFAMILY == "MACOS" && $CPUARCH == "x86_64" ]]; then
  RIPPER="$CONFDIR/exec/sacd_extract-macintel"
fi

if [[ $OSFAMILY == "MACOS" && $CPUARCH == "arm64" ]]; then
  RIPPER="$CONFDIR/exec/sacd_extract-macsilicon"
fi

if [[ $OSFAMILY != "MACOS" && $CPUARCH == "x86_64" ]]; then
  RIPPER="$CONFDIR"/exec/sacd_extract
fi

if [[ $OSFAMILY != "MACOS" && $CPUARCH == "arm64" ]]; then
  RIPPER="$CONFDIR"/exec/sacd_extract_arm
fi
}

determine_ripper
rip_folder

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
    if [[ $OSFAMILY == "MACOS" ]]; then
osascript <<EOF
  tell application "Terminal"
    do script "$RIPPER -i $SACDIP:2002 -I -z -2 -A -a -b -o $RIPDIR/SACD_ISORIPS; bash"
  end tell
EOF
    else
      /usr/bin/xterm -xrm 'xterm*iconHint: /home/hjr/.local/share/semplice2/art/sempliceico.xpm' -xrm 'XTerm.vt100.allowTitleOps: false' -T 'Semplice SACD Ripping' -bg black -fg green -geometry 103x28 -fa 'Luxi Mono:style=Regular' -fs 11 -ti 340 -tn xterm-256color -e "$RIPPER" -i $SACDIP:2002 -I -z -2 -A -a -b -o "$RIPDIR"/SACD_ISORIPS
    fi
  else
    dialog --stdout --backtitle "Semplice SACD Ripping" --title " Networking Error! " --msgbox "\nAn SACD player cannot be contacted at this IP address." 8 80
  fi
fi
