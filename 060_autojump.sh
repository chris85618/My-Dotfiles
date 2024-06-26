#!/bin/bash

# Only enable autojump if existed
if [ -f /usr/share/autojump/autojump.bash ]; then
    source /usr/share/autojump/autojump.bash
    export AUTOJUMP_IGNORE_CASE=1
    export AUTOJUMP_AUTOCOMPLETE_CMDS='cp vim cd'
fi
