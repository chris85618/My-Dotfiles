#!/bin/bash

note=~/.setup/note

echo """$(cat ${note})"""

alias editnote="${EDITOR} ${note}"
