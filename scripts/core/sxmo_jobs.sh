#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

ROOT="$XDG_RUNTIME_DIR/sxmo_jobs"
mkdir -p "$ROOT"

exec 3<> "$XDG_RUNTIME_DIR/sxmo.jobs.lock"
flock -x 3

list() {
	find "$ROOT" -mindepth 1 -exec 'basename' '{}' ';'
}

stop() {
	while [ "$#" -gt 0 ]; do
		case "$1" in
			-f)
				force=1
				shift
				;;
			*)
				id="$1"
				shift
				break
				;;
		esac
	done

	case "$id" in
		all)
			list | while read -r sub_id; do
				stop "$sub_id"
			done
			;;
		*)
			if [ -f "$ROOT/$id.group" ]; then
				sxmo_debug "stop group $id"
				pid="$(cat "$ROOT/$id.group")"
				kill ${force:+-9} -- "-$pid" 2> /dev/null
			elif [ -f "$ROOT/$id" ]; then
				sxmo_debug "stop $id"
				pid="$(cat "$ROOT"/"$id")"
				kill ${force:+-9} "$pid" 2> /dev/null
			fi

			rm "$ROOT/$id" "$ROOT/$id.group" 2>/dev/null || true
			;;
	esac
}

signal() {
	id="$1"
	shift

	if [ -f "$ROOT/$id" ]; then
		sxmo_debug "signal $id $*"
		xargs kill "$@" < "$ROOT"/"$id" 2> /dev/null
	fi
}

start() {
	while [ "$#" -gt 0 ]; do
		case "$1" in
			--no-restart)
				no_restart=1
				shift
				;;
			--group)
				has_group=1
				shift
				;;
			*)
				id="$1"
				shift
				break
				;;
		esac
	done

	if [ -n "$has_group" ]; then
		groupfile="$ROOT/$id.group"
	else
		groupfile="/dev/null"
	fi

	if [ -f "$ROOT/$id" ]; then
		if [ -n "$no_restart" ]; then
			sxmo_debug "$id already running"
			exit 1
		else
			stop "$id"
		fi
	fi

	sxmo_debug "start $id"
	# yes we know expressions don't expand, we want that to be done in the
	# nested shell
	# shellcheck disable=SC2016
	setsid sh -c '
		exec 3<&-
		echo $$ > "$1"
		cat /proc/self/stat | cut -d" " -f 6 > "$2"
		shift 2
		exec "$@"
	' sh "$ROOT/$id" "$groupfile" "$@" &
}

running() {
	while [ "$#" -gt 0 ]; do
		case "$1" in
			-q)
				quiet=1
				shift
				;;
			*)
				id="$1"
				shift
				;;
		esac
	done

	log() {
		if [ -z "$quiet" ]; then
			# shellcheck disable=SC2059
			printf "$@"
		fi
	}

	if [ -f "$ROOT/$id" ]; then
		pid="$(cat "$ROOT/$id")"
		if [ -d "/proc/$pid" ]; then
			log "%s is still running\n" "$id"
		else
			log "%s is not running anymore\n" "$id"
			exit 2
		fi
	else
		log "%s is not running\n" "$id"
		exit 1
	fi
}

"$@"
