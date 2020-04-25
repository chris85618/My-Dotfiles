#!/bin/bash

function copy-from() {
    cp -rfv ${@:2} ${1}
}

for p in $(find $HOME/* -maxdepth 0 -mindepth 0 -type d); do
    dirname=$(basename ${p})
    alias c${dirname}="cd ${p}"
    alias to${dirname}="copy-from ${p} "
    alias o${dirname}="xdg-open ${p}"
done
