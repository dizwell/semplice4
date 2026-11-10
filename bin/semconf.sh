#!/usr/bin/env bash
####################################################################
#
# A function to construct a configuration file, based on replies
# to prompts.
#
# Prompts get suggested values which (a) can be determined by
# examining the system; or (b) are sensible defaults; or (c)
# are values read-in from the existing configuration file
#
####################################################################
if ! [[ -d "$CONFDIR/tmp" ]]; then mkdir -p "$CONFDIR/tmp" 2>/dev/null; fi
CONFFILE="$CONFDIR/txt/semplice.conf"

# Read parameters from an existing config file, if present
# ====================================================================
if [[ -f "$CONFFILE" ]]; then
  confdrive=$(cat "$CONFFILE" | $GREPPROG -i OPTICAL_DEVICE= | awk -F= '{print $2}'); if [[ -z $confdrive ]]; then confdrive='/dev/cdrom'; fi
  confoffset=$(cat "$CONFFILE" | $GREPPROG -i OPTICAL_OFFSET= | awk -F= '{print $2}') # Confoffset is allowed to be null. Indeed, it's preferable for it to be so, triggering automatic offset detection.
  confhyper=$(cat "$CONFFILE" | $GREPPROG -i HYPER_ACCURATERIP= | awk -F= '{print $2}'); if [[ -z $confhyper ]]; then confhyper='no'; fi
  confretries=$(cat "$CONFFILE" | $GREPPROG -i READ_RETRIES= | awk -F= '{print $2}'); if [[ -z $confretries ]]; then confretries=40; fi
  confflac=$(cat "$CONFFILE" | $GREPPROG -i FLAC_QUALITY= | awk -F= '{print $2}'); if [[ -z $confflac ]]; then confflac='standard'; fi
  confdelete=$(cat "$CONFFILE" | $GREPPROG -i DELETE_WAV= | awk -F= '{print $2}'); if [[ -z $confdelete ]]; then confdelete='yes'; fi
  confart=$(cat "$CONFFILE" | $GREPPROG -i DELETE_ART= | awk -F= '{print $2}'); if [[ -z $confart ]]; then confart='yes'; fi
  confaccents=$(cat "$CONFFILE" | $GREPPROG -i ACCENTS= | awk -F= '{print $2}'); if [[ -z $confaccents ]]; then confaccents='no'; fi
  confbits=$(cat "$CONFFILE" | $GREPPROG -i NAMEBITS= | awk -F= '{print $2}'); if [[ -z $confbits ]]; then confbits='no'; fi
  confdisplay=$(cat "$CONFFILE" | $GREPPROG -i DISPLAYONEXTRACT= | awk -F= '{print $2}'); if [[ -z $confdisplay ]]; then confdisplay='yes'; fi
  confeditor=$(cat "$CONFFILE" | $GREPPROG -i EDITOR= | awk -F= '{print $2}'); if [[ -z $confeditor ]]; then confeditor='nano'; fi
  confcustom=$(cat "$CONFFILE" | $GREPPROG -i CUSTOMTAGS= | awk -F= '{print $2}'); if [[ -z $confcustom ]]; then confcustom='no'; fi
  confcustom1=$(cat "$CONFFILE" | $GREPPROG -i CUSTOMTAG1= | awk -F= '{print $2}')
  confcustom2=$(cat "$CONFFILE" | $GREPPROG -i CUSTOMTAG2= | awk -F= '{print $2}')
  confcustom3=$(cat "$CONFFILE" | $GREPPROG -i CUSTOMTAG3= | awk -F= '{print $2}')
  confcustom4=$(cat "$CONFFILE" | $GREPPROG -i CUSTOMTAG4= | awk -F= '{print $2}')
  confcustom5=$(cat "$CONFFILE" | $GREPPROG -i CUSTOMTAG5= | awk -F= '{print $2}')
  confcustom6=$(cat "$CONFFILE" | $GREPPROG -i CUSTOMTAG6= | awk -F= '{print $2}')
  confcustom7=$(cat "$CONFFILE" | $GREPPROG -i CUSTOMTAG7= | awk -F= '{print $2}')
  confcustom8=$(cat "$CONFFILE" | $GREPPROG -i CUSTOMTAG8= | awk -F= '{print $2}')
  confcustom9=$(cat "$CONFFILE" | $GREPPROG -i CUSTOMTAG9= | awk -F= '{print $2}')
  confautodel=$(cat "$CONFFILE" | $GREPPROG -i AUTODELETE_PERTRACK_FLACS= | awk -F= '{print $2}'); if [[ -z $confautodel ]]; then confautodel='no'; fi
  confqual=$(cat "$CONFFILE" | $GREPPROG -i AUDIO_QUALITY= | awk -F= '{print $2}'); if [[ -z $confqual ]]; then confqual='4'; fi
  confaudiodel=$(cat "$CONFFILE" | $GREPPROG -i AUDIOIN_DELETION= | awk -F= '{print $2}'); if [[ -z $confaudiodel ]]; then confaudiodel='no'; fi
  confboost=$(cat "$CONFFILE" | $GREPPROG -i AUTOBOOST= | awk -F= '{print $2}'); if [[ -z $confboost ]]; then confboost='no'; fi
  confwkdir=$(cat "$CONFFILE" | $GREPPROG -i RIP_FOLDER= | awk -F= '{print $2}'); if [[ -z $confwkdir ]]; then confwkdir='$HOME/Music'; fi
  confmetavol=$(cat "$CONFFILE" | $GREPPROG -i METAVOL= | awk -F= '{print $2}'); if [[ -z $confmetavol ]]; then confmetavol='real'; fi
  confartsize=$(cat "$CONFFILE" | $GREPPROG -i ARTSIZE= | awk -F= '{print $2}'); if [[ -z $confartsize ]]; then confartsize=380; fi
  conflogosize=$(cat "$CONFFILE" | $GREPPROG -i LOGOSIZE= | awk -F= '{print $2}'); if [[ -z $conflogosize ]]; then conflogosize=110; elif [[ $conflogosize == *"x"* ]]; then conflogosize=$(echo "$conflogosize" | awk -Fx '{print $1}'); fi
  conflogopos=$(cat "$CONFFILE" | $GREPPROG -i LOGOPOS= | awk -F= '{print $2}'); if [ -z $conflogopos ]; then conflogopos=0; fi
  confweztheme=$(cat "$CONFFILE" | $GREPPROG -i WEZTHEME= | awk -F= '{print $2}' | tr -d '"'); if [[ -z $confweztheme ]]; then confweztheme="Galaxy"; fi
  confwezfntsz=$(cat "$CONFFILE" | $GREPPROG -i WEZFNTSZ= | awk -F= '{print $2}'); if [[ -z $confwezfntsz ]]; then confwezfntsz=12; fi
  confdiatheme=$(cat "$CONFFILE" | $GREPPROG -i DIATHEME= | awk -F= '{print $2}' | tr -d '"'); if [[ -z $confdiatheme ]]; then confdiatheme="standard"; fi
