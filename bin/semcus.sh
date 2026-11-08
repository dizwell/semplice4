#!/usr/bin/env bash
####################################################################
#
# semcus: routine for setting custom tags
#
####################################################################
source "$CONFDIR/bin/semparse.sh"

if [[ $CUSTOMTAGS -eq 1 ]]; then
  # Check the first FLAC for writeability
  f=$(find "$(pwd)" -maxdepth 1 -name "*.flac" | sort | head -n 1)
  if [[ -w $f ]]; then
    :
  else
    dialog --title "Semplice Custom Tags" --msgbox "\\n\\nThere are files in this folder of FLACs that are not writeable, so we cannot continue.\\n\\nClick OK to return to the main menu." 12 70
    BREAKME=1
    return
  fi

  unset CUSTOMSTRING
  g=$(find "$(pwd)" -name "*.flac" | sort | head -n 1)
  for ((i=1; i<=9; i++)); do
    REF="CUSTOMTAG$i"
    CUSTOMTAGNAME="${!REF}"
    EXISTINGCUSTOMDATA=$(metaflac $UTFCHARS --show-tag="$CUSTOMTAGNAME" "$g" | $SEDPROG 's/.*=//g')   # Get existing data if any, for display purposes
    CUSTOMTAGNAME="${CUSTOMTAGNAME//_/ }"
    if ! [ "$CUSTOMTAGNAME" == "XqXXqXX" ]; then
      CUSTOMSTRING+=("$i. $CUSTOMTAGNAME:" "$i" 1 "$EXISTINGCUSTOMDATA" "$i" 22 65 256)
    fi
  done
  exec 3>&1
  VALUES=$( 2>&1 1>&3 dialog --ok-label "Submit" \
        --backtitle "Semplice FLAC Tagging" \
        --title " Supply Custom Tag Metadata " \
        --form "Custom Tags" 18 95 0 \
        "${CUSTOMSTRING[@]}"
  )
  exitStatus=$?
  exec 3>&-

  if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then
    return
  else
    echo "$VALUES" > "$CONFDIR/tmp/customtags.txt"

    for f in *.flac; do
      if [[ $CUSTOMTAGS -eq 1 ]]; then
        metaflac $UTFCHARS --remove-tag="$CUSTOMTAG1" "$f" 2>/dev/null
        metaflac $UTFCHARS --remove-tag="$CUSTOMTAG2" "$f" 2>/dev/null
        metaflac $UTFCHARS --remove-tag="$CUSTOMTAG3" "$f" 2>/dev/null
        metaflac $UTFCHARS --remove-tag="$CUSTOMTAG4" "$f" 2>/dev/null
        metaflac $UTFCHARS --remove-tag="$CUSTOMTAG5" "$f" 2>/dev/null
        metaflac $UTFCHARS --remove-tag="$CUSTOMTAG6" "$f" 2>/dev/null
        metaflac $UTFCHARS --remove-tag="$CUSTOMTAG7" "$f" 2>/dev/null
        metaflac $UTFCHARS --remove-tag="$CUSTOMTAG8" "$f" 2>/dev/null
        metaflac $UTFCHARS --remove-tag="$CUSTOMTAG9" "$f" 2>/dev/null
      fi

      for ((t=1; t<=9; t++)); do
        TAGVALUE=$($SEDPROG "${t}q;d" $CONFDIR/tmp/customtags.txt)
        if ! [[ -z $TAGVALUE ]]; then
          REF="CUSTOMTAG$t"
          CUSTOMTAGNAME="${!REF}"
          metaflac $UTFCHARS --set-tag="$CUSTOMTAGNAME"="$TAGVALUE" "$f"
        fi
      done
    done
  fi
else
  dialog --stdout --backtitle "Semplice FLAC Tagging" --title " Custom Tags " --msgbox "\nCustom tags have neither been enabled nor configured in the configuration file. Do that before attempting to tag anything with custom tags." 10 80
fi
