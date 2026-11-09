#!/usr/bin/env bash
####################################################################
#
# A function to write various menu options onto the screen
#
####################################################################
source "$CONFDIR/bin/semtput.sh"
SPACER="      "
escape_char=$(printf "\u1b")

function basename {
  # Uses Bash built-in, so no call to external basename utility needed
  local path="${1%/}"
  echo "${path##*/}"    
}

function dirname {
  # Uses Bash built-in, so no call to external dirname utility needed
  local path="${1%/}"
  echo "${path%/*}"    
}

if [[ $1 == "tag" ]]; then
  # ======================================================================================================
  tput cup  5 4
  tput setaf $DRAWLINES; echo -en "\e[7mTagging\e[0m"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "A"; tput setaf $DRAWLINES; echo -en "udio Processing"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "S"; tput setaf $DRAWLINES; echo -en "uperFLAC"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "R"; tput setaf $DRAWLINES; echo -en "ipping"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "M"; tput setaf $DRAWLINES; echo -en "iscellaneous"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "Q"; tput setaf $DRAWLINES; echo -en "uit"
  # ======================================================================================================
  DISPLAYNAME=$(basename "$(pwd)"); DISPLAYNAME=$(echo $DISPLAYNAME | awk -F '/' '{print $NF}') 
  if [ ${#DISPLAYNAME} -gt 70 ]; then DISPLAYNAME="${DISPLAYNAME: -70}"; fi
  tput cup  3 4; tput setaf $LOGO; echo -en "Working folder: "; tput setaf $INFOTEXT; echo -en "…/$DISPLAYNAME"
  tput cup  8 4; tput setaf $MAINTEXT; echo "1) Auto-Tagging"
  tput cup  9 4; echo "2) Set recording-wide tags"
  tput cup 10 4; echo "3) Set track titles"
  tput cup 11 4; echo "4) Renumber tracks"
  tput cup 12 4; echo "5) Embed album art"
  tput cup 13 4; echo "6) Set custom tags"
  tput cup 14 4; echo "7) View all current metadata"
  tput cup 15 4; echo "8) Extract album art (from first FLAC)"
  tput cup 16 4; echo "9) Edit embedded cuesheet"
  tput cup 18 4; echo -e "W) Change Working Folder"
  tput cup 19 4; echo -e "F) Open File Manager"
  tput cup 20 4; echo -e "K) Clean FLAC tags in current folder"
  tput cup 22 4; tput setaf $ALERT; echo -e "X) Exit the program"

  until [[ $option == "q" ]]; do
  tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
  tput cup 25 24; tput cvvis; read -n 1 -s -r option
  if [[ $option == $escape_char ]]; then
    read -rsn2 option
  fi
  case $option in
  "" ) f=$(find "$(pwd)" -maxdepth 1 -name "*.flac" | sort | head -n 1)
       if [[ -w $f ]]; then
         source "$CONFDIR/bin/semtags.sh" auto meta;
         AUTOMODE=1; source "$CONFDIR/bin/semtrks.sh"
         smenuoptions tag
       else
         dialog --title "Semplice Album Tags" --msgbox "\\n\\nThere are files in this folder of FLACs that are not writeable, so we cannot continue.\\n\\nClick OK to return to the main menu." 12 70
         smenuoptions tag
       fi
       ;;
    1) f=$(find "$(pwd)" -maxdepth 1 -name "*.flac" | sort | head -n 1)
       if [[ -w $f ]]; then
         source "$CONFDIR/bin/semtags.sh" auto meta;
         AUTOMODE=1; source "$CONFDIR/bin/semtrks.sh"
         smenuoptions tag
       else
         dialog --title "Semplice Album Tags" --msgbox "\\n\\nThere are files in this folder of FLACs that are not writeable, so we cannot continue.\\n\\nClick OK to return to the main menu." 12 70
         smenuoptions tag
       fi
       ;;
    2 ) source "$CONFDIR/bin/semtags.sh"; smenuoptions tag;;
    3 ) AUTOMODE=0; BREAKME=0; source "$CONFDIR/bin/semtrks.sh"; smenuoptions tag;;
    4 ) source "$CONFDIR/bin/semrenum.sh"; smenuoptions tag;;
    5 ) source "$CONFDIR/bin/semart.sh"; smenuoptions tag;;
    6 ) source "$CONFDIR/bin/semcus.sh"; smenuoptions tag;;
    7 ) source "$CONFDIR/bin/semmeta.sh"; smenuoptions tag;;
    8 ) source "$CONFDIR/bin/semxart.sh"; smenuoptions tag;;
    9 ) source "$CONFDIR/bin/semcuee.sh"; smenuoptions tag;;
    W|w ) source "$CONFDIR/bin/semdir.sh" flaconly; cd "$WORKINGDIR"; smenuoptions tag ;;
    F|f ) if [[ $OSFAMILY == "MACOS" ]]; then open "."; else xdg-open "." 2>/dev/null; fi; ;;
    K|k ) source "$CONFDIR/bin/semclean.sh"; smenuoptions tag;;
    X|x ) clear; exit 0 ;;
    R|r ) clear; smenuoptions rip;;
    T|t ) clear; smenuoptions tag;;
    S|s ) clear; smenuoptions super;;
    A|a ) clear; smenuoptions audio;;
    M|m ) clear; smenuoptions misc;;
    Q|q ) clear; smenuoptions quit;;
    '[D') smenuoptions quit;;
    '[C') smenuoptions audio;;
    * ) A=1;;
  esac
  done