fi

# First, prompt for CD Ripping parameters
# ====================================================================
dialog --backtitle "Semplice Configuration File Editor" --title " Program Configuration " --form "Parameters concerning CD Ripping:" 17 90 10 "Default optical drive " 1 1  "$confdrive"     1 50 35 0 "Default read offset " 2 1  "$confoffset" 2 50 35 0 "Use Hyper-AccurateRip " 3 1  "$confhyper"     3 50 6 0 "Number of re-reads on errors " 4 1  "$confretries"    4 50 35 0  "Default FLAC audio resolution " 5 1  "$confflac"     5 50 35 0 "Delete intermediate files after converting " 6 1  "$confdelete"  6 50 6 0  "Rip CDs to folder " 7 1  "$confwkdir"     7 50 35 0 2>"$CONFDIR/tmp/ripparams"

readarray -t ripparams < "$CONFDIR/tmp/ripparams" 2>/dev/null

CONFDRIVE="${ripparams[0]}"; if [[ -z $CONFDRIVE ]]; then CONFDRIVE="/dev/cdrom"; fi
CONFOFFSET="${ripparams[1]}"
CONFHYPER="${ripparams[2]}"; if [[ -z $CONFHYPER ]]; then CONFHYPER="no"; fi
CONFRETRIES="${ripparams[3]}"; if [[ -z $CONFRETRIES ]]; then CONFRETRIES=40; fi
CONFFLAC="${ripparams[4]}"; if [[ -z $CONFFLAC ]]; then CONFFLAC="standard"; fi
CONFDELETE="${ripparams[5]}"; if [[ -z $CONFDELETE ]]; then CONFDELETE="yes"; fi
CONFWKDIR="${ripparams[6]}"; if [[ -z $CONFWKDIR ]]; then CONFWKDIR='$HOME/Music'; fi

# Check for legal values and replace with defaults if not legal
# ====================================================================

