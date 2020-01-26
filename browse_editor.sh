# Editor
# nano as default
export EDITOR=$(which nano || echo 'nano')

alias code="path-alias code"
alias co="code"


# Browser
alias "xdg-open"="path-alias xdg-open"
alias o="xdg-open"

# Don’t clear the screen after quitting a manual page
export MANPAGER="less -X"

# Don’t clear the screen after quitting a manual page
export MANPAGER="less -X"

# here's LS_COLORS
# github.com/trapd00r/LS_COLORS
eval "$(dircolors -b ~/.setup/dircolors)"

function web() {
    if [ $# -eq 0 ]; then
        w3m +6 www.google.com
    elif [ `echo $* | grep -c "^/"` -eq 1 ]; then
        w3m file://$@
    else
        w3m $@
    fi
}

function google() {
    web "https://www.google.com/search?q=$(echo "$*" | sed 's/ /+/g')"
}

function duckduckgo() {
    web "https://duckduckgo.com/?q=$(echo "$*" | sed 's/ /+/g')"
}
