#!/bin/bash
echo;
echo "目前共有$(screen -list | grep --perl-regex '^\t' | wc -l)個console:";
for screenPid in $(screen -list | grep --perl-regex '^\t' | awk '{print $1}'); do
    echo "    screen -dr ${screenPid}";
done
