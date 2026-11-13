#!/usr/bin/env bash
####################################################################
#
# semconv: routine for converting audio files between various
# codecs.
#
####################################################################
source "$CONFDIR/bin/semspin.sh"

unset INCODECLIST; unset OUTCODECLIST
INPUTFORMAT=""
OUTPUTFORMAT=""
FLACCOUNT=0 ISOCOUNT=0 APECOUNT=0 ALACCOUNT=0 MP3COUNT=0
OGGCOUNT=0 WMACOUNT=0 WAVCOUNT=0 DSFCOUNT=0 AIFCOUNT=0

if hash nproc 2>/dev/null; then
  THREADS=$(nproc)
else
  THREADS=$(sysctl -n hw.logicalcpu)
fi
if [[ -z $THREADS ]]; then THREADS=2; fi		# A reasonably safe default

function type_count {
if [[ -n $NEWDIR && $NEWDIR != */ ]]; then NEWDIR="$NEWDIR/"; fi         # Make sure the folder path ends in a slash, so the next line looks inside it
for f in "$NEWDIR"*; do
  [ -f "$f" ] || continue
  case $f in
    *.flac) FLACCOUNT=$((FLACCOUNT+1)) ;;
    *.iso)  ISOCOUNT=$((ISOCOUNT+1)) ;;
    *.ape)  APECOUNT=$((APECOUNT+1)) ;;
    *.m4a)  ALACCOUNT=$((ALACCOUNT+1)) ;;
    *.mp3)  MP3COUNT=$((MP3COUNT+1)) ;;
    *.ogg)  OGGCOUNT=$((OGGCOUNT+1)) ;;
    *.wma)  WMACOUNT=$((WMACOUNT+1)) ;;
    *.wav)  WAVCOUNT=$((WAVCOUNT+1)) ;;
    *.dsf)  DSFCOUNT=$((DSFCOUNT+1)) ;;
    *.aif|*.aiff|*.aifc) AIFCOUNT=$((AIFCOUNT+1)) ;;
  esac
done
TOTCOUNT=$((FLACCOUNT+ISOCOUNT+APECOUNT+ALACCOUNT+MP3COUNT+OGGCOUNT+WMACOUNT+WAVCOUNT+DSFCOUNT+AIFCOUNT))

if [[ $TOTCOUNT -eq 0 ]]; then
  dialog --stdout --backtitle "Semplice Audio Conversion" --title " No valid music files detected " --msgbox "\nThe working folder needs to contain files of a type that Semplice can convert or work with: \n\nISO, DSF, AIF, WAV, WMA, OGG, MP3, ALAC, APE or FLAC" 10 80
  INPUTFORMAT="DONE"                                                   # Nothing to convert: end the conversion here
  return
fi

SOURCELIST=()
if [[ $FLACCOUNT -gt 0 ]]; then SOURCELIST+=("FLAC" "FLAC - Lossless" "OFF"); fi
if [[ $APECOUNT -gt 0 ]]; then SOURCELIST+=("APE" "APE - Lossless" "OFF"); fi
if [[ $ALACCOUNT -gt 0 ]]; then SOURCELIST+=("M4A" "ALAC - Lossless" "OFF"); fi
if [[ $AIFCOUNT -gt 0 ]]; then SOURCELIST+=("AIFF" "AIFF - Audio Interchange File Format" "OFF"); fi
if [[ $MP3COUNT -gt 0 ]]; then SOURCELIST+=("MP3" "MP3 - Lossy" "OFF"); fi
if [[ $OGGCOUNT -gt 0 ]]; then SOURCELIST+=("OGG" "OGG - Lossy" "OFF"); fi
if [[ $WMACOUNT -gt 0 ]]; then SOURCELIST+=("WMA" "WMA - Lossless or Lossy, Proprietary" "OFF"); fi
if [[ $WAVCOUNT -gt 0 ]]; then SOURCELIST+=("WAV" "WAV - Lossless" "OFF"); fi
if [[ $ISOCOUNT -gt 0 ]]; then SOURCELIST+=("ISO" "ISO - High resolution lossless" "OFF"); fi
if [[ $DSFCOUNT -gt 0 ]]; then SOURCELIST+=("DSF" "DSF - High resolution lossless" "OFF"); fi
}

