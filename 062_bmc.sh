#!/bin/bash

# ~/.bmc.sh - Shared BMC IP / subnet / completion library
# Sourced by ipmi.sh / snmp.sh / redfish.sh / bmcssh.sh

[[ -n "${_BMC_SH_LOADED:-}" ]] && return 0
_BMC_SH_LOADED=1

# ===================== iface / cidr autodetect =====================

: "${BMC_NET_IFACE_IGNORE:=^(lo|docker[0-9]+|br-[0-9a-f]+|virbr[0-9]+|veth.*|tun[0-9]+|tap[0-9]+|wg[0-9]+|zt.*|tailscale[0-9]+)$}"

bmc::pick_iface() {
    [[ -n "${BMC_NET_IFACE:-}" ]] && { printf '%s\n' "$BMC_NET_IFACE"; return; }
    if command -v ip >/dev/null 2>&1; then
        local dev
        dev="$(ip -4 route show default 2>/dev/null \
               | awk '/^default/ {for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
        if [[ -n "$dev" ]] && ! [[ "$dev" =~ $BMC_NET_IFACE_IGNORE ]]; then
            printf '%s\n' "$dev"; return
        fi
        ip -o -4 addr show scope global 2>/dev/null | awk '{print $2}' | sort -u \
        | while read -r ifc; do
            [[ "$ifc" =~ $BMC_NET_IFACE_IGNORE ]] && continue
            printf '%s\n' "$ifc"; return 0
          done
    fi
}

bmc::detect_cidr() {
    local iface; iface="$(bmc::pick_iface)" || return 1
    [[ -z "$iface" ]] && return 1
    if command -v ip >/dev/null 2>&1; then
        ip -o -4 addr show dev "$iface" scope global 2>/dev/null | awk '{print $4; exit}'
        return
    fi
    if command -v ifconfig >/dev/null 2>&1; then
        local ip
        ip="$(ifconfig "$iface" 2>/dev/null \
              | awk '/inet (addr:)?[0-9]+\./ {gsub("addr:","",$2); print $2; exit}')"
        [[ -n "$ip" ]] && printf '%s/24\n' "$ip"
    fi
}

bmc::autoset_cidr() {
    [[ -n "${BMC_NET_PREFIX:-}" ]] && return 0
    [[ -n "${BMC_NET_CIDR:-}"   ]] && return 0
    local cidr; cidr="$(bmc::detect_cidr)" || return 0
    [[ -n "$cidr" ]] && export BMC_NET_CIDR="$cidr"
}

bmc::derive_prefix() {
    [[ -n "${BMC_NET_PREFIX:-}" ]] && return 0
    [[ -z "${BMC_NET_CIDR:-}"  ]] && return 0
    local cidr="$BMC_NET_CIDR" ip="${BMC_NET_CIDR%/*}" bits="${BMC_NET_CIDR#*/}"
    [[ "$ip" == "$cidr" ]] && return 0
    local o1 o2 o3 o4; IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
    if   (( bits >= 24 )); then export BMC_NET_PREFIX="${o1}.${o2}.${o3}."
    elif (( bits >= 16 )); then export BMC_NET_PREFIX="${o1}.${o2}."
    elif (( bits >= 8  )); then export BMC_NET_PREFIX="${o1}."
    fi
}

# ===================== per-shell state =====================

: "${BMC_STATE_FILE:=/tmp/.bmc-state.$$}"

bmc::state_save() {
    {
        printf 'export BMC_IP=%q\n'          "${BMC_IP:-}"
        printf 'export BMC_NET_PREFIX=%q\n'  "${BMC_NET_PREFIX:-}"
        printf 'export BMC_LAST_HOST=%q\n'   "${BMC_LAST_HOST:-}"
    } > "$BMC_STATE_FILE" 2>/dev/null
}
bmc::state_load() { [[ -r "$BMC_STATE_FILE" ]] && . "$BMC_STATE_FILE"; }

