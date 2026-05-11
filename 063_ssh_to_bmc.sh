#!/bin/bash

# ~/.bmcssh.sh — SSH wrappers for BMC console (OpenBMC, iLO, iDRAC, XCC, etc.)
# Provides:
#   bssh   <IP|last-octet> [ssh-args...]   — interactive ssh login
#   bscp   <IP|last-octet> <local> :<remote>   — scp helpers (BMC<->host)
#   bsol   <IP|last-octet>                  — open Serial-over-LAN console via SSH
#                                              (iLO 'TEXTCONS', iDRAC 'console com2',
#                                               OpenBMC 'obmc-console-client', SuperMicro 'sol activate')
#
# Required env: BMC_SSH_USER (default 'root')
#               BMC_SSH_PASSWORD optional (uses sshpass if set; otherwise key/agent)
# Optional:     BMC_SSH_PORT (default 22), BMC_SSH_KEY (-i), BMC_SSH_OPTS (extra raw opts)
#               BMC_SSH_VENDOR=auto|openbmc|ilo|idrac|xcc|smc  (affects bsol)
#               BMC_SSH_KNOWN_HOSTS (default $XDG_RUNTIME_DIR/bmc/known_hosts)
#               BMC_SSH_STRICT=accept-new|yes|no  (default accept-new)

: "${BMC_SSH_USER:=root}"
: "${BMC_SSH_PASSWORD:=0penBmc}"
: "${BMC_SSH_PORT:=22}"
: "${BMC_SSH_VENDOR:=auto}"
: "${BMC_SSH_STRICT:=accept-new}"

_bmcssh_runtime_dir() {
    local d="${XDG_RUNTIME_DIR:-$HOME/.cache}/bmc"
    mkdir -p "$d" 2>/dev/null && chmod 700 "$d" 2>/dev/null
    printf '%s\n' "$d"
}

_bmcssh_known_hosts() {
    : "${BMC_SSH_KNOWN_HOSTS:=$(_bmcssh_runtime_dir)/known_hosts}"
    [[ -f "$BMC_SSH_KNOWN_HOSTS" ]] || { : >"$BMC_SSH_KNOWN_HOSTS"; chmod 600 "$BMC_SSH_KNOWN_HOSTS"; }
    printf '%s\n' "$BMC_SSH_KNOWN_HOSTS"
}

# Build ssh option array (echoes one option per line)
_bmcssh_opts() {
    local kh; kh="$(_bmcssh_known_hosts)"
    printf -- '-o\nUserKnownHostsFile=%s\n' "$kh"
    printf -- '-o\nStrictHostKeyChecking=%s\n' "$BMC_SSH_STRICT"
    # BMCs frequently use deprecated kex/host-key algos; enable common legacy ones.
    printf -- '-o\nKexAlgorithms=+diffie-hellman-group1-sha1,diffie-hellman-group14-sha1,diffie-hellman-group-exchange-sha1\n'
    printf -- '-o\nHostKeyAlgorithms=+ssh-rsa,ssh-dss\n'
    printf -- '-o\nPubkeyAcceptedAlgorithms=+ssh-rsa\n'
    printf -- '-o\nServerAliveInterval=30\n'
    printf -- '-o\nServerAliveCountMax=3\n'
    [[ -n "${BMC_SSH_KEY:-}" ]] && printf -- '-i\n%s\n' "$BMC_SSH_KEY"
    if [[ -n "${BMC_SSH_OPTS:-}" ]]; then
        # split by whitespace
        local w; for w in $BMC_SSH_OPTS; do printf '%s\n' "$w"; done
    fi
}

# Run ssh/scp with optional sshpass (if BMC_SSH_PASSWORD set).
_bmcssh_invoke() {
    local prog="$1"; shift
    if [[ -n "${BMC_SSH_PASSWORD:-}" ]]; then
        if ! command -v sshpass >/dev/null 2>&1; then
            echo "bmcssh: sshpass not installed; either install it or use SSH key auth" >&2
            return 2
        fi
        # SSHPASS env avoids password on cmdline
        SSHPASS="$BMC_SSH_PASSWORD" command sshpass -e "$prog" "$@"
    else
        command "$prog" "$@"
    fi
}

# ===================== bssh =====================

