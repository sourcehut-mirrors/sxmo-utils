#!/bin/sh
# Fairphone 6
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2025 Sxmo Contributors

export SXMO_TOUCHSCREEN_ID="0:0:ESWIN_EPH86XX_Touchscreen"
export SXMO_POWER_BUTTON="0:0:pmic_pwrkey"
export SXMO_VOLUME_BUTTON="1:1:gpio-keys 0:0:pmic_resin"
export SXMO_SWAY_SCALE="3.0"
export SXMO_MONITOR="DSI-1"
export LISGD_EDGE_SIZE=2
export SXMO_VIBRATE_DEV=/dev/input/by-path/platform-880000.i2c-event
export SXMO_VIBRATE_STRENGTH=30000