elif [[ $1 == "audio" ]]; then
  # ======================================================================================================
  tput cup  5 4
  tput setaf $HOTKEY; echo -en "T"; tput setaf $DRAWLINES; echo -en "agging"; echo -en "$SPACER"
  tput setaf $DRAWLINES; echo -en "\e[7mAudio Processing\e[0m"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "S"; tput setaf $DRAWLINES; echo -en "uperFLAC"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "R"; tput setaf $DRAWLINES; echo -en "ipping"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "M"; tput setaf $DRAWLINES; echo -en "iscellaneous"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "Q"; tput setaf $DRAWLINES; echo -en "uit"
  # ======================================================================================================  
  DISPLAYNAME=$(basename "$(pwd)"); DISPLAYNAME=$(echo $DISPLAYNAME | awk -F '/' '{print $NF}') 
  if [ ${#DISPLAYNAME} -gt 70 ]; then DISPLAYNAME="${DISPLAYNAME: -70}"; fi
  tput cup  3 4; tput setaf $LOGO; echo -en "Working folder: "; tput setaf $INFOTEXT; echo -en "…/$DISPLAYNAME"
  tput cup  8 4; tput setaf $MAINTEXT; echo -e "1) Boost volume"
  tput cup  9 4; echo "2) Convert between audio formats"
  tput cup 10 4; echo "3) Spectrum Analysis (FLACs only)"
  tput cup 11 4; echo "4) Remove ReplayGain tags from FLACs"
  tput cup 13 4; echo -e "W) Change Working Folder"
  tput cup 14 4; echo -e "F) Open File Manager"
  tput cup 15 4; echo -e "K) Clean FLAC tags in current folder"
  tput cup 22 4; tput setaf $ALERT; echo -e "X) Exit the program"

  until [[ $option == "q" ]]; do
  tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
  tput cup 25 24; tput cvvis; read -n 1 -s -r option
  if [[ $option == $escape_char ]]; then
    read -rsn2 option
  fi
  case $option in
   "" ) source "$CONFDIR/bin/semmaxv.sh"; smenuoptions audio;;
    1 ) source "$CONFDIR/bin/semmaxv.sh"; smenuoptions audio;;
    2 ) source "$CONFDIR/bin/semconv.sh"; smenuoptions audio;;
    3 ) source "$CONFDIR/bin/semspec.sh"; smenuoptions audio;;
    4 ) metaflac --remove-replay-gain *.flac 2>/dev/null
        dialog --stdout --backtitle "Semplice FLAC Volume Un-Boosting" --msgbox "All FLACs have had their metadata volume-boosting tags removed: \n\nClick OK to return to the main program menu." 8 80
        smenuoptions audio;;
    W|w ) source "$CONFDIR/bin/semdir.sh"; cd "$WORKINGDIR"; smenuoptions audio;;
    F|f ) if [[ $OSFAMILY == "MACOS" ]]; then open "."; else xdg-open "." 2>/dev/null; fi; ;;
    K|k ) source "$CONFDIR/bin/semclean.sh"; smenuoptions audio;;
    X|x ) clear; exit 0 ;;
    R|r ) clear; smenuoptions rip;;
    T|t ) clear; smenuoptions tag;;
    S|s ) clear; smenuoptions super;;
    A|a ) clear; smenuoptions audio;;
    M|m ) clear; smenuoptions misc;;
    Q|q ) clear; smenuoptions quit;;
    '[D') smenuoptions tag;;
    '[C') smenuoptions super;;
    * ) A=1;;
  esac
  done

