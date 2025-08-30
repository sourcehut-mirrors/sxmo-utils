#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2024 Sxmo Contributors

if brightnessctl -m -l | grep -q "white:flash" >/dev/null; then
	DEVICE="white:flash"
elif brightnessctl -m -l | grep -q "white:torch" >/dev/null; then
	DEVICE="white:torch"
else
	exit
fi
if [ "$(brightnessctl -d "$DEVICE" get)" -gt 0 ]; then
	brightnessctl -q -d "$DEVICE" set "0%"
else
	brightnessctl -q -d "$DEVICE" set "100%"
fi
