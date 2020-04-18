function namealise() {
    alias $1="echo ${@:2}"
}

SSH_DIR=${HOME}/.setup/ssh_links

function rsync_Send() {
    url=${1}
    username=${2}
    password=${3}
    sshpass -p ${password} rsync -Rhzzlura -e "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" $(echo ${@:3} | xargs) "${username}@${url}"
}

function rsync_Recv() {
    url=${1}
    username=${2}
    password=${3}
    sshpass -p ${password} rsync -e 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' -hzzlurva ssh://${username}@${url}:${@:3} .
}

function ssh_GenerateHotkey() {
    filename="${1}"
    alias_name="${filename}"
    filepath="${SSH_DIR}/${filename}"
    url="$(cat ${filepath} | cut -d$'\n' -f1)"
    username="$(cat ${filepath} | cut -d$'\n' -f2)"
    password="$(cat ${filepath} | cut -d$'\n' -f3)"
    alias ${alias_name}="sshpass -p ${password} ssh -o StrictHostKeyChecking=no ssh://${username}@${url}"
    alias ${alias_name}upload="rsync_Send ${url} ${username} ${pasword}"
    alias ${alias_name}download="rsync_Recv ${url} ${username} ${pasword}"
}


for filename in $(ls -q --color=none --indicator-style=none -1 ${HOME}/.setup/ssh_links); do
    ssh_GenerateHotkey ${filename}
done
