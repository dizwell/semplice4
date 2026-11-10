#!/usr/bin/env bash
####################################################################
#
# Installation Program for Semplice Version 4. In broad terms:
#
#  1. Get user consent to adjust system
#  2. Download the Dialog colour schemes
#  3. Use semoscheck to install Semplice's software dependencies
#  4. Install new Semplice 4 files
#  5. Verify installation
#  6. Install new fonts
#
####################################################################
PROGVERSION="4.00" COPYRIGHT="2021-2026"
PRIORVERSION=0; clear; USERNAME=$(whoami); ERRORCOUNT=0  YPOS=6

if [[ $1 == "beta" ]]; then 
  REMOTESOURCE="https://bbritten.com/software/semplicebeta"
else
  REMOTESOURCE="https://bbritten.com/software/semplice"
fi

NEWCONF="$HOME/.local/share/semplice4"
CONFDIR="$NEWCONF"

HOTKEY=11
DRAWLINES=2
MAINTEXT=15
LOGO=6
INFOTEXT=11
SPINNER=12
ALERT=1

function exit_program {
rm -f seminst >/dev/null 2>&1
reset
exit 1
}

trap exit_program TERM      # Trap to quit nicely if the terminal is closed by clicking 'X' icon in window titlebar
trap exit_program SIGHUP    # Same thing, different signal
trap exit_program INT       # Trap to prevent Ctrl+C from working

tput() {
	local VERSION='bash tput (1.0.0)'

	local opt OPTIND OPTARG
	while getopts 'ST:V' opt; do
		case "$opt" in
			S) command tput "$@"; return $?;;
			T) true;;
			V) echo "$VERSION"; return 0;;
		esac
	done
	shift "$((OPTIND - 1))"

	local ESC=$'\x1b'
	case "$1" in
		bel) echo -n $'\x7';;
		sgr0 | me) echo -n "$ESC[0m";;
		bold) echo -n "$ESC[1m";;
		dim) echo -n "$ESC[2m";;
		rev) echo -n "$ESC[7m";;
		blink) echo -n "$ESC[5m";;
		setaf | AF) echo -n "$ESC[38;5;$2m";;
		setab | AB) echo -n "$ESC[48;5;$2m";;
		sc) echo -n "${ESC}7";;
		rc) echo -n "${ESC}8";;
		cnorm) echo -n "$ESC[?25h";;
		civis) echo -n "$ESC[?25l";;
		smcup) echo -n "$ESC[?1049h";;
		rmcup) echo -n "$ESC[?1049l";;
		clear) echo -n "$ESC[H$ESC[2J";;
		home) echo -n "$ESC[H";;
		cuu) echo -n "$ESC[$2A";;
		cud) echo -n "$ESC[$2B";;
		cuf) echo -n "$ESC[$2C";;
		cub) echo -n "$ESC[$2D";;
		cup)
			local row=$(($2 + 1))
			local col=$(($3 + 1))
			echo -n "$ESC[$row;${col}H";;
		*) command tput "$@"; return $?;;
	esac
}

# Attempt to resize the terminal to 29 rows and 105 columns.
tput civis; printf '\e[8;29;105t'

function print_header {
tput setaf $DRAWLINES; echo -e "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                   │
│                                                                                                   │
│                                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘"
tput cup  1 4; tput setaf $LOGO; echo "♬♪ Semplice: The Digital Music Manager ♬♪"
tput cup  2 4; tput setaf $LOGO; echo "Copyright © Howard Rogers $COPYRIGHT"
tput cup  3 4; tput setaf $LOGO; echo "Version $PROGVERSION"
}

