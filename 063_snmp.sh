#!/bin/bash

: "${SNMP_VERSION:=2c}"
: "${SNMP_COMMUNITY:=public}"

# : "${SNMP_VERSION:=3}"
# : "${SNMP_SECNAME:=monitor}"
# : "${SNMP_LEVEL:=authPriv}"
# : "${SNMP_AUTH_PROTO:=SHA-256}"
# : "${SNMP_PRIV_PROTO:=AES}"
# : "${SNMPAUTHPASS:=auth-passphrase}"
# : "${SNMPPRIVPASS:=priv-passphrase}"

# ~/.snmp.sh — snmpget / snmpwalk / snmpset wrappers + completion
# Required (v2c): SNMP_COMMUNITY
# Required (v3):  SNMP_SECNAME, SNMPAUTHPASS (Net-SNMP native), SNMPPRIVPASS
# Optional:       SNMP_VERSION (default 2c), SNMP_LEVEL, SNMP_AUTH_PROTO,
#                 SNMP_PRIV_PROTO, SNMP_PORT, SNMP_TIMEOUT, SNMP_RETRIES,
#                 SNMP_MIBS, SNMP_MIBDIRS, SNMP_HOSTS, SNMP_USE_SNMPCONF

# ===================== arg builder =====================

_snmp_build_args() {
    local ver="${SNMP_VERSION:-2c}"
    printf -- '-v\n%s\n' "$ver"
    case "$ver" in
        1|2c)
            if [[ "${SNMP_USE_SNMPCONF:-0}" != "1" ]] && [[ -n "${SNMP_COMMUNITY:-}" ]]; then
                printf -- '-c\n%s\n' "$SNMP_COMMUNITY"
            fi
            ;;
        3)
            local lvl="${SNMP_LEVEL:-authPriv}"
            printf -- '-l\n%s\n' "$lvl"
            [[ -n "${SNMP_SECNAME:-}" ]] && printf -- '-u\n%s\n' "$SNMP_SECNAME"
            case "$lvl" in
                authNoPriv|authPriv)
                    printf -- '-a\n%s\n' "${SNMP_AUTH_PROTO:-SHA-256}" ;;
            esac
            case "$lvl" in
                authPriv)
                    printf -- '-x\n%s\n' "${SNMP_PRIV_PROTO:-AES}" ;;
            esac
            ;;
    esac
    [[ -n "${SNMP_TIMEOUT:-}" ]] && printf -- '-t\n%s\n' "$SNMP_TIMEOUT"
    [[ -n "${SNMP_RETRIES:-}" ]] && printf -- '-r\n%s\n' "$SNMP_RETRIES"
    [[ -n "${SNMP_MIBDIRS:-}" ]] && printf -- '-M\n+%s\n' "$SNMP_MIBDIRS"
    [[ -n "${SNMP_MIBS:-}"    ]] && printf -- '-m\n+%s\n' "$SNMP_MIBS"
}

_snmp_check_creds() {
    local ver="${SNMP_VERSION:-2c}"
    case "$ver" in
        1|2c)
            if [[ "${SNMP_USE_SNMPCONF:-0}" != "1" ]] && [[ -z "${SNMP_COMMUNITY:-}" ]]; then
                echo "snmp: SNMP_COMMUNITY not set (v$ver)" >&2; return 2
            fi ;;
        3)
            [[ -z "${SNMP_SECNAME:-}" ]] && { echo "snmp: SNMP_SECNAME not set (v3)" >&2; return 2; }
            local lvl="${SNMP_LEVEL:-authPriv}"
            case "$lvl" in
                authNoPriv|authPriv)
                    [[ -z "${SNMPAUTHPASS:-}" ]] && { echo "snmp: SNMPAUTHPASS not set" >&2; return 2; } ;;
            esac
            case "$lvl" in
                authPriv)
                    [[ -z "${SNMPPRIVPASS:-}" ]] && { echo "snmp: SNMPPRIVPASS not set" >&2; return 2; } ;;
            esac ;;
    esac
}

# ===================== runner =====================

