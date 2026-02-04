#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# Must be run as root

# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

on() {
	rfkill unblock bluetooth

	if [ -d /run/systemd/system ]; then
		systemctl start bluetooth
		systemctl enable bluetooth
	else
		rc-service bluetooth start
		rc-update add bluetooth
	fi
}

off() {
	if [ -d /run/systemd/system ]; then
		systemctl stop bluetooth
		systemctl disable bluetooth
	else
		rc-service bluetooth stop
		rc-update del bluetooth
	fi
	rfkill block bluetooth
}

case "$1" in
	on)
		on
		;;
	off)
		off
		;;
	*) #toggle
		if rfkill list bluetooth | grep -q "Soft blocked: no"; then
			off
		else
			on
		fi
esac
