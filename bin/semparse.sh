#!/usr/bin/env bash
####################################################################
#
# semparse: routine for parsing the persistent configuration
# file and deriving sensible values from whatever is supplied there.
#
####################################################################

# --------------------------------------------------------------------------------------------
# Shared tag helpers (semparse.sh is sourced by every script that reads tags)
# --------------------------------------------------------------------------------------------
# flatten_lines: reads text on stdin and returns it as a single line. Each line break becomes
# one space; spaces either side of a join are trimmed so words never abut and never double up;
# blank lines and carriage returns are dropped.
function flatten_lines {
awk '{ sub(/\r$/, ""); sub(/^[ \t]+/, ""); sub(/[ \t]+$/, "")
       if ($0 == "") next
       out = (n++ ? out " " : "") $0 }
     END { printf "%s", out }'
}

# to_nfc: on macOS, converts text read from standard input into 'composed' Unicode (NFC), so
# an accented letter is stored as one character rather than a letter plus a separate accent mark.
# Typed text on macOS can arrive decomposed. Elsewhere, or if uconv is missing, text passes through unchanged.
function to_nfc {
if [[ $(uname) == "Darwin" ]] && command -v uconv >/dev/null 2>&1; then
  uconv -x any-nfc
else
  cat
fi
}

# warn_corrupt: semclean.sh lists every FLAC whose audio MD5 does not match its stored checksum;
# this shows that list, if there is one. Used by K (all menus) and by Quit.
function warn_corrupt {
local LIST="$CONFDIR/tmp/corruptflacs.txt" FILES COUNT
if [[ -s $LIST ]]; then
  COUNT=$(wc -l < "$LIST" | xargs)
  FILES=$(head -n 8 "$LIST")
  if [[ $COUNT -gt 8 ]]; then FILES="$FILES\n...and $((COUNT-8)) more"; fi
  dialog --stdout --backtitle "Semplice Digital Music Manager" --title " Possibly Corrupt Files Detected! " --msgbox "\nThese files have an MD5 checksum mismatch:\n\n$FILES\n\nCheck your backups to resolve!" 18 80
fi
}

# get_tag NAME FILE: prints the value of tag NAME in FILE as a single line. Only the leading
# "NAME=" is removed, so values containing '=' survive intact. Repeated tags and multi-line
# values are joined with single spaces (see flatten_lines). Not for CUESHEET, which must keep
# its line breaks.
function get_tag {
metaflac $UTFCHARS --show-tag="$1" "$2" 2>/dev/null | awk -v pre="$1=" '
  { if (tolower(substr($0, 1, length(pre))) == tolower(pre)) $0 = substr($0, length(pre) + 1); print }' | flatten_lines
}

# lookup_drive_offset DEVICE: prints the read offset listed in cddriveoffsets.csv for the drive at
# DEVICE (as identified by cdparanoia), or nothing if the drive is not listed. Linux only.
function lookup_drive_offset {
local driveid
if ! [[ -f "$CONFDIR/txt/cddriveoffsets.csv" ]]; then
  wget --quiet https://bbritten.com/software/semplice/cddriveoffsets.csv -O "$CONFDIR/txt/cddriveoffsets.csv"
fi
driveid=$(cdparanoia -vsQ -d "$1" 2>&1 | awk -F: '/sensed/ {print $2}' | awk '{print $--NF}')
if [[ -z $driveid ]]; then return; fi
$GREPPROG -Rnw "$CONFDIR/txt/cddriveoffsets.csv" -e "$driveid" | awk -F '|' '{print $2; exit;}'
}

