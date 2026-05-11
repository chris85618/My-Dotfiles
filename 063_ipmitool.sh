#!/bin/bash

: "${IPMI_USERNAME:=root}"
: "${IPMI_PASSWORD:=0penBmc}"

# ~/.ipmi.sh — IPMI wrapper + native ipmitool completion
# Required env: IPMI_USERNAME, IPMI_PASSWORD
# Optional:     IPMI_CIPHER, IPMI_PORT

# ===================== wrapper =====================

ipmi() {
    local host=""
    if [[ $# -ge 1 ]]; then
        bmc::set_target "$1"
        host="$BMC_RESOLVED"
    fi

    if [[ $# -lt 2 ]]; then
        cat >&2 <<EOF
Usage: ipmi <IP|last-octet> <command> [args...]

  IPMI env:
    IPMI_USERNAME   '${IPMI_USERNAME:-<unset>}'
    IPMI_PASSWORD   $([[ -n "${IPMI_PASSWORD:-}" ]] && echo "<set>" || echo "<unset>")
    IPMI_CIPHER     '${IPMI_CIPHER:-<unset>}'
    IPMI_PORT       '${IPMI_PORT:-<unset>}'

  Shared BMC env:
$(bmc::status | sed 's/^/    /')
  Tip: 'ipmi 42 chassis power status' -> uses \${BMC_NET_PREFIX}42
EOF
        return 2
    fi

    [[ -z "${IPMI_USERNAME:-}" ]] && { echo "ipmi: IPMI_USERNAME not set" >&2; return 2; }
    [[ -z "${IPMI_PASSWORD:-}" ]] && { echo "ipmi: IPMI_PASSWORD not set" >&2; return 2; }

    shift
    local -a args=( -I lanplus -H "$host" -U "$IPMI_USERNAME" -E )
    [[ -n "${IPMI_CIPHER:-}" ]] && args+=( -C "$IPMI_CIPHER" )
    [[ -n "${IPMI_PORT:-}"   ]] && args+=( -p "$IPMI_PORT" )

    IPMI_PASSWORD="$IPMI_PASSWORD" command ipmitool "${args[@]}" "$@"
}

# ===================== ipmi command tree (shared) =====================

# Returns top-level commands.
_ipmi_top_cmds() {
    echo "raw i2c spd lan lan6 chassis power event mc sdr sensor \
fru gendev sel pef sol tsol isol user channel session dcmi nm sunoem \
kontronoem picmg fwum firewall delloem shell exec set hpm ekanalyzer \
ime vita help"
}

# Dispatch sub-tree completion.  $1=cmd $2=sub $3=sub2 $4=cword_relative_to_cmd
# (cword_rel: 1 means we are completing 'sub', 2 means 'sub2', etc.)
_ipmi_complete_subtree() {
    local cmd="$1" sub="$2" sub2="$3" cword_rel="$4" cur="$5"
    case "$cmd" in
        chassis)
            if (( cword_rel == 1 )); then
                COMPREPLY=( $(compgen -W "status power identify policy restart_cause poh bootdev bootparam selftest" -- "$cur") ); return
            fi
            case "$sub" in
                power)     (( cword_rel == 2 )) && COMPREPLY=( $(compgen -W "status on off cycle reset diag soft" -- "$cur") ) ;;
                policy)    (( cword_rel == 2 )) && COMPREPLY=( $(compgen -W "list always-on previous always-off" -- "$cur") ) ;;
                identify)  (( cword_rel == 2 )) && COMPREPLY=( $(compgen -W "0 force 15 60" -- "$cur") ) ;;
                bootdev)   (( cword_rel == 2 )) && COMPREPLY=( $(compgen -W "none pxe disk safe diag cdrom bios floppy" -- "$cur") ) ;;
                bootparam)
                    if   (( cword_rel == 2 )); then COMPREPLY=( $(compgen -W "get set" -- "$cur") )
                    elif (( cword_rel == 3 )) && [[ "$sub2" == "set" ]]; then COMPREPLY=( $(compgen -W "bootflag" -- "$cur") )
                    fi ;;
            esac ;;
        power)
            (( cword_rel == 1 )) && COMPREPLY=( $(compgen -W "status on off cycle reset diag soft" -- "$cur") ) ;;
        mc|bmc)
            if (( cword_rel == 1 )); then
                COMPREPLY=( $(compgen -W "reset guid info watchdog selftest getenables setenables chassis getsysinfo setsysinfo restart" -- "$cur") )
            else
                case "$sub" in
                    reset)    (( cword_rel == 2 )) && COMPREPLY=( $(compgen -W "warm cold" -- "$cur") ) ;;
                    watchdog) (( cword_rel == 2 )) && COMPREPLY=( $(compgen -W "get reset off" -- "$cur") ) ;;
                esac
            fi ;;
        sel)
            if (( cword_rel == 1 )); then
                COMPREPLY=( $(compgen -W "info list elist clear delete add get save readraw writeraw interpret time" -- "$cur") )
            else
                case "$sub" in
                    time) (( cword_rel == 2 )) && COMPREPLY=( $(compgen -W "get set" -- "$cur") ) ;;
                    list) (( cword_rel == 2 )) && COMPREPLY=( $(compgen -W "first last" -- "$cur") ) ;;
                esac
            fi ;;
        sdr)
            if (( cword_rel == 1 )); then
                COMPREPLY=( $(compgen -W "info list elist type get dump fill entity" -- "$cur") )
            else
                case "$sub" in
                    list|elist) (( cword_rel == 2 )) && COMPREPLY=( $(compgen -W "all full compact event mcloc fru generic" -- "$cur") ) ;;
                esac
            fi ;;
        sensor)
            (( cword_rel == 1 )) && COMPREPLY=( $(compgen -W "list get thresh reading" -- "$cur") ) ;;
        user)
            if (( cword_rel == 1 )); then
                COMPREPLY=( $(compgen -W "summary list set enable disable priv test help" -- "$cur") )
            elif [[ "$sub" == "set" ]] && (( cword_rel == 2 )); then
                COMPREPLY=( $(compgen -W "name password" -- "$cur") )
            fi ;;
        channel)
            (( cword_rel == 1 )) && COMPREPLY=( $(compgen -W "authcap info getaccess setaccess getciphers setkey" -- "$cur") ) ;;
        lan)
            if (( cword_rel == 1 )); then
                COMPREPLY=( $(compgen -W "print set alert stats" -- "$cur") )
            else
                case "$sub" in
                    alert) (( cword_rel == 2 )) && COMPREPLY=( $(compgen -W "print set" -- "$cur") ) ;;
                    stats) (( cword_rel == 2 )) && COMPREPLY=( $(compgen -W "get clear" -- "$cur") ) ;;
                    set)   (( cword_rel == 3 )) && COMPREPLY=( $(compgen -W "ipaddr netmask macaddr defgw ipsrc snmp user password access arp auth cipher_privs vlan" -- "$cur") ) ;;
                esac
            fi ;;
        lan6)    (( cword_rel == 1 )) && COMPREPLY=( $(compgen -W "print set" -- "$cur") ) ;;
        fru)     (( cword_rel == 1 )) && COMPREPLY=( $(compgen -W "print read write upgEkey edit internaluse" -- "$cur") ) ;;
        sol)
            if (( cword_rel == 1 )); then
                COMPREPLY=( $(compgen -W "info set payload activate deactivate looptest" -- "$cur") )
            else
                case "$sub" in
                    payload)  (( cword_rel == 2 )) && COMPREPLY=( $(compgen -W "enable disable status" -- "$cur") ) ;;
                    activate) (( cword_rel == 2 )) && COMPREPLY=( $(compgen -W "usesolkeepalive nokeepalive" -- "$cur") ) ;;
                esac
            fi ;;
        isol)    (( cword_rel == 1 )) && COMPREPLY=( $(compgen -W "info set activate" -- "$cur") ) ;;
        tsol)    (( cword_rel == 1 )) && COMPREPLY=( $(compgen -W "instance ro rw" -- "$cur") ) ;;
        event)   (( cword_rel == 1 )) && COMPREPLY=( $(compgen -W "1 2 3 file" -- "$cur") ) ;;
        pef)     (( cword_rel == 1 )) && COMPREPLY=( $(compgen -W "capabilities status policy list info" -- "$cur") ) ;;
        dcmi)
            if (( cword_rel == 1 )); then
                COMPREPLY=( $(compgen -W "discover power sensors asset_tag set_asset_tag get_mc_id_string set_mc_id_string thermalpolicy get_temp_reading get_conf_param set_conf_param oob_discover" -- "$cur") )
            else
                case "$sub" in
                    power) (( cword_rel == 2 )) && COMPREPLY=( $(compgen -W "reading get_limit set_limit activate deactivate" -- "$cur") ) ;;
                esac
            fi ;;
        nm)
            (( cword_rel == 1 )) && COMPREPLY=( $(compgen -W "discover capability control statistics policy alert threshold suspend reset" -- "$cur") ) ;;
        session)
            if   (( cword_rel == 1 )); then COMPREPLY=( $(compgen -W "info" -- "$cur") )
            elif (( cword_rel == 2 )) && [[ "$sub" == "info" ]]; then COMPREPLY=( $(compgen -W "active all id handle" -- "$cur") )
            fi ;;
        firewall) (( cword_rel == 1 )) && COMPREPLY=( $(compgen -W "info enable disable reset" -- "$cur") ) ;;
        hpm)
            if (( cword_rel == 1 )); then
                COMPREPLY=( $(compgen -W "check upgrade activate rollback rollbackstatus targetcap compare upgstatus" -- "$cur") )
            else
                COMPREPLY=( $(compgen -f -- "$cur") )
            fi ;;
        picmg)    (( cword_rel == 1 )) && COMPREPLY=( $(compgen -W "addrinfo frucontrol clia frushow gendev sensorinfo sensorread spreadtest" -- "$cur") ) ;;
        delloem)  (( cword_rel == 1 )) && COMPREPLY=( $(compgen -W "lcd mac lan powermonitor windbg vflash setled getsysinfo nic vmedia ipv6" -- "$cur") ) ;;
        sunoem)   (( cword_rel == 1 )) && COMPREPLY=( $(compgen -W "cli led sshkey version nacname getval setval" -- "$cur") ) ;;
        raw|exec|fwum|ime)
            COMPREPLY=( $(compgen -f -- "$cur") ) ;;
    esac
}

