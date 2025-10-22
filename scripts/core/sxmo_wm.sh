#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# shellcheck disable=SC2317 disable=SC2329
# include common definitions
# shellcheck source=configs/default_hooks/sxmo_hook_icons.sh
. sxmo_hook_icons.sh
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

swi3msg() {
	case "$SXMO_WM" in
		sway) swaymsg "$@" ;;
		i3) i3-msg "$@" ;;
	esac
}

# Output Power Management {{{
xorgdpms() {
	STATE=on
	if xset q | grep -q "Off: 3"; then
		STATE=off
	fi

	if [ -z "$1" ]; then
		printf %s "$STATE"
	elif [ "$1" = off ] && [ "$STATE" != off ]; then
		xset dpms 0 0 3
		xset dpms force off
	elif [ "$1" = on ] && [ "$STATE" != on ]; then
		xset dpms 0 0 0
		xset dpms force on
	fi
}

wldpms() {
	STATE=on
	if ! wlopm | grep -q "on"; then
		STATE=off
	fi

	if [ -z "$1" ]; then
		printf %s "$STATE"
	elif [ "$1" = on ] && [ "$STATE" != on ]; then
		wlopm --on "*"
	elif [ "$1" = off ] && [ "$STATE" != off ] ; then
		wlopm --off "*"
	fi
}
# }}}

# inputevent {{{
xorginputevent() {
	if [ "$1" = "touchscreen" ]; then
		TOUCH_POINTER_ID="$SXMO_TOUCHSCREEN_ID"
	elif [ "$1" = "stylus" ]; then
		TOUCH_POINTER_ID="$SXMO_STYLUS_ID"
	fi

	STATE=off
	if xinput list-props "$TOUCH_POINTER_ID" | \
		grep "Device Enabled" | \
		grep -q "1$"; then
		STATE=on
	fi

	if [ -z "$2" ]; then
		printf %s "$STATE"
	elif [ "$2" = on ] && [ "$STATE" != on ]; then
		xinput enable "$TOUCH_POINTER_ID"
	elif [ "$2" = off ] && [ "$STATE" != off ] ; then
		xinput disable "$TOUCH_POINTER_ID"
	fi
}

swayinputevent() {
	if [ "$1" = "touchscreen" ]; then
		TOUCH_POINTER_ID="touch"
	elif [ "$1" = "stylus" ]; then
		TOUCH_POINTER_ID="tablet_tool"
	fi

	# If we dont have any matching input
	if ! swaymsg -t get_inputs \
		| jq -r ".[] | select(.type == \"$TOUCH_POINTER_ID\" )" \
		| grep -q .; then

		if [ -z "$2" ]; then
			printf "not found"
			exit 0
		else
			exit 0
		fi
	fi

	STATE=on
	if swaymsg -t get_inputs \
		| jq -r ".[] | select(.type == \"$TOUCH_POINTER_ID\" ) | .libinput.send_events" \
		| grep -q "disabled"; then
		STATE=off
	fi

	if [ -z "$2" ]; then
		printf %s "$STATE"
	elif [ "$2" = on ] && [ "$STATE" != on ]; then
		swaymsg -- input type:"$TOUCH_POINTER_ID" events enabled
	elif [ "$2" = off ] && [ "$STATE" != off ] ; then
		swaymsg -- input type:"$TOUCH_POINTER_ID" events disabled
	fi
}
# }}}

# focusedwindow {{{
_xorgfocusedwindow() {
	xprop -id "$(xdotool getactivewindow 2>/dev/null)" 2>/dev/null | awk '
		/^WM_CLASS/ {
			sub(/^WM_CLASS[^=]*= ?"[^"]*", "/, "")
			sub(/"$/, "")
			class = $0
		}
		/^WM_NAME/ {
			sub(/^WM_NAME[^=]*= ?"/, "")
			sub(/"$/, "")
			title = $0
		}
		END { printf "%s\n%s\n", tolower(class), tolower(title) }
	'
}

_swi3_focusedwindow() {
	swi3msg -t get_tree | jq -r '
		recurse(.nodes[]) |
		select(.focused == true) |
		{
			app_id: (if .app_id != null then
					.app_id
				else
					.window_properties.class
				end) | gsub("\n"; "\\n") | ascii_downcase,
			name: (.name | gsub("\n"; "\\n") | ascii_downcase),
		} |
		select(.app_id != null and .name != null) |
		"\(.app_id)\n\(.name)"
	'
}

_raw_focusedwindow() {
	case "$SXMO_WM" in
		dwm) _xorgfocusedwindow ;;
		sway|i3) _swi3_focusedwindow ;;
		river) lswt -j | jq -r '
			.toplevels |
				map(select(.activated))[0] |
				(."app-id" | ascii_downcase), (.title | ascii_downcase)
		'
	esac
}

