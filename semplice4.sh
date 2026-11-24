#!/usr/bin/env bash
# Semplice is a FLAC and digital music manager, supporting the entire life-cycle
# of digitial music files, from first creation via ripping from physical media, to
# tagging, volume-boosting and merging into single-file, multi-track SuperFLACs.
#
# Full documentation available at:
# https://absolutelybaching.com/semplice-version-2-the-user-manual/
#
# Copyright © H. Rogers 2019-2026
# Version 4.00 - release date not yet set (??)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 2.0 only of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# A copy of the GNU General Public License can be displayed by running the program
# and selecting the Miscellaneous menu, Option 2.
#
# The `tput` wrapper used throughout Semplice is taken from https://github.com/bahamas10/bash-tput
# with grateful thanks to Dave Eddy and much appreciation: it speeds things up immensely!
#
# Version History
# ---------------
# 1.00  Initial Release                                                27.11.22 + 2 point releases
# 2.00  Major re-write & re-design                                     30.06.24
# 2.01  Enhancement to work with ImageMagick 6 or 7                    15.07.24
# 2.02  Enhancement to deal with CMYK images rather than sRGB ones     07.08.24
# 2.03  Enhancement to clean tags on superFLACs and to display the
#       volume boost amount when auto-boosting in status line          14.08.24
# 2.04  Bugfix: added -a switch to grep in track tagging               17.08.24
# 2.05  Bugfix: when converting, tag cleaning incorrectly invoked      14.09.24
# 2.06  Enhancement: 'I' key to inspect audio characteristics
#       Enhancement: Option to clear all track data
#       Enhancement: Genre guessing, depending on Composition Name
#       Enhancement: Genre guessing allowd when metadata present       25.10.24
# 2.07  Bug-fix: magick used incorrect variable name when embedding
#       album art, resulting in failure.                               01.11.24
# 2.08  Bug fix: Changing folders now checks for all music formats
#       Enhancement: Support for converting to/from AIFF               05.03.25
# 2.09  Assorted changes to improve/clarify workflow                   02.04.25
# 2.10  Minor bug-fixes and enhancements                               20.04.25
# 2.11  Switch from odio-sacd to sacd for handling SACD ISOs           04.07.25
# 2.12  Code modifications to support running on macOS                 31.01.26
# 2.13  Multiple bug-fixes and macOS accommodations                    30.03.26
# 2.14  Multiple bug-fixes. Better checks for software compilation
#       success. Support for WezTerm themes. Deprecation of Nobara &
#       Gecko. Added support for Void Linux                            30.06.26(??)
# ==============================================================================================================
echo -ne "\033]0;Semplice: The Digital Music Manager\007"
CONFDIR="$HOME/.local/share/semplice4"  OLDIFS=$IFS

# Folder and file pickers: dialog versions from late 2019 to May 2021 (RHEL 9's, for one) squash them, so give those
# a taller box; later versions grow the box themselves, and a taller one there covers the screen's title and messages
DIALOGDATE=$(dialog --version 2>/dev/null | grep -o '[0-9]\{8\}' | head -1)
if [[ -n $DIALOGDATE && $DIALOGDATE -lt 20210601 ]]; then PICKHEIGHT=18; else PICKHEIGHT=12; fi
# If the folder Semplice was started from no longer exists (moved or deleted since the Terminal was in it), start in the home folder instead
if [[ ! -d $PWD ]]; then cd "$HOME" 2>/dev/null || exit 1; fi
PROGFILE="${BASH_SOURCE[0]}"                      # This script's own path (a symlink such as /usr/local/bin/semplice is fine)
if ! sed -n '10p' "$PROGFILE" | grep -q '?'; then PROGVERSION="4.00"; else PROGVERSION="4.00-beta"; fi
mkdir -p "$CONFDIR" "$CONFDIR/txt" "$CONFDIR/bin" "$CONFDIR/tmp" "$CONFDIR/art" "$CONFDIR/rip" 2>/dev/null	   # Create a folder structure, if it doesn't already exist (and suppress errors if it does!)

trap ctrl_c INT      # Ctrl+C
trap exit_program TERM      # Told to terminate (a logout or shutdown, say): tidy up as Giocoso does
trap exit_program SIGHUP    # The window was closed: tidy up just the same

