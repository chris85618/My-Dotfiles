#!/bin/bash
function keep-try() {
    counter=1
    while : ; do
        echo "${counter}: "
        eval $*
        if [ $? -eq 0 ]; then
            break;
        fi
        sleep 1s
        counter=$(( $counter + 1 ))
    done
    unset counter
}

function remove-all() {
    sed "${1}" -
}

function rstrip() {
    if [ `echo "${1}" | grep -oc ":"` -eq 0 ]; then
        remove-all "s:\(${1}\)*$::g"
    elif [ `echo "${1}" | grep -oc '/'` -eq 0 ]; then
        remove-all "s/\(${1}\)*$//g"
    else
        exit 1
    fi
}

function lstrip() {
    if [ `echo "${1}" | grep -oc ":"` -eq 0 ]; then
        remove-all "s:^\(${1}\)*::g"
    elif [ `echo "${1}" | grep -oc '/'` -eq 0 ]; then
        remove-all "s/^\(${1}\)*//g"
    else
        exit 1
    fi
}

function strip() {
    rstrip "${1}" | lstrip "${1}"
}

function path-alias() {
    if [ $# -eq 1 ]; then
        ${1} .
    elif [ $# -gt 1 ]; then
        ${1} ${@:2}
    fi
}

alias cl="clear"

alias sd="sudo "
alias sudo="sudo "

alias d="diff"

alias ct="cat"
alias le="less"
alias s="sed"
alias gr="grep"
alias gra="grep -rn"
alias gerp="grep"
alias p="pwd"

alias py="python3"
alias p3="python3"
alias py3="python3"
alias p2="python2"
alias py2="python2"

alias sc="python3 -i ~/.setup/chrome_automation.py"

alias ifc="ifconfig"

alias m="mv"

alias cp="cp -i"                                                # Confirm before overwriting something
alias df='df -h'                                                # Human-readable sizes
alias free='free -m'                                            # Show sizes in MB

alias ls="ls -F --color=always"

alias ll="ls -alF --color=always"
alias l="ls --color=always"

alias c="cd"
alias ..="cd .."
alias cd..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ......="cd ../../../../.."
alias .......="cd ../../../../../.."
alias ~="cd ~" # `cd` is probably faster to type though
alias -- -="cd -"

# mv, rm, cp
alias mv='mv -v'
alias rm='rm -i -v'
alias cp='cp -v'

alias chmox='chmod -x'

alias where=which # sometimes i forget

alias hosts='sudo $EDITOR /etc/hosts'   # yes I occasionally 127.0.0.1 twitter.com ;)

# touch
alias t="touch"

# ls options: A = include hidden (but not . or ..), F = put `/` after folders, h = byte unit suffixes
alias lsd='ls -l | grep "^d"' # only directories
#    `la` defined in .functions
###



###
# GIT STUFF

alias push="git push"

# Undo a `git push`
alias undopush="git push -f origin HEAD^:master"

# git root
alias gr='[ ! -z `git rev-parse --show-cdup` ] && cd `git rev-parse --show-cdup || pwd`'
alias master="git checkout master"

alias diskspace_report="df -P -kHl"

# Shortcuts
alias g="git"
alias tk="gitk"
alias tkst='gitk $(for index in $(seq 0 $(( $(git stash list | wc -l)-1 ))); do echo "stash@{${index}}"; done)'
alias v="nvim"
alias vi="nvim"
alias vim="nvim"
alias n="nano"
alias ungz="gunzip -k"

# Create a new directory and enter it
function md() {
	mkdir -p "$@" && cd "$@"
}

# find shorthand
function f() {
	find . -name "$1" 2>&1 | grep -v 'Permission denied'
}

function la(){
 	ls --color=always -l "$@" | awk '
    {
      k=0;
      for (i=0;i<=8;i++)
        k+=((substr($1,i+2,1)~/[rwx]/) *2^(8-i));
      if (k)
        printf("%0o ",k);
      printf(" %9s  %3s %2s %5s  %6s  %s %s %s\n", $3, $6, $7, $8, $5, $9,$10, $11);
    }'
}

# git commit browser. needs fzf
function log() {
  git log --graph --color=always \
      --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "$@" |
  fzf --ansi --no-sort --reverse --tiebreak=index --toggle-sort=\` \
      --bind "ctrl-m:execute:
                echo '{}' | grep -o '[a-f0-9]\{7\}' | head -1 |
                xargs -I % sh -c 'git show --color=always % | less -R'"
}

# Copy w/ progress
function cp_p () {
  rsync -WavP --human-readable --progress $1 $2
}

# get gzipped size
function gz() {
	echo "orig size    (bytes): "
	cat "$1" | wc -c
	echo "gzipped size (bytes): "
	gzip -c "$1" | wc -c
}

# whois a domain or a URL
function whois() {
	local domain=$(echo "$1" | awk -F/ '{print $3}') # get domain from URL
	if [ -z $domain ] ; then
		domain=$1
	fi
	echo "Getting whois record for: $domain …"

	# avoid recursion
					# this is the best whois server
													# strip extra fluff
	/usr/bin/whois -h whois.internic.net $domain | sed '/NOTICE:/q'
}

# preview csv files. source: http://stackoverflow.com/questions/1875305/command-line-csv-viewer
function csvpreview(){
      sed 's/,,/, ,/g;s/,,/, ,/g' "$@" | column -s, -t | less -#2 -N -S
}

# Extract archives - use: extract <file>
# Based on http://dotfiles.org/~pseup/.bashrc
function extract() {
	if [ -f "$1" ] ; then
		local filename=$(basename "$1")
		local foldername="${filename%%.*}"
		local fullpath=`perl -e 'use Cwd "abs_path";print abs_path(shift)' "$1"`
		local didfolderexist=false
		if [ -d "$foldername" ]; then
			didfolderexist=true
			read -p "$foldername already exists, do you want to overwrite it? (y/n) " -n 1
			echo
			if [[ $REPLY =~ ^[Nn]$ ]]; then
				return
			fi
		fi
		mkdir -p "$foldername" && cd "$foldername"
		case $1 in
			*.tar.bz2) tar xjf "$fullpath" ;;
			*.tar.gz) tar xzf "$fullpath" ;;
			*.tar.xz) tar Jxvf "$fullpath" ;;
			*.tar.Z) tar xzf "$fullpath" ;;
			*.tar) tar xf "$fullpath" ;;
			*.taz) tar xzf "$fullpath" ;;
			*.tb2) tar xjf "$fullpath" ;;
			*.tbz) tar xjf "$fullpath" ;;
			*.tbz2) tar xjf "$fullpath" ;;
			*.tgz) tar xzf "$fullpath" ;;
			*.txz) tar Jxvf "$fullpath" ;;
			*.zip) unzip "$fullpath" ;;
			*.rar) rar e "$fullpath" ;;
			*) echo "'$1' cannot be extracted via extract()" && cd .. && ! $didfolderexist && rm -r "$foldername" ;;
		esac
	else
		echo "'$1' is not a valid file"
	fi
}

function nullify() {
  "$@" >/dev/null 2>&1
}

function overlay() {
  if [ ${#@} -lt 2 ]; then
    echo "usage: overlay destdir lowerdir [lowerdirs...]";
  else
    destDir="`realpath $1`"
    myHash="`echo "$destDir" | md5sum | cut -c -7`"
    overlayDir="/tmp/overlay/$myHash"
    if [ ! -d $overlayDir ]; then
      mkdir -p $overlayDir
      workDir="$overlayDir/work"
      upperDir="$overlayDir/upper"
      mkdir -p $destDir $workDir $upperDir
      local IFS=:; sudo mount -t overlay overlay -olowerdir='${*:2}',upperdir=$upperDir,workdir=$workDir $destDir && echo "$myHash" || rm -rf $overlayDir
    fi
  fi
}
