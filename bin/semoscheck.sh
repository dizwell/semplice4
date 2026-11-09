#!/usr/bin/env bash
####################################################################
#
# Queries the nature of the OS it's running on and sees if software
# prerequisites are present.
#
####################################################################
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
tput cup  2 4; echo -e "Copyright © Howard Rogers $COPYRIGHT"
tput cup  3 4; echo -e "Version $PROGVERSION"
}

function check_updates {
if [[ $pending -gt 0 ]]; then
  print_header
  tput cup 6 4; tput setaf $ALERT; echo "!! You have pending OS software updates !!"
  tput cup 8 4; tput setaf $MAINTEXT; echo "Do you want to quit the current installation and apply them yourself, or do you wish to proceed with installing Semplice regardless? [q/p] " | fold -s -w 76 | sed '2,$s/^/    /'
  read -s -n 1 choice
  
  # Default to 'q' if the user just presses Enter, or if they type 'q'/'Q'
  case "${choice:-q}" in
    [pP]* ) 
          echo "    OK, proceeding as requested. Please bear with us for a few moments..."    
          PROCEED=1
          ;;
        * ) 
          echo "    Exiting script at your request. Please update your system manually before trying again."
          reset
          rm -f seminst
          exit 1
          ;;
   esac
fi    
}

# Start by checking what operating system we're dealing with
# -----------------------------------------------------------------------------
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$NAME
    THISVER=$VERSION
else
  OS=$(uname -s)
  THISVER=$(uname -r)
fi

OS=${OS^^}

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

function sacd_install {
if ! command -v sacd >/dev/null 2>&1; then
  if [[ ! $OSFAMILY == "MACOS" ]]; then
    # Install build tools and Python dev headers, distro-independent
    if command -v apt >/dev/null 2>&1; then
      sudo apt update >/dev/null 2>&1
      sudo apt install -y build-essential python3-dev python3-setuptools python3-wheel >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf group install -y development-tools >/dev/null 2>&1
      sudo dnf install -y gcc-c++ >/dev/null 2>&1
      sudo dnf install -y python3-devel python3-setuptools python3-wheel >/dev/null 2>&1
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -Syu --noconfirm base-devel python python-setuptools python-wheel >/dev/null 2>&1
    fi

    dialog --stdout --backtitle "Semplice Software Install" --title " Installing Semplice's Software Dependencies " --backtitle "Semplice Software Install" --msgbox "\nAbout to install sacd, for SACD conversion purposes. \n\nClick OK to proceed." 10 80
    tput cup 24 4; echo -en "Processing. Please wait..."
    cd
    git clone https://github.com/Sound-Linux-More/sacd.git >/dev/null 2>&1
    cd sacd
    make >/dev/null 2>&1
    sudo make install >/dev/null 2>&1
    cd
    rm -rf sacd >/dev/null >/dev/null 2>&1
  fi

  if ! command -v sacd >/dev/null 2>&1; then
    dialog --stdout --backtitle "Semplice Software Install" --title " Software installation failure " --msgbox "\nThe automated installation of sacd has **failed**. \n\nYou may be able to install it yourself later on, but until you do, Semplice will lack SACD ripping and conversion capabilities. This does NOT affect any other Semplice functionality.\n\nClick OK to proceed." 14 80     
  fi
fi
}