function check_new_version {
# Administration's "Check for a newer version": the installer records which GitHub commit (and its date and branch) it
# installed from in txt/installedversion.txt; this asks GitHub for the latest commit on that same branch and compares
local VERFILE="$CONFDIR/txt/installedversion.txt" INSTBRANCH="" INSTCOMMIT="" INSTDATE="" KIND LATEST LCOMMIT LDATE MSG
local MONTHS=(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
if [[ -f $VERFILE ]]; then source "$VERFILE"; fi
if [[ -z $INSTCOMMIT || -z $INSTBRANCH ]]; then
  MSG="This installation doesn't record which version it is, so Semplice can't tell. Reinstall Semplice once, and this check will work from then on."
else
  if [[ $INSTBRANCH == "beta" ]]; then KIND="beta"; else KIND="stable"; fi
  LATEST=$(wget -qO- --tries=1 --timeout=15 "https://api.github.com/repos/dizwell/semplice4/commits/$INSTBRANCH" 2>/dev/null)
  LCOMMIT=$(echo "$LATEST" | grep -m1 '"sha"' | sed 's/.*"sha": *"\([0-9a-f]*\)".*/\1/')
  LDATE=$(echo "$LATEST" | grep -m1 '"date"' | sed 's/.*"date": *"\([^"]*\)".*/\1/')
  if [[ ! $LCOMMIT =~ ^[0-9a-f]{40}$ ]]; then
    MSG="Semplice couldn't reach GitHub to check. Please check your network connection and try again."
  else
    # ISO dates (2026-11-24T09:41:00Z) shown as 24 Nov 2026, without needing GNU or BSD date
    INSTDATE="$((10#${INSTDATE:8:2})) ${MONTHS[$((10#${INSTDATE:5:2}-1))]} ${INSTDATE:0:4}"
    LDATE="$((10#${LDATE:8:2})) ${MONTHS[$((10#${LDATE:5:2}-1))]} ${LDATE:0:4}"
    if [[ $LCOMMIT == "$INSTCOMMIT" ]]; then
      MSG="You have the latest $KIND version of Semplice ($INSTDATE)."
    else
      MSG="A newer $KIND version of Semplice is available ($LDATE); yours is from $INSTDATE. Reinstall Semplice to get it."
    fi
  fi
fi
dialog --backtitle "Semplice Version Check" --title " Check for a Newer Version " --msgbox "\\n$MSG\\n\\nClick OK to return to the menu." 11 80
}

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

function parse_config {
source "$CONFDIR/bin/semparse.sh"
}

function exit_program {
pkill -f "cdparanoia" >/dev/null 2>&1
rm -rf "$CONFDIR/art/albumart.jpg" 2>/dev/null
if [[ -t 1 ]]; then tput cvvis; tput sgr0; clear; fi      # Only when there's still a screen (not after the window was closed)
exit 0
}

function ctrl_c() {
  exit_program
}

function smenuoptions {
tput civis
source "$CONFDIR/bin/semmenudraw.sh"
source "$CONFDIR/bin/semmenuoptions.sh"
}

function menu_display {
clear; smenuoptions tag; clear
}

# ===========================================================================================================
# The actual program control code
# ===========================================================================================================
clear

source "$CONFDIR/bin/semtput.sh"                      # Bash-internal tput: part of every installation
source "$CONFDIR/bin/semfunctions.sh"                 # Shared helper functions, used throughout (as Giocoso's giofunctions.sh)

tput civis; printf '\e[8;28;103t'			# Setting terminal virtual size to 103x28, regardless of what it's actually set to
source "$CONFDIR/bin/semoscheck.sh"
source "$CONFDIR/txt/programvariables.txt"

parse_config

WORKINGDIR="$(pwd)"; SHORTNAME=$(basename "$WORKINGDIR")
DISPLAYDIR="…"${SHORTNAME:0:60}
if [[ $(uname -a) == *"Darwin"* ]]; then 
  echo -ne "\033]0;Semplice Working Folder: $DISPLAYDIR\007"
else
  echo -en "\033]0;Semplice Working Folder: $DISPLAYDIR\007\c"						# Setting terminal's titlebar
fi
  
smenuoptions tag
exit_program
