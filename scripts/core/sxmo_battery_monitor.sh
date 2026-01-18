#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

finalize() {
	pkill -P $$
}

trap 'finalize' TERM INT

gdbus monitor --system --dest org.freedesktop.UPower | while read -r line; do
	case "$line" in
		"/org/freedesktop/UPower/devices/DisplayDevice"*)
			continue
			;;
		*"org.freedesktop.DBus.Properties.PropertiesChanged"*)
			object="$(cut -d ':' -f 1 <<-EOF
				$line
			EOF
			)"
			set -- sxmo_hook_battery.sh PropertiesChanged "$object"

			sxmo_debug "$*"
			"$@"
			;;
	esac
done
