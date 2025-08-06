#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors
# title="$icon_wtr Weather"
# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

[ -z "$SXMO_GPSLOCATIONSFILES" ] && SXMO_GPSLOCATIONSFILES="$(xdg_data_path sxmo/appcfg/places_for_gps.tsv)"
LOCATIONS="$(grep -vE '^#' "$SXMO_GPSLOCATIONSFILES" | sed "s/\t/: /g")"

WEATHERMENU() {
	CHOICE="$(grep . <<-EOF | sxmo_dmenu.sh -i -p "Locations"
		Close Menu
		Current IP Location
		$LOCATIONS
EOF
)"
	case "$CHOICE" in
		'Close Menu'|'') exit 0 ;;
		'Current IP Location')
			PLACE=''
			FORECAST
			;;
		*)
			PLACE="$(echo "$CHOICE" | cut -d ',' -f 1 | sed s'/ /+/g')"
			FORECAST
		;;
	esac
}

FORECAST() {
	OUTPUT="$(grep . <<-EOF | sxmo_dmenu.sh -i -l 10
		Close Menu
		Right Now
		Forecast
EOF
)"
	case "$OUTPUT" in
		'Close Menu'|'') exit 0 ;;
		"Right Now")
			WEATHER="$(curl wttr.in/"$PLACE"?format=4 | tr '+' ' ')"
			notify-send "$WEATHER"
			;;
		"Forecast")
			if [ "$SXMO_TERMINAL" = "alacritty" ]; then
				sxmo_terminal.sh sh -c "curl http://wttr.in/$PLACE | less -SR"
			else
				sxmo_terminal.sh -f "monospace:size=5" sh -c "curl http://wttr.in/$PLACE | less -SR"
			fi
			;;
	esac
	WEATHERMENU

}
WEATHERMENU
