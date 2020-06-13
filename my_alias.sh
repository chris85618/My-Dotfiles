#!/bin/bash
if [ -f /usr/share/bash-completion/bash_completion ]; then
    source /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
    source /etc/bash_completion
fi

function new_alias() {
    alias_name=$1
    real_command=$2
    src_cmdname=${real_command}

    alias "${alias_name}"="${real_command}"

    # Load all the complete commands
    _completion_loader "${src_cmdname}" 1>/dev/null 2>/dev/null
    # Check those commands can be auto completed
    complete_cmd="$(complete -p ${src_cmdname} 2>/dev/null)"
    if [ $? -eq 0 ] ; then
        # Complete them
        $(echo "${complete_cmd}" | sed "s/${src_cmdname}[ \t\r]*$/${alias_name}/g")
    fi
}