# ===================== completion: 'ipmi' wrapper =====================

_ipmi_complete() {
    local cur cword
    if declare -F _init_completion >/dev/null; then
        _init_completion -n =: || return
    else
        COMPREPLY=(); cur="${COMP_WORDS[COMP_CWORD]}"; cword=$COMP_CWORD
    fi

    if (( cword == 1 )); then
        bmc::complete_pos1 "$cur"
        return
    fi

    if (( cword == 2 )); then
        COMPREPLY=( $(compgen -W "$(_ipmi_top_cmds)" -- "$cur") )
        return
    fi

    local cmd="${COMP_WORDS[2]:-}"
    local sub="${COMP_WORDS[3]:-}"
    local sub2="${COMP_WORDS[4]:-}"
    local cword_rel=$(( cword - 2 ))
    _ipmi_complete_subtree "$cmd" "$sub" "$sub2" "$cword_rel" "$cur"
}
complete -F _ipmi_complete ipmi

# ===================== completion: native 'ipmitool' =====================
# Mirrors the official ipmitool flag set + reuses the same command tree.

_ipmitool_top_flags() {
    echo "-h -V -v -c -d -I -H -p -U -f -z -S -D -4 -6 -a -Y -e -C -k -y -L -A -P -E -K -m -b -t -B -T -l -o -O -N -R -Z"
}

