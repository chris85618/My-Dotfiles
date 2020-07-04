#!/bin/bash
hostname | xargs -d. | awk '{print $1}' | grep -v '^$' | figlet -w ${COLUMNS}
echo "Hello, ${USER}"
