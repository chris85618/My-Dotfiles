#!/bin/bash
# nano as default
export EDITOR=$(which nano || echo 'nano')

# Don’t clear the screen after quitting a manual page
export MANPAGER="less -X"

# here's LS_COLORS
# github.com/trapd00r/LS_COLORS
eval "$(dircolors -b ~/.setup/dircolors)"

export PATH="/usr/lib/jvm/java-8-openjdk/bin:$PATH"
