#!/bin/bash

TOTAL_ZOXIDE_RECOMMENDATION=1

[[ $- != *i* ]] && return

eval "$(zoxide init bash --cmd cd --hook prompt)"

_cd_local_then_zoxide_top1() {
  local cur="${COMP_WORDS[COMP_CWORD]}"

  # 1) 本地目錄補全（永遠在前）
  COMPREPLY=( $(compgen -d -- "$cur") )

  # 2) 僅在完全沒有本地目錄可補全、且「像關鍵字」時才追加 zoxide（避免干擾 ./  /  ../  這些路徑語意）
  if [[ ${#COMPREPLY} -eq 0 ]] && [[ "$cur" != */* && "$cur" != .* ]]; then
    local -a zo
    zo=( $(zoxide query -l -- "$cur" 2>/dev/null | head -n ${TOTAL_ZOXIDE_RECOMMENDATION}) )

    # 3) 追加在最後，並去重（避免本地結果與資料庫結果相同時重複）
    local -A seen=()
    local x
    for x in "${COMPREPLY[@]}"; do seen["$(basename $x)"]=1; done
    for x in "${zo[@]}"; do
      local dir_basename="$(basename $x)"
      [[ -n "${dir_basename}" && -z "${seen[${dir_basename}]}" ]] || continue
      COMPREPLY+=("$x")
      seen["${dir_basename}"]=1
    done
  fi
}

# 用自訂 completion 覆蓋 cd
complete -o filenames -o nospace -F _cd_local_then_zoxide_top1 cd
