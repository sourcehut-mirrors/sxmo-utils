#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

returnvalid() {
	printf %s "$1"
	exit
}

if [ "$(printf "%b\n" "$1" | xargs -0 pnc find | xargs printf %s)" = "$1" ]; then
	# a multiple formated phone number
	returnvalid "$1"
fi

if pnc valid "$1"; then
	returnvalid "$1"
fi

REFORMATTED="$(pnc find ${DEFAULT_COUNTRY:+-c "$DEFAULT_COUNTRY"} "$1")"
if pnc valid "$REFORMATTED"; then
	printf %s "$REFORMATTED"
	exit
fi

PICKED="$(cat <<-EOF | sxmo_dmenu.sh -p "Invalid Number"
	Abort
	Use as is
EOF
)"

if [ "$PICKED" = "Abort" ]; then
	exit 1
fi

returnvalid "$1"