function audiotools_install {
if ! command -v trackverify >/dev/null 2>&1; then    
  if [[ ! $OSFAMILY == "MACOS" ]]; then     # Unfortunately, I do not have a way to install trackverify on MacOS at this time
    dialog --stdout --title " Installing Semplice's Software Dependencies " --backtitle "Semplice Software Install" \
           --msgbox "\nAbout to install Audiotools, for CD Rip verification purposes.\n\nClick OK to proceed." 10 80

    tput cup 24 4; echo -en "Processing. Please wait..."
    wget -q https://bbritten.com/software/semplice/tmp/audiotools.tar.gz \
         -O "$CONFDIR/tmp/audiotools.tar.gz"
    tar -xvzf "$CONFDIR/tmp/audiotools.tar.gz" -C "$CONFDIR/tmp" >/dev/null 2>&1
    mv "$CONFDIR/tmp/audiotools-3.1.1" "$CONFDIR/tmp/audiotools"

    cd "$CONFDIR/tmp/audiotools"

    # Detect Python major.minor version
    PYVER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    PYMAJOR=$(echo "$PYVER" | cut -d. -f1)
    PYMINOR=$(echo "$PYVER" | cut -d. -f2)

    # Patch setup.py only if Python >= 3.12 (distutils removed)
    if [[ $PYMAJOR -ge 3 && $PYMINOR -ge 12 ]]; then
      sed -i 's/from __future__ import print_function/from setuptools import setup/' setup.py
    fi

    # Build and install
    sudo python3 setup.py build >/dev/null 2>&1
    sudo python3 setup.py install >/dev/null 2>&1

    cd
    sudo rm -rf "$CONFDIR/tmp/audiotools"
    sudo rm -f "$CONFDIR/tmp/audiotools.tar.gz"
  fi
  
  if ! command -v trackverify >/dev/null 2>&1; then
    dialog --stdout --backtitle "Semplice Software Install" --title " Software installation failure " --msgbox "\nThe automated installation of audiotools has **failed**. \n\nYou may be able to install it yourself later on, but until you do, Semplice will lack the ability to perform track verification after a CD rip. This does NOT affect any other Semplice functionality.\n\nClick OK to proceed." 14 80     
  fi
fi
}

