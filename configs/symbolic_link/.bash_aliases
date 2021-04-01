#!/bin/bash
for file in ~/.setup/*.sh; do
    if [ -r "$file" ]; then source "$file"; fi
done
unset file
