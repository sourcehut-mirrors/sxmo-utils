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
	Close Menu
	$icon_pwr Screen Off
	$(rfkill list bluetooth | grep "yes" >/dev/null \
		&& printf "%s Bluetooth" "$icon_tof" \
		|| printf "%s Bluetooth" "$icon_ton")
	$(player_options)
	$(if brightness="$(brightnessctl -d "white:flash" get)"; then
		printf "%s Flashlight " "$icon_fll"
		[ "$brightness" -gt 0 ] &&
			printf %b "$icon_ton" || printf %b "$icon_tof";
	fi)
	$(rfkill list wifi | grep "yes" >/dev/null \
		&& printf "%s Wifi" "$icon_tof" \
		|| printf "%s Wifi" "$icon_ton")
EOF
)"

	case "$PICKED" in
		'Close Menu'|'') exit 0 ;;
		*"Bluetooth") doas sxmo_bluetoothtoggle.sh ;;
		*"Previous") playerctl previous ;;
		*"Pause") playerctl pause ;;
		*"Play") playerctl play ;;
		*"Next") playerctl next ;;
		*"Screen Off") sxmo_state.sh set screenoff && exit 0;;
		*"Flashlight"*) sxmo_flashtoggle.sh ;;
		*"Wifi") doas sxmo_wifitoggle.sh ;;
	esac
done
