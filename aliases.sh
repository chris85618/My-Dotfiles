#!/bin/bash

function new_alias() {
    alias_name=$1
    real_command=$2
    src_cmdname=${real_command}

    alias "${alias_name}"="${real_command}"
    if complete -p ${src_cmdname} 1>/dev/null 2>/dev/null; then
        _completion_loader ${src_cmdname}
        complete -o bashdefault -o default -o nospace -F _${src_cmdname} ${alias_name}
    fi
}

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

new_alias cl "clear"

new_alias sd "sudo "
new_alias sudo "sudo "

new_alias d "diff"

new_alias ct "cat"
new_alias le "less"
new_alias less "less -r"
new_alias s "sed"
new_alias ss "source"
new_alias gr "grep"
new_alias gra "grep -rn"
new_alias gerp "grep"
new_alias p "pwd"

new_alias py "python3"
new_alias p3 "python3"
new_alias py3 "python3"
new_alias p2 "python2"
new_alias py2 "python2"

new_alias sc "python3 -i ~/.setup/chrome_robot.py"

new_alias mk "make"

new_alias ifc "ifconfig"

new_alias m "mv"

new_alias cp "cp -i"                                                # Confirm before overwriting something
new_alias df 'df -h'                                                # Human-readable sizes
new_alias free 'free -m'                                            # Show sizes in MB

new_alias ls "ls -F --color=always"

new_alias ll "ls -alF --color=always"
new_alias l "ls --color=always"

new_alias c "cd"
new_alias .. "cd .."
new_alias cd.. "cd .."
new_alias ... "cd ../.."
new_alias .... "cd ../../.."
new_alias ..... "cd ../../../.."
new_alias ...... "cd ../../../../.."
new_alias ....... "cd ../../../../../.."
new_alias '~' "cd ~" # `cd` is probably faster to type though

# mv, rm, cp
new_alias mv 'mv -v'
new_alias rm 'rm -i -v'
new_alias cp 'cp -v'

new_alias chmox 'chmod -x'

new_alias where which # sometimes i forget

new_alias hosts 'sudo $EDITOR /etc/hosts'   # yes I occasionally 127.0.0.1 twitter.com ;)

# touch
new_alias t "touch"

# ls options: A = include hidden (but not . or ..), F = put `/` after folders, h = byte unit suffixes
new_alias lsd 'ls -l | grep "^d"' # only directories
#    `la` defined in .functions
###



###
# GIT STUFF

new_alias push "git push"

# Undo a `git push`
new_alias undopush "git push -f origin HEAD^:master"

# git root
new_alias gr '[ ! -z `git rev-parse --show-cdup` ] && cd `git rev-parse --show-cdup || pwd`'
new_alias master "git checkout master"

new_alias diskspace_report "df -P -kHl"

# Shortcuts
new_alias g "git"
new_alias tk "gitk"
new_alias tkl "gitk"
new_alias kt "gitk"
new_alias klt "gitk"
new_alias tkst 'gitk $(for index in $(seq 0 $(( $(git stash list | wc -l)-1 ))); do echo "stash@{${index}}"; done)'
new_alias ktst 'tkst'
new_alias v "nvim"
new_alias vi "nvim"
new_alias vim "nvim"
new_alias n "nano"
new_alias ungz "gunzip -k"

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
