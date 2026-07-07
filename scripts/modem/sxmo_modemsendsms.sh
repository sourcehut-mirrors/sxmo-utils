#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors
# shellcheck disable=SC3045

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

set -e

info() {
	sxmo_log "$*"
	printf "%s\n" "$*"
}

err() {
	info "$*"
	return 1
}

if [ 0 -eq $# ]; then
	printf "Usage: %s number|contact [-|message]\n" "$(basename "$0")"
	return 1
fi
NUMBER="$1"

make_attachments_arg() {
	MAX_SIZE="$(grep "^TotalMaxAttachmentSize" "$MMS_BASE_DIR/mms" | cut -d'=' -f2)"
	MAX_NUMBER="$(grep "^MaxAttachments" "$MMS_BASE_DIR/mms" | cut -d'=' -f2)"
	if [ -z "$MAX_NUMBER" ]; then
		MAX_NUMBER="25"
	fi
	if [ -z "$MAX_SIZE" ]; then
		MAX_SIZE="1100000"
	fi

	ATT_NUM=0
	TOTAL_SIZE=0
	while read -r ATTACHMENT; do
		if ! [ -f "$ATTACHMENT" ]; then
			err "Attachment ($ATTACHMENT) not found!"
		fi
		CTYPE=$(file -b --mime-type "$ATTACHMENT")
		# The 'file' command returns longer mime-types than mmsctl
		# likes, so convert those (if any) here. I have only tested mp3
		# (which needs to be converted) and jpeg (which does not).
		case "$CTYPE" in
			"audio/mpegapplication/octet-stream")
				CTYPE="audio/mpeg"
				;;
		esac

		# basic mms error checking (since mmsctl does not do it)
		ATT_NUM="$((ATT_NUM+1))"
		TOTAL_SIZE="$((TOTAL_SIZE+$(wc -c < "$ATTACHMENT")))"
		if [ "$ATT_NUM" -gt "$MAX_NUMBER" ]; then
			err "Number of attachments ($ATT_NUM) greater than MaxAttachments ($MAX_NUMBER)."
		fi
		if [ "$ATT_NUM" -ge 1 ] && [ "$TOTAL_SIZE" -gt "$MAX_SIZE" ]; then
			err "Total size of attachments ($TOTAL_SIZE) greater than TotalMaxAttachmentSize ($MAX_SIZE)."
		fi
		printf " -a '%s' -c '%s'" "$ATTACHMENT" "$CTYPE"
	done < "$SXMO_LOGDIR/$NUMBER/draft.attachments.txt"
}

# if number does not start with + assume it is a contact name, and if it isn't
# in our contacts book, then alert the user but continue anyway, e.g., one
# might send a message to "2600" or something.
if ! printf "%b\n" "$NUMBER" | grep -q '^+'; then
	ACTUAL_NUMBER="$(sxmo_contacts.sh "^$NUMBER:" | \
		cut -d':' -f2 | sed 's/^ //')"
	if [ -z "$ACTUAL_NUMBER" ]; then
		info "WARNING: $NUMBER does not look like a phone number or a contact."
	else
		NUMBER="$ACTUAL_NUMBER"
	fi
fi

finish() {
	if [ -n "$TMPFILE" ]; then
		rm "$TMPFILE"
	fi
	exit
}
trap 'finish' INT TERM EXIT

if [ "-" = "$2" ]; then
	TMPFILE="$(mktemp)"
	TEXTFILE="$TMPFILE"
	awk 'NR > 1 { print prev } { prev=$0 } END { ORS=""; print }' > "$TEXTFILE"
elif [ "-f" = "$2" ]; then
	TMPFILE="$(mktemp)"
	awk 'NR > 1 { print prev } { prev=$0 } END { ORS=""; print }' "$3" > "$TMPFILE"
	TEXTFILE="$TMPFILE"
