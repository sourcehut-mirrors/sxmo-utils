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
		*) pidof "$KEYBOARD" > /dev/null ;;
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
				#Note: KEYBOARD_ARGS is not quoted by design as it may includes a pipe and further tools
				# shellcheck disable=SC2086
				isopen || eval "$KEYBOARD" $KEYBOARD_ARGS >> "${XDG_STATE_HOME:-$HOME}"/sxmo.log 2>&1 &
			;;
		esac
	fi
}

close() {
	if [ -n "$KEYBOARD" ]; then # avoid killing everything !
		case "$KEYBOARD" in
			'onboard') dbus-send --type=method_call --print-reply --dest=org.onboard.Onboard /org/onboard/Onboard/Keyboard org.onboard.Onboard.Keyboard.Hide ;;
			*) pkill -f "$KEYBOARD" ;;
		esac
	fi
}

if [ "$1" = "toggle" ]; then
	close || open
elif [ "$1" = "close" ]; then
	if isopen; then
		close
	fi
elif [ "$1" = "isopen" ]; then
	isopen || exit 1
else
	open
fi
