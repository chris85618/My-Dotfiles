#!/bin/bash

todo=~/.setup/todo.txt

if [ ! -f ${todo} ]; then
    touch ${todo}
fi

cat ${todo}

alias edittodo="${EDITOR} ${todo}"
