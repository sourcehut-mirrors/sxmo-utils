#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh
# shellcheck source=configs/default_hooks/sxmo_hook_icons.sh
. sxmo_hook_icons.sh

set -e

SIMPLE_MODE=yes

controller="$(bluetoothctl list | grep "\[default\]" | cut -d" " -f2)"

_can_fail() {
	"$@" || notify-send "Something failed"
}

_ignore_fail() {
	if ! "$@"; then
		return
	fi
}

_device_list() {
	bluetoothctl devices | cut -d" " -f2 | while read -r mac; do
		bluetoothctl <<-EOF
			select $controller
			info $mac
		EOF
	done | awk '
		function print_cached_device() {
			print icon linkedsep paired connected " " name " " mac
			name=icon=mac=""
		}
		{ $1=$1 }
		/^Device/ && name { print_cached_device() }
		/^Device/ { mac=$2; paired=""; connected=""; linkedsep="" }
		/Name:/ { $1="";$0=$0;$1=$1; name=$0 }
		/Paired: yes/ { paired="'$icon_lnk'"; linkedsep=" " }
		/Connected: yes/ { connected="'$icon_a2x'"; linkedsep=" " }
		/Icon: computer/ { icon="'$icon_com'" }
		/Icon: phone/ { icon="'$icon_phn'" }
		/Icon: modem/ { icon="'$icon_mod'" }
		/Appearance: 0x00c2/ { icon="'$icon_wat'" }
		/Icon: watch/ { icon="'$icon_wat'" }
		/Icon: network-wireless/ { icon="'$icon_wif'" }
		/Icon: audio-headset/ { icon="'$icon_hdp'" }
		/Icon: audio-headphones/ { icon="'$icon_spk'" }
		/Icon: camera-video/ { icon="'$icon_vid'" }
		/Icon: audio-card/ { icon="'$icon_mus'" }
		/Icon: input-gaming/ { icon="'$icon_gam'" }
		/Icon: input-keyboard/ { icon="'$icon_kbd'" }
		/Icon: input-tablet/ { icon="'$icon_drw'" }
		/Icon: input-mouse/ { icon="'$icon_mse'" }
		/Icon: printer/ { icon="'$icon_prn'" }
		/Icon: camera-photo/ { icon="'$icon_cam'" }
		END { print_cached_device() }
	'
}

_restart_bluetooth() {
	if [ -d /run/systemd/system ]; then
		doas systemctl restart bluetooth
	else
		doas rc-service bluetooth restart
	fi
}

_full_reconnection() {
	notify-send 'Make the device discoverable'
	_ignore_fail sxmo_terminal.sh sh -c "expect - \"$controller\" \"$1\" <&4" <<-'EOF'
		lassign $argv controller mac

		spawn bluetoothctl -a NoInputNoOutput

		send -- "select $controller\r"

		send -- "remove $mac\r"
		expect {
			"Device has been removed" {
				expect "Device $mac"
			}
			"Device $mac not available"
		}

		send -- "scan on\r"
		expect "Discovery started"
		send -- "devices\r"

		set timeout 5
		expect {
			timeout {send -- "devices\r"; exp_continue}
			"Device $mac" {
				sleep 1
				send -- "connect $mac\r"
				expect {
					"Connection successful" {send -- "exit\r"; wait}
					"Operation already in progress" {sleep 1; exp_continue}
					timeout {
						sleep 1
						send -- "connect $mac\r"
						exp_continue
					}
				}
			}
		}
	EOF
}

_show_toggle() {
	if [ "$1" = yes ]; then
		printf %s "$icon_ton"
	else
		printf %s "$icon_tof"
	fi
}

toggle_connection() {
	DEVICE="$1"
	MAC="$(printf "%s\n" "$DEVICE" | awk '{print $NF}')"

	if printf "%s\n" "$PICK" | grep -q "$icon_a2x"; then
		_ignore_fail sxmo_terminal.sh sh -c "expect - \"$controller\" \"$MAC\" <&4" <<-'EOF'
			lassign $argv controller mac
			set timeout 7
			spawn bluetoothctl -a NoInputNoOutput
			send -- "select $controller\r"
			send -- "disconnect $mac\r"
			expect "Disconnection successful"
			send -- "exit\r"
			wait
		EOF
	else
		_ignore_fail sxmo_terminal.sh sh -c "expect - \"$controller\" \"$MAC\" <&4" <<-'EOF'
			lassign $argv controller mac
			set timeout 7
			spawn bluetoothctl -a NoInputNoOutput
			send -- "select $controller\r"
			send -- "connect $mac\r"
			expect {
				"Operation already in progress" {sleep 1}
				"Connection successful"
			}
			send -- "exit\r"
			wait
		EOF
	fi
}

