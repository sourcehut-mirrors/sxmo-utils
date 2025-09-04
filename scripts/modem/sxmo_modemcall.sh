#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# include common definitions
# shellcheck source=configs/default_hooks/sxmo_hook_icons.sh
. sxmo_hook_icons.sh
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

# We use this directory to store states, so it must exist
mkdir -p "$XDG_RUNTIME_DIR/sxmo_calls"

set -e

vid_to_number() {
	mmcli -m any -o "$1" -K | \
		grep call.properties.number | \
		cut -d ':' -f2 | \
		tr -d  ' '
}

log_event() {
	EVT_HANDLE="$1"
	EVT_VID="$2"

	NUM="$(vid_to_number "$EVT_VID")"
	TIME="$(date +%FT%H:%M:%S%z)"

	mkdir -p "$SXMO_LOGDIR"
	printf %b "$TIME\t$EVT_HANDLE\t$NUM\n" >> "$SXMO_LOGDIR/modemlog.tsv"
}

pickup() {
	CALLID="$1"

	DIRECTION="$(
		mmcli --voice-status -o "$CALLID" -K |
		grep call.properties.direction |
		cut -d: -f2 |
		tr -d " "
	)"
	case "$DIRECTION" in
		outgoing)
			if ! sxmo_modemaudio.sh setup_audio; then
				sxmo_notify_user.sh --urgency=critical "We failed to setup call audio"
				return 1
			fi

			if ! mmcli -m any -o "$CALLID" --start; then
				sxmo_notify_user.sh --urgency=critical "We failed to start the call"
				return 1
			fi

			sxmo_notify_user.sh "Started call"
			touch "$XDG_RUNTIME_DIR/sxmo_calls/${CALLID}.initiatedcall"
			log_event "call_start" "$CALLID"
			;;
		incoming)
			sxmo_log "Invoking pickup hook"
			sxmo_hook_pickup.sh

			if ! sxmo_modemaudio.sh setup_audio; then
				sxmo_notify_user.sh --urgency=critical "We failed to setup call audio"
				return 1
			fi

			if ! mmcli -m any -o "$CALLID" --accept; then
				sxmo_notify_user.sh --urgency=critical "We failed to accept the call"
				return 1
			fi

			sxmo_notify_user.sh "Picked up call"
			touch "$XDG_RUNTIME_DIR/sxmo_calls/${CALLID}.pickedupcall"
			log_event "call_pickup" "$CALLID"
			;;
		*)
			sxmo_notify_user.sh --urgency=critical "Couldn't initialize call with callid <$CALLID>; unknown direction <$DIRECTION>"
			# if we try to make an outgoing call while
			# already on an outgoing call, it crashes the modem and
			# gets us here.  We need to rm -rf
			# $XDG_RUNTIME_DIR/sxmo_call/* before we can call
			# again.
			#
			rm "$XDG_RUNTIME_DIR/sxmo_calls/"* 2>/dev/null || true
			rm -f "$XDG_RUNTIME_DIR"/sxmo.ring.pid 2>/dev/null
			rm -f "$SXMO_NOTIFDIR"/incomingcall* 2>/dev/null
			return 1
			;;
	esac
}

hangup() {
	CALLID="$1"

	if [ -f "$XDG_RUNTIME_DIR/sxmo_calls/${CALLID}.pickedupcall" ] || \
		[ -f "$XDG_RUNTIME_DIR/sxmo_calls/${CALLID}.initiatedcall" ]; then

		rm -f "$XDG_RUNTIME_DIR/sxmo_calls/${CALLID}.pickedupcall" \
			"$XDG_RUNTIME_DIR/sxmo_calls/${CALLID}.initiatedcall"
		touch "$XDG_RUNTIME_DIR/sxmo_calls/${CALLID}.hangedupcall"
		log_event "call_hangup" "$CALLID"

		sxmo_log "sxmo_modemcall: Invoking hangup hook"
		sxmo_hook_hangup.sh
	else
		#this call was never picked up and hung up immediately, so it is a discarded call
		touch "$XDG_RUNTIME_DIR/sxmo_calls/${CALLID}.discardedcall"
		log_event "call_discard" "$CALLID"

		sxmo_log "sxmo_modemcall: Invoking discard hook"
		sxmo_hook_discard.sh
	fi

	if ! mmcli -m any -o "$CALLID" --hangup; then
		# we ignore already closed calls
		if list_active_calls | grep -q "/$CALLID "; then
			sxmo_notify_user.sh --urgency=critical "We failed to hangup the call"
			return 1
		fi
	fi
}

# We shallow muted/blocked and terminated calls
list_active_calls() {
	mmcli -m any --voice-list-calls | \
		awk '$1=$1' | \
		grep -v terminated | \
		grep -v "No calls were found" | while read -r line; do
			CALLID="$(printf "%s\n" "$line" | awk '$1=$1' | cut -d" " -f1 | xargs basename)"
			if [ -e "$XDG_RUNTIME_DIR/sxmo_calls/${CALLID}.mutedring" ]; then
				continue # we shallow muted calls
			fi
			printf "%s\n" "$line"
	done
}

