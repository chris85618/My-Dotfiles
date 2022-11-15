#!/bin/bash

# Show welcome
if [ -z $(which figlet) ]; then
    echo "==== Welcome to $(hostname) ===="
else
    hostname | xargs -d. | awk '{print $1}' | grep -v '^$' | figlet -w $(tput cols)
fi

echo "Hello, ${USER}"
