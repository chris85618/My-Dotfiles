#!/bin/bash
# Automatically trim long paths in the prompt (requires Bash 4.x)
PROMPT_DIRTRIM=10

# Command that Bash executes just before displaying a prompt
OLD_PROMPT_COMMAND="${PROMPT_COMMAND}"
export PROMPT_COMMAND="${OLD_PROMPT_COMMAND:+$OLD_PROMPT_COMMAND; } set_prompts"

if [[ -n "$ZSH_VERSION" ]]; then  # quit now if in zsh
    return 1 2> /dev/null || exit 1;
fi;


if [[ $COLORTERM = gnome-* && $TERM = xterm ]] && infocmp gnome-256color >/dev/null 2>&1; then
    export TERM=gnome-256color
elif infocmp xterm-256color >/dev/null 2>&1; then
    export TERM=xterm-256color
fi


set_prompts() {
    # Capture exit code of last command
    local exit_code=$?

    local black="" blue="" bold="" cyan="" green="" orange="" \
          purple="" red="" reset="" white="" yellow=""

    local dateCmd=""

    if [ -x /usr/bin/tput ] && tput setaf 1 &> /dev/null; then

        tput sgr0 # Reset colors

        bold=$(tput bold)
        reset=$(tput sgr0)

        # Solarized colors
        # (https://github.com/altercation/solarized/tree/master/iterm2-colors-solarized#the-values)
        black=$(tput setaf 0)
        blue=$(tput setaf 33)
        cyan=$(tput setaf 37)
        green=$(tput setaf 190)
        orange=$(tput setaf 172)
        purple=$(tput setaf 141)
        red=$(tput setaf 124)
        violet=$(tput setaf 61)
        magenta=$(tput setaf 9)
        white=$(tput setaf 8)
        yellow=$(tput setaf 136)

    else

        bold=""
        reset="\e[0m"

        black="\e[1;30m"
        blue="\e[1;34m"
        cyan="\e[1;36m"
        green="\e[1;32m"
        orange="\e[1;33m"
        purple="\e[1;35m"
        red="\e[1;31m"
        magenta="\e[1;31m"
        violet="\e[1;35m"
        white="\e[1;37m"
        yellow="\e[1;33m"

    fi

    # Only show username/host if not default
    function usernamehost() {

        # Highlight the user name when logged in as root.
        if [[ "${USER}" == *"root" ]]; then
            userStyle="${red}";
        else
            userStyle="${green}";
        fi;

        userhost=""
        userhost+="\[${userStyle}\]$USER"
        userhost+="\[${reset}\]@"
        userhost+="\[${green}\]$HOSTNAME"
        userhost+="\[${reset}\]:"

        if [ $USER != "$default_username" ]; then echo $userhost; fi
    }


    function prompt_git() {
        # this is >5x faster than mathias's.

        # check if we're in a git repo. (fast)
        git rev-parse --is-inside-work-tree &>/dev/null || return

        # check for what branch we're on. (fast)
        #   if… HEAD isn’t a symbolic ref (typical branch),
        #   then… get a tracking remote branch or tag
        #   otherwise… get the short SHA for the latest commit
        #   lastly just give up.
        branchName="$(git symbolic-ref --quiet --short HEAD 2> /dev/null || \
            git describe --all --exact-match HEAD 2> /dev/null || \
            git rev-parse --short HEAD 2> /dev/null || \
            echo '(unknown)')";


        # ## early exit for Chromium & Blink repo, as the dirty check takes ~5s
        # ## also recommended (via goo.gl/wAVZLa ) : sudo sysctl kern.maxvnodes=$((512*1024))
        # repoUrl=$(git config --get remote.origin.url)
        # if grep -q chromium.googlesource.com <<<$repoUrl; then
        #     dirty=" ⁂"
        # else

        #     # check if it's dirty (slow)
        #     #   technique via github.com/git/git/blob/355d4e173/contrib/completion/git-prompt.sh#L472-L475
        #     dirty=$(git diff --no-ext-diff --quiet --ignore-submodules --exit-code || echo -e "*")

        #     # mathias has a few more checks some may like:
        #     #    github.com/mathiasbynens/dotfiles/blob/a8bd0d4300/.bash_prompt#L30-L43
        # fi

        bold=""
        reset="\e[0m"
        green="\e[1;32m"
        red="\e[1;31m"
        cyan="\e[1;36m"
        dirty="${reset}"
        dirty="${dirty}$(git diff --no-ext-diff --quiet --ignore-submodules --exit-code && echo ' ' || echo "${red}-${reset}")"
        dirty="${dirty}$(git diff --no-ext-diff --quiet --ignore-submodules --staged --exit-code && echo ' ' || echo "${green}+${reset}")"
        dirty="${dirty}$(test $(git log --oneline $(git config --get branch.master.remote)/HEAD..HEAD 2>/dev/null | wc -l) -gt 0 && echo "${reset}${cyan}*${reset}")"
        [ -n "${s}" ] && s=" [${s}]";
        echo -e "${1}${branchName}${2}$dirty";
        return
    }



    # ------------------------------------------------------------------
    # | Prompt string                                                  |
    # ------------------------------------------------------------------

    PS1=""
    if [ "${exit_code}" -ne 0 ]; then
        PS1+="\[$reset\]\[$orange\]\[$bold\]${exit_code}${black}|"
    fi
    PS1+="\[$red\]\[$bold\]\$(date +\"%Y-%m-%d(%a) %H:%M:%S\")"
    PS1+="\[$reset\]:" # terminal title (set to the current working directory)
    PS1+="$(usernamehost)"                              # username at host
    PS1+="\[$blue\]\w"                                     # working directory
    PS1+="\$(prompt_git \"\[$white\] on \[$purple\]\" \"\[$cyan\]\")"   # git repository details
    PS1+="\n"
    PS1+="\[$reset\]\\$ "

    export PS1

    # ------------------------------------------------------------------
    # | Subshell prompt string                                         |
    # ------------------------------------------------------------------

    export PS2="> "

    # ------------------------------------------------------------------
    # | Debug prompt string  (when using `set -x`)                     |
    # ------------------------------------------------------------------

    # When debugging a shell script via `set -x` this tricked-out prompt is used.

    # The first character (+) is used and repeated for stack depth
    # Then, we log the current time, filename and line number, followed by function name, followed by actual source line

    # FWIW, I have spent hours attempting to get time-per-command in here, but it's not possible. ~paul
    export PS4='+ \011\e[1;30m\t\011\e[1;34m${BASH_SOURCE}\e[0m:\e[1;36m${LINENO}\e[0m \011 ${FUNCNAME[0]:+\e[0;35m${FUNCNAME[0]}\e[1;30m()\e[0m:\011\011 }'


    # shoutouts:
    #   https://github.com/dholm/dotshell/blob/master/.local/lib/sh/profile.sh is quite nice.
    #   zprof is also hot.

}

#set_prompts
#unset set_prompts
