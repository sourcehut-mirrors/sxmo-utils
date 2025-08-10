#!/bin/sh

sxmobar -o plain -w | \
	stdbuf -o0 tr '\n' '\0' | \
	xargs -0 -n1 printf "all status %s\n" | \
	sandbar -font "Sxmo" -hide-vacant-tags \
		-active-fg-color 282a36 -active-bg-color ff4971 \
		-inactive-fg-color fdfdfd -inactive-bg-color 282a36 \
		-title-fg-color fdfdfd -title-bg-color 282a36 \
		-urgent-bg-color f2a272 -urgent-fg-color 282a36
