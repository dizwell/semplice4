#!/usr/bin/env bash
####################################################################
#
# Queries the nature of the OS it's running on and sees if software
# prerequisites are present.
#
####################################################################
COPYRIGHT="2019-2026"                             # Copyright years, used by every screen that displays them (set here, as bin/ is always current)
if [[ -f "$CONFDIR/bin/semtput.sh" ]]; then
  source "$CONFDIR/bin/semtput.sh"
fi
if [[ -z $1 ]]; then set -- "checkonly"; fi
if [[ $1 == "install" ]]; then
  CHECKONLY=0
else
  CHECKONLY=1
fi

function print_header {
clear
LOGO=6
tput setaf $DRAWLINES; echo -e "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                   │
│                                                                                                   │
│                                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘"
tput cup  1 4; tput setaf $LOGO; echo -e "♬♪ Semplice Digital Music Manager Installer ♬♪"
tput cup  2 4; echo -e "Copyright © H. Rogers $COPYRIGHT"
tput cup  3 4; echo -e "Version $PROGVERSION"
}

function check_updates {
if [[ $pending -gt 0 ]]; then
  print_header
  tput cup 6 4; tput setaf $ALERT; echo "!! You have pending OS software updates !!"
  tput cup 8 4; tput setaf ${ALERT:-1}; echo "Do you want to quit the current installation and apply them yourself, or do you wish to proceed with installing Semplice regardless? [q/p] " | fold -s -w 76 | sed '2,$s/^/    /'
  read -s -n 1 choice
  tput setaf ${MAINTEXT:-11}
  
  # Default to 'q' if the user just presses Enter, or if they type 'q'/'Q'
  case "${choice:-q}" in
    [pP]* ) 
          echo "    OK, proceeding as requested. Please bear with us for a few moments..."    
          PROCEED=1
          ;;
        * ) 
          echo "    Exiting script at your request. Please update your system manually before trying again."
          reset
          rm -f "$INSTALLERFILE"
          exit 1
          ;;
   esac
fi    
}

# Start by checking what operating system we're dealing with, unless we've
# been told explicitly as part of installer invocation (-d)
# -----------------------------------------------------------------------------
if [[ -z $SEMDISTRO ]]; then
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$NAME
    THISVER=$VERSION
  else
    OS=$(uname -s)
    THISVER=$(uname -r)
  fi
  OS=${OS^^}
else
  OS=${SEMDISTRO^^}
fi

if hash nproc 2>/dev/null; then
  THREADS=$(nproc)
else
  THREADS=$(sysctl -n hw.logicalcpu)
fi

# If we're not running version 4+ of Bash, all our maths break!
# -----------------------------------------------------------------------------
if ((BASH_VERSINFO[0] < 4)); then
  echo "You are running an ancient version of Bash and Semplice cannot continue."
  exit 1
fi

# Put OS into appropriate family:
# -----------------------------------------------------------------------------
if [[ $OS == *"DARWIN"* ]]; then OSFAMILY="MACOS"; fi
if [[ $OS == *"VOID"* ]]; then OSFAMILY="VOID"; fi
if [[ $OS == *"ALMA"* || $OS == *"ROCKY"* ]]; then OSFAMILY="RHEL"; fi
if [[ $OS == *"ARCH"* || $OS == *"CACHY"* || $OS == *"MANJARO"* || $OS == *"ENDEAVOUROS"* || $OS == *"GARUDA"* ]]; then OSFAMILY="ARCH"; fi
if [[ $OS == *"DEBIAN"* || $OS == *"DEVUAN"* || $OS == *"RASPBIAN"* || $OS == *"LMDE"* ]]; then OSFAMILY="DEBIAN"; fi
if [[ $OS == *"FEDORA"* || $OS == *"ULTRAMARINE"* ]]; then OSFAMILY="FEDORA"; fi
if [[ $OS == *"UBUNTU"* || $OS == *"MINT"* || $OS == *"POP!"* || $OS == *"ZORIN"* || $OS == *"ELEMENTARY"* || $OS == *"TUXEDO"* || $OS == *"NEON"* ]]; then OSFAMILY="UBUNTU"; fi
if [[ $OS == *"MANJARO ARM"* ]]; then OSFAMILY="MANARM"; fi
if [[ -z $OSFAMILY ]]; then OSFAMILY="ELSE"; fi

# Raspberry Pi OS calls itself Debian, so spot it by the file only a Pi has (as Giocoso does)
if [[ -f /etc/rpi-issue ]]; then OSFAMILY="RASPBIAN"; fi