function prompt_source {
type_count
if [[ $INPUTFORMAT == "DONE" ]]; then return; fi
SOURCECODEC=$(dialog --no-tags --backtitle "Semplice Audio Conversion" --radiolist "Pick the SOURCE audio format" 10 80 0 "${SOURCELIST[@]}"  3>&1 1>&2 2>&3 3>&- )

exitStatus=$?
if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then        # They've pressed Cancel or ESC
  INPUTFORMAT="DONE"; return
else
  INPUTFORMAT="$SOURCECODEC"
fi

case $INPUTFORMAT in
  FLAC) DISPLAYIN="FLAC";;
  APE)  DISPLAYIN="APE";;
  M4A)  DISPLAYIN="M4A";;
  MP3)  DISPLAYIN="MP3";;
  OGG)  DISPLAYIN="OGG";;
  WMA)  DISPLAYIN="WMA";;
  WAV)  DISPLAYIN="WAV";;
  ISO)  DISPLAYIN="ISO";;
  DSF)  DISPLAYIN="DSF";;
  AIFF) DISPLAYIN="AIFF";;
esac
}

function prompt_output {
options=(--no-tags --backtitle "Semplice Audio Conversion" --radiolist "Pick the OUTPUT audio format" 10 80 0)
if [[ $INPUTFORMAT == "ISO" || $INPUTFORMAT == "ISO" ]]; then
  SINKS=("FLAC" "Standard FLAC (44.1KHz, 16-bit)" "HIRES" "Hi-res FLAC (88.2KHz, 24-bit)" "XHIRES" "Super Hi-res FLAC (176.4KHz, 24-bit)" "AIFF" "AIFF")
  SINKCODEC=$(dialog "${options[@]}" \
  "${SINKS[0]}" "${SINKS[1]}" OFF \
  "${SINKS[2]}" "${SINKS[3]}" OFF \
  "${SINKS[4]}" "${SINKS[5]}" OFF \
  "${SINKS[6]}" "${SINKS[7]}" OFF \
   3>&1 1>&2 2>&3 3>&-)
else
  SINKS=("FLAC" "Standard FLAC (44.1KHz, 16-bit)" "HIRES" "Hi-res FLAC (88.2KHz, 24-bit)" "XHIRES" "Super Hi-res FLAC (176.4KHz, 24-bit)" "AIFF" "AIFF" "MP3" "MP3" "OGG" "OGG" "WMA" "WMA")
  SINKCODEC=$(dialog "${options[@]}" \
  "${SINKS[0]}" "${SINKS[1]}" OFF \
  "${SINKS[2]}" "${SINKS[3]}" OFF \
  "${SINKS[4]}" "${SINKS[5]}" OFF \
  "${SINKS[6]}" "${SINKS[7]}" OFF \
  "${SINKS[8]}" "${SINKS[9]}" OFF \
  "${SINKS[10]}" "${SINKS[11]}" OFF \
  "${SINKS[12]}" "${SINKS[13]}" OFF \
   3>&1 1>&2 2>&3 3>&-)
fi
exitStatus=$?
if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then        # They've pressed Cancel or ESC
  OUTPUTFORMAT="DONE"; return
  return
else
  OUTPUTFORMAT="$SINKCODEC"
fi
}

