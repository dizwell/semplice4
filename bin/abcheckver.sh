#!/usr/bin/env bash
#
####################################################################
#
# abcheckver: A function to check if software updates are available
# and to apply them if so and the user requests it.
#
####################################################################
source "$CONFDIR/bin/ablibnentput.sh"
REMOTESOURCE="https://bbritten.com/software/semplice"
NEWCONF="$HOME/.local/share/semplice2"

BACKTITLE="Semplice Software Update Checker"  LINENUM=9
if ! [[ -d "$CONFDIR/tmp" ]]; then mkdir -p "$CONFDIR/tmp" 2>/dev/null; fi
unset response

remote_hash=$(curl -s "$REMOTESOURCE/releasehash.txt" | tr -d '[:space:]')
RELEASEHASH=dd0610fde9557388ef3d2be2ec78b7db    #hard-coded at time of release by date +%Y%m%d | md5sum | awk '{print $1}'

if [[ $remote_hash != $RELEASEHASH ]]; then
  DOUPGRADE=1
else 
  DOUPGRADE=0
fi

function perform_upgrade {
# Fetch Semnplice components: BIN files first
components=(abcheckver.sh ablibsemart.sh ablibsembits.sh ablibsemcaom.sh ablibsemcaos.sh ablibsemclean.sh ablibsemcolour.sh ablibsemconf.sh ablibsemconv.sh ablibsemcuee.sh ablibsemdevpick.sh ablibsemdir.sh ablibsemmaxv.sh ablibsemmeta.sh ablibsemoffpick.sh ablibsemparse.sh ablibsemquit.sh ablibsemrenum.sh ablibsemrip.sh ablibsemsacd.sh ablibsemspec.sh ablibsemspin.sh ablibsemtags.sh ablibsemtput.sh ablibsemtrks.sh ablibsemxart.sh aboscheck.sh smenudraw.sh smenuoptions.sh sacd_extract sacd_extract_arm sacd_extract-macintel sacd_extract-macsilicon)
total=${#components[@]}
count=0
(
for f in "${components[@]}"; do
  count=$((count + 1 ))
  percent=$((count * 100 / total))
  echo $percent
  wget -q "$REMOTESOURCE/bin/$f" -O "$NEWCONF/bin/$f";
  sleep 0.1
done
) | dialog --title "Updating Semplice Binary Components" --gauge "\\n\\nDownloading fresh copies of Semplice's own software components: this might take some time..." 12 70

# Art files next
components=(Luxi_License.txt luximr.ttf sempliceco.png sempliceico.svg sempliceico.xpm)
total=${#components[@]}
count=0
(
for f in "${components[@]}"; do
  count=$((count + 1 ))
  percent=$((count * 100 / total))
  echo $percent
  wget -q "$REMOTESOURCE/art/$f" -O "$NEWCONF/art/$f";
  sleep 0.1
done
) | dialog --title "Updating Semplice Art Components" --guage "\\n\\nDownloading fresh copies of some other Semplice bits and pieces: not long to wait now..." 12 70

# Finally, /usr/bin and miscellaneous stuff
if [[ $OS == "DARWIN" ]]; then
  sudo wget -q "$REMOTESOURCE/semplice2.sh" -O "/usr/local/bin/semplice2.sh";  sudo chmod +x /usr/local/bin/semplice2.sh
  sudo rm -f /usr/local/bin/semplice 2>/dev/null; sudo ln -s /usr/local/bin/semplice2.sh /usr/local/bin/semplice 2>/dev/null
else
  sudo wget -q "$REMOTESOURCE/semplice2.sh" -O "/usr/bin/semplice2.sh";  sudo chmod +x /usr/bin/semplice2.sh
  sudo rm -f /usr/bin/semplice 2>/dev/null; sudo ln -s /usr/bin/semplice2.sh /usr/bin/semplice 2>/dev/null
fi

# Confirmation when concluded
dialog --title "Software Components Completed" --msgbox "\\n\\nAll Semplice's components have now been updated successfully." 12 70
}

clear; source "$CONFDIR/bin/smenudraw.sh" short
if [[ $DOUPGRADE -eq 1 ]]; then
  dialog --title " Software Update Available " --backtitle "$BACKTITLE" --yesno "\\nA software update is available. Would you like to install it?" 10 80
  response=$?			# 0=yes, 1=no, 255=Escape key pressed
  case $response in
    0  ) perform_upgrade;;
    1  ) dialog --stdout --backtitle "$BACKTITLE" --msgbox "The software update has been cancelled.\\n\\nNo software has been modified or altered.\\n\\nPress OK to continue..." 10 80 ;;
    255) dialog --stdout --backtitle "$BACKTITLE" --msgbox "The software update has been cancelled.\\n\\nNo software has been modified or altered.\\n\\nPress OK to continue..." 10 80 ;;
  esac
else
  dialog --title " Software Update " --backtitle "$BACKTITLE" --msgbox "\\nYou are all good: there is no newer version of Semplice software to apply.\\n\\nPress OK to continue..." 10 80
fi
