#!/bin/bash

todo=~/.setup/todo.md

if [ ! -f ${todo} ]; then
    touch ${todo}
fi

echo
cat ${todo}

alias edittodo='${EDITOR} ${todo}'
