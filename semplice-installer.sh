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
PROGVERSION="4.00" COPYRIGHT="2019-2026"
PRIORVERSION=0; clear; USERNAME=$(whoami); ERRORCOUNT=0  YPOS=6

# Determine if the user has invoked the installer with a specific release flavour (-v beta)
# or distro (-d name) in mind, exactly as Giocoso's installer does
SEMRELEASE=""    SEMDISTRO=""
while getopts "v:d:" opt; do
	case "$opt" in
	  v)  SEMRELEASE="$OPTARG";;
	  d)  SEMDISTRO="$OPTARG";;
	esac
done

# Everything is fetched from GitHub: the beta branch (work in progress) or main (releases)
# -v must be beta or stable; if it's left out, choose_release asks which (after "Do you wish to proceed?")
case "$SEMRELEASE" in
  beta|stable|"") ;;
  *) echo "Unknown release '$SEMRELEASE': use -v beta or -v stable."; exit 1 ;;
esac

function choose_release {
if [[ -z $SEMRELEASE ]]; then
  clear; print_header
  tput cup 6 4; tput setaf $INFOTEXT; echo "You have a choice of whether to install the stable or beta release of Semplice. Beta releases contain all the latest fixes and new features but have not been thoroughly tested on every supported platform and might break, badly. Stable releases have been tested to work correctly on all supported platforms." | fold -s -w 76 | sed '2,$s/^/    /'
  echo ""
  while true; do
    tput setaf $ALERT; read -s -n 1 -p "    Choose now whether to install the stable or beta release (s/b): " input
    case "$input" in
      [sS]) SEMRELEASE="stable"; break ;;
      [bB]) SEMRELEASE="beta"; break ;;
      *) echo ""; echo ""; tput setaf $MAINTEXT; echo "    Invalid input: only s or b are allowed. Please try again."; echo "" ;;
    esac
  done
fi

# Everything is fetched from GitHub: the beta branch (work in progress) or main (releases)
if [[ $SEMRELEASE == "beta" ]]; then
  REMOTESOURCE="https://raw.githubusercontent.com/dizwell/semplice4/beta"
else
  REMOTESOURCE="https://raw.githubusercontent.com/dizwell/semplice4/main"
fi
}

# The installer deletes itself when it finishes or is cancelled, whatever it was saved as (sem4inst, gio4inst...),
# unless it's the copy inside a program's own repository folder
INSTALLERFILE="$0"
if git -C "$(dirname "$INSTALLERFILE")" rev-parse --is-inside-work-tree >/dev/null 2>&1; then INSTALLERFILE=""; fi

NEWCONF="$HOME/.local/share/semplice4"
CONFDIR="$NEWCONF"

HOTKEY=11
DRAWLINES=2
MAINTEXT=11
LOGO=6
INFOTEXT=11
SPINNER=12
ALERT=1