elif [[ $1 == "super" ]]; then
  # ======================================================================================================
  tput cup  5 4
  tput setaf $HOTKEY; echo -en "T"; tput setaf $DRAWLINES; echo -en "agging"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "A"; tput setaf $DRAWLINES; echo -en "udio Processing"; echo -en "$SPACER"
  tput setaf $DRAWLINES; echo -en "\e[7mSuperFLAC\e[0m"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "R"; tput setaf $DRAWLINES; echo -en "ipping"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "M"; tput setaf $DRAWLINES; echo -en "iscellaneous"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "Q"; tput setaf $DRAWLINES; echo -en "uit"
  # ======================================================================================================
  DISPLAYNAME=$(basename "$(pwd)"); DISPLAYNAME=$(echo $DISPLAYNAME | awk -F '/' '{print $NF}') 
  if [ ${#DISPLAYNAME} -gt 70 ]; then DISPLAYNAME="${DISPLAYNAME: -70}"; fi
  tput cup  3 4; tput setaf $LOGO; echo -en "Working folder: "; tput setaf $INFOTEXT; echo -en "…/$DISPLAYNAME"
  tput cup  8 4; tput setaf $MAINTEXT; echo -e "1) Merge tracks into SuperFLAC"
  tput cup  9 4; echo "2) Split FLAC out into separate tracks"
  tput cup 10 4; echo "3) Edit embedded Cuesheet"
  tput cup 12 4; echo -e "W) Change Working Folder"
  tput cup 13 4; echo -e "F) Open File Manager"
  tput cup 14 4; echo -e "K) Clean FLAC tags in current folder"
  tput cup 22 4; tput setaf $ALERT; echo -e "X) Exit the program"
  
  until [[ $option == "q" ]]; do
  tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
  tput cup 25 24; tput cvvis; read -n 1 -s -r option
  if [[ $option == $escape_char ]]; then
    read -rsn2 option
  fi
  case $option in
   "" ) source "$CONFDIR/bin/semcaom.sh"; smenuoptions super;;
    1 ) source "$CONFDIR/bin/semcaom.sh"; smenuoptions super;;
    2 ) source "$CONFDIR/bin/semcaos.sh"; smenuoptions super;;
    3 ) source "$CONFDIR/bin/semcuee.sh"; smenuoptions super;;
    W|w ) source "$CONFDIR/bin/semdir.sh" flaconly; cd "$WORKINGDIR"; smenuoptions super ;;
    F|f ) if [[ $OSFAMILY == "MACOS" ]]; then open "."; else xdg-open "." 2>/dev/null; fi; ;;
    K|k ) source "$CONFDIR/bin/semclean.sh"; smenuoptions super;;
    X|x ) clear; exit 0 ;;
    R|r ) clear; smenuoptions rip;;
    T|t ) clear; smenuoptions tag;;
    S|s ) clear; smenuoptions super;;
    A|a ) clear; smenuoptions audio;;
    M|m ) clear; smenuoptions misc;;
    Q|q ) clear; smenuoptions quit;;
    '[D') smenuoptions audio;;
    '[C') smenuoptions rip;;
    * ) A=1;;
  esac
  done