_snmp_run() {
    local tool="$1"; shift
    local host=""
    if [[ $# -ge 1 ]]; then
        bmc::set_target "$1"
        host="$BMC_RESOLVED"
        if [[ -n "${SNMP_PORT:-}" ]] && [[ "$host" != *:* ]] && [[ "$host" != \[*\]* ]]; then
            host="${host}:${SNMP_PORT}"
        fi
    fi

    local need_min=2
    [[ "$tool" == "snmpset" ]] && need_min=4
    if [[ $# -lt $need_min ]]; then
        cat >&2 <<EOF
Usage: ${tool} <host|last-octet> $( [[ $tool == snmpset ]] \
        && echo "<OID> <type> <value> [...]" \
        || echo "<OID> [OID...]")

  SNMP env:
    SNMP_VERSION    '${SNMP_VERSION:-2c}'
    SNMP_COMMUNITY  $([[ -n "${SNMP_COMMUNITY:-}" ]] && echo "<set>" || echo "<unset>")
    SNMP_SECNAME    '${SNMP_SECNAME:-<unset>}'
    SNMP_LEVEL      '${SNMP_LEVEL:-authPriv}'
    SNMP_AUTH_PROTO '${SNMP_AUTH_PROTO:-SHA-256}'
    SNMP_PRIV_PROTO '${SNMP_PRIV_PROTO:-AES}'
    SNMPAUTHPASS    $([[ -n "${SNMPAUTHPASS:-}" ]] && echo "<set>" || echo "<unset>")
    SNMPPRIVPASS    $([[ -n "${SNMPPRIVPASS:-}" ]] && echo "<set>" || echo "<unset>")
    SNMP_LAST_OID   '${SNMP_LAST_OID:-<unset>}'
    SNMP_PORT       '${SNMP_PORT:-161}'

  Shared BMC env:
$(bmc::status | sed 's/^/    /')
EOF
        return 2
    fi

    _snmp_check_creds || return $?
    shift

    # remember last OID-looking arg
    local a
    for a in "$@"; do
        if [[ "$a" =~ ^\.?[0-9]+(\.[0-9]+)+$ ]] || [[ "$a" =~ :: ]]; then
            export SNMP_LAST_OID="$a"; break
        fi
    done

    local -a base_args=()
    mapfile -t base_args < <(_snmp_build_args)
    command "$tool" "${base_args[@]}" "$host" "$@"
}

snmpget()  { _snmp_run snmpget  "$@"; }
snmpwalk() { _snmp_run snmpwalk "$@"; }
snmpset()  { _snmp_run snmpset  "$@"; }

# ===================== OID completion =====================

_snmp_oid_cache=""
_snmp_oid_candidates() {
    if [[ -z "$_snmp_oid_cache" ]] && command -v snmptranslate >/dev/null 2>&1; then
        local -a tx=()
        [[ -n "${SNMP_MIBDIRS:-}" ]] && tx+=( -M "+${SNMP_MIBDIRS}" )
        [[ -n "${SNMP_MIBS:-}"    ]] && tx+=( -m "+${SNMP_MIBS}" )
        _snmp_oid_cache="$(snmptranslate "${tx[@]}" -Tso 2>/dev/null | head -n 5000)"
    fi
    printf '%s\n' "$_snmp_oid_cache"
}

_snmp_complete_oid() {
    local cur="$1"
    if [[ -z "$cur" ]] && [[ -n "${SNMP_LAST_OID:-}" ]]; then
        COMPREPLY=( "$SNMP_LAST_OID" \
                    "1.3.6.1.2.1" \
                    "SNMPv2-MIB::system" \
                    "IF-MIB::ifTable" )
        return
    fi
    local cands; cands="$(_snmp_oid_candidates)"
    local IFS=$'\n'
    COMPREPLY=( $(compgen -W "$cands" -- "$cur") )
}

_snmpget_complete() {
    local cur cword
    if declare -F _init_completion >/dev/null; then
        _init_completion -n =: || return
    else
        COMPREPLY=(); cur="${COMP_WORDS[COMP_CWORD]}"; cword=$COMP_CWORD
    fi
    if (( cword == 1 )); then bmc::complete_pos1 "$cur"; return; fi
    _snmp_complete_oid "$cur"
}
_snmpwalk_complete() { _snmpget_complete "$@"; }

_snmpset_complete() {
    local cur cword
    if declare -F _init_completion >/dev/null; then
        _init_completion -n =: || return
    else
        COMPREPLY=(); cur="${COMP_WORDS[COMP_CWORD]}"; cword=$COMP_CWORD
    fi
    case $cword in
        1) bmc::complete_pos1 "$cur" ;;
        2) _snmp_complete_oid "$cur" ;;
        3) COMPREPLY=( $(compgen -W "i u s x d n o t a b U I F D" -- "$cur") ) ;;
        *) local rel=$(( (cword - 2) % 3 ))
           case $rel in
               0) _snmp_complete_oid "$cur" ;;
               1) COMPREPLY=( $(compgen -W "i u s x d n o t a b U I F D" -- "$cur") ) ;;
               2) COMPREPLY=() ;;
           esac ;;
    esac
}
complete -F _snmpget_complete  snmpget
complete -F _snmpwalk_complete snmpwalk
complete -F _snmpset_complete  snmpset
