#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

_swayidletoidles() {
	# Loop over args and convert to variables
	for arg in "$@"; do
		case "$arg" in
			-w)
				shift
				;;
			timeout)
				timeoutarg="$2"
				program="$3"
				shift 2
				;;
			resume)
				resumeprogram="$1"
				shift 1
				;;
			*)
				shift
				;;
		esac
	done
}

usage() {
	#editorconfig-checker-disable
	cat <<- EOF
		sxmo_idle.sh is a wrapper for swayidle and also to convert swayidle commands
		into other idle tools compatible commands.

		Usage: sxmo_idle.sh [options] [value]

		Options:
		  -h/--help
		        Show this message.
		  timeout [VALUE in seconds] 'sh -c "COMMAND"'
		        Set the timeout and execute COMMAND once timeout expires.

		Optional Options:
		  resume 'sh -c "COMMAND"'
		        When resuming from elapsed timeout execute COMMAND.

		All other args are either passed to swayidle or removed.

		This script supports the following:
		  wayland - swayidle
		  xorg	  - Using internal timer function.
	EOF
	#editorconfig-checker-enable
	exit
}

xorgidlefinish() {
	sh -c "$resumeprogram"
	trap - EXIT
	exit
}

xorgidle() {
	tick=0
	resumes=""
	new_idle="$(xprintidle)"
	last_idle="$new_idle"

	trap 'xorgidlefinish' TERM HUP INT EXIT

	while : ; do
		last_idle="$new_idle"
		new_idle="$(xprintidle)"
		if [ "$last_idle" -gt "$new_idle" ]; then
			sh -c "$resumes"
			tick=0
			resumes=""
		fi

		if [ "$tick" -eq "$timeoutarg" ]; then
			sh -c "$program"
			resumes="$resumeprogram"
		fi

		sleep 1
		tick=$(( tick + 1 ))
	done
}

case "$1" in
	-h|--help)
		usage
		;;
esac

case "$SXMO_WM" in
	dwm|i3)
		_swayidletoidles "$@"
		xorgidle
		;;
	sway|river)
		exec swayidle "$@"
		;;
esac
