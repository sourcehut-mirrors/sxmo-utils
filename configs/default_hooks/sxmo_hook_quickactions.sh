#!/bin/sh

# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2025 Sxmo Contributors

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh
# shellcheck source=configs/default_hooks/sxmo_hook_icons.sh
. sxmo_hook_icons.sh

# WARNING: The menus in this script will be displayed over the lockscreen

player_options() {
	case "$(playerctl status 2>/dev/null)" in
		"") ;; # no player found
		*"Playing"*) cat - <<-EOF
			$icon_arl Previous
			$icon_pau Pause
			$icon_arr Next
			EOF
			;;
		*) printf "%s Play" "$icon_itm" ;;
	esac
}

while true
do
	PICKED="$(grep . <<-EOF | sxmo_dmenu.sh --show-over-lockscreen
	$icon_cls Close Menu
	$icon_pwr Screen Off
	$icon_bth Bluetooth $(rfkill list bluetooth | grep "yes" >/dev/null \
		&& printf %b "$icon_tof" \
		||  printf %b "$icon_ton")
	$(player_options)
	$(if brightness="$(brightnessctl -l -m | grep -e "white:torch" -e "white:flash" | cut -d ',' -f 3)"; then
		printf "%s Flashlight " "$icon_fll"
		[ "$brightness" -gt 0 ] &&
			printf %b "$icon_ton" || printf %b "$icon_tof";
	fi)
	$icon_wifi_signal_4 Wifi $(rfkill list wifi | grep "yes" >/dev/null \
		&& printf %b "$icon_tof" \
		|| printf %b "$icon_ton")
EOF
)"

	case "$PICKED" in
		*'Close Menu'|'') exit 0 ;;
		*"Bluetooth"*) doas sxmo_bluetoothtoggle.sh ;;
		*"Previous") playerctl previous ;;
		*"Pause") playerctl pause ;;
		*"Play") playerctl play ;;
		*"Next") playerctl next ;;
		*"Screen Off") sxmo_state.sh set screenoff && exit 0;;
		*"Flashlight"*) sxmo_flashtoggle.sh ;;
		*"Wifi"*) doas sxmo_wifitoggle.sh ;;
	esac
done