_ipmitool_complete() {
    local cur prev cword words
    if declare -F _init_completion >/dev/null; then
        _init_completion -n =: || return
    else
        COMPREPLY=(); cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        cword=$COMP_CWORD
        words=( "${COMP_WORDS[@]}" )
    fi

    # ----- arguments to flags -----
    case "$prev" in
        -I) COMPREPLY=( $(compgen -W "open imb lan lanplus serial-terminal serial-basic" -- "$cur") ); return ;;
        -A) COMPREPLY=( $(compgen -W "NONE PASSWORD MD2 MD5 OEM" -- "$cur") ); return ;;
        -L) COMPREPLY=( $(compgen -W "CALLBACK USER OPERATOR ADMINISTRATOR" -- "$cur") ); return ;;
        -C) COMPREPLY=( $(compgen -W "0 1 2 3 6 7 8 11 12 15 17" -- "$cur") ); return ;;
        -o) COMPREPLY=( $(compgen -W "list intelplus i82571spt" -- "$cur") ); return ;;
        -H) bmc::complete_pos1 "$cur"; return ;;
        -U) [[ -n "${IPMI_USERNAME:-}" ]] && COMPREPLY=( "$IPMI_USERNAME" ); return ;;
        -f|-S|-O) COMPREPLY=( $(compgen -f -- "$cur") ); return ;;
        -p|-d|-N|-R|-z|-m|-b|-t|-B|-T|-l)
            COMPREPLY=(); return ;;
    esac

    # ----- still in flag section? -----
    # Find the position of the first non-flag word (= the command).
    local i cmd_idx=0
    for (( i=1; i<cword; i++ )); do
        local w="${words[i]}"
        case "$w" in
            -I|-H|-p|-U|-f|-z|-S|-D|-e|-C|-k|-y|-L|-A|-P|-d|-o|-O|-N|-R|-m|-b|-t|-B|-T|-l)
                ((i++)); continue ;;   # this flag consumes next word
            -*) continue ;;
            *) cmd_idx=$i; break ;;
        esac
    done

    if (( cmd_idx == 0 )); then
        # Not yet at command; offer flags or, if cur is empty, the command list too.
        if [[ "$cur" == -* ]]; then
            COMPREPLY=( $(compgen -W "$(_ipmitool_top_flags)" -- "$cur") )
        else
            COMPREPLY=( $(compgen -W "$(_ipmitool_top_flags) $(_ipmi_top_cmds)" -- "$cur") )
        fi
        return
    fi

    if (( cword == cmd_idx )); then
        COMPREPLY=( $(compgen -W "$(_ipmi_top_cmds)" -- "$cur") )
        return
    fi

    local cmd="${words[cmd_idx]}"
    local sub="${words[cmd_idx+1]:-}"
    local sub2="${words[cmd_idx+2]:-}"
    local cword_rel=$(( cword - cmd_idx ))
    _ipmitool_complete_subtree() { _ipmi_complete_subtree "$@"; }
    _ipmi_complete_subtree "$cmd" "$sub" "$sub2" "$cword_rel" "$cur"
}
complete -F _ipmitool_complete ipmitool

