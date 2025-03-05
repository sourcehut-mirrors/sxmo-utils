#!/bin/sh

# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2025 Sxmo Contributors

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh
# shellcheck source=configs/default_hooks/sxmo_hook_icons.sh
. sxmo_hook_icons.sh

# WARNING: The menus in this script will be displayed over the lockscreen

while true
do
	PICKED="$(grep . <<-EOF | sxmo_dmenu.sh --show-over-lockscreen
	Close Menu
	$icon_pwr Screen Off
	$(rfkill list bluetooth | grep "yes" >/dev/null \
		&& printf "%s Bluetooth" "$icon_tof" \
		|| printf "%s Bluetooth" "$icon_ton")
	$(pacmd list-sink-inputs | grep -c 'state: RUNNING' >/dev/null \
		&& printf "%s Music" "$icon_pau" \
		|| printf "%s Music" "$icon_itm")
	$([ "$(brightnessctl -d "white:flash" get)" -gt 0 ] \
		&& printf "%s Torch" "$icon_ton" \
		|| printf "%s Torch" "$icon_tof")
	$(rfkill list wifi | grep "yes" >/dev/null \
		&& printf "%s Wifi" "$icon_tof" \
		|| printf "%s Wifi" "$icon_ton")
EOF
)"

	case "$PICKED" in
		'Close Menu'|'') exit 0 ;;
		*"Bluetooth") doas sxmo_bluetoothtoggle.sh ;;
		*"Music") playerctl play-pause ;;
		*"Screen Off") sxmo_state.sh set screenoff && exit 0;;
		*"Torch") sxmo_flashtoggle.sh ;;
		*"Wifi") doas sxmo_wifitoggle.sh ;;
	esac
done
