#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

# This hook enables the proximity lock.

finish() {
	sxmo_wakelock.sh unlock sxmo_proximity_lock_running
	sxmo_state.sh restore "$storeid"
	pkill -P $$
}

last=

near() {
	if [ "$last" = "near" ]; then return; fi
	sxmo_debug "near"
	sxmo_state.sh set screenoff
	last=near
}

far() {
	if [ "$last" = "far" ]; then return; fi
	sxmo_debug "far"
	sxmo_state.sh set unlock
	last=far
}

trap 'finish' TERM INT EXIT

# check if iio-sensor-proxy found a proximity sensor
dbus-send --system --dest=net.hadess.SensorProxy --print-reply=literal \
	/net/hadess/SensorProxy org.freedesktop.DBus.Properties.Get \
	string:net.hadess.SensorProxy string:HasProximity | grep -q 'true' || exit

sxmo_wakelock.sh lock sxmo_proximity_lock_running infinite

storeid="$(sxmo_state.sh store)"

monitor-sensor --proximity | while read -r line; do
	case "$line" in
		"=== Has proximity sensor (near: 0)")
			far
			;;
		"=== Has proximity sensor (near: 1)")
			near
			;;
		"Proximity value changed: 1")
			near
			;;
		"Proximity value changed: 0")
			far
			;;
	esac
done &

wait