function cuetools_install {
# Needed by RHEL, as cuetools aren't in the standard repositories
cd
git clone https://github.com/svend/cuetools.git >/dev/null 2>&1
cd cuetools
autoreconf -fi >/dev/null 2>&1
./configure --prefix=/usr >/dev/null 2>&1
make >/dev/null 2>&1
sudo make install >/dev/null 2>&1
cd
rm -rf cuetools >/dev/null 2>&1

if ! command -v cueprint >/dev/null 2>&1; then
  dialog --stdout --backtitle "Semplice Software Install" --title " Software installation failure " --msgbox "\nThe automated installation of cuetools has **failed**. \n\nYou may be able to install it yourself later on, but until you do, Semplice will lack the ability to split a SuperFLAC into properly-named component tracks: you'll get generically-named tracks instead. This does NOT affect any other Semplice functionality.\n\nClick OK to proceed." 14 80     
fi
}

function wezterm_app_install {
# MacPorts' WezTerm package needs the full Xcode application, not just the command-line tools, so on MacPorts Macs
# we install WezTerm's own ready-made app instead: a Universal build for Intel and Apple Silicon alike, and the
# same release Homebrew installs. Skipped if WezTerm is already present.
local WEZVER="20240203-110809-5046fc22"
local WEZDIR="/tmp/WezTerm-macos-$WEZVER"
if [[ -x /opt/local/bin/wezterm || -x /Applications/WezTerm.app/Contents/MacOS/wezterm ]]; then return 0; fi
curl -fsSL --retry 5 -o "$WEZDIR.zip" "https://github.com/wezterm/wezterm/releases/download/$WEZVER/WezTerm-macos-$WEZVER.zip" || return 1
rm -rf "$WEZDIR"
ditto -x -k "$WEZDIR.zip" /tmp || return 1
rm -rf /Applications/WezTerm.app
mv "$WEZDIR/WezTerm.app" /Applications/ || return 1
rm -rf "$WEZDIR" "$WEZDIR.zip"
}

function dnf_retry {
# Runs "sudo dnf ARGS", logging to the install log. If Fedora's own background updater (PackageKit, GNOME
# Software) is busy, dnf fails with an rpm transaction lock error, so wait and try again: 20 tries, 15s apart.
local LOG="$CONFDIR/txt/install-log.txt" OUT tries=0
mkdir -p "$CONFDIR/txt" 2>/dev/null
while true; do
  OUT=$(sudo dnf "$@" 2>&1); local rc=$?
  echo "$OUT" >> "$LOG"
  if [[ $rc -eq 0 ]] || ! grep -q -i -E "transaction lock|another transaction is in progress" <<< "$OUT"; then return $rc; fi
  tries=$((tries+1)); [[ $tries -ge 20 ]] && return $rc
  echo "dnf busy (another program is installing software): waiting 15s, attempt $tries of 20" >> "$LOG"
  sleep 15
done
}

# Packages that fail to install are noted in failedpkgs.txt; afterwards report_failed_pkgs lists them in one box
# (returning 0) or, if there were none, returns 1 so the usual "all installed" box shows instead
FAILEDPKGS="$CONFDIR/tmp/failedpkgs.txt"
mkdir -p "$CONFDIR/tmp" 2>/dev/null; rm -f "$FAILEDPKGS" 2>/dev/null
function report_failed_pkgs {
[[ -s $FAILEDPKGS ]] || return 1
dialog --title " Some Software Could Not Be Installed " --msgbox "\\n\\nThese packages could not be installed:\\n\\n  $(sort -u "$FAILEDPKGS" | tr '\n' ' ')\\n\\nSemplice may not work fully until you install them yourself with your package manager. Details are in Semplice's txt/install-log.txt.\\n\\nClick OK to proceed." 16 80
return 0
}

# On a Mac the package lists name some packages twice, as Homebrew and MacPorts know them differently (icu4c/icu,
# for instance), so "no such package" from one manager is expected and isn't reported as a failure
function mac_install {
local OUT rc
if [[ $pkgmanager == "homebrew" ]]; then OUT=$(brew install --quiet "$1" 2>&1); else OUT=$(sudo port -N install "$1" 2>&1); fi
rc=$?; echo "$OUT" >> "$CONFDIR/txt/install-log.txt"
if [[ $rc -ne 0 ]] && grep -q -i -E "no available formula|not found|no such port|unknown port" <<< "$OUT"; then return 0; fi
return $rc
}

