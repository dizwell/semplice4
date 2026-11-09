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

# get_tag NAME FILE: prints the value of tag NAME in FILE as a single line. Only the leading
# "NAME=" is removed, so values containing '=' survive intact. Repeated tags and multi-line
# values are joined with single spaces (see flatten_lines). Not for CUESHEET, which must keep
# its line breaks.
function get_tag {
metaflac $UTFCHARS --show-tag="$1" "$2" 2>/dev/null | awk -v pre="$1=" '
  { if (tolower(substr($0, 1, length(pre))) == tolower(pre)) $0 = substr($0, length(pre) + 1); print }' | flatten_lines
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

  if ! [[ -z $ACCENTS ]]; then                                                            # Accents, if set, must be explicitly set to 'Yes' before utfchars is set, otherwise utfchars is left unset.
    if [[ ${ACCENTS^^} == "YES" ]]; then
          UTFCHARS="--no-utf8-convert"
        else
          UTFCHARS=""
        fi
  else
    UTFCHARS=""
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
LOGO=10
INFOTEXT=11        
SPINNER=9
ALERT=1

# Parameters controlling CD Ripping
# ====================================================================
OPTICAL_DEVICE=/dev/cdrom
OPTICAL_OFFSET=
HYPER_ACCURATERIP=no
READ_RETRIES=40
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
" > "$CONFDIR/txt/semplice.conf"
  chmod 775 "$CONFDIR/txt/semplice.conf"
  parse_config
fi