if [[ -f $CONFDIR/txt/semplice.conf ]]; then
  source "$CONFDIR/txt/semplice.conf"                       # Read the configuration file and pick up all its values

  if [[ -z $EDITOR ]]; then
    EDITOR=nano
  elif [[ $(type $EDITOR 2>/dev/null | wc -l) -eq 0 ]]; then    # True only if chosen editor isn't actually present on the system
    EDITOR=nano
  fi;

  if ! [[ -z $READ_RETRIES ]]; then                                                       # Read Retries, if set, must be a positive integer. If not a positive integer, or not set at all, the default is 40.
    if ! [[ $READ_RETRIES =~ ^[0-9]+$ ]] ; then
      READ_RETRIES=40
    elif [[ $READ_RETRIES -lt 1 ]]; then
      READ_RETRIES=40
    fi
  else
    READ_RETRIES=40
  fi

  if [[ $OPTICAL_OFFSET == *"+"* ]]; then OPTICAL_OFFSET="${OPTICAL_OFFSET//+}"; fi    # Positive offsets have the '+' stripped if supplied: it's not syntactically necessary

  if [[ ${RIPMODE,,} == "safe" ]]; then RIPMODE="safe"; else RIPMODE="fast"; fi       # Rip mode is fast (-Z: no checking, much quicker, confirmed by AccurateRip) unless explicitly set to safe (cdparanoia's full checking)

  if ! [[ -z $HYPER_ACCURATERIP ]]; then                                          # Hyper AccurateRip, if set, must be Yes or No, with the default being No and being interpreted as 0 or 1.
    if [[ ${HYPER_ACCURATERIP^^} == "YES" ]] ; then
      HYPER_ACCURATERIP=1
    else
      HYPER_ACCURATERIP=0
    fi
  else
    HYPER_ACCURATERIP=0
  fi

  if ! [[ -z $DELETE_WAV ]]; then                            # Delete_Wav, if set, must be Yes or No, with the default being yes (and being interpreted as 1).
    if [[ ${DELETE_WAV^^} == "NO" ]] ; then
      DELETE_WAV=0
    else
      DELETE_WAV=1
    fi
  else
    DELETE_WAV=1
  fi

  if ! [[ -z $DELETE_ART ]]; then                                                     # Delete_Art, if set, must be Yes or No, with the default being yes (and being interpreted as 1).
    if ! [[ ${DELETE_ART^^} == "YES" ]] ; then
      DELETE_ART=0
    else
      DELETE_ART=1
    fi
  else
    DELETE_ART=1
  fi

  if [[ ${ACCENTS^^} == "NO" ]]; then                                                     # Accents are preserved (yes) by default: only an explicit 'no' allows conversion (as Giocoso)
    UTFCHARS=""
  else
    UTFCHARS="--no-utf8-convert"
  fi

  if ! [[ -z $AUTODELETE_PERTRACK_FLACS ]]; then                          # AutoDelete-pertrack-flacs, if set, must be explicitly set to 'Yes' before autodelete happens. Otherwise, per-track FLACs are left untouched.
    if [[ ${AUTODELETE_PERTRACK_FLACS^^} == "YES" ]]; then
          AUTODELETE=1
        else
          AUTODELETE=0
        fi
  else
    AUTODELETE=0
  fi

  if ! [[ -z $AUDIO_QUALITY ]]; then                                         # Audio Quality must be a numeric value between 1 and 9, with 4 being the default
    if ! [[ $AUDIO_QUALITY =~ ^[0-9]+$ ]] ; then
      AUDIO_QUALITY=4
    elif [[ $AUDIO_QUALITY -lt 1 ]]; then
      AUDIO_QUALITY=4
    elif [[ $AUDIO_QUALITY -gt 9 ]]; then
      AUDIO_QUALITY=4
    fi
  else
    AUDIO_QUALITY=4
  fi

  if ! [[ -z $AUDIOIN_DELETION ]]; then                                           # Audio-in Deletion must be a yes/no setting, but defaults to being off (no)
    if [[ ${AUDIOIN_DELETION^^} == "YES" ]]; then
      AUDIOIN_DELETION=1
    else
      AUDIOIN_DELETION=0
    fi
  else
    AUDIOIN_DELETION=0
  fi

  if ! [[ -z $AUTOBOOST ]]; then                                                  # Autoboost is yes or no, but defaults to being no.
    if [[ ${AUTOBOOST^^} == "YES" ]]; then
      AUTOBOOST=1
    else
      AUTOBOOST=0
    fi
  else
    AUTOBOOST=0
  fi

  if ! [[ -z $DISPLAYONEXTRACT ]]; then                                       # Display on extract is yes or no, but defaults to being yes
    if [[ ${DISPLAYONEXTRACT^^} == "NO" ]]; then
      DISPLAYONEXTRACT=0
    else
      DISPLAYONEXTRACT=1
    fi
  else
    DISPLAYONEXTRACT=1
  fi

  if ! [[ -z $NAMEBITS ]]; then                                                   # Namebits (whether to include bit-depth and sample rate in a file's name) is yes or no, but defaults to being no.
    if [[ ${NAMEBITS^^} == "YES" ]]; then
      NAMEBITS=1
    else
      NAMEBITS=0
    fi
  else
    NAMEBITS=0
  fi

  # Rip folder: the configured RIP_FOLDER, or $HOME/Music if none is configured. It is not created
  # here: semrip.sh checks that it exists and can be written to before any rip starts. It is held in
  # RIPROOT, so that reading the configuration never changes the user's working folder (WORKINGDIR).
  if ! [[ -z $RIP_FOLDER ]]; then
    RIPROOT="$RIP_FOLDER"
  else
    RIPROOT="$HOME/Music"
  fi

  if ! [[ -z $CUSTOMTAGS ]]; then                                                     # CUSTOM_TAGS defaults to no, but can be set to yes.
    if [[ ${CUSTOMTAGS^^} == "YES" ]]; then
      CUSTOMTAGS=1
    else
      CUSTOMTAGS=0
    fi
  else
    CUSTOMTAGS=0
  fi

  if [[ -z ${CUSTOMTAG1} ]]; then CUSTOMTAG1="XqXXqXX"; fi
  if [[ -z ${CUSTOMTAG2} ]]; then CUSTOMTAG2="XqXXqXX"; fi
  if [[ -z ${CUSTOMTAG3} ]]; then CUSTOMTAG3="XqXXqXX"; fi
  if [[ -z ${CUSTOMTAG4} ]]; then CUSTOMTAG4="XqXXqXX"; fi
  if [[ -z ${CUSTOMTAG5} ]]; then CUSTOMTAG5="XqXXqXX"; fi
  if [[ -z ${CUSTOMTAG6} ]]; then CUSTOMTAG6="XqXXqXX"; fi
  if [[ -z ${CUSTOMTAG7} ]]; then CUSTOMTAG7="XqXXqXX"; fi
  if [[ -z ${CUSTOMTAG8} ]]; then CUSTOMTAG8="XqXXqXX"; fi
  if [[ -z ${CUSTOMTAG9} ]]; then CUSTOMTAG9="XqXXqXX"; fi
  
  if ! [[ -z $ARTSIZE ]]; then                    # Artsize: size to display embedded artwork. Defaults to 380, but if not that, needs to be numeric.
    if ! [[ $ARTSIZE =~ ^[0-9]+$ ]] ; then
      ARTSIZE=380
    elif [[ $ARTSIZE -lt 1 ]]; then
      ARTSIZE=380
    fi
  else
    ARTSIZE=380
  fi
  
