#!/bin/bash

todo=~/.setup/todo.txt

cat ${todo}

alias edittodo="${EDITOR} ${todo}"
