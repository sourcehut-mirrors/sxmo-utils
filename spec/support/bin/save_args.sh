#!/bin/sh

exec 2>/tmp/log.txt
set -x
file="$1"
shift
printf "<%s> " "$@" >"$file"
