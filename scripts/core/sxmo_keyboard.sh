#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

isopen() {
	if [ -z "$KEYBOARD" ]; then
		exit 0 # ssh/tty usage by example
	fi
	case "$KEYBOARD" in
		'onboard') dbus-send --type=method_call --print-reply --dest=org.onboard.Onboard /org/onboard/Onboard/Keyboard org.freedesktop.DBus.Properties.Get string:"org.onboard.Onboard.Keyboard" string:"Visible" || exit 0 ;;
		*) sxmo_jobs.sh running sxmo_keyboard -q ;;
	esac
}

open() {
	if [ -n "$SXMO_NO_VIRTUAL_KEYBOARD" ]; then
		return
	fi
	if [ -n "$KEYBOARD" ]; then
		case "$KEYBOARD" in
			'onboard') dbus-send --type=method_call --print-reply --dest=org.onboard.Onboard /org/onboard/Onboard/Keyboard org.onboard.Onboard.Keyboard.Show ;;
			*)
				sxmo_jobs.sh start --group sxmo_keyboard sh -c "$KEYBOARD $KEYBOARD_ARGS" &
			;;
		esac
	fi
}

close() {
	if [ -n "$KEYBOARD" ]; then # avoid killing everything !
		case "$KEYBOARD" in
			'onboard') dbus-send --type=method_call --print-reply --dest=org.onboard.Onboard /org/onboard/Onboard/Keyboard org.onboard.Onboard.Keyboard.Hide ;;
			*) sxmo_jobs.sh stop sxmo_keyboard ;;
		esac
	fi
}

if [ "$1" = "toggle" ]; then
	#shellcheck disable=SC2015
	isopen && close || open
elif [ "$1" = "close" ]; then
	if isopen; then
		close
	fi
elif [ "$1" = "isopen" ]; then
	isopen || exit 1
else
	isopen || open
fi