bmc::resolve_host() {
    local host="$1"
    if [[ "$host" =~ ^[0-9]{1,3}$ ]] && [[ -n "${BMC_NET_PREFIX:-}" ]]; then
        host="${BMC_NET_PREFIX}${host}"
    fi
    printf '%s\n' "$host"
}

bmc::update_state() {
    local host="$1"
    [[ -z "$host" ]] && return 0
    export BMC_IP="$host"
    local h="$host"
    [[ "$h" =~ ^(udp|tcp|udp6|tcp6): ]] && h="${h#*:}"
    if [[ "$h" =~ ^\[(.+)\](:[0-9]+)?$ ]]; then
        h="${BASH_REMATCH[1]}"
    else
        h="${h%%:*}"
    fi
    if [[ "$h" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
        export BMC_NET_PREFIX="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}."
        export BMC_LAST_HOST="${BASH_REMATCH[4]}"
    else
        export BMC_LAST_HOST="$h"
    fi
    bmc::state_save
}

# Resolve + update state in caller's shell. Result goes into global BMC_RESOLVED.
# Returns 0 on success. Does NOT print to stdout (avoid $() subshell trap).
bmc::set_target() {
    bmc::resolve_host_into BMC_RESOLVED "$1"
    bmc::update_state "$BMC_RESOLVED"
}

# Pure function variant: writes resolved host into the named variable.
bmc::resolve_host_into() {
    local __out="$1" __input="$2" __h="$2"
    if [[ "$__h" =~ ^[0-9]{1,3}$ ]] && [[ -n "${BMC_NET_PREFIX:-}" ]]; then
        __h="${BMC_NET_PREFIX}${__h}"
    fi
    printf -v "$__out" '%s' "$__h"
}

# Keep the old stdout-style for cases that genuinely want a pure echo.
bmc::resolve_host() {
    local out
    bmc::resolve_host_into out "$1"
    printf '%s\n' "$out"
}
# ===================== position-1 completion =====================

bmc::complete_pos1() {
    local cur="$1"
    local prefix="${BMC_NET_PREFIX:-}"
    local last="${BMC_LAST_HOST:-}"
    local last_full=""
    if [[ -n "$last" ]]; then
        if [[ "$last" =~ ^[0-9]{1,3}$ && -n "$prefix" ]]; then
            last_full="${prefix}${last}"
        else
            last_full="$last"
        fi
    fi
    local -a extras=()
    [[ -n "${BMC_HOSTS:-}" ]] && read -r -a extras <<< "$BMC_HOSTS"

    if [[ -z "$cur" ]] && [[ -n "$last_full" ]]; then
        COMPREPLY=( "$last_full" ); return
    fi
    if [[ -n "$prefix" ]] && [[ "$prefix" == "$cur"* ]] && [[ "$cur" != "$prefix" ]]; then
        COMPREPLY=( "$prefix" )
        local e
        for e in "${extras[@]}"; do
            [[ "$e" == "$cur"* ]] && COMPREPLY+=( "$e" )
        done
        compopt -o nospace 2>/dev/null
        return
    fi
    if (( ${#extras[@]} )); then
        COMPREPLY=( $(compgen -W "${extras[*]}" -- "$cur") )
    else
        COMPREPLY=()
    fi
}

# ===================== status helper =====================

bmc::status() {
    cat <<EOF
BMC_IP             '${BMC_IP:-<unset>}'
BMC_NET_PREFIX     '${BMC_NET_PREFIX:-<unset>}'
BMC_NET_CIDR       '${BMC_NET_CIDR:-<unset>}'
BMC_NET_IFACE      '$(bmc::pick_iface 2>/dev/null)'  (override: '${BMC_NET_IFACE:-<unset>}')
BMC_LAST_HOST      '${BMC_LAST_HOST:-<unset>}'
BMC_HOSTS          '${BMC_HOSTS:-<unset>}'
BMC_STATE_FILE     '$BMC_STATE_FILE'
EOF
}

# ===================== bootstrap =====================

bmc::state_load
bmc::autoset_cidr
bmc::derive_prefix

trap '[[ -n "${BMC_STATE_FILE:-}" ]] && command rm -f "$BMC_STATE_FILE"' EXIT
