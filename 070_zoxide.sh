#!/bin/bash

[[ $- != *i* ]] && return

eval "$(zoxide init bash --cmd cd --hook prompt)"

_cd_local_then_zoxide_top1() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=()

  # 1) 本地目錄補全（永遠在前）
  local -a fs
  mapfile -t fs < <(compgen -d -- "$cur")
  COMPREPLY+=("${fs[@]}")

  # 2) 僅在「像關鍵字」時才追加 zoxide（避免干擾 ./  /  ../  這些路徑語意）
  if [[ "$cur" != */* && "$cur" != .* ]]; then
    local -a zo
    mapfile -t zo < <(zoxide query -l -- "$cur" 2>/dev/null | head -n 1)

    # 3) 追加在最後，並去重（避免本地結果與資料庫結果相同時重複）
    local -A seen=()
    local x
    for x in "${COMPREPLY[@]}"; do seen["$x"]=1; done
    for x in "${zo[@]}"; do
      [[ -n "$x" && -z "${seen[$x]}" ]] || continue
      COMPREPLY+=("$x")
      seen["$x"]=1
    done
  fi
}

# 用自訂 completion 覆蓋 cd
complete -o filenames -o nospace -F _cd_local_then_zoxide_top1 cd
