#!/bin/bash
function ping-scan() {
    if [ $# -ne 0 ]; then
        ip_prefix="$1"
    else
        ip_prefix=iprange
    fi

    for ip_seg in $(
        for ip in `seq 1 255`; do
            ping -c 1 "${ip_prefix}.${ip}" 1>/dev/null 2>/dev/null && echo ${ip} &
        done 2>/dev/null | sort -g); do
        echo "${ip_prefix}.${ip_seg}";
    done
}
