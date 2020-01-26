#!/bin/bash
export PATH="${HOME}/.local/bin:$PATH"

# Don’t clear the screen after quitting a manual page
export MANPAGER="less -X"

# here's LS_COLORS
# github.com/trapd00r/LS_COLORS
eval "$(dircolors -b ~/.setup/dircolors)"
