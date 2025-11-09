# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (c) 2025 Sxmo Contributors
# Copyright (c) 2025 Aren Moynihan

# Shellspec formatting confuses shellcheck, so we have to disbale some checks
# SC2317: Command appears to be unreachable
# SC2329: Command not invoked
# SC2034: variable appears unused
# shellcheck disable=SC2317 disable=SC2329 disable=SC2034

PATH="$(pwd)/scripts/core:$PATH"

Describe "sxmo_wm.sh"

term_window() {
	TERMNAME="$1" sxmo_terminal.sh sh -c 'read -r line' >/dev/null 2>&1 &
}

in_graphical_env() {
	test -z "$SXMO_WM"
}
Skip if "Not running in a graphical session" in_graphical_env

Describe "Output power management"
	It "Turns off the screen"
		When call sxmo_wm.sh "display" "off"
		The status should be success
		The stdout should equal ""
		The stderr should equal ""
	End

	It "Reports the screen is off"
		When call sxmo_wm.sh "display"
		The status should be success
		The stdout should equal "off"
		The stderr should equal ""
	End

	It "Turns on the screen"
		When call sxmo_wm.sh "display" "on"
		The status should be success
		The stdout should equal ""
		The stderr should equal ""
	End

	It "Reports the screen if on"
		When call sxmo_wm.sh "display"
		The status should be success
		The stdout should equal "on"
		The stderr should equal ""
	End
End

Describe "Touch input management"
	no_touchscreen() {
		test "$(sxmo_wm.sh inputevent touchscreen)" = "not found"
	}
	Skip if "No touchscreen available:" no_touchscreen

	It "Turns off the touchscreen input"
		When call sxmo_wm.sh inputevent touchscreen off
		The status should be success
		The stdout should equal ""
		The stderr should equal ""
	End

	It "Reports the touchscreen input is off"
		When call sxmo_wm.sh inputevent touchscreen
		The status should be success
		The stdout should equal "off"
		The stderr should equal ""
	End

	It "Turns on the touchscreen input"
		When call sxmo_wm.sh inputevent touchscreen on
		The status should be success
		The stdout should equal ""
		The stderr should equal ""
	End

	It "Reports the touchscreen input is on"
		When call sxmo_wm.sh inputevent touchscreen
		The status should be success
		The stdout should equal "on"
		The stderr should equal ""
	End
End

Describe "Stylus input management"
	no_stylus() {
		test "$(sxmo_wm.sh inputevent stylus)" = "not found"
	}
	Skip if "No stylus available:" no_stylus

	It "Turns off the stylus input"
		When call sxmo_wm.sh inputevent stylus off
		The status should be success
		The stdout should equal ""
		The stderr should equal ""
	End

	It "Reports the stylus input is off"
		When call sxmo_wm.sh inputevent stylus
		The status should be success
		The stdout should equal "off"
		The stderr should equal ""
	End

	It "Turns on the stylus input"
		When call sxmo_wm.sh inputevent stylus on
		The status should be success
		The stdout should equal ""
		The stderr should equal ""
	End

	It "Reports the stylus input is on"
		When call sxmo_wm.sh inputevent stylus
		The status should be success
		The stdout should equal "on"
		The stderr should equal ""
	End
End

Describe "Focused window"
	setup() {
		term_window "Sxmo selftest helper"
		TERM_PID="$!"

		# give it a moment to open
		sleep 0.5
	}
	cleanup() {
		kill "$TERM_PID"
	}
	BeforeAll setup
	AfterAll cleanup

	case "$SXMO_TERMINAL" in
		st) EXPECTED_TERM="st-256color" ;;
		*) EXPECTED_TERM="$SXMO_TERMINAL" ;;
	esac

	It "Gets the focused window in the raw format"
		When call sxmo_wm.sh focusedwindow -r
		The status should be success

		The stdout should equal "$(cat <<-EOF
			$EXPECTED_TERM
			sxmo selftest helper
		EOF
		)"
		The stderr should equal ""
	End

	It "Gets the focused window in the legacy format"
		When call sxmo_wm.sh focusedwindow
		The status should be success
		The stdout should equal "$(cat <<-EOF
			app: $EXPECTED_TERM
			title: sxmo selftest helper
		EOF
		)"
		The stderr should equal ""
	End
End