incall_menu() {
	# Note that mute mic does NOT actually work:
	# See: https://gitlab.com/mobian1/callaudiod/-/merge_requests/10

	# We have an active call
	while list_active_calls | grep -q . ; do
		CHOICES="$(grep . <<EOF
$icon_cls Close menu                ^ exit
$icon_aru Volume ($(sxmo_audio.sh vol get)) ^ sxmo_audio.sh vol up 20
$icon_ard Volume  ^ sxmo_audio.sh vol down 20
$icon_cfg Audio Settings ^ sxmo_audio.sh
$(
	cards="$(pactl -f json list cards | jq -r '.[] | select(any(.profiles | keys[]; startswith("Voice Call")))')"
	printf "%s\n" "$cards" | jq -r '[.name, .active_profile] | @tsv' | \
		while IFS="	" read -r card active_profile; do
		printf "%s %s\n" "$icon_nte" "$card"
		printf "%s\n" "$cards" | jq -r "select(.name == \"$card\") | .profiles | to_entries[] | select(.value.available) | select(.key | startswith(\"Voice Call\")) | [.key, .value.description] | @tsv" | \
			while IFS="	" read -r profile desc; do
			if [ "$profile" = "$active_profile" ]; then
				printf "%s %s ^ true\n" "$icon_chk" "$desc"
			else
				printf "  %s ^ pactl set-card-profile %s \"%s\"\n" "$desc" "$card" "$profile"
			fi
		done
	done

	default_sink="$(pactl get-default-sink)"
	sink="$(pactl --format=json list sinks | jq -r ".[] | select(.name == \"$default_sink\" )")"
	active_port="$(printf "%s\n" "$sink" | jq -r .active_port)"
	ports="$(printf "%s\n" "$sink" | jq -r '.ports[] | select(.availability != "not available")')"
	printf "%s\n" "$ports" | jq -r '[.name, .description] | @tsv' | \
		while IFS="	" read -r name desc; do
		if [ "$name" = "$active_port" ]; then
			printf "%s %s ^ true\n" "$icon_ton" "$desc"
		else
			printf "%s %s ^ pactl set-sink-port @DEFAULT_SINK@ \"%s\"\n" "$icon_tof" "$desc" "$name"
		fi
	done
)
$(
	list_active_calls | while read -r line; do
		CALLID="$(printf %s "$line" | cut -d" " -f1 | xargs basename)"
		NUMBER="$(vid_to_number "$CALLID")"
		CONTACT="$(sxmo_contacts.sh --name-or-number "$NUMBER")"
		case "$line" in
			*"(ringing-in)")
				# TODO switch to this call
				printf "%s Hangup %s ^ hangup %s\n" "$icon_phx" "$CONTACT" "$CALLID"
				printf "%s Ignore %s ^ mute %s\n" "$icon_phx" "$CONTACT" "$CALLID"
				;;
			*"(held)")
				# TODO switch to this call
				printf "%s Hangup %s ^ hangup %s\n" "$icon_phx" "$CONTACT" "$CALLID"
				;;
			*)
				printf "%s DTMF Tones %s ^ sxmo_terminal.sh sxmo_dtmf.sh %s\n" "$icon_mus" "$CONTACT" "$CALLID"
				printf "%s Hangup %s ^ hangup %s\n" "$icon_phx" "$CONTACT" "$CALLID"
				;;
		esac
	done
)
EOF
	)"


		PICKED="$(
			printf "%s\n" "$CHOICES" |
				cut -d'^' -f1 |
				sxmo_dmenu.sh --show-over-lockscreen -i -p "Incall Menu"
		)" || exit

		sxmo_log "Picked is $PICKED"

		CMD="$(printf "%s\n" "$CHOICES" | grep "$PICKED" | cut -d'^' -f2)"

		sxmo_log "Eval in call context: $CMD"
		eval "$CMD" || exit 1
	done & # To be killeable
	wait
}

mute() {
	CALLID="$1"

	# this signals that we muted this ring
	touch "$XDG_RUNTIME_DIR/sxmo_calls/${CALLID}.mutedring"
	sxmo_log "Invoking mute_ring hook"
	sxmo_hook_mute_ring.sh
	log_event "ring_mute" "$1"
}

incoming_call_menu() {
	NUMBER="$(vid_to_number "$1")"
	NUMBER="$(sxmo_modem.sh cleanupnumber "$NUMBER")"
	CONTACTNAME="$(sxmo_contacts.sh --name-or-number "$NUMBER")"

	MENU_OPTS=""
	if [ "$SXMO_WM" = "sway" ]; then
		case "$SXMO_MENU" in
			bemenu)
				MENU_OPTS="-H 40 -l 3"
				;;
			wofi)
				MENU_OPTS="-L 3"
				;;
			dmenu)
				MENU_OPTS="-l 3"
				;;
		esac
	else
		case "$SXMO_MENU" in
			bemenu)
				MENU_OPTS="-H 100 -l 3"
				;;
			dmenu)
				MENU_OPTS="-l 3"
				;;
		esac
	fi

	(
		# shellcheck disable=SC2086
		#  (MENU_OPTS is not quoted because we want to split args here)
		PICKED="$(
			cat <<EOF | sxmo_dmenu.sh --show-over-lockscreen -i $MENU_OPTS -p "$CONTACTNAME"
$icon_phn Pickup
$icon_phx Hangup
$icon_mut Ignore
EOF
		)" || exit

		case "$PICKED" in
			"$icon_phn Pickup")
				if ! pickup "$1"; then
					sxmo_notify_user.sh --urgency=critical "We failed to pickup the call"
					sxmo_modemaudio.sh reset_audio
					return 1
				fi

				incall_menu
				;;
			"$icon_phx Hangup")
				hangup "$1"
				;;
			"$icon_mut Ignore")
				mute "$1"
				;;
		esac
	) & # To be killeable
	wait
}

killed() {
	sxmo_dmenu.sh close
}
if [ "$1" = "incall_menu" ] || [ "$1" = "incoming_call_menu" ]; then
	trap 'killed' TERM INT
fi

"$@"