if ! [[ $CONFOFFSET =~ ^[+-]?[0-9]+$ ]]; then CONFOFFSET=0; fi
if ! [[ $CONFRETRIES =~ ^[+-]?[0-9]+$ ]] ; then CONFRETRIES=40; fi
if [[ ${CONFHYPER,,} == "yes" || ${CONFHYPER,,} == "no" ]]; then CONFHYPER=${CONFHYPER,,}; else CONFHYPER="no"; fi
if [[ ${CONFDELETE,,} == "yes" || ${CONFDELETE,,} == "no" ]]; then CONFDELETE=${CONFDELETE,,}; else CONFDELETE="yes"; fi

if [[ ${CONFFLAC,,} == "standard" || ${CONFFLAC,,} == "high" || ${CONFFLAC,,} == "extreme" ]]; then
  CONFFLAC=${CONFFLAC,,}
else
  CONFFLAC="standard"
fi

# Next, prompt for FLAC tagging parameters
# ====================================================================
dialog --backtitle "Semplice Configuration File Editor" --title " Program Configuration " --form "Parameters affecting FLAC tagging:" 17 90 10 "Delete album art after embedding" 1 1  "$confart" 1 65 6 0 "Prevent conversion of accented to non-accented characters" 2 1  "$confaccents"  2 65 6 0 "Force filenames to display bitdepth/sample rate" 3 1  "$confbits"     3 65 6 0 "Display album art when extracting" 4 1  "$confdisplay"     4 65 6 0 "Default text editor" 5 1  "$confeditor"  5 65 19 0  "Use Custom Tags" 6 1  "$confcustom"  6 65 6 0   2>"$CONFDIR/tmp/tagparams"

readarray -t tagparams < "$CONFDIR/tmp/tagparams" 2>/dev/null
CONFART="${tagparams[0]}";     if [[ -z $CONFART ]]; then CONFART="yes"; fi
CONFACCENTS="${tagparams[1]}"; if [[ -z $CONFACCENTS ]]; then CONFACCENTS="no"; fi
CONFBITS="${tagparams[2]}";    if [[ -z $CONFBITS ]]; then CONFBITS="no"; fi
CONFDISPLAY="${tagparams[3]}"; if [[ -z $CONFDISPLAY ]]; then CONFDISPLAY="yes"; fi
CONFEDITOR="${tagparams[4]}";  if [[ -z $CONFEDITOR ]]; then CONFEDITOR="nano"; fi
CONFCUSTOM="${tagparams[5]}";  if [[ -z $CONFCUSTOM ]]; then CONFCUSTOM="no"; fi

# Check for legal values and replace with defaults if not legal
# ====================================================================
if [[ ${CONFART,,} == "yes" || ${CONFART,,} == "no" ]]; then CONFART=${CONFART,,}; else CONFART="yes"; fi
if [[ ${CONFACCENTS,,} == "yes" || ${CONFACCENTS,,} == "no" ]]; then CONFACCENTS=${CONFACCENTS,,}; else CONFACCENTS="no"; fi
if [[ ${CONFBITS,,} == "yes" || ${CONFBITS,,} == "no" ]]; then CONFBITS=${CONFBITS,,}; else CONFBITS="no"; fi
if [[ ${CONFDISPLAY,,} == "yes" || ${CONFDISPLAY,,} == "no" ]]; then CONFDISPLAY=${CONFDISPLAY,,}; else CONFDISPLAY="yes"; fi
if [[ ${CONFCUSTOM,,} == "yes" || ${CONFCUSTOM,,} == "no" ]]; then CONFCUSTOM=${CONFCUSTOM,,}; else CONFCUSTOM="no"; fi
if ! type "$CONFEDITOR" >/dev/null 2>&1; then CONFEDITOR="nano"; fi