function exit_program {
rm -f "$INSTALLERFILE" >/dev/null 2>&1
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
tput cup  2 4; tput setaf $LOGO; echo "Copyright © H. Rogers $COPYRIGHT"
tput cup  3 4; tput setaf $LOGO; echo "Version $PROGVERSION"
# Once known (from -v, or from the stable/beta prompt), the release being installed shows flush right
if [[ -n $SEMRELEASE ]]; then
  RELTEXT="INSTALLING $(tr "[:lower:]" "[:upper:]" <<< "$SEMRELEASE") RELEASE"
  tput cup  3 $(( 97 - ${#RELTEXT} )); tput setaf $LOGO; echo "$RELTEXT"
fi
}

function downloads {
# Fetch Semplice components: BIN files first
components=(semart.sh semcaom.sh semcaos.sh semclean.sh semcolour.sh semconf.sh semconv.sh semcuee.sh semcus.sh semdevpick.sh semdir.sh semfunctions.sh semmaxv.sh semmeta.sh semparse.sh semquit.sh semrenum.sh semrip.sh semsacd.sh semspec.sh semspin.sh semtags.sh semtput.sh semtrks.sh semxart.sh semoscheck.sh semmenudraw.sh semmenuoptions.sh)
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
components=(sacd_extract-linux-x86_64 sacd_extract-linux-arm64 sacd_extract-macos-x86_64 sacd_extract-macos-arm64 img2sixel-linux-x86_64 img2sixel-linux-arm64 img2sixel-macos-x86_64 img2sixel-macos-arm64 magick-linux-x86_64 magick-linux-arm64 magick-macos-x86_64 magick-macos-arm64 ffmpeg-linux-x86_64 ffmpeg-linux-arm64 ffmpeg-macos-x86_64 ffmpeg-macos-arm64 ffprobe-linux-x86_64 ffprobe-linux-arm64 ffprobe-macos-x86_64 ffprobe-macos-arm64 semarv-linux-x86_64 semarv-linux-arm64 semarv-macos-x86_64 semarv-macos-arm64)
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
components=(Luxi_License.txt luximr.ttf sempliceico.png sempliceicobeta.png sempliceico.svg)
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
  rm -f "$NEWCONF/semplice4.sh"
  downloaded=0
  for attempt in {1..5}; do
    if wget -q --tries=1 "$REMOTESOURCE/semplice4.sh" -O "$NEWCONF/semplice4.sh" && [[ $(head -c2 "$NEWCONF/semplice4.sh") == '#!' ]]; then
      downloaded=1
      break
    fi
    sleep 1
  done
  if [[ $downloaded -eq 0 ]]; then
    dialog --title " Download Failed " --msgbox "A Semplice component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
    rm -f "$NEWCONF/semplice4.sh"
    exit 1
  fi
  chmod +x "$NEWCONF/semplice4.sh"
else
  rm -f "$NEWCONF/semplice4.sh"
  downloaded=0
  for attempt in {1..5}; do
    if wget -q --tries=1 "$REMOTESOURCE/semplice4.sh" -O "$NEWCONF/semplice4.sh" && [[ $(head -c2 "$NEWCONF/semplice4.sh") == '#!' ]]; then
      downloaded=1
      break
    fi
    sleep 1
  done
  if [[ $downloaded -eq 0 ]]; then
    dialog --title " Download Failed " --msgbox "A Semplice component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
    rm -f "$NEWCONF/semplice4.sh"
    exit 1
  fi
  chmod +x "$NEWCONF/semplice4.sh"
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

# And now an app for MacOS, as for Giocoso: it opens Semplice in WezTerm with Semplice's own settings
else
  APPNAME="Semplice"
  APPPATH="/Applications/$APPNAME.app"
  ICONPNG="$HOME/.local/share/semplice4/art/sempliceico.png"
  ICONSET="/tmp/semplice.iconset"
  ICONFILE="/tmp/semplice.icns"

  rm -rf "$APPPATH" >/dev/null 2>&1
  mkdir -p "$APPPATH/Contents/MacOS" "$APPPATH/Contents/Resources" >/dev/null 2>&1

  cat > "$APPPATH/Contents/MacOS/$APPNAME" <<EOF
#!/bin/bash
# Use the first bash and WezTerm found: Homebrew (Apple Silicon or Intel), MacPorts, then WezTerm's own app
for bashPath in /opt/homebrew/bin/bash /usr/local/bin/bash /opt/local/bin/bash; do
  [[ -x "\$bashPath" ]] && break
done
for weztermPath in /opt/homebrew/bin/wezterm /usr/local/bin/wezterm /opt/local/bin/wezterm /Applications/WezTerm.app/Contents/MacOS/wezterm; do
  [[ -x "\$weztermPath" ]] && break
done

exec "\$weztermPath" --config-file "\$HOME/.semplice.lua" start -- "\$bashPath" -l -c 'ulimit -u 4000; exec "\$BASH" /usr/local/bin/semplice4.sh'
EOF

  chmod +x "$APPPATH/Contents/MacOS/$APPNAME"

  cat > "$APPPATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>CFBundleExecutable</key>
<string>$APPNAME</string>
<key>CFBundleIdentifier</key>
<string>com.bbritten.semplice4</string>
<key>CFBundleName</key>
<string>$APPNAME</string>
<key>CFBundleDisplayName</key>
<string>$APPNAME</string>
<key>CFBundlePackageType</key>
<string>APPL</string>
<key>CFBundleIconFile</key>
<string>semplice.icns</string>
<key>LSArchitecturePriority</key>
<array>
  <string>arm64</string>
  <string>x86_64</string>
</array>
</dict>
</plist>
EOF

  rm -rf "$ICONSET" >/dev/null 2>&1
  mkdir -p "$ICONSET" >/dev/null 2>&1
  for size in 16 32 128 256 512; do
    sips -z $size $size "$ICONPNG" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null 2>&1
    sips -z $((size*2)) $((size*2)) "$ICONPNG" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null 2>&1
  done
  iconutil -c icns "$ICONSET" -o "$ICONFILE" >/dev/null 2>&1
  cp "$ICONFILE" "$APPPATH/Contents/Resources/semplice.icns" >/dev/null 2>&1

  rm -rf "$ICONSET" >/dev/null 2>&1
  rm -f "$ICONFILE" >/dev/null 2>&1
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APPPATH" >/dev/null 2>&1
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
echo ""; tput setaf $ALERT; read -s -n 1 -p "    Do you wish to proceed? (y/n): " response   # One line below the text, however long it is

if [[ "$response" == [Yy]* ]]; then
  choose_release
  clear; print_header; tput setaf $MAINTEXT; tput cup 6 0
  tput cup 6 4; echo -e "Checking your network connection is working..."
  if ! ping -c1 -W1 "1.1.1.1" >/dev/null 2>&1; then
    tput clear; print_header
    tput cup 6 4; tput setaf $ALERT; echo -e "Sadly, you do not appear to be able to reach the Internet.\n\nThis is a requirement for the Semplice installation." | fold -s -w 76 | sed '2,$s/^/    /'
    tput cup 10 4; tput setaf $ALERT; read -n 1 -p "Quitting in the meantime. Press a key to exit."
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

  # 3a. Ask for the sudo password once, now, and make the command links straight away. They point at the
  # main script in the program folder, which arrives later; nothing after this needs the password again.
  # -----------------------------------------------------
  echo ""
  tput setaf $ALERT
  sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; exit_program; }
  tput setaf $MAINTEXT
  if [[ $(uname -s) == "Darwin" ]]; then BINDIR="/usr/local/bin"; else BINDIR="/usr/bin"; fi
  sudo mkdir -p "$BINDIR"
  sudo rm -f "$BINDIR/semplice4.sh" "$BINDIR/semplice" 2>/dev/null
  sudo ln -s "$NEWCONF/semplice4.sh" "$BINDIR/semplice4.sh"
  sudo ln -s "$NEWCONF/semplice4.sh" "$BINDIR/semplice"

  
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
  # WezTerm's Semplice settings use the Luxi Mono font, so it must be installed where the system looks for fonts
  if [[ $(uname -s) == "Darwin" ]]; then
    mkdir -p "$HOME/Library/Fonts" 2>/dev/null
    cp "$HOME/.local/share/semplice4/art/"*.ttf "$HOME/Library/Fonts/" 2>/dev/null
  else
    mkdir -p "$HOME/.local/share/fonts" 2>/dev/null
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
--config.front_end = "WebGpu"
local schemes = wezterm.get_builtin_color_schemes()
if not schemes[config.color_scheme] then
  config.color_scheme = "Galaxy"
end
return config
EOF
  fi
    
  # 8. Assess state of installation and advise accordingly
  # -----------------------------------------------------
  COUNTBIN=$(ls "$CONFDIR"/bin/*.sh 2>/dev/null | wc -l)
  COUNTEXC=$(( $(ls /usr/local/bin/semplice4.sh 2>/dev/null | wc -l) + $(ls /usr/bin/semplice4.sh 2>/dev/null | wc -l) ))
  if [[ $COUNTBIN -eq 27 ]]; then COUNTBINOK=1; else COUNTBINOK=0; fi
  if [[ $COUNTEXC -eq 1 ]]; then COUNTXECOK=1; else COUNTXECOK=0; fi
  if [[ $COUNTBINOK -eq 1 && $COUNTXECOK -eq 1 ]]; then BASICINSTALLOK=1; else BASICINSTALLOK=0; fi
  
  if command -v cueprint >/dev/null 2>&1; then CUEPRINTOK=1; else CUEPRINTOK=0; fi
  case "$(uname -s)" in Darwin) ARVPLAT="macos" ;; Linux) ARVPLAT="linux" ;; *) ARVPLAT="unknown" ;; esac
  case "$(uname -m)" in arm64|aarch64) ARVARCH="arm64" ;; x86_64) ARVARCH="x86_64" ;; *) ARVARCH="unknown" ;; esac
  if [[ -x "$NEWCONF/exec/semarv-$ARVPLAT-$ARVARCH" ]]; then TRKVEROK=1; else TRKVEROK=0; fi   # Semplice's own AccurateRip checker for this computer
  if [[ -x "$NEWCONF/exec/sacd_extract-$ARVPLAT-$ARVARCH" ]]; then SACDOK=1; else SACDOK=0; fi   # SACD ripping and ISO conversion for this computer
  if [[ -x "$NEWCONF/exec/img2sixel-$ARVPLAT-$ARVARCH" ]]; then SIXELOK=1; else SIXELOK=0; fi    # Album art and logo display for this computer
  
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
  
    if [[ $SIXELOK -eq 1 ]]; then 
      DIALOGTEXT=$DIALOGTEXT"\n  ✓ Semplice can display album art OK"
    else
      DIALOGTEXT=$DIALOGTEXT"\n  ✘ Semplice cannot display album art at all"
    fi

    if [[ $TRKVEROK -eq 1 ]]; then 
      DIALOGTEXT=$DIALOGTEXT"\n  ✓ Semplice can verify CD rips for accuracy"
    else
      DIALOGTEXT=$DIALOGTEXT"\n  ✘ Semplice cannot verify CD rips for accuracy"
    fi
  
    if [[ $CUEPRINTOK -eq 0 || $SACDOK -eq 0 || $SIXELOK -eq 0 || $TRKVEROK -eq 0 ]]; then
      DIALOGTEXT=$DIALOGTEXT"\n\nSee the Semplice documentation for how to potentially resolve these issues manually. You can otherwise close this terminal now."
    else 
      DIALOGTEXT=$DIALOGTEXT"\n\nSemplice has full functionality: click OK to return the command line."
    fi
  else
    DIALOGTEXT=$DIALOGTEXT"\n\n  ✘ Your basic Semplice installation appears to be wrong."
   DIALOGTEXT=$DIALOGTEXT"\n\nSince even the basic installation seems faulty, you're advised to check your network connection and try re-installing Semplice afresh."
  fi
  
  dialog --stdout --backtitle "Semplice Software Install" --title " Software installation status " --msgbox "\n$DIALOGTEXT" 18 80 
    
  # 9. Finish Up
  # -----------------------------------------------------
  reset
  rm -f "$INSTALLERFILE"
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
rm -f "$INSTALLERFILE"
exit 0