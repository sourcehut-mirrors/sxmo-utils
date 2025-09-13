#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2025 Sxmo Contributors

# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

# Source sxmo_brightness.sh to improve script speed and cpu usage
# shellcheck source=scripts/core/sxmo_brightness.sh
. sxmo_brightness.sh

# Initalise variables
timeout=10


finalize() {
	kill "$monpid"
	pkill -P $$
}

# Function to convert lux values to brightness
lux_to_pct() {
	# $1 current lux value
	target=$1

	while read -r lux pct; do
		if [ "$target" -lt "$lux" ]; then
			break
		fi
	done <<-EOF
		1 $SXMO_MIN_BRIGHTNESS
		2 $((SXMO_MIN_BRIGHTNESS + 1))
		5 $((SXMO_MIN_BRIGHTNESS + 2))
		10 $((SXMO_MIN_BRIGHTNESS + 4))
		40 12
		50 15
		60 20
		100 30
		200 40
		400 50
		500 60
		900 70
		1200 80
		2000 90
		5000 100
		20000 100
	EOF

	# Call to sxmo_brightness.sh
	smooth_brightness_adjustment "$pct"
}

trap 'finalize' TERM INT

# check if iio-sensor-proxy found a light sensor
# check if the unit from dbus is in lux
dbus-send --system --dest=net.hadess.SensorProxy --print-reply=literal \
	/net/hadess/SensorProxy org.freedesktop.DBus.Properties.Get \
	string:net.hadess.SensorProxy string:HasAmbientLight | grep -q "true" || exit 1
dbus-send --system --dest=net.hadess.SensorProxy --print-reply=literal \
	/net/hadess/SensorProxy org.freedesktop.DBus.Properties.Get \
	string:net.hadess.SensorProxy string:LightLevelUnit | grep -q "lux" || exit 1

# Setup sensor monitoring and grab pid
monitor-sensor --light > /dev/null &
monpid=$!

while :; do
	if [ "$(cat "$SXMO_STATE")" = "unlock" ]; then
		# Cut processed the string in 1/2 the time of awk with hyperfine tests
		lux_value=$(dbus-send --system --dest=net.hadess.SensorProxy --print-reply=literal \
			/net/hadess/SensorProxy org.freedesktop.DBus.Properties.Get \
			string:net.hadess.SensorProxy string:LightLevel | cut -d ' ' -f 12)

		lux_to_pct "$lux_value"
		# Stop brightness jitter by sleeping
		sleep "$timeout"
	else
		# Sleep for next unlocked check
		sleep "$timeout"
	fi
done &

wait
