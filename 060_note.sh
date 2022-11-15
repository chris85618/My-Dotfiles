#!/bin/bash
NOTE=$HOME/.setup/note.txt

if [ ! -f ${NOTE} ]; then
    touch ${NOTE}
fi

function note() {
    if [ $# -eq 1 ]; then
        # Store the origin variable 'iprange'
        ori_iprange=${iprange}
        # export the iprange for 'note'
        export iprange=${1}
        # Get the actually IP
        my_ip=$(get_ip)
        # restore
        export iprange=${ori_iprange}
    fi
    cat ${NOTE} | sed -e "s/\${RAND_MAC}/$(rand-mac)/g" -e "s:\${MINE}:${my_ip}:g"
}
alias editnote='${EDITOR} ${NOTE}'
