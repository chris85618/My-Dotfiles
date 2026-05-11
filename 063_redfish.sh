#!/bin/bash

# ~/.redfish.sh — Redfish curl wrapper + completion
# Required: REDFISH_USERNAME, REDFISH_PASSWORD
# Optional: REDFISH_AUTH_MODE (basic|session, default session)
#           REDFISH_SCHEME (default https), REDFISH_PORT
#           REDFISH_CACERT, REDFISH_INSECURE=1 (skip TLS verify)
#           REDFISH_PRETTY=1 (pipe to jq), REDFISH_AUTO_IFMATCH=0
#           REDFISH_SESSION_DIR (default $XDG_RUNTIME_DIR/bmc/redfish)

: "${REDFISH_USERNAME:=root}"
: "${REDFISH_PASSWORD:=0penBmc}"
: "${REDFISH_AUTH_MODE:=session}"
: "${REDFISH_SCHEME:=https}"
: "${REDFISH_AUTO_IFMATCH:=0}"
# : "${REDFISH_VERIFY_TLS:=1}"
# : "${REDFISH_CA_BUNDLE:=/etc/ssl/bmc-ca.pem}"

_redfish_runtime_dir() {
    local d="${REDFISH_SESSION_DIR:-${XDG_RUNTIME_DIR:-$HOME/.cache}/bmc/redfish}"
    mkdir -p "$d" 2>/dev/null && chmod 700 "$d" 2>/dev/null
    printf '%s\n' "$d"
}

_redfish_session_file() {
    local host="$1"
    local key="${host//[^A-Za-z0-9._-]/_}"
    printf '%s/session.%s\n' "$(_redfish_runtime_dir)" "$key"
}