elif [[ $1 == "rip" ]]; then
  # ======================================================================================================
  tput cup  5 4
  tput setaf $HOTKEY; echo -en "T"; tput setaf $DRAWLINES; echo -en "agging"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "A"; tput setaf $DRAWLINES; echo -en "udio Processing"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "S"; tput setaf $DRAWLINES; echo -en "uperFLAC"; echo -en "$SPACER"
  tput setaf $DRAWLINES; echo -en "\e[7mRipping\e[0m"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "M"; tput setaf $DRAWLINES; echo -en "iscellaneous"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "Q"; tput setaf $DRAWLINES; echo -en "uit"
  # ======================================================================================================
  DISPLAYNAME=$(basename "$(pwd)"); DISPLAYNAME=$(echo $DISPLAYNAME | awk -F '/' '{print $NF}') 
  if [ ${#DISPLAYNAME} -gt 70 ]; then DISPLAYNAME="${DISPLAYNAME: -70}"; fi
  tput cup  3 4; tput setaf $LOGO; echo -en "Working folder: "; tput setaf $INFOTEXT; echo -en "…/$DISPLAYNAME"
  tput cup  8 4; tput setaf $MAINTEXT; echo -e "1) Rip CD"
  tput cup  9 4; echo -e "2) Specify Optical Drive"
  tput cup 10 4; echo -e "3) Rip an SACD"
  tput cup 13 4; echo -e "W) Change Working Folder"
  tput cup 14 4; echo -e "F) Open File Manager"
  tput cup 15 4; echo -e "K) Clean FLAC tags in current folder"
  tput cup 22 4; tput setaf $ALERT; echo -e "X) Exit the program"

  until [[ $option == "q" ]]; do
  tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
  tput cup 25 24; tput cvvis; read -n 1 -s -r option
  if [[ $option == $escape_char ]]; then
    read -rsn2 option
  fi
  case $option in
   "" ) clear; source "$CONFDIR/bin/semrip.sh"; smenuoptions rip ;;
    1 ) clear; source "$CONFDIR/bin/semrip.sh"; smenuoptions rip ;;
    2 ) clear; source "$CONFDIR/bin/semdevpick.sh"; smenuoptions rip ;;
    3 ) clear; source "$CONFDIR/bin/semsacd.sh"; smenuoptions rip ;;
    W|w ) source "$CONFDIR/bin/semdir.sh"; cd "$WORKINGDIR"; smenuoptions rip ;;
    F|f ) if [[ $OSFAMILY == "MACOS" ]]; then open "."; else xdg-open "." 2>/dev/null; fi; ;;
    K|k ) source "$CONFDIR/bin/semclean.sh"; smenuoptions rip;;
    X|x ) clear; exit 0 ;;
    R|r ) clear; smenuoptions rip;;
    T|t ) clear; smenuoptions tag;;
    S|s ) clear; smenuoptions super;;
    A|a ) clear; smenuoptions audio;;
    M|m ) clear; smenuoptions misc;;
    Q|q ) clear; smenuoptions quit;;
    '[D') smenuoptions super;;
    '[C') smenuoptions misc;;
    * ) A=1;;
  esac
  done

elif [[ $1 == "misc" ]]; then
  # ======================================================================================================
  tput cup  5 4
  tput setaf $HOTKEY; echo -en "T"; tput setaf $DRAWLINES; echo -en "agging"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "A"; tput setaf $DRAWLINES; echo -en "udio Processing"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "S"; tput setaf $DRAWLINES; echo -en "uperFLAC"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "R"; tput setaf $DRAWLINES; echo -en "ipping"; echo -en "$SPACER"
  tput setaf $DRAWLINES; echo -en "\e[7mMiscellaneous\e[0m"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "Q"; tput setaf $DRAWLINES; echo -en "uit"
  # ======================================================================================================
  DISPLAYNAME=$(basename "$(pwd)"); DISPLAYNAME=$(echo $DISPLAYNAME | awk -F '/' '{print $NF}') 
  if [ ${#DISPLAYNAME} -gt 70 ]; then DISPLAYNAME="${DISPLAYNAME: -70}"; fi
  tput cup  3 4; tput setaf $LOGO; echo -en "Working folder: "; tput setaf $INFOTEXT; echo -en "…/$DISPLAYNAME"
  tput cup  8 4; tput setaf $MAINTEXT; echo -e "1) Edit Configuration File"
  tput cup  9 4; echo "2) Display License"
  tput cup 10 4; echo "3) Change the program colour scheme"  
  tput cup 12 4; echo -e "W) Change Working Folder"
  tput cup 13 4; echo -e "F) Open File Manager"
  tput cup 14 4; echo -e "K) Clean FLAC tags in current folder"
  tput cup 22 4; tput setaf $ALERT; echo -e "X) Exit the program"

  until [[ $option == "q" ]]; do
  tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
  tput cup 25 24; tput cvvis; read -n 1 -s -r option
  if [[ $option == $escape_char ]]; then
    read -rsn2 option
  fi
  case $option in
   "" ) source "$CONFDIR/bin/semconf.sh"; smenuoptions misc;;
    1 ) source "$CONFDIR/bin/semconf.sh"; smenuoptions misc;;
    2 ) if [[ ! -d "$CONFDIR/tmp" ]]; then mkdir -p "$CONFDIR/tmp"; fi
        if [[ ! -f "$CONFDIR/tmp/license.txt" ]]; then
          wget -q https://bbritten.com/software/semplice/gpl-v2.0.txt -O "$CONFDIR/tmp/license.txt"
        fi
        fmt -w 90 < "$CONFDIR/tmp/license.txt" > "$CONFDIR/tmp/licensewrapped.txt"
        sed -i 's/\\n/\n/g' "$CONFDIR/tmp/licensewrapped.txt"  # Sorts out spurious extra blank lines, replacing them with singles
        sed -i '1s/^/\n/' "$CONFDIR/tmp/licensewrapped.txt"    # Add a blank line to the start of the file for appearance's sake
        if [[ -f "$CONFDIR/tmp/licensewrapped.txt" ]]; then
          dialog --backtitle "Semplice GPL v2 Software Licence" --title " Text of the GPLv2 Licence " --ok-label "OK" --extra-button --extra-label "Cancel" --textbox "$CONFDIR/tmp/licensewrapped.txt" 20 95
        fi
        smenuoptions misc ;;
    3 ) source "$CONFDIR/bin/semcolour.sh"; smenuoptions misc;;
    W|w ) source "$CONFDIR/bin/semdir.sh"; cd "$WORKINGDIR"; smenuoptions misc ;;
    F|f ) if [[ $OSFAMILY == "MACOS" ]]; then open "."; else xdg-open "." 2>/dev/null; fi; ;;
    K|k ) source "$CONFDIR/bin/semclean.sh"; smenuoptions misc;;
    X|x ) clear; exit 0 ;;
    R|r ) clear; smenuoptions rip;;
    T|t ) clear; smenuoptions tag;;
    S|s ) clear; smenuoptions super;;
    A|a ) clear; smenuoptions audio;;
    M|m ) clear; smenuoptions misc;;
    Q|q ) clear; smenuoptions quit;;
    '[D') smenuoptions rip;;
    '[C') smenuoptions quit;;
    * ) A=1;;
  esac
  done