# Is a package installed already, whatever the package manager said? Used so that a package the package manager
# couldn't reach (because something else held its lock, say) isn't reported as missing when it's actually present
function pkg_installed {
case "$OSFAMILY" in
  DEBIAN|UBUNTU|RASPBIAN) dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed" ;;
  FEDORA|RHEL)            rpm -q "$1" >/dev/null 2>&1 || rpm -q --whatprovides "$1" >/dev/null 2>&1 ;;
  ARCH)                   pacman -Q "$1" >/dev/null 2>&1 ;;
  VOID)                   xbps-query "$1" >/dev/null 2>&1 ;;
  MACOS)
    if [[ $1 == "wezterm" && -x /Applications/WezTerm.app/Contents/MacOS/wezterm ]]; then return 0; fi
    if [[ $pkgmanager == "homebrew" ]]; then brew list --formula "$1" >/dev/null 2>&1; else port -q installed "$1" 2>/dev/null | grep -q active; fi ;;
  *) return 1 ;;
esac
}

# Now define the software tools etc. required for each family
# -----------------------------------------------------------------------------
case $OSFAMILY in
  VOID)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      tput setaf ${ALERT:-1}; sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f "$INSTALLERFILE"; exit 1; }; tput setaf ${MAINTEXT:-11}
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo "    Getting the Semplice installer ready. Please bear with us for a few moments..."
    sudo xbps-install -Sy >/dev/null 2>&1

    if sudo xbps-install -un | grep -q .; then
      pending=1
      check_updates
    fi
    
    sudo xbps-install -Sfy dialog > /dev/null 2>&1

    # Define what's required    
    packages=(bc cdparanoia coreutils cuetools curl dialog flac fd libcdio ncurses nerd-fonts-ttf wezterm libpulseaudio alsa-utils)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo xbps-install -Sf -y "$pkg" >> "$CONFDIR/txt/install-log.txt" 2>&1 || pkg_installed "$pkg" || echo "$pkg" >> "$FAILEDPKGS"
      sleep 0.1
    done
    ) | dialog --title " Installing Semplice's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
	
	
	
    # Confirmation when concluded
    report_failed_pkgs || dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Semplice's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum  FDPROG=fd
  ;;
  
  ARCH)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      tput setaf ${ALERT:-1}; sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f "$INSTALLERFILE"; exit 1; }; tput setaf ${MAINTEXT:-11}
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo "    Getting the Semplice installer ready. Please bear with us for a few moments..."
    sudo pacman -Syy --noconfirm >/dev/null 2>&1

    if sudo pacman -Qu | grep -q .; then
      pending=1
      check_updates
    fi

    sudo pacman -S --noconfirm dialog > /dev/null 2>&1

    # Define what's required
    packages=(bc cdparanoia coreutils cuetools curl dialog flac fd libcdio ncurses ttf-nerd-fonts-symbols-mono wezterm libpulse alsa-utils)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo pacman -S --noconfirm "$pkg" >> "$CONFDIR/txt/install-log.txt" 2>&1 || pkg_installed "$pkg" || echo "$pkg" >> "$FAILEDPKGS"
      sleep 0.1
    done
    ) | dialog --backtitle "Semplice Software Install" --title " Installing Semplice's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
    tput cup 24 4
	
		
	
    # Confirmation when concluded
    report_failed_pkgs || dialog --backtitle "Semplice Software Install" --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Semplice's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum  FDPROG=fd  
  ;;
  
  DEBIAN)
  if [[ $CHECKONLY -eq 0 ]]; then
    # If sudo doesn't work, grant the user SUDO privileges. Otherwise, just get on with it...
    if ! sudo -n true 2>/dev/null; then
      tput cup 8 4; tput setaf $INFOTEXT; echo -en "Please supply the "; tput setaf $ALERT; echo -en "\e[4mroot user\e[24m "; tput setaf $INFOTEXT
      su -c "
      echo \"$USER ALL=(ALL:ALL) ALL\" >/etc/sudoers.d/$USER
      chmod 440 /etc/sudoers.d/$USER
      "
    fi

    if ! sudo -n true 2>/dev/null; then
      tput setaf ${ALERT:-1}; sudo -p $'\r    Now supply the sudo password for user %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f "$INSTALLERFILE"; exit 1; }; tput setaf ${MAINTEXT:-11}
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo "    Getting the Semplice installer ready. Please bear with us for a few moments..." 
    wget -qO- https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg >/dev/null 2>&1
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
    sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg >/dev/null 2>&1
    sudo apt-get -o DPkg::Lock::Timeout=300 update -qq
    pending=$(apt-get -s upgrade | awk '/^Inst / {count++} END {print count+0}')
    check_updates
 
    sudo apt -o DPkg::Lock::Timeout=300 -y install dialog > /dev/null 2>&1
        
    # Define what's required 
    packages=(bc cdparanoia coreutils cuetools curl fd-find flac libncurses* wezterm libpulse0 alsa-utils)
    total=${#packages[@]}
    count=0
    
    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo apt -o DPkg::Lock::Timeout=300 -y install "$pkg" >> "$CONFDIR/txt/install-log.txt" 2>&1 || pkg_installed "$pkg" || echo "$pkg" >> "$FAILEDPKGS"
      sleep 0.1
    done
    ) | dialog --title " Installing Semplice's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
    
    # Confirmation when concluded
    report_failed_pkgs || dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Semplice's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum  FDPROG=fdfind
  ;;
  
  RASPBIAN)
  if [[ $CHECKONLY -eq 0 ]]; then
    # If sudo doesn't work, grant the user SUDO privileges. Otherwise, just get on with it...
    if ! sudo -n true 2>/dev/null; then
      tput cup 8 4; tput setaf $INFOTEXT; echo -en "Please supply the "; tput setaf $ALERT; echo -en "\e[4mroot user\e[24m "; tput setaf $INFOTEXT
      su -c "
      echo \"$USER ALL=(ALL:ALL) ALL\" >/etc/sudoers.d/$USER
      chmod 440 /etc/sudoers.d/$USER
      "
    fi

    if ! sudo -n true 2>/dev/null; then
      tput setaf ${ALERT:-1}; sudo -p $'\r    Now supply the sudo password for user %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f "$INSTALLERFILE"; exit 1; }; tput setaf ${MAINTEXT:-11}
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo "    Getting the Semplice installer ready. Please bear with us for a few moments..."
    wget -qO- https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg >/dev/null 2>&1
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
    sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg >/dev/null 2>&1
    sudo apt-get -o DPkg::Lock::Timeout=300 update -qq
    pending=$(apt-get -s upgrade | awk '/^Inst / {count++} END {print count+0}')
    check_updates

    sudo apt -o DPkg::Lock::Timeout=300 -y install dialog > /dev/null 2>&1

    # Define what's required
    packages=(bc cdparanoia coreutils cuetools curl dialog fd-find flac libncurses* wezterm libpulse0 alsa-utils)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo apt -o DPkg::Lock::Timeout=300 -y install "$pkg" >> "$CONFDIR/txt/install-log.txt" 2>&1 || pkg_installed "$pkg" || echo "$pkg" >> "$FAILEDPKGS"
      sleep 0.1
    done
    ) | dialog --title " Installing Semplice's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
    
    # Confirmation when concluded
    report_failed_pkgs || dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Semplice's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum  FDPROG=fdfind
  ;;  
    
  UBUNTU)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      tput setaf ${ALERT:-1}; sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f "$INSTALLERFILE"; exit 1; }; tput setaf ${MAINTEXT:-11}
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo "    Getting the Semplice installer ready. Please bear with us for a few moments..."
    wget -qO- https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg >/dev/null 2>&1
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list > /dev/null
    sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg >/dev/null 2>&1
    sudo apt-get -o DPkg::Lock::Timeout=300 update -qq
    pending=$(apt-get -s upgrade | awk '/^Inst / {count++} END {print count+0}')
    check_updates
    
    sudo apt -o DPkg::Lock::Timeout=300 -y install dialog > /dev/null 2>&1
        
     # Define what's required 
    packages=(bc cdparanoia coreutils cuetools curl fd-find flac libncurses6 wezterm libpulse0 alsa-utils)
    total=${#packages[@]}
    count=0
    
    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo apt -o DPkg::Lock::Timeout=300 -y install "$pkg" >> "$CONFDIR/txt/install-log.txt" 2>&1 || pkg_installed "$pkg" || echo "$pkg" >> "$FAILEDPKGS"
      sleep 0.1
    done
    ) | dialog --title " Installing Semplice's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
    
    # Confirmation when concluded
    report_failed_pkgs || dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Semplice's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum  FDPROG=fdfind
  ;; 
  
  FEDORA)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      tput setaf ${ALERT:-1}; sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f "$INSTALLERFILE"; exit 1; }; tput setaf ${MAINTEXT:-11}
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo "    Getting the Semplice installer ready. Please bear with us for a few moments..."
    sudo dnf copr enable -y -q wezfurlong/wezterm-nightly >/dev/null 2>&1
    sudo dnf check-update --refresh -q; rc=$?
    if [[ $rc -eq 100 ]]; then
      pending=1
      check_updates
    fi
    
    echo "    Adding needed repositories. Please be patient..."
    dnf_retry -y install dialog
    
     # Define what's required 
    packages=(bc cdparanoia coreutils cuetools curl fd-find flac ncurses wezterm pulseaudio-libs alsa-utils)
    total=${#packages[@]}
    count=0
    
    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      dnf_retry -y install "$pkg" --allowerasing || pkg_installed "$pkg" || echo "$pkg" >> "$FAILEDPKGS"
      sleep 0.1
    done
    ) | dialog --title " Installing Semplice's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
    
    # Confirmation when concluded
    report_failed_pkgs || dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Semplice's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum  FDPROG=fd
  ;;
  
  RHEL)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      tput setaf ${ALERT:-1}; sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f "$INSTALLERFILE"; exit 1; }; tput setaf ${MAINTEXT:-11}
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo "    Getting the Semplice installer ready. Please bear with us for a few moments..."
    sudo dnf copr enable -y -q wezfurlong/wezterm-nightly rhel-9-x86_64 >/dev/null 2>&1
    sudo dnf check-update --refresh -q; rc=$?
    if [[ $rc -eq 100 ]]; then
      pending=1
      check_updates
    fi

    echo "    Adding needed repositories. Please be patient..."
    dnf_retry -y install dialog
    EPELON=$(sudo dnf repolist | grep epel | wc -l)
    if [[ $EPELON -eq 0 ]]; then
      dnf_retry -y install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm"
      dnf_retry -y install "https://dl.fedoraproject.org/pub/epel/epel-next-release-latest-$(rpm -E %rhel).noarch.rpm"
      sudo dnf -y config-manager --set-enabled crb >/dev/null 2>&1
    fi

    # Define what's required 
    packages=(autoconf automake bc bison cdparanoia coreutils curl fd-find flac flex fontconfig gawk gcc git grep make ncurses wezterm pulseaudio-libs alsa-utils)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      dnf_retry -y install "$pkg" --allowerasing || pkg_installed "$pkg" || echo "$pkg" >> "$FAILEDPKGS"
      sleep 0.1
    done
    ) | dialog --title " Installing Semplice's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
    tput cup 24 4
    cuetools_install

    # Confirmation when concluded
    report_failed_pkgs || dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Semplice's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum FDPROG=fd
  ;;  
  
  MACOS)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      tput setaf ${ALERT:-1}; sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f "$INSTALLERFILE"; exit 1; }; tput setaf ${MAINTEXT:-11}
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    echo ""
    echo "    Getting the Semplice installer ready. Please bear with us for a few moments..."
    echo ""

    # Create a destination folder for Semplice
    if [[ ! -d /usr/local/bin ]]; then
      sudo mkdir -p /usr/local/bin
      sudo chown -R $(whoami) /usr/local/bin
      sudo chmod -R u=rwX,go=rX /usr/local/bin
    fi
    
     while true; do
      echo "    Do you want to use Homebrew (h) or Macports (m) as your package installer?"
      echo "    Note that whatever you choose here must have already been installed by you, manually."
      echo "    Do not mix package installers: if you've already used one or the other, stick"
      echo "    to that one now. If you have a free choice, choose Macports for older machines"
      echo "    and for the fact that it's *much* faster to complete!"
      echo ""
      tput setaf ${ALERT:-1}; read -n 1 -p "    Homebrew or Macports, then? (h/m): " input; tput setaf ${MAINTEXT:-11}
      case "$input" in
       [hH])
         if command -v brew >/dev/null 2>&1; then
           pkgmanager=homebrew
           echo ""
           echo "    Using the Homebrew Package Manager. Please hold on..."
           echo ""
           brew install --quiet dialog >/dev/null 2>&1
           break
         else
           echo ""
           echo "    Unfortunately, it appears that Homebrew has not already been installed on this system."
           echo "    Do that first, manually, before trying to re-run this installer."
           echo ""
           exit 1        
         fi  
         ;;
       [mM])
         if command -v port >/dev/null 2>&1; then
           pkgmanager=macports
           echo ""
           echo "    Using the Macports Package Manager. Please wait..."
           echo ""
           sudo port -N install dialog > /dev/null 2>&1           
           break
         else
           echo ""
           echo "    Unfortunately, it appears that Macports has not already been installed on this system."
           echo "    Do that first, manually, before trying to re-run this installer."
           echo ""
           exit 1
         fi   
         ;;
       *)
         clear
         echo ""
         echo "    Invalid input: only h or m are allowed. Please try again."
         echo ""
        ;;
      esac
    done

    # Define what's required
    packages=(bc cdparanoia coreutils cuetools curl dialog fd flac gawk grep gsed icu4c icu libcdio-paranoia md5sha1sum ncurses wezterm)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      if [[ $pkgmanager == "homebrew" ]]; then
        mac_install "$pkg" || pkg_installed "$pkg" || echo "$pkg" >> "$FAILEDPKGS"
      elif [[ $pkgmanager == "macports" ]]; then
        if [[ $pkg == "wezterm" ]]; then
          wezterm_app_install >> "$CONFDIR/txt/install-log.txt" 2>&1 || pkg_installed wezterm || echo "wezterm" >> "$FAILEDPKGS"
        else
          mac_install "$pkg" || pkg_installed "$pkg" || echo "$pkg" >> "$FAILEDPKGS"
        fi
      fi
      
      sleep 0.1
    done
    ) | dialog --title " Installing Semplice's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
    tput cup 24 4
    
    if [[ $pkgmanager == "homebrew" ]]; then
      ln -sf "$(brew --prefix)/bin/cd-paranoia" "$(brew --prefix)/bin/cdparanoia" 2>/dev/null
      ln -sf "$(brew --prefix icu4c)/bin/uconv" "$(brew --prefix)/bin/uconv" 2>/dev/null     # Version-free path: survives Homebrew upgrades of icu4c
    fi

    # Confirmation when concluded
    report_failed_pkgs || dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Semplice's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=gsed  DATEPROG=gdate  MD5PROG=md5sum  FDPROG=fd
  ;;  
  
  *)
  echo "You are using an unsupported operating system. Quitting!"
  exit 1
  ;;
