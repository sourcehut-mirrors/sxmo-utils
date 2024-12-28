#!/bin/sh
# Samsung Core Prime VE LTE (SM-G361F)
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2023 Sxmo Contributors

export SXMO_VOLUME_BUTTON="1:1:gpio-keys"
export SXMO_POWER_BUTTON="0:0:88pm886-onkey"
export SXMO_NO_MODEM=1
export SXMO_MIN_BRIGHTNESS=0 # can go all the way down
export SXMO_SWAY_SCALE="1.25"
