#!/bin/bash
echo;
echo "目前共有$(screen -list | grep --perl-regex '^\t' | wc -l)個console:";
for screenPid in $(screen -list | grep --perl-regex '^\t' | sed 's/^\t*\([0-9]\+\)\.pts.*$/\1/g'); do
    echo "    screen -dr ${screenPid}";
done