esac

# Platform and architecture, used to pick the right self-compiled programs in exec/ (named as Giocoso's:
# <program>-<macos|linux>-<arm64|x86_64>).
# -----------------------------------------------------------------------------
case "$(uname -s)" in
    Darwin) OS_PLATFORM="macos" ;;
    Linux)  OS_PLATFORM="linux" ;;
    *)      OS_PLATFORM="unknown" ;;
esac
case "$(uname -m)" in
    arm64|aarch64) OS_ARCHITECTURE="arm64" ;;
    x86_64)        OS_ARCHITECTURE="x86_64" ;;
    armv7l|armv6l) OS_ARCHITECTURE="armv7l" ;;
    *)             OS_ARCHITECTURE="unknown" ;;
esac
SEMARV="$CONFDIR/exec/semarv-${OS_PLATFORM}-${OS_ARCHITECTURE}"
SACDEXTRACT="$CONFDIR/exec/sacd_extract-${OS_PLATFORM}-${OS_ARCHITECTURE}"
SIXEL="$CONFDIR/exec/img2sixel-${OS_PLATFORM}-${OS_ARCHITECTURE}"
CONVERTER="$CONFDIR/exec/magick-${OS_PLATFORM}-${OS_ARCHITECTURE}"      # Self-contained ImageMagick 7 (JPG and PNG), the same build as Giocoso's
FFMPEG="$CONFDIR/exec/ffmpeg-${OS_PLATFORM}-${OS_ARCHITECTURE}"        # Self-contained ffmpeg and ffprobe, the same builds as Giocoso's
FFPROBE="$CONFDIR/exec/ffprobe-${OS_PLATFORM}-${OS_ARCHITECTURE}"
chmod +x "$SEMARV" "$SACDEXTRACT" "$SIXEL" "$CONVERTER" "$FFMPEG" "$FFPROBE" 2>/dev/null

echo "SEDPROG=$SEDPROG
GREPPROG=$GREPPROG
DATEPROG=$DATEPROG
MD5PROG=$MD5PROG
FDPROG=$FDPROG
CONVPROG=\"$CONVERTER\"
FFMPEG=\"$FFMPEG\"
FFPROBE=\"$FFPROBE\"
OS_PLATFORM=$OS_PLATFORM
OS_ARCHITECTURE=$OS_ARCHITECTURE
SEMARV=\"$SEMARV\"
SACDEXTRACT=\"$SACDEXTRACT\"
SIXEL=\"$SIXEL\"" > "$CONFDIR/txt/programvariables.txt"