function downloads {
# Fetch Semplice components: BIN files first
components=(semart.sh sembits.sh semcaom.sh semcaos.sh semclean.sh semcolour.sh semconf.sh semconv.sh semcuee.sh semcus.sh semdevpick.sh semdir.sh semmaxv.sh semmeta.sh semparse.sh semquit.sh semrenum.sh semrip.sh semsacd.sh semspec.sh semspin.sh semtags.sh semtput.sh semtrks.sh semxart.sh semoscheck.sh semmenudraw.sh semmenuoptions.sh)
total=${#components[@]}
count=0

(
for f in "${components[@]}"; do
  downloaded=0
  for attempt in {1..5}; do
    if wget -q --tries=1 "$REMOTESOURCE/bin/$f" -O "$NEWCONF/bin/$f" && [[ $(head -c2 "$NEWCONF/bin/$f") == '#!' ]]; then
      downloaded=1
      break
    fi
    rm -f "$NEWCONF/bin/$f"
    sleep 1
  done
  if [[ $downloaded -eq 0 ]]; then exit 1; fi
  count=$((count + 1 ))
  percent=$((count * 100 / total))
  echo $percent
  sleep 0.1
done
) | dialog --title " Installing Semplice Binary Components " --gauge "\\n\\nDownloading Semplice's own software components: this might take some time..." 12 70

download_status=${PIPESTATUS[0]}
if [[ $download_status -ne 0 ]]; then
  dialog --title " Download Failed " --msgbox "A Semplice component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
  exit 1
fi

# Self-compiled static executables next: these live in exec, not bin
components=(sacd_extract-linux-x86_64 sacd_extract-linux-armv7l sacd_extract-macos-x86_64 sacd_extract-macos-arm64 semarv-linux-x86_64 semarv-linux-arm64 semarv-macos-x86_64 semarv-macos-arm64)
total=${#components[@]}
count=0
(
for f in "${components[@]}"; do
  downloaded=0
  for attempt in {1..5}; do
    if wget -q --tries=1 "$REMOTESOURCE/exec/$f" -O "$NEWCONF/exec/$f"; then
      downloaded=1
      break
    fi
    rm -f "$NEWCONF/exec/$f"
    sleep 1
  done
  if [[ $downloaded -eq 0 ]]; then exit 1; fi
  count=$((count + 1 ))
  percent=$((count * 100 / total))
  echo $percent
  sleep 0.1
done
) | dialog --title " Installing Semplice Executables " --gauge "\\n\\nDownloading the external programs Semplice depends on: not long to wait now..." 12 70

download_status=${PIPESTATUS[0]}
if [[ $download_status -ne 0 ]]; then
  dialog --title " Download Failed " --msgbox "A Semplice component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
  exit 1
fi

chmod +x "$NEWCONF/exec/"*

# Art files next
components=(Luxi_License.txt luximr.ttf sempliceico.png sempliceicobeta.png sempliceico.svg sempliceicosmall.png sempliceicosmallbeta.png)
total=${#components[@]}
count=0
(
for f in "${components[@]}"; do
  downloaded=0
  for attempt in {1..5}; do
    if wget -q --tries=1 "$REMOTESOURCE/art/$f" -O "$NEWCONF/art/$f"; then
      downloaded=1
      break
    fi
    rm -f "$NEWCONF/art/$f"
    sleep 1
  done
  if [[ $downloaded -eq 0 ]]; then exit 1; fi
  count=$((count + 1 ))
  percent=$((count * 100 / total))
  echo $percent
  sleep 0.1
done
) | dialog --title " Installing Semplice Art Components " --gauge "\\n\\nNow downloading some other Semplice bits and pieces: not long to wait now..." 12 70

download_status=${PIPESTATUS[0]}
if [[ $download_status -ne 0 ]]; then
  dialog --title " Download Failed " --msgbox "A Semplice component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
  exit 1
fi

# Finally, /usr/bin and miscellaneous stuff
if [[ $OS == "DARWIN" ]]; then
  sudo rm -f "/usr/local/bin/semplice4.sh"
  downloaded=0
  for attempt in {1..5}; do
    if sudo wget -q --tries=1 "$REMOTESOURCE/semplice4.sh" -O "/usr/local/bin/semplice4.sh" && [[ $(head -c2 "/usr/local/bin/semplice4.sh") == '#!' ]]; then
      downloaded=1
      break
    fi
    sleep 1
  done
  if [[ $downloaded -eq 0 ]]; then
    dialog --title " Download Failed " --msgbox "A Semplice component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
    sudo rm -f "/usr/local/bin/semplice4.sh"
    exit 1
  fi
  sudo chmod +x /usr/local/bin/semplice4.sh
  sudo rm -f /usr/local/bin/semplice 2>/dev/null; sudo ln -s /usr/local/bin/semplice4.sh /usr/local/bin/semplice 2>/dev/null 
else
  sudo rm -f "/usr/bin/semplice4.sh"
  downloaded=0
  for attempt in {1..5}; do
    if sudo wget -q --tries=1 "$REMOTESOURCE/semplice4.sh" -O "/usr/bin/semplice4.sh" && [[ $(head -c2 "/usr/bin/semplice4.sh") == '#!' ]]; then
      downloaded=1
      break
    fi
    sleep 1
  done
  if [[ $downloaded -eq 0 ]]; then
    dialog --title " Download Failed " --msgbox "A Semplice component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
    sudo rm -f "/usr/bin/semplice4.sh"
    exit 1
  fi
  sudo chmod +x /usr/bin/semplice4.sh
  sudo rm -f /usr/bin/semplice 2>/dev/null; sudo ln -s /usr/bin/semplice4.sh /usr/bin/semplice 2>/dev/null
fi

# Only create a desktop launcher if this is NOT macOS.
# -----------------------------------------------------
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$NAME
    THISVER=$VERSION
else
  OS=$(uname -s)
  THISVER=$(uname -r)
fi
OS=${OS^^}

if [[ ! $OS == *"DARWIN"* ]]; then
  if [[ ! -d "$HOME/.local/share/applications" ]]; then mkdir -p "$HOME/.local/share/applications/"; fi
  wget -q "$REMOTESOURCE/semplice.desktop" -O "$HOME/.local/share/applications/semplice.desktop"
  sed -i "s|xxxxxxxx|$USERNAME|" "$HOME/.local/share/applications/semplice.desktop"
  chmod +x "$HOME/.local/share/applications/semplice.desktop"
  ln -s "$HOME/.local/share/applications/semplice.desktop" "$HOME/Desktop" 2>/dev/null
fi

# Confirmation when concluded
dialog --title " Software Components Completed " --msgbox "\\n\\nAll Semplice's components have now been installed successfully.\\n\\nPress OK to see an installation summary report." 12 70
}

function backup_install {
# Nothing to back up on a first-ever install, so skip creating an empty backup folder
if [[ ! -d "$NEWCONF" ]] && ! compgen -G "/usr/bin/semplice*.sh" >/dev/null && ! compgen -G "/usr/local/bin/semplice*.sh" >/dev/null; then return; fi
tput clear; print_header
tput cup 6 4; tput setaf $MAINTEXT; echo -n "Backing up prior version's program."
BACKUPDIR="$HOME/.local/share/semplice-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUPDIR"
cp -r "$NEWCONF" "$BACKUPDIR" 2>/dev/null; BACKUPSUCCESS=$?
cp /usr/bin/semplice*.sh "$BACKUPDIR" 2>/dev/null
cp /usr/local/bin/semplice*.sh "$BACKUPDIR" 2>/dev/null

# Now prune old backups
if [[ $BACKUPSUCCESS -eq 0 ]]; then
    local count=0
    for dir in "$HOME"/.local/share/semplice-backup-*; do
        [[ -d "$dir" ]] && echo "$dir"
    done | sort -r | while IFS= read -r dir; do
        ((count+=1))
        ((count > 5)) && rm -rf "$dir"
    done
fi
}

# ====================================================================================
# Installation Code Starts Here
# ====================================================================================

# 1. Warning
# -----------------------------------------------------
tput clear; print_header
tput cup 6 4; tput setaf $INFOTEXT; echo -e "Welcome to the Semplice Installer."
tput cup 8 4; tput setaf $INFOTEXT; echo -e "• It will install numerous new software packages necessary for Semplice to function correctly. It will also create a bunch of new folders within your \$HOME folder.\n\n• Any existing Semplice installation will be backed up, just in case it's needed.\n\n• If you are happy to proceed, tap 'y' when prompted; tapping anything else will cancel the installation without it having touched your system at all." | fold -s -w 76 | sed '2,$s/^/    /'
tput cup 19 4; tput setaf $ALERT; read -s -n 1 -p "Do you wish to proceed? (y/n): " response

if [[ "$response" == [Yy]* ]]; then
  clear; print_header; tput setaf $MAINTEXT; tput cup 6 0
  tput cup 6 4; echo -e "Checking your network connection is working..."
  if ! ping -c1 -W1 "1.1.1.1" >/dev/null 2>&1; then
    tput clear; print_header
    tput cup 6 4; tput setaf $ALERT; echo -e "Sadly, you do not appear to be able to reach the Internet.\n\nThis is a requirement for the Semplice installation." | fold -s -w 76 | sed '2,$s/^/    /'
    tput cup 10 4; tput setaf $MAINTEXT; read -n 1 -p "Quitting in the meantime. Press a key to exit."
    tput reset; tput sgr0
    exit_program
  fi

  # 2. Backup if appropriate
  # -----------------------------------------------------
  backup_install

  # 3. Make new version directory structure if needed
  # -----------------------------------------------------
  if [[ ! -d "$NEWCONF" ]]; then mkdir -p "$NEWCONF"; fi
  if [[ ! -d "$NEWCONF/art" ]]; then mkdir -p "$NEWCONF/art"; fi
  if [[ ! -d "$NEWCONF/bin" ]]; then mkdir -p "$NEWCONF/bin"; fi
  if [[ ! -d "$NEWCONF/exec" ]]; then mkdir -p "$NEWCONF/exec"; fi
  if [[ ! -d "$NEWCONF/txt" ]]; then mkdir -p "$NEWCONF/txt"; fi
  if [[ ! -d "$NEWCONF/tmp" ]]; then mkdir -p "$NEWCONF/tmp"; fi
  if [[ ! -d "$NEWCONF/rip" ]]; then mkdir -p "$NEWCONF/rip"; fi
  
  # 4. Call semoscheck.sh and get packages installed
  # -----------------------------------------------------
  YPOS=$((YPOS+1)); tput cup $YPOS 1;
  wget -q "$REMOTESOURCE/bin/semoscheck.sh" -O "$NEWCONF/bin/semoscheck.sh"
  source "$NEWCONF/bin/semoscheck.sh" install        # Triggers a check of software dependencies and *fixes* them
  downloads
  chown -R $USERNAME:$USERNAME "$NEWCONF" 2>/dev/null
  
  # 5. Download the various Dialog configuration files
  # -----------------------------------------------------
  wget -q "$REMOTESOURCE/txt/standard.conf" -O "$NEWCONF/txt/standard.conf"
  wget -q "$REMOTESOURCE/txt/red.conf" -O "$NEWCONF/txt/red.conf"
  wget -q "$REMOTESOURCE/txt/green.conf" -O "$NEWCONF/txt/green.conf"
  wget -q "$REMOTESOURCE/txt/yellow.conf" -O "$NEWCONF/txt/yellow.conf"
  wget -q "$REMOTESOURCE/txt/magenta.conf" -O "$NEWCONF/txt/magenta.conf"

  # 6. Try to install the program fonts (but it may not work on all distros, and ultimately it's up to them)
  # -----------------------------------------------------
  if [[ ! -d "$HOME/.local/share/fonts" ]]; then 
    mkdir "$HOME/.local/share/fonts" 2>/dev/null
    cp "$HOME/.local/share/semplice4/art/"*.ttf "$HOME/.local/share/fonts/" 2>/dev/null
    fc-cache -f 2>/dev/null
    clear
  fi
  
  # 7. If possible, configure WezTerm terminals to display appropriately
  # -----------------------------------------------------
  if ! [[ -f "$HOME/.semplice.lua" ]]; then
cat << 'EOF' > "$HOME/.semplice.lua"
local wezterm = require 'wezterm'
local config = wezterm.config_builder()
config.initial_cols = 103
config.initial_rows = 28
config.color_scheme = 'Galaxy'
config.font = wezterm.font("Luxi Mono", {weight="Regular", stretch="Normal", style="Normal"})
config.font_size = 12
config.audible_bell = "Disabled"
config.window_close_confirmation = "NeverPrompt"
config.mouse_bindings = {
  -- Right-click over highlighted text: Copies and instantly clears the highlight
  {
    event = { Down = { streak = 1, button = "Right" } },
    mods = "NONE",
    action = wezterm.action.Multiple {
      wezterm.action.CopyTo("ClipboardAndPrimarySelection"),
      wezterm.action.ClearSelection,
	},
  },

-- Shift + Right-click: Triggers your paste action
  {
    event = { Down = { streak = 1, button = "Right" } },
    mods = "SHIFT",
    action = wezterm.action.PasteFrom("Clipboard"),
  },
}
config.window_decorations = "TITLE | RESIZE"
config.freetype_load_target = "Light"
config.enable_wayland = false
config.enable_tab_bar = false
config.line_height = 1.1
return config
EOF
  fi
    
  # 8. Assess state of installation and advise accordingly
  # -----------------------------------------------------
  COUNTBIN=$(ls "$CONFDIR"/bin/*.sh 2>/dev/null | wc -l)
  COUNTEXC=$(( $(ls /usr/local/bin/semplice4.sh 2>/dev/null | wc -l) + $(ls /usr/bin/semplice4.sh 2>/dev/null | wc -l) ))
  if [[ $COUNTBIN -eq 28 ]]; then COUNTBINOK=1; else COUNTBINOK=0; fi
  if [[ $COUNTEXC -eq 1 ]]; then COUNTXECOK=1; else COUNTXECOK=0; fi
  if [[ $COUNTBINOK -eq 1 && $COUNTXECOK -eq 1 ]]; then BASICINSTALLOK=1; else BASICINSTALLOK=0; fi
  
  if command -v cueprint >/dev/null 2>&1; then CUEPRINTOK=1; else CUEPRINTOK=0; fi
  if command -v sacd >/dev/null 2>&1; then SACDOK=1; else SACDOK=0; fi
  if command -v trackverify >/dev/null 2>&1; then TRKVEROK=1; else TRKVEROK=0; fi
  
  DIALOGTEXT="\nThe Semplice installation has now completed. Its current status is as follows:"
  
  if [[ $BASICINSTALLOK -eq 1 ]]; then 
    DIALOGTEXT=$DIALOGTEXT"\n\n  ✓ Your basic Semplice installation is fine"
    if [[ $CUEPRINTOK -eq 1 ]]; then 
      DIALOGTEXT=$DIALOGTEXT"\n  ✓ Semplice can split SuperFLACs OK"
    else
      DIALOGTEXT=$DIALOGTEXT"\n  ✘ Semplice cannot split SuperFLACs at all"
    fi
  
    if [[ $SACDOK -eq 1 ]]; then 
      DIALOGTEXT=$DIALOGTEXT"\n  ✓ Semplice can convert SACD ISOs OK"
    else
      DIALOGTEXT=$DIALOGTEXT"\n  ✘ Semplice cannot handle SACD ISOs at all"
    fi    
  
    if [[ $TRKVEROK -eq 1 ]]; then 
      DIALOGTEXT=$DIALOGTEXT"\n  ✓ Semplice can verify CD rips for accuracy"
    else
      DIALOGTEXT=$DIALOGTEXT"\n  ✘ Semplice cannot verify CD rips for accuracy"
    fi
  
    if [[ $CUEPRINTOK -eq 0 || $SACDOK -eq 0 || $TRKVEROK -eq 0 ]]; then
      DIALOGTEXT=$DIALOGTEXT"\n\nSee the Semplice documentation for how to potentially resolve these issues manually. You can otherwise close this terminal now."
    else 
      DIALOGTEXT=$DIALOGTEXT"\n\nSemplice has full functionality: click OK to return the command line."
    fi
  else
    DIALOGTEXT=$DIALOGTEXT"\n\n  ✘ Your basic Semplice installation appears to be wrong."
   DIALOGTEXT=$DIALOGTEXT"\n\nSince even the basic installation seems faulty, you're advised to check your network connection and try re-installing Semplice afresh."
  fi
  
  dialog --stdout --backtitle "Semplice Software Install" --title " Software installation status " --msgbox "\n$DIALOGTEXT" 17 80 
    
  # 9. Finish Up
  # -----------------------------------------------------
  reset
  rm -f seminst
  exit 0
else      # They said not to proceed
  clear
  echo ""
  echo "Semplice installation aborted. You can close this terminal now."
  exit_program
fi

# Failsafe cleanup
# -----------------------------------------------------
reset
rm -f seminst
exit 0