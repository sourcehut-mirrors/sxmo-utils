#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

MODEM="$1"
TYPE="$2"
MESSAGE="$3"

MM_IFACE="org.freedesktop.ModemManager1"
DBUS_PROP_IFACE="org.freedesktop.DBus.Properties"
USSD_IFACE="org.freedesktop.ModemManager1.Modem.Modem3gpp.Ussd"

STATE=$(busctl --json=short call "$MM_IFACE" "$MODEM" "$DBUS_PROP_IFACE" Get ss "$USSD_IFACE" State | jq -r '.data[].data')

if [ "$TYPE" = "NetworkNotification" ] || [ "$TYPE" = "NetworkRequest" ]; then
	MESSAGE=$(busctl --json=short call "$MM_IFACE" "$MODEM" "$DBUS_PROP_IFACE" Get ss "$USSD_IFACE" "$TYPE" | jq -r '.data[].data')
fi

echo "$MESSAGE"
read -r entry

if [ "$STATE" = "3" ]; then
	CHOICE=$(printf "Send: %s\nEnd USSD dialog" "$entry" | sxmo_dmenu.sh -p "Reply")

	case "$CHOICE" in
		*"End USSD dialog"*)
			busctl --json=short call "$MM_IFACE" "$MODEM" "$USSD_IFACE" Cancel > /dev/null
			;;
		*)
			busctl --json=short call "$MM_IFACE" "$MODEM" "$USSD_IFACE" Respond s "$CHOICE" > /dev/null
			;;
	esac
fi
