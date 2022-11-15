#!/bin/bash

for script in ${HOME}/.setup/temporary_dotfiles/*.sh; do
    . ${script}
done
