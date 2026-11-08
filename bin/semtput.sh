#!/usr/bin/env bash
####################################################################
#
# semtput: routine for making tput work as a bash internal
# call rather than as an invocation of an external utility
#
####################################################################

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