Describe "Spawning programs in the graphical env"
	It "Spawns programs in the graphical session with exec"
		env_file="$(mktemp)"

		When call env -u WAYLAND_DISPLAY -u DISPLAY sxmo_wm.sh exec sh -c "printf '%s\n' \"$DISPLAY\" \"$WAYLAND_DISPLAY\" > $env_file"
		The status should be success
		The stdout should equal ""
		The stderr should equal ""

		The contents of file "$env_file" should equal "$(cat <<-EOF
			$DISPLAY
			$WAYLAND_DISPLAY
		EOF
		)"

		rm "$env_file"
	End

	It "Doesn't wait for programs started with exec"
		env_file="$(mktemp)"

		When call sxmo_wm.sh exec sh -c "echo started > $env_file; sleep 1; echo done > $env_file"
		The status should be success
		The stdout should equal ""
		The stderr should equal ""
		The contents of file "$env_file" should equal "started"

		rm "$env_file"
	End

	It "Spawns programs in the graphical session with execwait"
		env_file="$(mktemp)"

		When call env -u WAYLAND_DISPLAY -u DISPLAY sxmo_wm.sh execwait \
			sh -c "printf '%s\n' \"$DISPLAY\" \"$WAYLAND_DISPLAY\" > $env_file"
		The status should be success
		The stdout should equal ""
		The stderr should equal ""
		The contents of file "$env_file" should equal "$(cat <<-EOF
			$DISPLAY
			$WAYLAND_DISPLAY
		EOF
		)"

		rm "$env_file"
	End

	It "Waits for programs started with execwait"
		env_file="$(mktemp)"

		When call sxmo_wm.sh execwait sh -c "echo started > $env_file; sleep 1; echo done > $env_file"
		The status should be success
		The stdout should equal ""
		The stderr should equal ""
		The contents of file "$env_file" should equal "done"

		rm "$env_file"
	End

	It "Doesn't expand arguments passed to exec"
		env_file="$(mktemp)"
		save_args="$(which save_args.sh)"

		# shellcheck disable=SC2016
		When call sxmo_wm.sh exec "$save_args" "$env_file" "'one" 'two $three' "; four"
		sleep 0.5

		The status should be success
		The stdout should equal ""
		The stderr should equal ""
		The contents of file "$env_file" should equal "<'one> <two \$three> <; four> "

		rm "$env_file"
	End

	It "Doesn't expand arguments passed to execwait"
		env_file="$(mktemp)"
		save_args="$(which save_args.sh)"

		# shellcheck disable=SC2016
		When call sxmo_wm.sh execwait "$save_args" "$env_file" "'five" 'six $seven' "; eight"
		The status should be success
		The stdout should equal ""
		The stderr should equal ""
		The contents of file "$env_file" should equal "<'five> <six \$seven> <; eight> "

		rm "$env_file"
	End
End

Describe "Workspace switching"
	export SXMO_WORKSPACE_WRAPPING=4

	setup() {
		for wk in $(seq 1 4); do
			sxmo_wm.sh workspace "$wk"
			term_window "Workspace $wk"
			PIDS="$PIDS $!"
			sleep 0.25
		done
	}
	BeforeAll setup

	cleanup() {
		# There may be multiple pids, so we want to slit them
		# shellcheck disable=SC2086
		kill $PIDS
	}
	AfterAll cleanup

	get_workspace() {
		sxmo_wm.sh focusedwindow -r | tail -n 1
	}

	Describe "sxmo_wm.sh workspace"
		Parameters:value 2 3 4 1

		It "switches to #$1"
			When call sxmo_wm.sh workspace "$1"
			The status should be success
			The stdout should equal ""
			The stderr should equal ""

			workspace="$(get_workspace)"
			The variable workspace should equal "workspace $1"
		End
	End

	Describe "sxmo_wm.sh nextworkspace"
		Parameters:value 4 1 2 3
		BeforeAll "sxmo_wm.sh workspace 3"

		It "next workspace is #$1"
			When call sxmo_wm.sh nextworkspace
			The status should be success
			The stdout should equal ""
			The stderr should equal ""

			workspace="$(get_workspace)"
			The variable workspace should equal "workspace $1"
		End
	End

	Describe "sxmo_wm.sh previousworkspace"
		Parameters:value 2 1 4 3
		BeforeAll "sxmo_wm.sh workspace 3"

		It "previous workspace is #$1"
			When call sxmo_wm.sh previousworkspace
			The status should be success
			The stdout should equal ""
			The stderr should equal ""

			workspace="$(get_workspace)"
			The variable workspace should equal "workspace $1"
		End
	End
End

Describe "Move windows to workspace"
	export SXMO_WORKSPACE_WRAPPING=4

	setup() {
		sxmo_wm.sh workspace 1
		term_window "sxmo_wm.sh move test window"
		PIDS="$!"
		sleep 0.25
	}
	BeforeAll setup

	# Shellspec will evaulate this string, so it will get expanded later
	# shellcheck disable=SC2016
	AfterAll 'kill $PIDS'

	get_focused() {
		sxmo_wm.sh focusedwindow -r | tail -n 1
	}

	Describe "sxmo_wm.sh moevnextworkspace"
		# Moving windows has undefined behavior when the workspace wraps
		Parameters:value 2 3 4

		It "moves window to next workspace #$1"
			When call sxmo_wm.sh movenextworkspace
			The status should be success
			The stdout should equal ""
			The stderr should equal ""

			sxmo_wm.sh workspace "$1"
			focused="$(get_focused)"
			The variable focused should equal "sxmo_wm.sh move test window"
		End
	End

	Describe "sxmo_wm.sh moevpreviousworkspace"
		# Moving windows has undefined behavior when the workspace wraps
		Parameters:value 3 2 1

		It "moves window to previous workspace #$1"
			When call sxmo_wm.sh movepreviousworkspace
			The status should be success
			The stdout should equal ""
			The stderr should equal ""

			sxmo_wm.sh workspace "$1"
			focused="$(get_focused)"
			The variable focused should equal "sxmo_wm.sh move test window"
		End
	End

	Describe "sxmo_wm.sh moveworkspace"
		# Moving windows has undefined behavior when the workspace wraps
		Parameters:value 3 4 2 1

		It "moves window to workspace #$1"
			When call sxmo_wm.sh moveworkspace "$1"
			The status should be success
			The stdout should equal ""
			The stderr should equal ""

			sxmo_wm.sh workspace "$1"
			focused="$(get_focused)"
			The variable focused should equal "sxmo_wm.sh move test window"
		End
	End
End

End
