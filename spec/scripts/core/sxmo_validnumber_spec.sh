# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (c) 2025 Sxmo Contributors
# Copyright (c) 2025 Aren Moynihan

# NOTE: test numbers in this script start at +12015550123, and are incremented
# from there. 201 is the lowest valid area code, and 555-0XXX is reserved for
# fictious numbers. Hopefully this is enough to avoid accidentally including a
# real phone number.

validnumber="scripts/core/sxmo_validnumber.sh"

Mock sxmo_dmenu.sh
	echo "dmenu called" >&2
	echo "Abort"
End

Describe "sxmo_validnumber.sh"
	It "detects valid numbers"
		When call "$validnumber" "+12015550123"
		The status should be success
		The stdout should equal "+12015550123"
	End

	# For group texts, sxmo just concatonates all the numbers together
	It "detects group numbers"
		When call "$validnumber" "+12015550123+12015550125"
		The status should be success
		The stdout should equal "+12015550123+12015550125"
	End

	It "reformats numers"
		Skip "TODO: when does it ever reformat a number?"
		When call "$validnumber" "+1 (201) 555-0123"
		The status should be success
		The stdout should equal "+12015550123"
	End

	# This is a tough one to test, we rely on libphonenumber to report back to us
	It "prompts when a number doesn't seem right"
		When call "$validnumber" "+120155501"
		The status should equal 1
		The stderr should equal "dmenu called"
	End

	It "passes through potentially invalid numbers if the user accepts it"
		Mock sxmo_dmenu.sh
			echo "Use as is"
		End

		When call "$validnumber" "+120155501"
		The status should be success
		The stdout should equal "+120155501"
	End

	It "treats unknown input as accepting the number"
		Mock sxmo_dmenu.sh
			echo "asdf"
		End

		When call "$validnumber" "+120155501"
		The status should be success
		The stdout should equal "+120155501"
	End

	It "continues if the user aborts the menu"
		Mock sxmo_dmenu.sh
			# avoid shellcheck thinking we exit the script
			if true; then exit 1; fi
		End

		When call "$validnumber" "+120155501"
		The status should be success
		The stdout should equal "+120155501"
	End
End