# If CUSTOMTAGS has been set to yes, then prompt for 9 custom tags:
# ====================================================================
if [[ $CONFCUSTOM == "yes" ]]; then
  dialog --backtitle "Semplice Configuration File Editor" --title " Program Configuration " --form "Custom Tag Names:" 17 80 10 \
  "Custom Tag 1 : " 1 1  "$confcustom1" 1 17 17 0 \
  "Custom Tag 2 : " 2 1  "$confcustom2" 2 17 17 0 \
  "Custom Tag 3 : " 3 1  "$confcustom3" 3 17 17 0 \
  "Custom Tag 4 : " 4 1  "$confcustom4" 4 17 17 0 \
  "Custom Tag 5 : " 5 1  "$confcustom5" 5 17 17 0 \
  "Custom Tag 6 : " 6 1  "$confcustom6" 6 17 17 0 \
  "Custom Tag 7 : " 7 1  "$confcustom7" 7 17 17 0 \
  "Custom Tag 8 : " 8 1  "$confcustom8" 8 17 17 0 \
  "Custom Tag 9 : " 9 1  "$confcustom9" 9 17 17 0 2>"$CONFDIR/tmp/customtagparams"
  readarray -t customparams < "$CONFDIR/tmp/customtagparams" 2>/dev/null
  CONFCUSTOM1="${customparams[0]}"; CONFCUSTOM1="${CONFCUSTOM1// /_}"; CONFCUSTOM1="${CONFCUSTOM1^^}"
  CONFCUSTOM2="${customparams[1]}"; CONFCUSTOM2="${CONFCUSTOM2// /_}"; CONFCUSTOM2="${CONFCUSTOM2^^}"
  CONFCUSTOM3="${customparams[2]}"; CONFCUSTOM3="${CONFCUSTOM3// /_}"; CONFCUSTOM3="${CONFCUSTOM3^^}"
  CONFCUSTOM4="${customparams[3]}"; CONFCUSTOM4="${CONFCUSTOM4// /_}"; CONFCUSTOM4="${CONFCUSTOM4^^}"
  CONFCUSTOM5="${customparams[4]}"; CONFCUSTOM5="${CONFCUSTOM5// /_}"; CONFCUSTOM5="${CONFCUSTOM5^^}"
  CONFCUSTOM6="${customparams[5]}"; CONFCUSTOM6="${CONFCUSTOM6// /_}"; CONFCUSTOM6="${CONFCUSTOM6^^}"
  CONFCUSTOM7="${customparams[6]}"; CONFCUSTOM7="${CONFCUSTOM7// /_}"; CONFCUSTOM7="${CONFCUSTOM7^^}"
  CONFCUSTOM8="${customparams[7]}"; CONFCUSTOM8="${CONFCUSTOM8// /_}"; CONFCUSTOM8="${CONFCUSTOM8^^}"
  CONFCUSTOM9="${customparams[8]}"; CONFCUSTOM9="${CONFCUSTOM9// /_}"; CONFCUSTOM9="${CONFCUSTOM9^^}"
fi

# Now, the SuperFLAC parameter
# ====================================================================
dialog --backtitle "Semplice Configuration File Editor" --title " Program Configuration " --form "Parameters affecting SuperFLAC management:" 17 90 10 \
"Auto-delete per-track FLACs after SuperFLAC creation " 1 1  "$confautodel" 1 70 6 0 2>"$CONFDIR/tmp/superparams"

readarray -t superparams < "$CONFDIR/tmp/superparams" 2>/dev/null
CONFAUTODEL="${superparams[0]}"; if [[ -z $CONFAUTODEL ]]; then CONFAUTODEL="no"; fi

# Check for legal values and replace with defaults if not legal
# ====================================================================
if [[ ${CONFAUTODEL,,} == "yes" || ${CONFAUTODEL,,} == "no" ]]; then CONFAUTODEL=${CONFAUTODEL,,}; else CONFAUTODEL="no"; fi

# Now, the Audio processing parameters
# ====================================================================
dialog --backtitle "Semplice Configuration File Editor" --title " Program Configuration " --form "Parameters for Audio Processing:" 17 90 10 "Lossy codec quality setting (1-9)" 1 1  "$confqual" 1 65 9 0 "Delete source files after codec conversion" 2 1  "$confaudiodel"  2 65 9 0 "Apply audio boost automatically if appropriate" 3 1  "$confboost" 3 65 9 0 "Apply real or metadata audio boost?" 4 1 "$confmetavol" 4 65 9 0 2>"$CONFDIR/tmp/audioparams"

readarray -t audioparams < "$CONFDIR/tmp/audioparams" 2>/dev/null
CONFQUAL="${audioparams[0]}";     if [[ -z $CONFQUAL ]]; then CONFQUAL="4"; fi
CONFAUDIODEL="${audioparams[1]}"; if [[ -z $CONFAUDIODEL ]]; then CONFAUDIODEL="no"; fi
CONFBOOST="${audioparams[2]}";    if [[ -z $CONFBOOST ]]; then CONFBOOST="no"; fi
CONFMETAVOL="${audioparams[3]}";    if [[ -z $CONFMETAVOL ]]; then CONFMETAVOL="real"; fi

