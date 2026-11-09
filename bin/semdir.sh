#!/usr/bin/env bash
####################################################################
#
# semdir: routine for picking a working folder
#
####################################################################
rm -rf "$CONFDIR/art/albumart.jpg" 2>/dev/null
FLACCOUNT=0; ISOCOUNT=0; FILECOUNT=0; WORKINGDIR="$(pwd)"

function basename {
  # Uses Bash built-in, so no call to external basename utility needed
  local path="${1%/}"
  echo "${path##*/}"    
}

while [[ $FILECOUNT -eq 0 ]]; do
  NEWDIR=$(dialog --backtitle "Semplice FLAC Tagging" --title " Please choose a working folder " --dselect "$WORKINGDIR" 18 80  3>&1 1>&2 2>&3 3>&- )
  exitStatus=$?

  if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then break; fi      # 1 is cancel, 255 is hitting the ESC jkey
  if [[ -n $NEWDIR && $NEWDIR != */ ]]; then NEWDIR="$NEWDIR/"; fi       # A highlighted folder comes back without its trailing slash: add it, so the file checks below look inside it

  if [[ $1 == "flaconly" ]]; then
    FLACCOUNT=$(ls "$NEWDIR"*.flac 2>/dev/null | wc -l)
    FILECOUNT=$FLACCOUNT
  else
    FLACCOUNT=$(ls "$NEWDIR"*.flac 2>/dev/null | wc -l)
    ISOCOUNT=$(ls "$NEWDIR"*.iso 2>/dev/null | wc -l)
    APECOUNT=$(ls "$NEWDIR"*.ape 2>/dev/null | wc -l)
    ALACCOUNT=$(ls "$NEWDIR"*.m4a 2>/dev/null | wc -l)
    MP3COUNT=$(ls "$NEWDIR"*.mp3 2>/dev/null | wc -l)
    OGGCOUNT=$(ls "$NEWDIR"*.ogg 2>/dev/null | wc -l)
    WMACOUNT=$(ls "$NEWDIR"*.wma 2>/dev/null | wc -l)
    WAVCOUNT=$(ls "$NEWDIR"*.wav 2>/dev/null | wc -l)
    DSFCOUNT=$(ls "$NEWDIR"*.dsf 2>/dev/null | wc -l)
    AIFCOUNT=$(ls "$NEWDIR"*.{aif,aiff,aifc} 2>/dev/null | wc -l)
    FILECOUNT=$((FLACCOUNT+ISOCOUNT+APECOUNT+ALACCOUNT+MP3COUNT+OGGCOUNT+WMACOUNT+WAVCOUNT+DSFCOUNT+AIFCOUNT))
  fi

  if [[ $FILECOUNT -eq 0 ]]; then
    if [[ $1 == "flaconly" ]]; then
      dialog --stdout --backtitle "Semplice Change Working Folder" --title " No valid music files detected " --msgbox "\nYou're trying to change the working folder from the Tagging or SuperFLAC menus: the proposed new working folder thus needs to contain some FLAC files that Semplice can convert or work with." 10 80
      WORKINGDIR="$(pwd)"
    else
      dialog --stdout --backtitle "Semplice Change Working Folder" --title " No valid music files detected " --msgbox "\nThe working folder needs to contain files of a type that Semplice can convert or work with: \n\nISO, DSF, AIF, WAV, WMA, OGG, MP3, ALAC, APE or FLAC" 10 80
      WORKINGDIR="$(pwd)"
    fi
  else
    WORKINGDIR="$NEWDIR"
  fi
done

if [[ -z $NEWDIR ]]; then
  WORKINGDIR="$(pwd)"
fi

export WORKINGDIR
SHORTNAME=$(basename "$WORKINGDIR")
DISPLAYDIR=${SHORTNAME:0:60}
if [[ $(uname -a) == *"Darwin"* ]]; then 
  echo -ne "\033]0;Semplice Working Folder: $DISPLAYDIR\007"
else
  echo -en "\033]0;Semplice Working Folder: $DISPLAYDIR\007\c"						# Setting terminal's titlebar
fi
sleep .1

