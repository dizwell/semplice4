#!/usr/bin/env bash
####################################################################
#
# semcus: routine for setting custom tags. Holds the one and only
# custom tags form (customtags_form), used both by the standalone
# custom tags menu option and by album tagging (semtags.sh).
#
# A custom tag slot whose name is the placeholder XqXXqXX is unused
# and never shown or written.
#
####################################################################

function customtags_form {
# Collect the names of the custom tag slots actually in use, in order
local i REF NAME
local -a USED_NAMES=()
for ((i=1; i<=9; i++)); do
  REF="CUSTOMTAG$i"; NAME="${!REF}"
  if [[ -n $NAME && $NAME != "XqXXqXX" ]]; then USED_NAMES+=("$NAME"); fi
done
if [[ ${#USED_NAMES[@]} -eq 0 ]]; then return; fi

# Build the form with one row per tag in use: consecutive rows, so no gaps.
# Existing values are read from the first FLAC, for display.
local g row=0 LABEL LABELWIDTH=0 FIELDCOL FIELDWIDTH
local -a CUSTOMSTRING=()
g=$(find "$(pwd)" -maxdepth 1 -name "*.flac" | sort | head -n 1)
for NAME in "${USED_NAMES[@]}"; do                                                # Find the longest label, so every input field starts clear of it
  row=$((row+1)); LABEL="$row. ${NAME//_/ }:"
  if [[ ${#LABEL} -gt $LABELWIDTH ]]; then LABELWIDTH=${#LABEL}; fi
done
FIELDCOL=$((LABELWIDTH+3)); FIELDWIDTH=$((90-FIELDCOL))                          # Two spaces' gap after the longest label; field fills the rest of the form
row=0
for NAME in "${USED_NAMES[@]}"; do
  row=$((row+1))
  CUSTOMSTRING+=("$row. ${NAME//_/ }:" "$row" 1 "$(get_tag "$NAME" "$g")" "$row" $FIELDCOL $FIELDWIDTH 256)
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
if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then BREAKME=1; return; fi

# Answers come back one line per row shown, in the same order as USED_NAMES
VALUES=$(printf '%s\n' "$VALUES" | to_nfc)                                      # On macOS, force accented characters into composed form
local -a ANSWERS=()
mapfile -t ANSWERS <<< "$VALUES"

local f n VALUE
for f in *.flac; do
  metaflac $UTFCHARS --remove-tag=XqXXqXX "$f" 2>/dev/null                        # Clear out any junk placeholder tags left by earlier versions
  for ((n=0; n<${#USED_NAMES[@]}; n++)); do
    metaflac $UTFCHARS --remove-tag="${USED_NAMES[$n]}" "$f" 2>/dev/null
    VALUE=$(printf '%s' "${ANSWERS[$n]}" | flatten_lines)
    if [[ -n $VALUE ]]; then
      metaflac $UTFCHARS --set-tag="${USED_NAMES[$n]}=$VALUE" "$f"
    fi
  done
done
}

# Standalone use from the menu: check custom tags are enabled and the FLACs writeable, then show the form.
# When album tagging sources this file with "define", it only wants the function above.
if [[ $1 != "define" ]]; then
  if [[ $CUSTOMTAGS -eq 1 ]]; then
    f=$(find "$(pwd)" -maxdepth 1 -name "*.flac" | sort | head -n 1)
    if [[ -w $f ]]; then
      customtags_form
    else
      dialog --title "Semplice Custom Tags" --msgbox "\\n\\nThere are files in this folder of FLACs that are not writeable, so we cannot continue.\\n\\nClick OK to return to the main menu." 12 70
      BREAKME=1
    fi
  else
    dialog --stdout --backtitle "Semplice FLAC Tagging" --title " Custom Tags " --msgbox "\nCustom tags have neither been enabled nor configured in the configuration file. Do that before attempting to tag anything with custom tags." 10 80
  fi
fi
