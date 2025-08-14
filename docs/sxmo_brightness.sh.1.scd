sxmo_brightness.sh(1)

# NAME

sxmo_brightness.sh - Sets screen brightness via brightnessctl.

# SYNOPSIS

*sxmo_brightness.sh* [subcommand] [value]

# DESCRIPTION

This script manipulates the brightness of your screen.

# SUBCOMMNANDS

*silent*
	Prevents notification with (w/x)ob. Use this as first arg to below options.

*notify*
	Notify with (w/x)ob current brightness.

*setvalue* <VALUE>
	Set current brightness to VALUE.

*up* <VALUE>
	Up the brightness by 5%% or if VALUE supplied, by VALUE.

*down* <VALUE>
	Lower the brightness by 5%% or if VALUE supplied, by VALUE. Caps out at SXMO_MIN_BRIGHTNESS.

*getvalue*
	Get current value.

# SEE ALSO

_sxmo_(7)