function convert_music {
IN=${INPUTFORMAT,,}

# If input format is FLAC, preserve existing tags (at least, the ones which
# ffmpeg will go on to mangle if given a chance
# -----------------------------------------------------------------------------
if [[ $INPUTFORMAT == "FLAC" ]]; then
  f=$(find "$(pwd)" -name "*.flac" | sort | head -n 1)						# The first FLAC found will be the source of truth
  COMMENT=$(get_tag Comment "$f")
  DESCRIPTION=$(get_tag Description "$f")
fi

# If comment is null, but DESCRIPTION isn't, then make the COMMENT=DESCRIPTION
if [[ -z $COMMENT && -n $DESCRIPTION ]]; then
  COMMENT="$DESCRIPTION"
fi

# If input AND output are standard FLAC, we'll need to spot the difference between
# source and output files, so prepare to add '-16' to the filename. And
# retrieve existing tag data for re-use in output files
# -----------------------------------------------------------------------------
if [[ $INPUTFORMAT == "FLAC" && $OUTPUTFORMAT == "FLAC" ]]; then
  BITS="-16"
else
  BITS=""
fi

# Handling different formats' output quality settings
# -----------------------------------------------------------------------------
case $OUTPUTFORMAT in
    FLAC)
    BITDEPTH="-sample_fmt s16 -ar 44100"
    BITS="-16"
    XHIRES=0
    HIRES=0
	OUT="flac"
	DISPLAYOUT="Standard CD-Audio resolution FLACs"
	PRESERVETAG=()
    ;;
    MP3)
    BITDEPTH="-qscale:a $AUDIO_QUALITY"             # 0 is better than 8
    BITS=""
    XHIRES=0
    HIRES=0
	OUT="mp3"
	DISPLAYOUT="Quality $AUDIO_QUALITY MP3s"
	NOCORRUPTCHECK=1
	PRESERVETAG=()
    ;;
    OGG)
    BITDEPTH="-vn -c:a libvorbis -q:a $AUDIO_QUALITY"   # 8 is better than 0. -vn: Ogg files take no cover art, so leave it out
    BITS=""
    XHIRES=0
    HIRES=0
	OUT="ogg"
	DISPLAYOUT="Quality $AUDIO_QUALITY Oggs"
	NOCORRUPTCHECK=1
	PRESERVETAG=()
    ;;
    WMA)
    QUALNO=$((50+(20 * "$AUDIO_QUALITY")))          # 8 is better than 0
    BITS=""
    BITDEPTH="-vn -ar 44100 -acodec wmav2 -ab $QUALNO"   # -vn: WMA files take no cover art. -ar 44100: WMA can't hold more than 48kHz, so high-res sources must be brought down
    BITDEPTH+="k"
    XHIRES=0
    HIRES=0
	OUT="wma"
	DISPLAYOUT="Quality $AUDIO_QUALITY WMAs"
	NOCORRUPTCHECK=1
	PRESERVETAG=()
    ;;
    HIRES)
    BITDEPTH="-sample_fmt s32 -ar 88200"
    BITS="-24"
    OUT="flac"
    HIRES=1
    XHIRES=0
	DISPLAYOUT="High Resolution FLACs"
	NOCORRUPTCHECK=1
	PRESERVETAG=()
    ;;
    XHIRES)
    BITDEPTH="-sample_fmt s32 -ar 176400"
    BITS="-24"
    OUT="flac"
    XHIRES=1
    HIRES=0
	DISPLAYOUT="Extremely High Resolution FLACs"
	NOCORRUPTCHECK=1
	PRESERVETAG=()
    ;;
    WAV)
    OUT="wav"
	DISPLAYOUT="WAV Format"
	NOCORRUPTCHECK=1
	PRESERVETAG=()
    ;;
    AIFF)
    OUT="aif"
    DISPLAYOUT="AIFF Format"
    NOCORRUPTCHECK=1
    PRESERVETAG=()
    PRESERVETAG+=("-write_id3v2" "1" "-c:v" "copy")
    ;;
esac

if [[ $INPUTFORMAT == "ISO" ]]; then
  # SACDEXTRACT is sacd_extract-<macos|linux>-<arm64|x86_64>, set by semoscheck.sh
  if [[ ! -x $SACDEXTRACT ]]; then
    dialog --stdout --backtitle "Semplice Audio Conversion" --msgbox "\nSemplice's SACD program for this computer could not be found, so SACD ISOs cannot be converted." 8 80
    return
  fi
  MESSAGE="Splitting the ISO. Please wait…  "
  shopt -s nullglob; PREDSF=(*.dsf); shopt -u nullglob   # Note any DSFs already here, so only the ones extracted below count as intermediate files
  for f in *.iso; do
    # Extract the ISO to DSFs, move them all into the source folder and delete the "Stereo" subfolder sacd_extract originally writes them to
    "$SACDEXTRACT" -2 -s -i "$f" >/dev/null & spinner $! && find . -name "*.dsf" -exec mv {} . \; && find . -type d -empty -delete
  done
  MESSAGE="Converting the output files to $DISPLAYOUT. Please wait…  "
  if [[ $XHIRES -eq 1 ]]; then
    LOWPASS=87000
  elif [[ $HIRES -eq 1 ]]; then
    LOWPASS=43000
  else
    LOWPASS=21000
  fi
  "$FDPROG" -j "$THREADS" -d 1 -t f -e "dsf" -x "$FFMPEG" -hide_banner -loglevel 0 -i "{}" -af "lowpass=$LOWPASS" $BITDEPTH -y "{.}$BITS.$OUT" & spinner $!
fi

if [[ $INPUTFORMAT == "DSF" ]]; then                # Only major difference to any other conversion is addition of a low-pass filter to stop quantisation effects appearing in the output
  if [[ $XHIRES -eq 1 ]]; then
    LOWPASS=87000
  elif [[ $HIRES -eq 1 ]]; then
    LOWPASS=43000
  else
    LOWPASS=21000
  fi
  MESSAGE="Converting DSF files to $DISPLAYOUT. Please wait…  "
  "$FDPROG" -j "$THREADS" -d 1 -t f -e "$IN" -x "$FFMPEG" -hide_banner -loglevel 0 -i "{}" -af "lowpass=$LOWPASS" $BITDEPTH -y "{.}$BITS.$OUT" & spinner $!
