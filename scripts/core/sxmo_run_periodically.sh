#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

usage() {
	cat <<-EOF >&2
		Usage: $(basename "$0") [-w] [-c <clock-name>] <timeout> [--] <cmd...>
	EOF
	exit 1
}

while [ -n "$*" ]; do
	case "$1" in
		"--")
			shift
			break;
			;;
		"-w")
			waitfirst=1
			shift
			;;
		"-c")
			clockname="$2"
			shift 2
			;;
		*)
			if [ -n "$timeout" ]; then
				break;
			fi
			timeout="$1"
			shift
			;;
	esac
done

if [ -z "$timeout" ] || [ -z "$*" ]; then
	usage
fi

finish() {
	trap - INT TERM
	jobs -p | xargs -r kill
	wait
	exit
}

trap 'finish' INT TERM

if [ -n "$waitfirst" ]; then
	sxmo_sleep ${clockname:+-c $clockname} "$timeout" &
	wait $!
	ret=$?
	if [ $ret -ne 0 ]; then
		exit $ret
	fi
fi

while : ; do
	"$@" &
	wait $!
	ret=$?
	if [ $ret -ne 0 ]; then
		exit $ret
	fi

	sxmo_sleep ${clockname:+-c $clockname} "$timeout" &
	wait $!
	ret=$?
	if [ $ret -ne 0 ]; then
		exit $ret
	fi
done