_redfish_url() {
    local host="$1" path="$2"
    [[ "$path" != /* ]] && path="/redfish/v1/${path}"
    if [[ -n "${REDFISH_PORT:-}" ]] && [[ "$host" != *:* ]] && [[ "$host" != \[*\]* ]]; then
        host="${host}:${REDFISH_PORT}"
    fi
    printf '%s://%s%s\n' "$REDFISH_SCHEME" "$host" "$path"
}

# Curl wrapper that feeds credentials via --config - (no temp files, no cmdline leak).
_redfish_curl_basic() {
    [[ -z "${REDFISH_USERNAME:-}" || -z "${REDFISH_PASSWORD:-}" ]] && {
        echo "redfish: REDFISH_USERNAME / REDFISH_PASSWORD not set" >&2; return 2; }
    local u="${REDFISH_USERNAME//\\/\\\\}"; u="${u//\"/\\\"}"
    local p="${REDFISH_PASSWORD//\\/\\\\}"; p="${p//\"/\\\"}"
    printf 'user = "%s:%s"\n' "$u" "$p" | command curl --config - "$@"
}

_redfish_curl_token() {
    local token="$1"; shift
    command curl -H "X-Auth-Token: ${token}" "$@"
}

_redfish_tls_args() {
    if [[ "${REDFISH_INSECURE:-0}" == "1" ]]; then
        printf '%s\n' "-k"
    elif [[ -n "${REDFISH_CACERT:-}" ]]; then
        printf '%s\n%s\n' "--cacert" "$REDFISH_CACERT"
    fi
}

# ----- session login / logout -----

redfish::login() {
    local host="$1"
    local sf; sf="$(_redfish_session_file "$host")"
    local body
    body=$(printf '{"UserName":"%s","Password":"%s"}' \
                  "${REDFISH_USERNAME//\"/\\\"}" \
                  "${REDFISH_PASSWORD//\"/\\\"}")

    local -a tls; mapfile -t tls < <(_redfish_tls_args)
    local resp_headers; resp_headers=$(mktemp "$(_redfish_runtime_dir)/hdr.XXXXXX")
    chmod 600 "$resp_headers"

    local body_out
    body_out=$(_redfish_curl_basic \
        -sS "${tls[@]}" \
        -D "$resp_headers" \
        -H 'Content-Type: application/json' \
        -X POST --data "$body" \
        "$(_redfish_url "$host" /redfish/v1/SessionService/Sessions)")
    local rc=$?

    local token loc
    token=$(awk 'BEGIN{IGNORECASE=1} /^X-Auth-Token:/ {sub(/\r$/,"",$2); print $2; exit}' "$resp_headers")
    loc=$(  awk 'BEGIN{IGNORECASE=1} /^Location:/      {sub(/\r$/,"",$2); print $2; exit}' "$resp_headers")
    command rm -f "$resp_headers"

    if [[ -z "$token" ]]; then
        echo "redfish: login failed for $host" >&2
        printf '%s\n' "$body_out" >&2
        return ${rc:-1}
    fi
    printf 'TOKEN=%q\nLOCATION=%q\n' "$token" "$loc" > "$sf"
    chmod 600 "$sf"
}

redfish::logout() {
    local host="$1"
    local sf; sf="$(_redfish_session_file "$host")"
    [[ -r "$sf" ]] || return 0
    local TOKEN="" LOCATION=""
    . "$sf"
    if [[ -n "$LOCATION" && -n "$TOKEN" ]]; then
        local -a tls; mapfile -t tls < <(_redfish_tls_args)
        _redfish_curl_token "$TOKEN" -sS "${tls[@]}" -X DELETE \
            "$(_redfish_url "$host" "$LOCATION")" >/dev/null 2>&1 || true
    fi
    command rm -f "$sf"
}

_redfish_ensure_session() {
    local host="$1"
    local sf; sf="$(_redfish_session_file "$host")"
    if [[ ! -r "$sf" ]]; then
        redfish::login "$host" || return $?
    fi
    . "$sf"
    REDFISH_TOKEN="$TOKEN"
}

# ----- core caller -----

# usage: _redfish_call <METHOD> <host> <path> [body] [extra curl args...]
_redfish_call() {
    local method="$1" host="$2" path="$3"; shift 3 || true
    local body="${1:-}"; [[ $# -ge 1 ]] && shift

    local -a tls; mapfile -t tls < <(_redfish_tls_args)
    local url; url="$(_redfish_url "$host" "$path")"

    local -a c=( -sS "${tls[@]}" -X "$method" )
    [[ "$method" =~ ^(POST|PATCH|PUT)$ ]] && c+=( -H 'Content-Type: application/json' )
    [[ -n "$body" ]] && c+=( --data "$body" )
    [[ $# -gt 0 ]] && c+=( "$@" )
    c+=( "$url" )

    local out
    case "$REDFISH_AUTH_MODE" in
        basic)
            out=$(_redfish_curl_basic "${c[@]}") ;;
        session)
            _redfish_ensure_session "$host" || return $?
            out=$(_redfish_curl_token "$REDFISH_TOKEN" "${c[@]}") ;;
        oauth)
            [[ -z "${REDFISH_BEARER_TOKEN:-}" ]] && {
                echo "redfish: REDFISH_BEARER_TOKEN not set (oauth mode)" >&2; return 2; }
            out=$(command curl -H "Authorization: Bearer ${REDFISH_BEARER_TOKEN}" "${c[@]}") ;;
        *)
            echo "redfish: unknown REDFISH_AUTH_MODE='$REDFISH_AUTH_MODE'" >&2; return 2 ;;
    esac

    if [[ "${REDFISH_PRETTY:-0}" == "1" ]] && command -v jq >/dev/null 2>&1; then
        printf '%s\n' "$out" | jq .
    else
        printf '%s\n' "$out"
    fi
}

# ----- patch-safe (auto If-Match) -----

_redfish_get_etag() {
    local host="$1" path="$2"
    local resp; resp=$(REDFISH_PRETTY=0 _redfish_call GET "$host" "$path" 2>/dev/null)
    if command -v jq >/dev/null 2>&1; then
        printf '%s\n' "$resp" | jq -r '."@odata.etag" // empty'
    else
        printf '%s\n' "$resp" | grep -oE '"@odata\.etag"[[:space:]]*:[[:space:]]*"[^"]+"' \
                              | sed -E 's/.*"([^"]+)"$/\1/' | head -n1
    fi
}

# ----- public dispatch -----

redfish() {
    local host=""
    if [[ $# -ge 1 ]]; then
        bmc::set_target "$1"
        host="$BMC_RESOLVED"
    fi

    if [[ $# -lt 2 ]]; then
        cat >&2 <<EOF
Usage: redfish <IP|last-octet> <verb> [path] [body] [curl-extras...]

  Verbs:
    get|head|options <path>
    post|patch|put|delete <path> [json-body]
    patch-safe|put-safe  <path> <json-body>     (auto If-Match)
    login | logout
    raw <METHOD> <path> [body] [curl-extras]    (low-level)

  Redfish env:
    REDFISH_USERNAME     '${REDFISH_USERNAME:-<unset>}'
    REDFISH_PASSWORD     $([[ -n "${REDFISH_PASSWORD:-}" ]] && echo "<set>" || echo "<unset>")
    REDFISH_AUTH_MODE    '${REDFISH_AUTH_MODE}'   (basic|session|oauth)
    REDFISH_SCHEME       '${REDFISH_SCHEME}'
    REDFISH_PORT         '${REDFISH_PORT:-<default>}'
    REDFISH_CACERT       '${REDFISH_CACERT:-<unset>}'
    REDFISH_INSECURE     '${REDFISH_INSECURE:-0}'
    REDFISH_PRETTY       '${REDFISH_PRETTY:-0}'
    REDFISH_AUTO_IFMATCH '${REDFISH_AUTO_IFMATCH}'

  Shared BMC env:
$(bmc::status | sed 's/^/    /')
EOF
        return 2
    fi

    shift
    local verb="$1"; shift
    local path="${1:-}"; [[ $# -ge 1 ]] && shift
    local body="${1:-}"; [[ $# -ge 1 ]] && shift

    case "$verb" in
        get|GET)            _redfish_call GET     "$host" "$path"          "$@" ;;
        head|HEAD)          _redfish_call HEAD    "$host" "$path"          "$@" ;;
        options|OPTIONS)    _redfish_call OPTIONS "$host" "$path"          "$@" ;;
        post|POST)          _redfish_call POST    "$host" "$path" "$body"  "$@" ;;
        delete|DELETE)      _redfish_call DELETE  "$host" "$path" ""       "$@" ;;
        patch|PATCH)
            if [[ "${REDFISH_AUTO_IFMATCH}" == "1" ]]; then
                local et; et=$(_redfish_get_etag "$host" "$path")
                if [[ -n "$et" && "$et" != "null" ]]; then
                    _redfish_call PATCH "$host" "$path" "$body" -H "If-Match: $et" "$@"
                else
                    _redfish_call PATCH "$host" "$path" "$body" "$@"
                fi
            else
                _redfish_call PATCH "$host" "$path" "$body" "$@"
            fi ;;
        put|PUT)
            if [[ "${REDFISH_AUTO_IFMATCH}" == "1" ]]; then
                local et; et=$(_redfish_get_etag "$host" "$path")
                if [[ -n "$et" && "$et" != "null" ]]; then
                    _redfish_call PUT "$host" "$path" "$body" -H "If-Match: $et" "$@"
                else
                    _redfish_call PUT "$host" "$path" "$body" "$@"
                fi
            else
                _redfish_call PUT "$host" "$path" "$body" "$@"
            fi ;;
        patch-safe)
            local et; et=$(_redfish_get_etag "$host" "$path")
            if [[ -n "$et" && "$et" != "null" ]]; then
                _redfish_call PATCH "$host" "$path" "$body" -H "If-Match: $et" "$@"
            else
                _redfish_call PATCH "$host" "$path" "$body" "$@"
            fi ;;
        put-safe)
            local et; et=$(_redfish_get_etag "$host" "$path")
            if [[ -n "$et" && "$et" != "null" ]]; then
                _redfish_call PUT "$host" "$path" "$body" -H "If-Match: $et" "$@"
            else
                _redfish_call PUT "$host" "$path" "$body" "$@"
            fi ;;
        login)              redfish::login  "$host" ;;
        logout)             redfish::logout "$host" ;;
        raw)
            local m="$path"; local p="$body"
            local extra_body="${1:-}"; [[ $# -ge 1 ]] && shift
            _redfish_call "$m" "$host" "$p" "$extra_body" "$@" ;;
        *)
            echo "redfish: unknown verb '$verb'" >&2; return 2 ;;
    esac
}

# ----- completion -----

_redfish_common_paths() {
    cat <<'EOF'
/redfish/v1/
/redfish/v1/Systems
/redfish/v1/Systems/1
/redfish/v1/Systems/1/Bios
/redfish/v1/Systems/1/Processors
/redfish/v1/Systems/1/Memory
/redfish/v1/Systems/1/EthernetInterfaces
/redfish/v1/Systems/1/SimpleStorage
/redfish/v1/Systems/1/Storage
/redfish/v1/Systems/1/Actions/ComputerSystem.Reset
/redfish/v1/Chassis
/redfish/v1/Chassis/1
/redfish/v1/Chassis/1/Power
/redfish/v1/Chassis/1/Thermal
/redfish/v1/Managers
/redfish/v1/Managers/1
/redfish/v1/Managers/1/EthernetInterfaces
/redfish/v1/Managers/1/NetworkProtocol
/redfish/v1/Managers/1/Actions/Manager.Reset
/redfish/v1/AccountService
/redfish/v1/AccountService/Accounts
/redfish/v1/AccountService/Roles
/redfish/v1/SessionService
/redfish/v1/SessionService/Sessions
/redfish/v1/UpdateService
/redfish/v1/UpdateService/FirmwareInventory
/redfish/v1/EventService
/redfish/v1/EventService/Subscriptions
/redfish/v1/TaskService
/redfish/v1/TelemetryService
/redfish/v1/CertificateService
EOF
}

_redfish_complete() {
    local cur cword
    if declare -F _init_completion >/dev/null; then
        _init_completion -n =: || return
    else
        COMPREPLY=(); cur="${COMP_WORDS[COMP_CWORD]}"; cword=$COMP_CWORD
    fi

    if (( cword == 1 )); then bmc::complete_pos1 "$cur"; return; fi
    if (( cword == 2 )); then
        COMPREPLY=( $(compgen -W "get head options post patch put delete patch-safe put-safe login logout raw" -- "$cur") )
        return
    fi
    local verb="${COMP_WORDS[2]}"
    case "$verb" in
        login|logout) COMPREPLY=(); return ;;
        raw)
            if (( cword == 3 )); then
                COMPREPLY=( $(compgen -W "GET HEAD OPTIONS POST PATCH PUT DELETE" -- "$cur") )
            elif (( cword == 4 )); then
                local IFS=$'\n'
                COMPREPLY=( $(compgen -W "$(_redfish_common_paths)" -- "$cur") )
            fi
            return ;;
    esac
    if (( cword == 3 )); then
        local IFS=$'\n'
        COMPREPLY=( $(compgen -W "$(_redfish_common_paths)" -- "$cur") )
        return
    fi
}
complete -F _redfish_complete redfish
