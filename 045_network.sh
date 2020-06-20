#!/bin/bash

iprange=192.168.1
export my_ip="$(ifconfig | grep -o "inet \+${iprange}.[0-9]\{1,3\}" | grep --color=none -o "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}")"

alias 'rand-mac'="dd bs=1 count=6 if=/dev/random 2>/dev/null |hexdump -v -e '/1 \":%02X\"' |cut -c 2- | sed 's/^[0-9a-zA-Z]\{2\}/00/'"
