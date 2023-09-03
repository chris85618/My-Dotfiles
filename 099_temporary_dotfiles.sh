#!/bin/bash

if [ $(ls -1 ${HOME}/.setup/temporary_dotfiles/*.sh 2>/dev/null | wc -l) -ne 0 ]; then
    for script in ${HOME}/.setup/temporary_dotfiles/*.sh; do
       . ${script}
    done
fi