wm_generic_focusedwindow() {
	if [ "$1" = "-r" ]; then
		_raw_focusedwindow
	else
		# This script originally output this format, which is a bit
		# harder to parse. Keep it for backwards compatibility in case
		# anyone was using it.
		_raw_focusedwindow | {
			read -r app
			read -r title
			printf "app: %s\ntitle: %s\n" "$app" "$title"
		}
	fi
}
# }}}

# paste {{{
wlpaste() {
	wl-paste
}

xorgpaste() {
	xclip -o
}
# }}}

# exec {{{
wm_generic__swi3exec_inner() {
	cmd="$(cat "$1")"
	rm "$1"
	eval "$cmd"
}

swi3exec() {
	set -e

	cmdfile="$(mktemp)"
	jq -r --null-input '$ARGS.positional | @sh' --args -- "$@" > "$cmdfile"

	swi3msg exec "sxmo_wm.sh _swi3exec_inner '$cmdfile'" > /dev/null
}

riverexec() {
	riverctl spawn "$@"
}

xorgexec() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	"$@" &
}
# }}}

# execwait {{{
wm_generic__execwait_inner() {
	notify_file="$1/done"
	shift

	# This opens the pipe for writing, when this process exits it will be
	# closed, which will send eof to the monitoring process.
	exec 3>"$notify_file"

	"$@"
}

_execwait() {
	set -e
	runner="$1"
	shift

	notify_dir="$(mktemp -d)"
	mkfifo "$notify_dir/done"

	"$runner" sxmo_wm.sh _execwait_inner "$notify_dir" "$@"

	exec 3<"$notify_dir/done"

	# The exec line won't finish until the inner file has been opened for
	# writing, so it's safe to remove the temp dir here.
	rm -r "$notify_dir"

	# Wait for the notification file to be closed
	read -r _ <&3 || true
}

swi3execwait() {
	_execwait swi3exec "$@"
}

riverexecwait() {
	_execwait riverexec "$@"
}

xorgexecwait() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	exec "$@"
}
# }}}

# toggle layout {{{
swi3togglelayout() {
	swi3msg layout toggle splith splitv tabbed
}

xorgtogglelayout() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	xdotool key --clearmodifiers key Super+space
}

rivertogglelayout() {
	riverctl toggle-fullscreen
}
# }}}

# switch focus {{{
i3switchfocus() {
	sxmo_wmmenu.sh i3windowswitcher
}

swayswitchfocus() {
	sxmo_wmmenu.sh swaywindowswitcher
}

xorgswitchfocus() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	xdotool key --clearmodifiers Super+x
}
# }}}

# workspace switching {{{
_swi3getcurrentworkspace() {
	swi3msg -t get_workspaces | jq -r '.[] | select(.focused).name'
}

_swi3getnextworkspace() {
	value="$(($(_swi3getcurrentworkspace)+1))"
	if [ "$value" -eq "$((${SXMO_WORKSPACE_WRAPPING:-4}+1))" ]; then
		printf 1
	else
		printf %s "$value"
	fi
}

_swi3getpreviousworkspace() {
	value="$(($(_swi3getcurrentworkspace)-1))"
	if [ "$value" -lt 1 ]; then
		if [ "${SXMO_WORKSPACE_WRAPPING:-4}" -ne 0 ]; then
			printf %s "${SXMO_WORKSPACE_WRAPPING:-4}"
		else
			return 1 # cant have previous workspace
		fi
	else
		printf %s "$value"
	fi
}

