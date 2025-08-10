#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2025 Sxmo Contributors

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

switch_to() {
	file="$(xdg_data_path "$1")"
	if ! [ -e "$file" ]; then
		sxmo_notify_user.sh "Selected window manager not found, please install relevent sxmo-ui package."
		return
	fi

	if doas tinydm-set-session -f -s "$file"; then
		sxmo_power.sh logout
	else
		sxmo_notify_user.sh "tinydm failed to change the session"
	fi
}

CHOICE="$(grep -v "$SXMO_WM" <<-EOF | sxmo_dmenu.sh -p "Switch WM"
	i3
	dwm
	sway
	river
EOF
)" || exit

case "$CHOICE" in
	'Close Menu') exit ;;
	i3) switch_to "xsessions/sxmo_i3.desktop" ;;
	dwm) switch_to "xsessions/sxmo.desktop" ;;
	sway) switch_to "wayland-sessions/swmo.desktop" ;;
	river) switch_to "wayland-sessions/sxmo_river.desktop" ;;
esac