elif [[ $1 == "quit" ]]; then
  # ======================================================================================================
  tput cup  5 4
  tput setaf $HOTKEY; echo -en "T"; tput setaf $DRAWLINES; echo -en "agging"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "A"; tput setaf $DRAWLINES; echo -en "udio Processing"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "S"; tput setaf $DRAWLINES; echo -en "uperFLAC"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "R"; tput setaf $DRAWLINES; echo -en "ipping"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "M"; tput setaf $DRAWLINES; echo -en "iscellaneous"; echo -en "$SPACER"
  tput setaf $DRAWLINES; echo -en "\e[7mQuit\e[0m"
  # ======================================================================================================
  DISPLAYNAME=$(basename "$(pwd)"); DISPLAYNAME=$(echo $DISPLAYNAME | awk -F '/' '{print $NF}') 
  if [ ${#DISPLAYNAME} -gt 70 ]; then DISPLAYNAME="${DISPLAYNAME: -70}"; fi
  tput cup  3 4; tput setaf $LOGO; echo -en "Working folder: "; tput setaf $INFOTEXT; echo -en "…/$DISPLAYNAME"
  tput cup 8 4; tput setaf $MAINTEXT; echo -e "1) Quit with Post-Processing"
  tput cup 9 4; echo "2) Quit with no file processing"
  
  until [[ $option == "W" ]]; do
  tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
  tput cup 25 24; tput cvvis; read -n 1 -s -r option
  if [[ $option == $escape_char ]]; then
    read -rsn2 option
  fi
  case $option in
   "" ) source "$CONFDIR/bin/semquit.sh" clean; smenuoptions quit ;;
    1 ) source "$CONFDIR/bin/semquit.sh" clean; smenuoptions quit ;;
    2 ) source "$CONFDIR/bin/semquit.sh" noclean; smenuoptions quit ;;
    R|r ) clear; smenuoptions rip;;
    T|t ) clear; smenuoptions tag;;
    S|s ) clear; smenuoptions super;;
    A|a ) clear; smenuoptions audio;;
    M|m ) clear; smenuoptions misc;;
    X|x ) clear; exit 0 ;;
    Q|q ) smenuoptions quit;;
    '[D') smenuoptions misc;;
    '[C') smenuoptions tag;;
    * ) A=1;;
  esac
  done
fi