swi3nextworkspace() {
	swi3msg "workspace $(_swi3getnextworkspace)"
}

rivernextworkspace() {
	river-shifttags
}

xorgnextworkspace() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	xdotool key --clearmodifiers Super+Shift+r
}

swi3previousworkspace() {
	swi3msg -- workspace "$(_swi3getpreviousworkspace )"
}

xorgpreviousworkspace() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	xdotool key --clearmodifiers Super+Shift+e
}

riverpreviousworkspace() {
	river-shifttags --shift -1
}

swi3movenextworkspace() {
	swi3msg "move container to workspace $(_swi3getnextworkspace)"
}

xorgmovenextworkspace() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	xdotool key --clearmodifiers Super+r
}

swi3movepreviousworkspace() {
	swi3msg -- move container to workspace "$(_swi3getpreviousworkspace )"
}

xorgmovepreviousworkspace() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	xdotool key --clearmodifiers Super+e
}

swi3workspace() {
	swi3msg "workspace $1"
}

riverworkspace() {
	tags=$((1 << ($1 - 1)))
	riverctl set-focused-tags "$tags"
}

xorgworkspace() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	xdotool key --clearmodifiers "Super+$1"
}

swi3moveworkspace() {
	swi3msg "move container to workspace $1"
}

rivermoveworkspace() {
	tags=$((1 << ($1 - 1)))
	riverctl set-view-tags "$tags"
}

xorgmoveworkspace() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	xdotool key --clearmodifiers "Super+shift+$1"
}
# }}}

# toggle bar {{{
swi3togglebar() {
	swi3msg bar mode toggle
}

xorgtogglebar() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	xdotool key --clearmodifiers "Super+b"
}

rivertogglebar() {
	if superctl status sxmo_riverbar | grep -q started; then
		superctl stop sxmo_riverbar
	else
		superctl start sxmo_riverbar
	fi
}
# }}}

# configmenuentry {{{
wm_generic_configmenuentry() {
	case "$SXMO_WM" in
		dwm)
			printf "%s\n" "$icon_cfg Edit configuration ^ 0 ^ sxmo_terminal.sh $EDITOR $XDG_CONFIG_HOME/sxmo/xinit"
			;;
		i3)
			printf "%s\n" "$icon_cfg Edit configuration ^ 0 ^ sxmo_terminal.sh $EDITOR $XDG_CONFIG_HOME/sxmo/i3"
			;;
		river)
			printf "%s\n" "$icon_cfg Edit configuration ^ 0 ^ sxmo_terminal.sh $EDITOR $XDG_CONFIG_HOME/sxmo/river"
			;;
		sway)
			printf "%s\n" "$icon_cfg Edit configuration ^ 0 ^ sxmo_terminal.sh $EDITOR $XDG_CONFIG_HOME/sxmo/sway"
			;;
	esac
}
# }}}

dispatch() {
	action="$1"
	shift

	# invoke action covering single wm
	if type "$SXMO_WM$action" >/dev/null 2>&1; then
		"$SXMO_WM$action" "$@"
		return
	fi

	# invoke action covering multiple wms
	if [ "$SXMO_WM" = "sway" ] || [ "$SXMO_WM" = "i3" ]; then
		if type "swi3$action" >/dev/null 2>&1; then
			"swi3$action" "$@"
			return
		fi
	fi

	# invoke action covering all of xorg/wayland
	case "$SXMO_WM" in
		dwm|i3)
			if type "xorg$action" >/dev/null 2>&1; then
				"xorg$action" "$@"
				return
			fi
			;;
		sway|river)
			# We don't yet support everything
			if type "wl$action" >/dev/null 2>&1; then
				"wl$action" "$@"
				return
			fi
			;;
	esac

	# invoke action covering all wms
	if type "wm_generic_$action" >/dev/null 2>&1; then
		"wm_generic_$action" "$@"
		return
	else
		printf "%s not implemented for %s\n" "$action" "$SXMO_WM" >&2
		return 1
	fi
}

dispatch "$@"