# Now define the software tools etc. required for each family
# -----------------------------------------------------------------------------
case $OSFAMILY in
  VOID)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f seminst; exit 1; }
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
    packages=(automake base-devel bc cdparanoia cmake coreutils cuetools curl dialog ffmpeg flac fd gcc gd-devel git ImageMagick lame-devel libcdio libjpeg-turbo-devel libpng-devel libtool make ncurses nerd-fonts-ttf pkg-config python3-devel python3-setuptools libflac-devel libogg-devel wezterm xclip xdpyinfo xterm)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo xbps-install -Sf -y "$pkg" > /dev/null 2>&1 || true
      sleep 0.1
    done
    ) | dialog --title " Installing Semplice's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
	
	# Compile Libsixel
	dialog --backtitle "Semplice Software Install" --title " Installing Semplice's Software Dependencies " --msgbox "\\n\\nNow we have to compile the Libsixel, AudioTools and SACD support packages. This can take a **very** long time! Please be even more patient than before..." 12 70
	tput cup 24 4	
	git clone https://github.com/saitoha/libsixel.git > /dev/null 2>&1
	cd libsixel
	./autogen.sh > "$HOME/Desktop/sixelinstall.log" 2>&1
	./configure >> "$HOME/Desktop/sixelinstall.log" 2>&1
	make >> "$HOME/Desktop/sixelinstall.log" 2>&1
	sudo make install >> "$HOME/Desktop/sixelinstall.log" 2>&1
	sudo ldconfig > /dev/null 2>&1
	
	# Compile python audio tools
	tput cup 24 4
	git clone https://github.com/tuffy/python-audio-tools.git > /dev/null 2>&1
	cd python-audio-tools
	python3 setup.py build > "$HOME/Desktop/audioinstall.log" 2>&1
	sudo python3 setup.py install >> "$HOME/Desktop/audioinstall.log" 2>&1
	
	cd
	rm -rf libsixel > /dev/null 2>&1
	
	# Compile SACD ISO support
	tput cup 24 4	
    sacd_install
	
    # Confirmation when concluded
    dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Semplice's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum  FDPROG=fd
  ;;
  
  ARCH)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f seminst; exit 1; }
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

    sudo pacman -S --noconfirm dialog git base-devel go > /dev/null 2>&1

    # Define what's required
    packages=(base-devel bc cdparanoia cmake coreutils cuetools curl dialog ffmpeg flac fd git imagemagick libcdio libxml2-legacy ncurses python python-setup-tools ttf-nerd-fonts-symbols-mono wezterm xclip xorg-xdpyinfo xterm)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo pacman -S --noconfirm "$pkg" > /dev/null 2>&1 || true
      sleep 0.1
    done
    ) | dialog --backtitle "Semplice Software Install" --title " Installing Semplice's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
    tput cup 24 4
	
	dialog --backtitle "Semplice Software Install" --title " Installing Semplice's Software Dependencies " --msgbox "\\n\\nNow we have to compile the Libsixel, AudioTools and SACD support packages. This can take a **very** long time! Please be even more patient than before..." 12 70
    if ! command -v yay &> /dev/null
	then
        dialog  --backtitle "Semplice Software Install" --title " Installing Semplice's Software Dependencies " --msgbox "\\nThe 'Yay' utility is required to compile additional necessary Semplice components. It takes a long time to install and there won't be much by way of progress indicators.\\n\\nClick OK to begin the Yay installation process now." 12 70
        exitStatus=$?
		if [[ $exitStatus -eq 0 ]]; then INSTALLYAY=1; else INSTALLYAY=0; fi  	
        if [[ $INSTALLYAY -eq 1 ]]; then
          cd
          git clone https://aur.archlinux.org/yay.git >/dev/null 2>&1
          cd yay
          if [[ -d "$HOME/Desktop" ]]; then
		    makepkg -si --noconfirm > "$HOME/Desktop/yayinstall.log" 2>&1
		  else
			mkdir "$HOME/Desktop" 2>&1
			makepkg -si --noconfirm > "$HOME/Desktop/yayinstall.log" 2>&1
		  fi 	
		  yay -Y --save --answerclean All --answerdiff None --answerupgrade None --noconfirm >> $HOME/Desktop/yayinstall.log 2>&1
  		else
		  dialog  --backtitle "Semplice Software Install" --title " Installing Semplice's Software Dependencies " --msgbox "\\n\\nYou have cancelled the installation of Yay, without which this installation cannot complete. Quitting back to the command line." 12 70	 
		  exit 1
        fi
	fi
	
	mkdir -p /tmp/gcc-patch
	echo '#!/bin/sh' > /tmp/gcc-patch/gcc
	echo '/usr/bin/gcc -Wno-error=implicit-function-declaration "$@"' >> /tmp/gcc-patch/gcc
	chmod +x /tmp/gcc-patch/gcc
		
	if ! command -v trackverify &> /dev/null
	then
  	  dialog  --backtitle "Semplice Software Install" --title " Installing Semplice's Software Dependencies " --msgbox "\\n\\nNow we need to compile the Audiotools package, which allows Semplice to verify CD Rips. This can run for many minutes..." 12 70	 	
	  PATH="/tmp/gcc-patch:$PATH" yay -S audiotools --noconfirm > "$HOME/Desktop/audioinstall.log" 2>&1
	fi
		
	dialog  --backtitle "Semplice Software Install" --title " Installing Semplice's Software Dependencies " --msgbox "\\n\\nNext, we need to compile the libsixel package, without which Semplice cannot display graphics or album artwork..." 12 70	 	
	PATH="/tmp/gcc-patch:$PATH" yay -Rdd libsixel --noconfirm > "$HOME/Desktop/sixelinstall.log" 2>&1 
	PATH="/tmp/gcc-patch:$PATH" yay -S libsixel-git --noconfirm >> "$HOME/Desktop/sixelinstall.log" 2>&1
		
	sacd_install >/dev/null 2>&1
	echo "sacd installed"
	
    # Confirmation when concluded
    dialog --backtitle "Semplice Software Install" --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Semplice's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
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
      sudo -p $'\r    Now supply the sudo password for user %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f seminst; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo "    Getting the Semplice installer ready. Please bear with us for a few moments..." 
    wget -qO- https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg >/dev/null 2>&1
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
    sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg >/dev/null 2>&1
    sudo apt-get update -qq
    pending=$(apt-get -s upgrade | awk '/^Inst / {count++} END {print count+0}')
    check_updates
 
    sudo apt -y install dialog > /dev/null 2>&1
        
    # Define what's required 
    packages=(bc binutils build-essential cdparanoia cmake coreutils cuetools curl fd-find ffmpeg flac git imagemagick libmp3lame-dev libncurses* libsixel-bin pkg-config python3 python3-dev wezterm x11-utils xclip xterm)
    total=${#packages[@]}
    count=0
    
    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo apt -y install "$pkg" > /dev/null 2>&1 || true
      sleep 0.1
    done
    ) | dialog --title " Installing Semplice's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
    tput cup 24 4
    sacd_install
    audiotools_install
    
    # Confirmation when concluded
    dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Semplice's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
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
      sudo -p $'\r    Now supply the sudo password for user %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f seminst; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo "    Getting the Semplice installer ready. Please bear with us for a few moments..."
    sudo apt-get update -qq
    pending=$(apt-get -s upgrade | awk '/^Inst / {count++} END {print count+0}')
    check_updates

    sudo apt -y install dialog > /dev/null 2>&1

    # Define what's required
    packages=(bc binutils build-essential cdparanoia cmake coreutils cuetools curl dialog fd-find ffmpeg flac git imagemagick libncurses* libsixel-bin pkg-config python3 python3-dev x11-utils xclip xterm)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo apt -y install "$pkg" > /dev/null 2>&1 || true
      sleep 0.1
    done
    ) | dialog --title " Installing Semplice's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
    tput cup 24 4
    sacd_install
    audiotools_install
    
    # Confirmation when concluded
    dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Semplice's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum  FDPROG=fdfind
  ;;  
    
  UBUNTU)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f seminst; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo "    Getting the Semplice installer ready. Please bear with us for a few moments..."
    wget -qO- https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg >/dev/null 2>&1
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list > /dev/null
    sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg >/dev/null 2>&1
    sudo apt-get update -qq
    pending=$(apt-get -s upgrade | awk '/^Inst / {count++} END {print count+0}')
    check_updates
    
    sudo apt -y install dialog > /dev/null 2>&1
        
     # Define what's required 
    packages=(bc binutils build-essential cdparanoia cmake coreutils cuetools curl fd-find ffmpeg flac git imagemagick libmp3lame-dev libncurses6 libsixel-bin pkg-config python3 python3-dev wezterm x11-utils xclip xterm)
    total=${#packages[@]}
    count=0
    
    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo apt -y install "$pkg" > /dev/null 2>&1 || true
      sleep 0.1
    done
    ) | dialog --title " Installing Semplice's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
    tput cup 24 4
    sacd_install
    audiotools_install
    
    # Confirmation when concluded
    dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Semplice's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum  FDPROG=fdfind
  ;; 
  
  FEDORA)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f seminst; exit 1; }
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
    sudo dnf -y install dialog > /dev/null 2>&1
    FUSIONON=$(sudo dnf repolist | grep "RPM Fusion.*Free" | wc -l)
    if [[ $FUSIONON -eq 0 ]]; then
      sudo dnf -y install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm >/dev/null 2>&1
    fi
    sudo dnf -y copr enable lchh/libsixel > /dev/null 2>&1
    
     # Define what's required 
    packages=(bc binutils cdparanoia cmake coreutils cuetools curl fd-find ffmpeg flac gcc git ImageMagick kernel-devel lame-devel libsixel libsixel-utils ncurses pkg-config python python-devel python-setuptools wezterm xclip xdpyinfo xterm)
    total=${#packages[@]}
    count=0
    
    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo dnf -y install "$pkg" --allowerasing > /dev/null 2>&1 || true
      sleep 0.1
    done
    ) | dialog --title " Installing Semplice's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
    tput cup 24 4
    sacd_install
    
	# Compile Audiotools
	cd
	wget https://sourceforge.net/projects/audiotools/files/audiotools-3.1.1.tar.gz/download -O audiotools.tar.gz >/dev/null 2>&1
	tar xf audiotools.tar.gz >/dev/null 2>&1
	cd audiotools-3.1.1
	python3 setup.py build >/dev/null 2>&1
	tput cup 24 4
	sudo python3 setup.py install >/dev/null 2>&1
	cd
	rm -rf audiotools-3.1.1 >/dev/null 2>&1
	
    # Confirmation when concluded
    dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Semplice's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum  FDPROG=fd
  ;;
  
  RHEL)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f seminst; exit 1; }
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
    sudo dnf -y install dialog > /dev/null 2>&1
    FUSIONON=$(sudo dnf repolist | grep epel | wc -l)
    if [[ $FUSIONON -eq 0 ]]; then
      sudo dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm" >/dev/null 2>&1
      sudo dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-next-release-latest-$(rpm -E %rhel).noarch.rpm" >/dev/null 2>&1
      sudo dnf -y install "https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm" >/dev/null 2>&1
      sudo dnf -y install "https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-$(rpm -E %rhel).noarch.rpm" >/dev/null 2>&1
      sudo dnf config-manager --add-repo=https://negativo17.org/repos/epel-multimedia.repo
      sudo dnf -y config-manager --set-enabled crb >/dev/null 2>&1
    fi

    # Define what's required 
    packages=(autoconf automake bc binutils cdparanoia cmake coreutils curl fd-find ffmpeg-free flac fontconfig gawk gcc git grep ImageMagick kernel-devel lame lame-devel lame-devel libsixel libsixel-utils ncurses pkg-config python python-devel wezterm xclip xdotool xdpyinfo xterm)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo dnf -y install "$pkg" --allowerasing > /dev/null 2>&1 || true
      sleep 0.1
    done
    ) | dialog --title " Installing Semplice's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
    tput cup 24 4
    cuetools_install
    sacd_install
    audiotools_install

    # Confirmation when concluded
    dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Semplice's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum FDPROG=fd
  ;;  
  
  MACOS)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; rm -f seminst; exit 1; }
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
      echo " Do you want to use Homebrew (h) or Macports (m) as your package installer?"
      echo " Note that whatever you choose here must have already been installed by you, manually."
      echo " Do not mix package installers: if you've already used one or the other, stick"
      echo " to that one now. If you have a free choice, choose Macports for older machines"
      echo " and for the fact that it's *much* faster to complete!"
      echo ""
      read -n 1 -p " Homebrew or Macports, then? (h/m): " input
      case "$input" in
       [hH])
         if command -v brew >/dev/null 2>&1; then
           pkgmanager=homebrew
           echo ""
           echo " Using the Homebrew Package Manager. Please hold on..."
           echo ""
           brew install --quiet dialog >/dev/null 2>&1
           break
         else
           echo ""
           echo " Unfortunately, it appears that Homebrew has not already been installed on this system."
           echo " Do that first, manually, before trying to re-run this installer."
           echo ""
           exit 1        
         fi  
         ;;
       [mM])
         if command -v port >/dev/null 2>&1; then
           pkgmanager=macports
           echo ""
           echo " Using the Macports Package Manager. Please wait..."
           echo ""
           sudo port -N install dialog > /dev/null 2>&1           
           break
         else
           echo ""
           echo " Unfortunately, it appears that Macports has not already been installed on this system."
           echo " Do that first, manually, before trying to re-run this installer."
           echo ""
           exit 1
         fi   
         ;;
       *)
         clear
         echo ""
         echo " Invalid input: only h or m are allowed. Please try again."
         echo ""
        ;;
      esac
    done

    # Define what's required
    packages=(bc cdparanoia cmake coreutils cuetools curl dialog fd ffmpeg flac gawk git grep gsed icu4c icu ImageMagick libcdio-paranoia md5sha1sum ncurses libsixel wezterm xclip xdpyinfo xterm)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      if [[ $pkgmanager == "homebrew" ]]; then
        brew install --quiet "$pkg" >/dev/null 2>&1
      elif [[ $pkgmanager == "macports" ]]; then
        sudo port -N install "$pkg" > /dev/null 2>&1
      fi
      
      sleep 0.1
    done
    ) | dialog --title " Installing Semplice's Software Dependencies " --gauge "\\n\\nInstallation may take some time. Please be patient..." 12 70
    tput cup 24 4
    
    if [[ $pkgmanager == "homebrew" ]]; then
      ln -s /opt/homebrew/bin/cd-paranoia /opt/homebrew/bin/cdparanoia 2>/dev/null
      ln -s /opt/homebrew/opt/icu4c@78/bin/uconv /opt/homebrew/bin/uconv 2>/dev/null
    fi

    # Confirmation when concluded
    dialog --title " Software Dependencies Installation Completed " --msgbox "\\n\\nAll Semplice's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=gsed  DATEPROG=gdate  MD5PROG=md5sum  FDPROG=fd
  ;;  
  
  *)
  echo "You are using an unsupported operating system. Quitting!"
  exit 1
  ;;
esac

# Check which version of ImageMagick they have: if 'magick' works, it's 7
# -----------------------------------------------------------------------------
if hash magick 2>/dev/null; then
  CONVERTER=magick
else
  CONVERTER=convert
fi

echo "SEDPROG=$SEDPROG
GREPPROG=$GREPPROG
DATEPROG=$DATEPROG
MD5PROG=$MD5PROG
FDPROG=$FDPROG
CONVPROG=$CONVERTER" > "$CONFDIR/txt/programvariables.txt"
