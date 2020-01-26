
ip_range="192.168.1"

function ping-scan() {
    for ip_seg in $(
        for ip in `seq 1 255`; do
            ping -c 1 "${ip_range}.${ip}" 1>/dev/null 2>/dev/null && echo ${ip} &
        done 2>/dev/null | sort -g); do
        echo "${ip_range}.${ip_seg}";
    done
}
