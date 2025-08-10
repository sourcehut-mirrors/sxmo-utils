#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

usage() {
	printf "usage: %s [reboot|poweroff|logout|togglewm]\n" "$(basename "$0")"
}

case "$1" in
	reboot)
		sxmo_hook_power.sh reboot
		sxmo_jobs.sh stop all
		doas reboot
		;;
	poweroff)
		sxmo_hook_power.sh poweroff
		sxmo_jobs.sh stop all
		doas poweroff
		;;
	logout)
		sxmo_hook_logout.sh
		case "$SXMO_WM" in
			"i3") i3-msg exit ;;
			"sway") swaymsg exit ;;
			"river") riverctl exit ;;
			"dwm") pkill dwm ;;
		esac
		;;
	togglewm) sxmo_togglewm.sh ;;
	*)
		usage
		exit 1
		;;
esac