elif [[ $INPUTFORMAT != "ISO" ]]; then           # ISOs were dealt with above
  MESSAGE="Converting $DISPLAYIN files to $DISPLAYOUT. Please wait…  "
  if [[ ! $IN == "aiff" ]]; then    # AIFFs come with multiple possible extensions, so they need a separate '-e' extension clause
    "$FDPROG" -j "$THREADS" -d 1 -t f -e "$IN" -x "$FFMPEG" -hide_banner -loglevel 0 -i "{}" "${PRESERVETAG[@]}" $BITDEPTH -y "{.}$BITS.$OUT" & spinner $!
  else
    "$FDPROG" -j "$THREADS" -d 1 -t f -e aiff -e aif -e aifc -x "$FFMPEG" -hide_banner -loglevel 0 -i "{}" "${PRESERVETAG[@]}" $BITDEPTH -y "{.}$BITS.$OUT" & spinner $!
  fi
fi

# The DSFs extracted from an ISO are intermediate files, and intermediate files are always deleted
if [[ $INPUTFORMAT == "ISO" ]]; then
  for f in *.dsf; do
    [[ -f $f && " ${PREDSF[*]} " != *" $f "* ]] && rm -f "$f"
  done
fi

if [[ $AUDIOIN_DELETION == "1" ]]; then
  if [[ $INPUTFORMAT == "ISO" ]]; then			# The ISO is a source file only if "Treat SACD ISOs as source files" is also yes
    if [[ $ISO_AS_SOURCE == "1" ]]; then rm -f *.iso; fi
  elif [[ $INPUTFORMAT == "WMA" || $INPUTFORMAT == "OGG" || $INPUTFORMAT == "MP3" ]]; then
    "$FDPROG" -j "$THREADS" -d 1 -t f -e "$IN" -x rm -rf {} \;
  elif [[ $INPUTFORMAT == "AIFF" ]]; then
    "$FDPROG" -j "$THREADS" -d 1 -t f -e aif -e aiff -e aifc -x rm -rf {} \;
  elif [[ $BITS != "-16" && $BITS != "-24" ]]; then
    "$FDPROG" -j "$THREADS" -d 1 -t f -e "$IN" -x rm -rf {} \;             # if asked, delete the input files
  elif [[ $BITS = "-24" ]]; then
    "$FDPROG" -j "$THREADS" -d 1 -t f -e "$IN" -E "*-24.*" -x rm -rf {} \; # flacs that were converted to 24-bit flacs, only delete the non-24-bit ones.
  elif [[ $BITS = "-16" ]]; then
    "$FDPROG" -j "$THREADS" -d 1 -t f -e "$IN" -E "*-16.*" -x rm -rf {} \; # flacs that were converted to 16-bit flacs, only delete the non-16-bit ones.
  fi
fi

# Make sure we put comments back, for all FLAC outputs (standard, hi-res and super hi-res). The first source
# FLAC's COMMENT represents the whole album. If there was none, ffmpeg's DESCRIPTION is left for cleaning to carry over.
if [[ $OUT == "flac" ]]; then
  if [[ -n $COMMENT ]]; then
    for f in *$BITS*.flac; do
      metaflac $UTFCHARS --remove-tag=COMMENT --remove-tag=DESCRIPTION "$f" 2>/dev/null
      metaflac $UTFCHARS "--set-tag=COMMENT=$COMMENT" "$f" 2>/dev/null
    done
  fi
  source "$CONFDIR/bin/semclean.sh"
  ALREADYCLEAN=1
fi

# Finally, rename files so that the bit-depth is not proliferated over multiple conversions
for f in *; do
    [[ $f =~ ^(.*)-16(-16)+(\.[^.]+)$ ]] || continue
    mv -- "$f" "${BASH_REMATCH[1]}-16${BASH_REMATCH[3]}"
done
}

while [[ -z $INPUTFORMAT ]]; do prompt_source; done
if ! [[ $INPUTFORMAT == "DONE" ]]; then
  while [[ -z $OUTPUTFORMAT ]]; do prompt_output; done
  if ! [[ $OUTPUTFORMAT == "DONE" ]]; then
    convert_music
  fi
fi