# And finally, miscellaneous program control parameters
# ====================================================================
dialog --backtitle "Semplice Configuration File Editor" --title " Program Configuration " --form "Program Control Parameters:" 17 90 10 \
"Display embedded artwork at size:" 1 1  "$confartsize" 1 55 35 0 \
"Size of the Program Logo" 2 1  "$conflogosize"     2 55 35 0 \
"Program Logo position (- or +)" 3 1  "$conflogopos"     3 55 35 0 \
"Semplice colour theme name" 4 1 "$confweztheme" 4 55 35 0 \
"Semplice font size (in points)" 5 1 "$confwezfntsz" 5 55 35 0 \
"Dialog colour theme name" 6 1 "$confdiatheme" 6 55 35 0 \
2>"$CONFDIR/tmp/miscparams"

readarray -t miscparams < "$CONFDIR/tmp/miscparams" 2>/dev/null
CONFARTSIZE="${miscparams[0]}";  if [[ -z $CONFARTSIZE ]]; then CONFARTSIZE="380"; fi
CONFLOGOSIZE="${miscparams[1]}"
  if [[ $((CONFLOGOSIZE)) != "$CONFLOGOSIZE" ]]; then CONFLOGOSIZE=110; fi
  if [[ $CONFLOGOSIZE -lt 0 ]]; then CONFLOGOSIZE=110; fi
  CONFLOGOSIZE=$CONFLOGOSIZE"x"$CONFLOGOSIZE
CONFLOGOPOS="${miscparams[2]}"
  if [[ $((CONFLOGOPOS)) != "$CONFLOGOPOS" ]]; then CONFLOGOPOS=0; fi
CONFWEZTHEME="${miscparams[3]}"
  if [[ -z $CONFWEZTHEME ]]; then CONFWEZTHEME="Galaxy"; fi
CONFWEZFNTSZ="${miscparams[4]}"
  if ! [[ $CONFWEZFNTSZ =~ ^[0-9]+$ ]]; then CONFWEZFNTSZ=12; fi
  if [[ $CONFWEZFNTSZ -gt 32 ]]; then CONFWEZFNTSZ=12; fi
  if [[ $CONFWEZFNTSZ -lt 8 ]]; then CONFWEZFNTSZ=12; fi
CONFDIATHEME="${miscparams[5]}"

# Make sure CONFDIATHEME is one of standard, red, green, yellow or magenta. If not, it's standard
if [[ ${CONFDIATHEME,,} =~ ^(standard|red|green|yellow|magenta)$ ]]; then
  CONFDIATHEME=${CONFDIATHEME,,}
else
  CONFDIATHEME=standard
fi

# Check for legal values and replace with defaults if not legal
# ====================================================================
NUM='^[0-9]+$'
if ! [[ $CONFQUAL =~ $NUM ]] ; then CONFQUAL=4; fi
if [[ $CONFQUAL -gt 9 ]]; then CONFQUAL=4; fi
if [[ $CONFQUAL -lt 1 ]]; then CONFQUAL=4; fi

if ! [[ $CONFARTSIZE =~ $NUM ]] ; then CONFARTSIZE=380; fi
if [[ $CONFARTSIZE -lt 1 ]]; then CONFARTSIZE=380; fi

if [[ ${CONFAUDIODEL,,} == "yes" || ${CONFAUDIODEL,,} == "no" ]]; then CONFAUDIODEL=${CONFAUDIODEL,,}; else CONFAUDIODEL="no"; fi
if [[ ${CONFBOOST,,} == "yes" || ${CONFBOOST,,} == "no" ]]; then CONFBOOST=${CONFBOOST,,}; else CONFBOOST="no"; fi
if [[ ${CONFMETAVOL,,} == "real" || ${CONFMETAVOL,,} == "metadata" ]]; then CONFMETAVOL=${CONFMETAVOL,,}; else CONFMETAVOL="real"; fi

if [[ -f $HOME/.semplice.lua ]]; then
  $SEDPROG -i "s/^config\.color_scheme = '.*'$/config.color_scheme = '$CONFWEZTHEME'/" "$HOME/.semplice.lua"
  $SEDPROG -i "s/^config\.font_size = .*$/config.font_size = $CONFWEZFNTSZ/" "$HOME/.semplice.lua"
fi