else
echo "# New Semplice Configuration File, created $(date),
# with all parameters set to their default values.
# ====================================================================

# Colour Constants (alter at your peril!)
# ====================================================================
HOTKEY=11
DRAWLINES=2
MAINTEXT=15        
LOGO=6
INFOTEXT=11        
SPINNER=12
ALERT=1

# Parameters controlling CD Ripping
# ====================================================================
OPTICAL_DEVICE=/dev/cdrom
OPTICAL_OFFSET=
HYPER_ACCURATERIP=no
READ_RETRIES=40
RIPMODE=fast
FLAC_QUALITY=standard
DELETE_WAV=yes
RIP_FOLDER="\$HOME/Music"

# Parameters controlling FLAC tagging
# ====================================================================
DELETE_ART=yes
ACCENTS=yes
NAMEBITS=no
DISPLAYONEXTRACT=yes
EDITOR=nano

# Parameters controlling custom tagging
# ====================================================================
CUSTOM_TAGS=no
CUSTOMTAG1=
CUSTOMTAG2=
CUSTOMTAG3=
CUSTOMTAG4=
CUSTOMTAG5=
CUSTOMTAG6=
CUSTOMTAG7=
CUSTOMTAG8=
CUSTOMTAG9=

# Parameters controlling SuperFLACs
# ====================================================================
AUTODELETE_PERTRACK_FLACS=no

# Parameters controlling Audio Processing/Conversion
# ====================================================================
AUDIO_QUALITY=4
AUDIOIN_DELETION=no
AUTOBOOST=no

# Parameters controlling general program behaviour
# ====================================================================
ARTSIZE=380
LOGOSIZE=110x110
LOGOPOS=0
DIATHEME=\"standard\"
" > "$CONFDIR/txt/semplice.conf"
  chmod 775 "$CONFDIR/txt/semplice.conf"
  parse_config
fi

# Display colours: any colour that is blank, or not a whole number from 0 to 255, gets its default.
# Runs after the configuration file has been read (or written), so blanks in the file are caught too.
for colourpair in HOTKEY:11 DRAWLINES:2 MAINTEXT:15 LOGO:6 INFOTEXT:11 SPINNER:12 ALERT:1; do
  colourname=${colourpair%%:*}; colourvalue=${!colourname}
  if [[ $colourvalue =~ ^[0-9]{1,3}$ ]] && (( 10#$colourvalue <= 255 )); then
    printf -v "$colourname" '%d' "$((10#$colourvalue))"
  else
    printf -v "$colourname" '%s' "${colourpair#*:}"
  fi
done
unset colourpair colourname colourvalue

# Dialog colour theme: must be one of the supplied themes (anything else, including blank, gets 'standard').
# Exported here, so a theme chosen in the configuration editor takes effect as soon as it is saved.
if [[ ${DIATHEME,,} =~ ^(standard|red|green|yellow|magenta)$ ]]; then DIATHEME=${DIATHEME,,}; else DIATHEME=standard; fi
export DIALOGRC="$CONFDIR/txt/$DIATHEME.conf"
