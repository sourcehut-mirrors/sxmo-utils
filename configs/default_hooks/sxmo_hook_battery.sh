#!/bin/sh

load_data() {
	dbus_data="$(dbus-send --print-reply --system --dest=org.freedesktop.UPower "$object" org.freedesktop.DBus.Properties.GetAll string:org.freedesktop.UPower.Device)"

	dbus_data_properties="$(awk 'c&&c--;/Percentage/||/State/||/Type/||/NativePath/{c=1}' <<-EOF
		$dbus_data
	EOF
	)"

	# see upower dbus interface for uinit32 meanings
	# below awk will print out as follows:
	#string "NativePath"
	#string "Type" (2 is battery)
	#string "Percentage"
	#string "State"
	property_data="$(awk '{gsub(/"/, ""); print $3}' <<-EOF
		$dbus_data_properties
	EOF
	)"

	for varname in native_path device_type percentage number_state; do
		read -r "${varname?}"
	done <<-EOF
		$property_data
	EOF

	while read -r number state; do
		if [ "$number" -eq "${number_state:?}" ]; then
			break
		fi
	done <<-EOF
		0 unknown
		1 charging
		2 discharging
		3 empty
		4 fully-charged
		5 pending-charge
		6 pending-discharge
	EOF
}

SET_LED_PATH="$XDG_RUNTIME_DIR/sxmo_hook_battery_set_led"

object="$1"

load_data "$object"

# Test for battery
if [ "${device_type:?}" != "2" ]; then
	exit
fi

if [ "${state:?}" = "unknown" ]; then
	exit
fi

if [ "${percentage:?}" -lt 25 ] && [ ! -f "$SET_LED_PATH" ]; then
	touch "$SET_LED_PATH"
	sxmo_led.sh set red 100
elif [ -f "$SET_LED_PATH" ]; then
	rm "$SET_LED_PATH"
	sxmo_led.sh set red 0
fi

sxmo_hook_statusbar.sh battery "${native_path:?}" "$state" "$percentage"
