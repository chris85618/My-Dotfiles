#!/bin/bash
SSH_DIR=${HOME}/.setup/ssh_links

function link() {
    sshpass -p "$1" ${@:2}
}

function getIp() {
    echo "`ping -c 1 $1 | grep -o '([0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\})' | sed 's/[()]//g' | head -n 1 | sed 's/ \+$//g'`"
}

function remoteFormat() {
    if [ ${#@} -le 2 ]; then
        echo "$1@`getIp $2`"
    else
        echo "$1@`getIp $2`:$3" ${@:4}
    fi
}

function sshLink() {
    link "$2" "ssh -t" "`remoteFormat $1 $3`" "${@:4}"
}

function remoteUpload() {
    link "$2" "rsync -avzh" "$4" "`remoteFormat $1 $3`:$5"
}

function remoteDownload() {
    link "$2" "rsync -avzh" "`remoteFormat $1 $3`:$4" "${5-.}"
}

function ssh_GenerateHotkey() {
    filename="${1}"
    alias_name="${filename}"
    filepath="${SSH_DIR}/${filename}"
    url="$(cat ${filepath} | cut -d$'\n' -f1)"
    username="$(cat ${filepath} | cut -d$'\n' -f2)"
    password="$(cat ${filepath} | cut -d$'\n' -f3)"

    alias ${alias_name}="sshLink  '${username}' '${password}' '${url}'"
    for i in `seq 0 10`; do
        alias ${alias_name}${i}="${alias_name}  \"bash -c 'minicom -wD /dev/ttyUSB${i}'\""
        alias "${alias_name}.${i}"="${alias_name}  \"bash -c 'minicom -wD /dev/ttyUSB.${i}'\""
    done
    alias $1upload="remoteUpload '${username}' '${password}' '${url}'"
    alias $1download="remoteDownload '${username}' '${password}' '${url}'"
    alias $1ping="ping '${url}'"
    alias ${1}users="${alias_name} \"bash -c 'find-user'\""
}

for filename in $(ls -q --color=none --indicator-style=none -1 ${HOME}/.setup/ssh_links); do
    ssh_GenerateHotkey ${filename}
done
