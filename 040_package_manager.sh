#!/bin/bash
alias "package-intall"="yay-install"
alias "package-remove"="yay-remove"
alias "package-upgrade"="pacman-update --needed pacman && yay-upgrade"
alias "package-search"="yay-search"

alias "pacman-install"="sudo pacman -S"
alias "pacman-remove"="sudo pacman -Rs"
alias "pacman-update"="sudo pacman -Sy"
alias "pacman-upgrade"="sudo pacman -Syu"
alias "pacman-full-upgrade"="sudo pacman -Syyuu"
alias "pacman-search"="pacan -Ss"

alias "yay-install"="yay -S"
alias "yay-remove"="yay -Rs"
alias "yay-update"="yay -Sy"
alias "yay-upgrade"="pacman-upgrade && yay -Syu"
alias "yay-full-upgrade"="pacman-full-upgrade && yay -Syyuu"
alias "yay-search"="yay -Ss"