device_loop() {
	DEVICE="$1"
	MAC="$(printf "%s\n" "$DEVICE" | awk '{print $NF}')"
	INDEX=0
	while : ; do
		INFO="$(bluetoothctl info "$MAC")"
		PAIRED="$(printf "%s\n" "$INFO" | grep "Paired:" | awk '{print $NF}')"
		TRUSTED="$(printf "%s\n" "$INFO" | grep "Trusted:" | awk '{print $NF}')"
		CONNECTED="$(printf "%s\n" "$INFO" | grep "Connected:" | awk '{print $NF}')"

		PICK="$(
			cat <<-EOF | sxmo_dmenu.sh -i -p "$DEVICE" -I "$INDEX"
				$icon_ret Return
				$icon_rld Refresh
				Paired $(_show_toggle "$PAIRED")
				Trusted $(_show_toggle "$TRUSTED")
				Connected $(_show_toggle "$CONNECTED")
				$icon_ror Clean re-connection
				$icon_trh Remove
			EOF
		)"

		case "$PICK" in
			"$icon_ret Return")
				INDEX=0
				return
				;;
			"$icon_rld Refresh")
				INDEX=1
				continue
				;;
			"Paired $icon_tof")
				INDEX=2
				_ignore_fail sxmo_terminal.sh sh -c "expect - \"$controller\" \"$MAC\" <&4" <<-'EOF'
					lassign $argv controller mac
					set timeout 5
					spawn bluetoothctl -a NoInputNoOutput
					send -- "select $controller\r"
					send -- "pair $mac\r"
					expect "Pairing successful"
					send -- "exit\r"
					wait
				EOF
				;;
			"Trusted $icon_ton")
				INDEX=3
				_ignore_fail sxmo_terminal.sh sh -c "expect - \"$controller\" \"$MAC\" <&4" <<-'EOF'
					lassign $argv controller mac
					set timeout 5
					spawn bluetoothctl -a NoInputNoOutput
					send -- "select $controller\r"
					send -- "untrust $mac\r"
					expect "untrust succeeded"
					send -- "exit\r"
					wait
				EOF
				;;
			"Trusted $icon_tof")
				INDEX=3
				_ignore_fail sxmo_terminal.sh sh -c "expect - \"$controller\" \"$MAC\" <&4" <<-'EOF'
					lassign $argv controller mac
					set timeout 5
					spawn bluetoothctl -a NoInputNoOutput
					send -- "select $controller\r"
					send -- "trust $mac\r"
					expect "trust succeeded"
					send -- "exit\r"
					wait
				EOF
				;;
			"Connected $icon_ton")
				INDEX=4
				_ignore_fail sxmo_terminal.sh sh -c "expect - \"$controller\" \"$MAC\" <&4" <<-'EOF'
					lassign $argv controller mac
					set timeout 5
					spawn bluetoothctl -a NoInputNoOutput
					send -- "select $controller\r"
					send -- "disconnect $mac\r"
					expect "Disconnection successful"
					send -- "exit\r"
					wait
				EOF
				;;
			"Connected $icon_tof")
				INDEX=4
				_ignore_fail sxmo_terminal.sh sh -c "expect - \"$controller\" \"$MAC\" <&4" <<-'EOF'
					lassign $argv controller mac
					set timeout 5
					spawn bluetoothctl -a NoInputNoOutput
					send -- "select $controller\r"
					send -- "connect $mac\r"
					expect "Connection successful"
					send -- "exit\r"
					wait
				EOF
				;;
			"$icon_ror Clean re-connection")
				_full_reconnection "$MAC"
				INDEX=6
				;;
			"$icon_trh Remove")
				INDEX=7
				if confirm_menu -p "Remove this device ?"; then
					if _can_fail bluetoothctl remove "$MAC"; then
						return
					fi
				fi
				;;
		esac
		sleep 0.5
	done
}

main_loop() {
	INDEX=0
	while : ; do
		DISCOVERING="$(bluetoothctl show "$controller" | grep "Discovering:" | awk '{print $NF}')"

		CONTROLLERS="$(bluetoothctl <<-EOF | grep ^Controller | sort -u | sed "s|^Controller|$icon_rss|"
			select $controller
			list
		EOF
		)"
		DEVICES="$(_device_list)"

		PICK="$(
			cat <<-EOF | sxmo_dmenu.sh -i -p "$icon_bth Bluetooth" -I "$INDEX"
				$icon_cls Close Menu
				$icon_rld Refresh
				$icon_pwr Restart daemon
				Simple mode $(_show_toggle "$SIMPLE_MODE")
				Discovering $(_show_toggle "$DISCOVERING")
				Start Agent
				$CONTROLLERS
				$DEVICES
			EOF
		)"

		case "$PICK" in
			"$icon_cls Close Menu")
				INDEX=0
				exit
				;;
			"$icon_rld Refresh")
				INDEX=1
				continue
				;;
			"$icon_pwr Restart daemon")
				INDEX=2
				confirm_menu -p "Restart the daemon ?" && _restart_bluetooth
				;;
			"Simple mode $icon_ton")
				SIMPLE_MODE=no
				INDEX=3
				;;
			"Simple mode $icon_tof")
				SIMPLE_MODE=yes
				INDEX=3
				;;
			"Discovering $icon_ton")
				INDEX=4
				sxmo_jobs.sh stop bluetooth_scan
				sleep 0.5
				;;
			"Discovering $icon_tof")
				sxmo_jobs.sh start bluetooth_scan expect -c "
					spawn bluetoothctl
					send -- \"select $controller\r\"
					send -- \"scan on\r\"
					expect \"Discovery started\"
					sleep 60
					send -- \"exit\r\"
					wait
				" &
				sleep 0.5
				notify-send "Scanning for 60 seconds"
				INDEX=5
				sleep 0.5
				;;
			"Start Agent")
				INDEX=5
				_ignore_fail sxmo_terminal.sh expect -c "
					spawn bluetoothctl
					send -- \"select $controller\r\"
					send -- \"pairable on\r\"
					expect \"Changing pairable on succeeded\"
					interact
					wait
				"
				;;
			"$icon_rss"*)
				INDEX=0
				controller="$(printf %s "$PICK" | cut -d" " -f2)"
				;;
			*)
				INDEX=0

				if [ "$SIMPLE_MODE" = no ]; then
					device_loop "$PICK"
				else
					toggle_connection "$PICK"
				fi
				;;
		esac
	done
}

main_loop
