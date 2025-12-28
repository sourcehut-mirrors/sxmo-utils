sxmo_idle.sh(1)

# NAME

sxmo_idle.sh - Idle management script.


# SYNOPSIS

*sxmo_idle.sh* [subcommand] [value]

# DESCRIPTION

A wrapper for swayidle or used to convert swayidle commands into other idle
programs compatible commands.

How this works depends on the compositor:

Wayland based wms, all args are passed to swayidle for execution.

Xorg based wms, this will modify the args to use an internal while loop
tracking the time passed between input events. Any args that aren't needed will
be discarded.

# SUBCOMMANDS

*timeout* <VALUE in seconds> <'sh -c "COMMAND"'>
	Set the timeout and execute COMMAND once timeout expires.

	The sh -c is required to correctly parse the command.


# OPTIONAL SUBCOMMANDS

*resume* <'sh -c "COMMAND"'>
	When resuming from elapsed timeout execute COMMAND.

# SEE ALSO

_sxmo_(7)