# Keep the colours already chosen (via the colour picker): read each from the existing file, falling back
# to its default if missing or not a whole number from 0 to 255
# ====================================================================
for colourpair in HOTKEY:11 DRAWLINES:2 MAINTEXT:15 LOGO:6 INFOTEXT:11 SPINNER:12 ALERT:1; do
  colname="${colourpair%%:*}"; coldefault="${colourpair##*:}"
  colvalue=$($GREPPROG -i -m1 "^$colname=" "$CONFFILE" 2>/dev/null | $SEDPROG -e "s/^[^=]*=//" -e "s/[[:space:]]*$//")
  if ! [[ $colvalue =~ ^[0-9]+$ && $colvalue -le 255 ]]; then colvalue=$coldefault; fi
  printf -v "KEEP_$colname" "%s" "$colvalue"
done

if [[ -f "$CONFDIR/txt/semplice.conf" ]]; then
  cp "$CONFDIR/txt/semplice.conf" "$CONFDIR/txt/semplice.conf-$(date +%F-%T).bkp"
fi

echo "# New Semplice Configuration File, created $(date)
# ====================================================================

# Colour Constants (alter at your peril!)
# ====================================================================
HOTKEY=$KEEP_HOTKEY
DRAWLINES=$KEEP_DRAWLINES
MAINTEXT=$KEEP_MAINTEXT
LOGO=$KEEP_LOGO
INFOTEXT=$KEEP_INFOTEXT
SPINNER=$KEEP_SPINNER
ALERT=$KEEP_ALERT

# Parameters controlling CD Ripping
# ====================================================================
OPTICAL_DEVICE=$CONFDRIVE
OPTICAL_OFFSET=$CONFOFFSET
HYPER_ACCURATERIP=$CONFHYPER
READ_RETRIES=$CONFRETRIES
FLAC_QUALITY=$CONFFLAC
DELETE_WAV=$CONFDELETE
RIP_FOLDER=$CONFWKDIR

# Parameters controlling FLAC tagging
# ====================================================================
DELETE_ART=$CONFART
ACCENTS=$CONFACCENTS
NAMEBITS=$CONFBITS
DISPLAYONEXTRACT=$CONFDISPLAY
EDITOR=$CONFEDITOR
CUSTOMTAGS=$CONFCUSTOM
CUSTOMTAG1=$CONFCUSTOM1
CUSTOMTAG2=$CONFCUSTOM2
CUSTOMTAG3=$CONFCUSTOM3
CUSTOMTAG4=$CONFCUSTOM4
CUSTOMTAG5=$CONFCUSTOM5
CUSTOMTAG6=$CONFCUSTOM6
CUSTOMTAG7=$CONFCUSTOM7
CUSTOMTAG8=$CONFCUSTOM8
CUSTOMTAG9=$CONFCUSTOM9

# Parameters controlling SuperFLACs
# ====================================================================
AUTODELETE_PERTRACK_FLACS=$CONFAUTODEL

# Parameters controlling Audio Processing/Conversion
# ====================================================================
AUDIO_QUALITY=$CONFQUAL
AUDIOIN_DELETION=$CONFAUDIODEL
AUTOBOOST=$CONFBOOST
METAVOL=$CONFMETAVOL

# Parameters controlling general program behaviour
# ====================================================================
ARTSIZE=$CONFARTSIZE
LOGOSIZE=$CONFLOGOSIZE
WEZTHEME=\"$CONFWEZTHEME\"
WEZFNTSZ=$CONFWEZFNTSZ
DIATHEME=\"$CONFDIATHEME\"
LOGOPOS=$CONFLOGOPOS" > "$CONFDIR/txt/semplice.conf"

# Regenerate the small program logos based on the new logo size parameter (as Giocoso does)
# ====================================================================
$CONVPROG "$CONFDIR/art/sempliceicobeta.png" -resize "$CONFLOGOSIZE" "$CONFDIR/art/sempliceicosmallbeta.png" 2>/dev/null
$CONVPROG "$CONFDIR/art/sempliceico.png" -resize "$CONFLOGOSIZE" "$CONFDIR/art/sempliceicosmall.png" 2>/dev/null

rm -f "$CONFDIR/tmp/ripparams" 2>/dev/null
rm -f "$CONFDIR/tmp/tagparams" 2>/dev/null
rm -f "$CONFDIR/tmp/customtagparams" 2>/dev/null
rm -f "$CONFDIR/tmp/superparams" 2>/dev/null
rm -f "$CONFDIR/tmp/audioparams" 2>/dev/null
rm -f "$CONFDIR/tmp/miscparams" 2>/dev/null
source "$CONFDIR/bin/semparse.sh"