bssh() {
    local host=""
    if [[ $# -ge 1 ]]; then
        bmc::set_target "$1"
        host="$BMC_RESOLVED"
        shift;
    fi

    if [[ -z "$host" ]]; then
        cat >&2 <<EOF
Usage: bssh <IP|last-octet> [ssh-args...]

  SSH env:
    BMC_SSH_USER       '${BMC_SSH_USER}'
    BMC_SSH_PORT       '${BMC_SSH_PORT}'
    BMC_SSH_KEY        '${BMC_SSH_KEY:-<unset>}'
    BMC_SSH_PASSWORD   $([[ -n "${BMC_SSH_PASSWORD:-}" ]] && echo "<set>" || echo "<unset>")
    BMC_SSH_VENDOR     '${BMC_SSH_VENDOR}'
    BMC_SSH_STRICT     '${BMC_SSH_STRICT}'
    BMC_SSH_OPTS       '${BMC_SSH_OPTS:-<unset>}'
    BMC_SSH_KNOWN_HOSTS '$(_bmcssh_known_hosts)'

  Shared BMC env:
$(bmc::status | sed 's/^/    /')
EOF
        return 2
    fi

    local -a opts; mapfile -t opts < <(_bmcssh_opts)
    _bmcssh_invoke ssh "${opts[@]}" -p "$BMC_SSH_PORT" -l "$BMC_SSH_USER" "$host" "$@"
}

# ===================== bscp =====================
# Usage:
#   bscp <IP> <local-file> :<remote-path>          # upload
#   bscp <IP> :<remote-path> <local-file>          # download

bscp() {
    local host=""
    if [[ $# -ge 1 ]]; then
        bmc::set_target "$1"
        host="$BMC_RESOLVED"
        shift;
    fi
    if [[ $# -lt 2 || -z "$host" ]]; then
        echo "Usage: bscp <IP|last-octet> <src> <dst>   (use ':path' for remote)" >&2
        return 2
    fi

    local src="$1" dst="$2"
    local remote_prefix="${BMC_SSH_USER}@${host}:"
    [[ "$src" == :* ]] && src="${remote_prefix}${src#:}"
    [[ "$dst" == :* ]] && dst="${remote_prefix}${dst#:}"

    local -a opts; mapfile -t opts < <(_bmcssh_opts)
    _bmcssh_invoke scp "${opts[@]}" -P "$BMC_SSH_PORT" "$src" "$dst"
}

# ===================== bsol =====================
# Open SoL console via SSH, vendor-aware.

_bmcssh_detect_vendor_via_banner() {
    # Quick & dirty: peek SSH banner; fallback to 'auto' default mapping.
    local host="$1"
    local banner
    banner=$(ssh-keyscan -T 2 -p "$BMC_SSH_PORT" -t rsa "$host" 2>&1 | head -n5)
    case "$banner" in
        *iLO*)        echo ilo ;;
        *iDRAC*|*Dell*) echo idrac ;;
        *OpenBMC*)    echo openbmc ;;
        *XClarity*|*XCC*|*Lenovo*) echo xcc ;;
        *Supermicro*|*SMCI*|*SMC*) echo smc ;;
        *)            echo auto ;;
    esac
}

bsol() {
    local host=""
    if [[ $# -ge 1 ]]; then
        bmc::set_target "$1"
        host="$BMC_RESOLVED"
        shift;
    fi
    if [[ -z "$host" ]]; then
        echo "Usage: bsol <IP|last-octet>" >&2
        return 2
    fi

    local vendor="$BMC_SSH_VENDOR"
    if [[ "$vendor" == "auto" ]]; then
        vendor="$(_bmcssh_detect_vendor_via_banner "$host")"
    fi

    local -a opts; mapfile -t opts < <(_bmcssh_opts)
    case "$vendor" in
        ilo)
            # iLO: after SSH login, run 'TEXTCONS'  (use ESC ( to leave)
            _bmcssh_invoke ssh "${opts[@]}" -t -p "$BMC_SSH_PORT" -l "$BMC_SSH_USER" "$host" "TEXTCONS" ;;
        idrac)
            # iDRAC: 'console com2'  (use ~. or ^\ to leave)
            _bmcssh_invoke ssh "${opts[@]}" -t -p "$BMC_SSH_PORT" -l "$BMC_SSH_USER" "$host" "console com2" ;;
        openbmc)
            # OpenBMC: obmc-console-client
            _bmcssh_invoke ssh "${opts[@]}" -t -p "$BMC_SSH_PORT" -l "$BMC_SSH_USER" "$host" "obmc-console-client" ;;
        xcc)
            # Lenovo XCC: 'console 1'
            _bmcssh_invoke ssh "${opts[@]}" -t -p "$BMC_SSH_PORT" -l "$BMC_SSH_USER" "$host" "console 1" ;;
        smc)
            # SuperMicro SMC: usually use ipmitool sol activate; fall back to 'sol activate' shell command if exposed
            _bmcssh_invoke ssh "${opts[@]}" -t -p "$BMC_SSH_PORT" -l "$BMC_SSH_USER" "$host" "sol activate" ;;
        auto|*)
            echo "bsol: unknown/auto vendor; opening plain shell. Set BMC_SSH_VENDOR=ilo|idrac|openbmc|xcc|smc to auto-launch SoL." >&2
            _bmcssh_invoke ssh "${opts[@]}" -t -p "$BMC_SSH_PORT" -l "$BMC_SSH_USER" "$host" ;;
    esac
}

# ===================== completion =====================

_bssh_complete() {
    local cur cword
    if declare -F _init_completion >/dev/null; then
        _init_completion -n =: || return
    else
        COMPREPLY=(); cur="${COMP_WORDS[COMP_CWORD]}"; cword=$COMP_CWORD
    fi
    if (( cword == 1 )); then bmc::complete_pos1 "$cur"; return; fi
    # Beyond pos 1 we leave it to user / ssh standard args
    COMPREPLY=()
}
_bsol_complete() { _bssh_complete "$@"; }

_bscp_complete() {
    local cur cword
    if declare -F _init_completion >/dev/null; then
        _init_completion -n =: || return
    else
        COMPREPLY=(); cur="${COMP_WORDS[COMP_CWORD]}"; cword=$COMP_CWORD
    fi
    case $cword in
        1) bmc::complete_pos1 "$cur" ;;
        2|3)
            if [[ "$cur" == :* ]]; then
                COMPREPLY=( $(compgen -W ":/tmp/ :/etc/ :/var/log/ :/run/" -- "$cur") )
            else
                COMPREPLY=( $(compgen -f -- "$cur") )
            fi ;;
    esac
}

complete -F _bssh_complete bssh
complete -F _bscp_complete bscp
complete -F _bsol_complete bsol
