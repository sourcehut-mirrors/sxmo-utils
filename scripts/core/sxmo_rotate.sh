#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

applyptrmatrix() {
	[ -n "$SXMO_TOUCHSCREEN_ID" ] && xinput set-prop "$SXMO_TOUCHSCREEN_ID" --type=float --type=float "Coordinate Transformation Matrix" "$@"
	[ -n "$SXMO_STYLUS_ID" ] && xinput set-prop "$SXMO_STYLUS_ID" --type=float --type=float "Coordinate Transformation Matrix" "$@"
}

swayfocusedtransform() {
	swaymsg -t get_outputs | jq -r '.[] | select(.focused == true) | .transform'
}

swayfocusedname() {
	swaymsg -t get_outputs | jq -r '.[] | select(.focused == true) | .name'
}

riverfocusedname() {
	river-bedload -print outputs | jq -r '.[] | select(.focused).name'
}

riverfocusedtransform() {
	focused_output=$(riverfocusedname)
	wlr-randr --json | jq -r '.[] | select(.name == "'"$focused_output"'").transform'
}

restart_sxmo_hook_lisgd() {
	if [ ! -e "$XDG_CACHE_HOME"/sxmo/sxmo.nogesture ]; then
		superctl restart sxmo_hook_lisgd
	fi
}

xorgisrotated() {
	rotation="$(
		xrandr | grep primary | cut -d' ' -f 5 | sed s/\(//
	)"
	if [ "$rotation" = "normal" ]; then
		return 1;
	fi
	printf %s "$rotation"
	return 0;
}

swayisrotated() {
	rotation="$(
		swayfocusedtransform | sed -e s/90/right/ -e s/270/left/ -e s/180/reverse/
	)"
	if [ "$rotation" = "normal" ]; then
		return 1;
	fi
	printf %s "$rotation"
	return 0;
}

riverisrotated() {
	rotation="$(
		riverfocusedtransform | sed -e s/270/right/ -e s/90/left/ -e s/180/reverse/
	)"
	if [ "$rotation" = "normal" ]; then
		return 1;
	fi
	printf %s "$rotation"
	return 0;
}

xorgrotinvert() {
	sxmo_keyboard.sh close
	xrandr -o inverted
	applyptrmatrix -1 0 1 0 -1 1 0 0 1
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh invert
	exit 0
}

swayrotinvert() {
	swaymsg -- output "-" transform 180
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh invert
	exit 0
}

riverrotinvert() {
	focused_output=$(river-bedload -print outputs | jq -r ".[] | select(.focused).name")
	wlr-randr --output "$focused_output" --transform 180
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh invert
	exit 0
}

xorgrotnormal() {
	sxmo_keyboard.sh close
	xrandr -o normal
	applyptrmatrix 0 0 0 0 0 0 0 0 0
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh normal
	exit 0
}

swayrotnormal() {
	swaymsg -- output "-" transform 0
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh normal
	exit 0
}

riverrotnormal() {
	focused_output=$(river-bedload -print outputs | jq -r ".[] | select(.focused).name")
	wlr-randr --output "$focused_output" --transform normal
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh normal
	exit 0
}

xorgrotright() {
	sxmo_keyboard.sh close
	xrandr -o right
	applyptrmatrix 0 1 0 -1 0 1 0 0 1
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh right
	exit 0
}

swayrotright() {
	swaymsg -- output "-" transform 90
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh right
	exit 0
}

riverrotright() {
	focused_output=$(river-bedload -print outputs | jq -r ".[] | select(.focused).name")
	wlr-randr --output "$focused_output" --transform 270
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh right
	exit 0
}

xorgrotleft() {
	sxmo_keyboard.sh close
	xrandr -o left
	applyptrmatrix 0 -1 1 1 0 0 0 0 1
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh left
	exit 0
}

swayrotleft() {
	swaymsg -- output "-" transform 270
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh left
	exit 0
}

riverrotleft() {
	focused_output=$(river-bedload -print outputs | jq -r ".[] | select(.focused).name")
	wlr-randr --output "$focused_output" --transform 90
	restart_sxmo_hook_lisgd
	sxmo_hook_rotate.sh left
	exit 0
}

isrotated() {
	case "$SXMO_WM" in
		sway)
			"swayisrotated"
			;;
		river)
			"riverisrotated"
			;;
		dwm|i3)
			"xorgisrotated"
			;;
	esac
}

if [ -z "$1" ] || [ "rotate" = "$1" ]; then
	if [ $# -ne 0 ]; then
		shift
	fi
	if isrotated; then
		set -- rotnormal "$@"
	else
		set -- rot"${SXMO_ROTATE_DIRECTION:-right}" "$@"
	fi
fi

case "$SXMO_WM" in
	sway)
		"sway$1" "$@"
		;;
	river)
		"river$1" "$@"
		;;
	dwm|i3)
		"xorg$1" "$@"
		;;
esac
