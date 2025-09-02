#!/bin/sh

# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

ca_dbus_get_prop() {
	dbus-send --session --print-reply --dest=org.mobian_project.CallAudio \
		--reply-timeout=2500 /org/mobian_project/CallAudio org.freedesktop.DBus.Properties.Get \
		string:org.mobian_project.CallAudio string:"$1"
}

ca_dbus_set_prop() {
	dbus-send --session --print-reply --type=method_call \
		--reply-timeout=2500 --dest=org.mobian_project.CallAudio \
		/org/mobian_project/CallAudio org.mobian_project.CallAudio."$1" "$2" |\
		grep -q "boolean true" && return 0 || return 1
}

enable_call_audio_mode() {
	if ca_dbus_set_prop SelectMode uint32:1; then
		sxmo_log "Successfully enabled call audio mode."
		sxmo_hook_statusbar.sh volume
	else
		sxmo_notify_user.sh "Failed to enable call audio mode."
		return 1
	fi
}

disable_call_audio_mode() {
	if ca_dbus_set_prop SelectMode uint32:0; then
		sxmo_log "Successfully disabled call audio mode."
		sxmo_hook_statusbar.sh volume
	else
		sxmo_notify_user.sh "Failed to disable call audio mode."
		return 1
	fi
}

setup_audio() {
	if ! enable_call_audio_mode; then
		return 1
	fi
}

reset_audio() {
	if ! disable_call_audio_mode; then
		return 1
	fi
}

# Swallow with Wireplumber 0.5.11
if pactl -f json info | jq -r .server_name | grep -q PipeWire; then
	exit
fi

"$@"