ipmissh() {
    # Usage: ipmissh [user@]host  <ipmitool args...>
    # If first arg omitted, uses $BMC_SSH_HOST or $BMC_IP
    local sshtarget
    if [[ $# -ge 1 ]] && [[ "$1" == *@* || "$1" =~ ^[A-Za-z0-9._-]+$ ]] \
       && [[ "$1" != "chassis" && "$1" != "sel" && "$1" != "sdr" \
             && "$1" != "mc"   && "$1" != "power" ]]; then
        sshtarget="$1"; shift
    else
        sshtarget="${BMC_SSH_HOST:-${BMC_IP:-}}"
    fi
    [[ -z "$sshtarget" ]] && {
        echo "ipmissh: no target (BMC_SSH_HOST / BMC_IP unset)" >&2; return 2; }

    local iface="${BMC_SSH_IPMI_IFACE:-open}"   # 'open' for host-OS mode
    # Use 'lanplus' if you SSH'd to a jump host that has BMC LAN reachability
    ssh -o BatchMode=yes -o ConnectTimeout=5 "$sshtarget" \
        ipmitool -I "$iface" "$@"
}

_ipmissh_complete() {
    local cur cword
    cur="${COMP_WORDS[COMP_CWORD]}"; cword=$COMP_CWORD
    if (( cword == 1 )); then
        # reuse BMC host completion
        _bmc_complete_host_pos1 "$cur"
        return
    fi
    # delegate to your ipmitool top-level command list
    if (( cword == 2 )); then
        COMPREPLY=( $(compgen -W "chassis power sel sdr sensor mc lan user fru sol dcmi raw" -- "$cur") )
    fi
}
complete -F _ipmissh_complete ipmissh
