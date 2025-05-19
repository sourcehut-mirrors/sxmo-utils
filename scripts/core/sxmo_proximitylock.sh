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

near() {
	sxmo_debug "near"
	sxmo_state.sh set screenoff
}

far() {
	sxmo_debug "far"
	sxmo_state.sh set unlock
}

trap 'finish' TERM INT EXIT

# check if iio-sensor-proxy found a proximity sensor
dbus-send --system --dest=net.hadess.SensorProxy --print-reply=literal \
	/net/hadess/SensorProxy org.freedesktop.DBus.Properties.Get \
	string:net.hadess.SensorProxy string:HasProximity | grep -q 'true' || exit

sxmo_wakelock.sh lock sxmo_proximity_lock_running infinite

storeid="$(sxmo_state.sh store)"
last=far

monitor-sensor --proximity | while read -r line; do
	if echo "$line" | grep -q ".*Proximity value.*1"; then
		if "$last" != "near"; then
			near
			last=near
		fi
	elif echo "$line" | grep -q ".*Proximity value.*0"; then
		if "$last" != "far"; then
			far
			last=far
		fi
	fi
done &

wait
