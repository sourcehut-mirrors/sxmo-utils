#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

i3dpms() {
	xorgdpms "$@"
}

xorgdpms() {
	STATE=off
	if xset q | grep -q "Off: 3"; then
		STATE=on
	fi

	if [ -z "$1" ]; then
		printf %s "$STATE"
	elif [ "$1" = on ] && [ "$STATE" != on ]; then
		xset dpms 0 0 3
		xset dpms force off
	elif [ "$1" = off ] && [ "$STATE" != off ]; then
		xset dpms 0 0 0
		xset dpms force on
	fi
}

swaydpms() {
	STATE=off
	if ! swaymsg -t get_outputs \
		| jq ".[] | .dpms" \
		| grep -q "true"; then
		STATE=on
	fi

	if [ -z "$1" ]; then
		printf %s "$STATE"
	elif [ "$1" = on ] && [ "$STATE" != on ]; then
		swaymsg -- output '*' power false
	elif [ "$1" = off ] && [ "$STATE" != off ] ; then
		swaymsg -- output '*' power true
	fi

}

i3inputevent() {
	xorginputevent "$@"
}

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

xorgfocusedwindow() {
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

ipc_focusedwindow() {
	jq -r '
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

raw_focusedwindow() {
	case "$SXMO_WM" in
		dwm) xorgfocusedwindow ;;
		i3) i3-msg -t get_tree | ipc_focusedwindow ;;
		sway) swaymsg -t get_tree | ipc_focusedwindow ;;
	esac
}

focusedwindow() {
	if [ "$1" = "-r" ]; then
		raw_focusedwindow
	else
		# This script originally output this format, which is a bit
		# harder to parse. Keep it for backwards compatibility in case
		# anyone was using it.
		raw_focusedwindow | {
			read -r app
			read -r title
			printf "app: %s\ntitle: %s\n" "$app" "$title"
		}
	fi
}

i3paste () {
	xclip -o
}

swaypaste() {
	wl-paste
}

xorgpaste() {
	xclip -o
}

i3exec() {
	i3-msg exec -- "$@"
}

i3execwait() {
	PIDFILE="$(mktemp)"
	printf '"%s" & printf %%s "$!" > "%s"' "$*" "$PIDFILE" \
		| xargs -I{} i3-msg exec -- '{}'
	while : ; do
		sleep 0.5
		kill -0 "$(cat "$PIDFILE")" 2> /dev/null || break
	done
	rm "$PIDFILE"
}

swayexec() {
	swaymsg exec -- "$@"
}

swayexecwait() {
	PIDFILE="$(mktemp)"
	printf '"%s" & printf %%s "$!" > "%s"' "$*" "$PIDFILE" \
		| xargs -I{} swaymsg exec -- '{}'
	while : ; do
		sleep 0.5
		kill -0 "$(cat "$PIDFILE")" 2> /dev/null || break
	done
	rm "$PIDFILE"
}

xorgexec() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	"$@" &
}

xorgexecwait() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	exec "$@"
}

i3togglelayout() {
	i3-msg layout toggle splith splitv tabbed
}

swaytogglelayout() {
	swaymsg layout toggle splith splitv tabbed
}

xorgtogglelayout() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	xdotool key --clearmodifiers key Super+space
}

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

_i3getcurrentworkspace() {
	i3-msg -t get_workspaces | jq -r '.[] | select(.focused==true).name'
}

_i3getnextworkspace() {
	value="$(($(_i3getcurrentworkspace)+1))"
	if [ "$value" -eq "$((${SXMO_WORKSPACE_WRAPPING:-4}+1))" ]; then
		printf 1
	else
		printf %s "$value"
	fi
}

_i3getpreviousworkspace() {
	value="$(($(_i3getcurrentworkspace)-1))"
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

_swaygetcurrentworkspace() {
	swaymsg -t get_outputs  | \
		jq -r '.[] | select(.focused) | .current_workspace'
}

_swaygetnextworkspace() {
	value="$(($(_swaygetcurrentworkspace)+1))"
	if [ "$value" -eq "$((${SXMO_WORKSPACE_WRAPPING:-4}+1))" ]; then
		printf 1
	else
		printf %s "$value"
	fi
}

_swaygetpreviousworkspace() {
	value="$(($(_swaygetcurrentworkspace)-1))"
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

i3nextworkspace() {
	i3-msg "workspace $(_i3getnextworkspace)"
}

swaynextworkspace() {
	swaymsg "workspace $(_swaygetnextworkspace)"
}

xorgnextworkspace() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	xdotool key --clearmodifiers Super+Shift+r
}

i3previousworkspace() {
	_i3getpreviousworkspace | xargs -r i3-msg -- workspace
}

swaypreviousworkspace() {
	_swaygetpreviousworkspace | xargs -r swaymsg -- workspace
}

xorgpreviousworkspace() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	xdotool key --clearmodifiers Super+Shift+e
}

i3movenextworkspace() {
	i3-msg "move container to workspace $(_i3getnextworkspace)"
}

swaymovenextworkspace() {
	swaymsg "move container to workspace $(_swaygetnextworkspace)"
}

xorgmovenextworkspace() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	xdotool key --clearmodifiers Super+r
}

i3movepreviousworkspace() {
	_i3getpreviousworkspace | xargs -r i3-msg -- move container to workspace
}

swaymovepreviousworkspace() {
	_swaygetpreviousworkspace | xargs -r swaymsg -- move container to workspace
}

xorgmovepreviousworkspace() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	xdotool key --clearmodifiers Super+e
}

i3workspace() {
	i3-msg "workspace $1"
}

swayworkspace() {
	swaymsg "workspace $1"
}

xorgworkspace() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	xdotool key --clearmodifiers "Super+$1"
}

i3moveworkspace() {
	i3-msg "move container to workspace $1"
}

swaymoveworkspace() {
	swaymsg "move container to workspace $1"
}

xorgmoveworkspace() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	xdotool key --clearmodifiers "Super+shift+$1"
}

i3togglebar() {
	i3-msg bar mode toggle
}

swaytogglebar() {
	swaymsg bar mode toggle
}

xorgtogglebar() {
	if [ -z "$DISPLAY" ]; then
		export DISPLAY=:0
	fi
	xdotool key --clearmodifiers "Super+b"
}

action="$1"
shift

case "$action" in
	focusedwindow)
		focusedwindow "$@"
		exit
		;;
esac

case "$SXMO_WM" in
	dwm) "xorg$action" "$@";;
	*) "$SXMO_WM$action" "$@";;
esac
