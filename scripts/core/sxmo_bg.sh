#!/bin/sh

bg="$(sxmo_hook_wallpaper.sh)"

case "$SXMO_WM" in
	dwm|i3)
		exec feh "${1+--bg-$1}" "$bg"
		;;
	sway|river)
		exec swaybg -i "$bg" ${1+-m "$1"}
		;;
	"")
		printf "%s: empty \$SXMO_WM\n" "$(basename "$0")" >&2
		exit 1
		;;
esac

printf "%s: \$SXMO_WM not supported yet '%s'\n" "$(basename "$0")" "$SXMO_WM" >&2
exit 1
