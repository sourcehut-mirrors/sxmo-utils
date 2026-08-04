#!/bin/sh
# shiftphone shift8
export SXMO_MIN_BRIGHTNESS=1
export SXMO_MONITOR="DSI-1"
export SXMO_POWER_BUTTON="0:0:pmic_pwrkey"

# The shift8 has a rounded edge hiding the minutes digit.
# We add a backspace here to fill the gap
export SXMO_STATUS_DATE_FORMAT="%H:%M\\"
export SXMO_VOLUME_BUTTON="1:1:gpio-keys 0:0:pmic_resin"
export SXMO_SWAY_SCALE="2"
# SXMO_VIBRATE_DEV is not set: No mainline support yet

# Supported by the device, needed for colour profiles
export WLR_RENDERER=vulkan