else
	shift
	[ 0 -eq $# ] && usage

	TMPFILE="$(mktemp)"
	TEXTFILE="$TMPFILE"
	printf "%s" "$*" > "$TEXTFILE"
fi
TEXT="$(cat "$TEXTFILE")"

# ensure we use the correct NUMBER directory
# (e.g., if multiple recipients, sort numerically)
NUMBER="$(pnc find "$NUMBER" | sort -u)"

# if multiple recipients or attachment, then send via mmsctl
if [ "$(printf '%b\n' "$NUMBER" | wc -l)" -gt 1 ] \
		|| [ -f "$SXMO_LOGDIR/$NUMBER/draft.attachments.txt" ]; then

	MMS_BASE_DIR="${SXMO_MMS_BASE_DIR:-"$HOME"/.mms/modemmanager}"
	if ! [ -d "$MMS_BASE_DIR" ]; then
		err "MMS not configured."
	fi

	NUMBER="$(printf '%b\n' "$NUMBER" | sort -u | tr -d '\n')"

	# -a 'filename' -c 'content/type' -a 'filename2' -c 'content/type'
	if [ -f "$SXMO_LOGDIR/$NUMBER/draft.attachments.txt" ]; then
		ATTACHMENTS_ARG="$(make_attachments_arg)"
	fi

	# -a 'tmpfile' for message content
	ATTACHMENTS_ARG="-a '$TEXTFILE' $ATTACHMENTS_ARG"

	# -r +123 -r +345
	RECIPIENTS_ARG="$(printf %s "$NUMBER" | sed 's/+/ -r +/g' | sed 's/^ //')"

	# Send it to mmsd-tng via mmsctl.  We can't use dbus-send since
	# dbus-send doesn't recognize a(sss) types.
	info "mmsctl -S $RECIPIENTS_ARG $ATTACHMENTS_ARG"
	if ! MMSCTL_RES="$(eval mmsctl -S "$RECIPIENTS_ARG" "$ATTACHMENTS_ARG")"; then
		err "mmsctl failed with \"$MMSCTL_RES\""
	fi

	# mmsd-tng should immediately add a message of status 'draft' and then
	# after a few beats it will send it and transform that message to
	# 'sent'.
	info "Waiting for mmsd-tng to send..."
	MMS_PIPE="$(mktemp -u)"
	mkfifo "$MMS_PIPE"
	timeout 60 dbus-monitor "interface='org.ofono.mms.Message',type='signal',member='PropertyChanged'" > "$MMS_PIPE" &
	MMS_PIPE_PID="$!"
	while read -r line; do
		if printf %s "$line" | grep -q 'member=PropertyChanged'; then
			MESSAGE_PATH="$(printf "%b\n" "$line" | cut -d'=' -f6 | cut -d';' -f1)"
		fi
		if printf %s "$line" | grep -q "string \"sent\""; then
			SENT_SUCCESS=1
			break
		fi
	done < "$MMS_PIPE"
	kill "$MMS_PIPE_PID"
	wait "$MMS_PIPE_PID" || true
	rm -f "$NAMED_PIPE"

	if [ -z "$SENT_SUCCESS" ]; then
		err "mmsd-tng did not send the draft."
	fi

	if [ -f "$SXMO_LOGDIR/$NUMBER/draft.attachments.txt" ]; then
		rm -f "$SXMO_LOGDIR/$NUMBER/draft.attachments.txt"
	fi

	# process it just like any other mms (this will handle logging it)
	sxmo_mms.sh processmms "$MESSAGE_PATH"

	MMS_FILE="$(basename  "$MESSAGE_PATH")"
	CONTACTNAME="$(sxmo_contacts.sh --name-or-number "$NUMBER")"
	sxmo_hook_sendsms.sh "$CONTACTNAME" "$TEXT" "$MMS_FILE" "$CONTACTNAME"

	info "Sent mms text to $CONTACTNAME."

# we are dealing with a normal sms, so use mmcli
else
	TEXTSIZE="${#TEXT}"

	SMSNO="$(mmcli -m any \
		--messaging-create-sms-with-text="$TEXTFILE" \
		--messaging-create-sms="number=$NUMBER" |
		grep -o "[0-9]*$"
	)"

	if ! SMS_RES="$(mmcli -s "${SMSNO}" --send \
			--timeout="${SXMO_MM_TIMEOUT:-"30"}" 2>&1)"; then
		# if we fail to send due to a bad number,
		# clear it from the modem
		if printf "%b\n" "$SMS_RES" | grep -q "Invalid number"; then
			for i in $(mmcli -m any --messaging-list-sms \
					| grep " (unknown)" | cut -f5 -d' '); do
				if mmcli -m any -s "$i" -K | grep -q "not requested"; then
					mmcli -m any --messaging-delete-sms="$i" >/dev/null
				fi
			done
			err "Couldn't send text message: Invalid number."
		else
			err "Couldn't send text message ($SMS_RES)"
		fi
	fi

	# we sent it successfully, but also clear it from the modem
	for i in $(mmcli -m any --messaging-list-sms \
			| grep " (sent)" | cut -f5 -d' ') ; do
		mmcli -m any --messaging-delete-sms="$i" > /dev/null
	done

	TIME="$(date +%FT%H:%M:%S%z)"
	mkdir -p "$SXMO_LOGDIR/$NUMBER"
	sxmo_hook_smslog.sh "sent" "$NUMBER" "$NUMBER" "$TIME" "$TEXT" \
		>> "$SXMO_LOGDIR/$NUMBER/sms.txt"
	printf "%s\tsent_txt\t%s\t%s chars\n" "$TIME" "$NUMBER" "$TEXTSIZE" \
		>> "$SXMO_LOGDIR/modemlog.tsv"

	CONTACTNAME="$(sxmo_contacts.sh --name-or-number "$NUMBER")"
	sxmo_hook_sendsms.sh "$CONTACTNAME" "$TEXT"
	info "Sent sms text to $CONTACTNAME."
fi
