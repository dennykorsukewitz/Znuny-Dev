# Znuny Dev - root zsh (colored)
autoload -U colors && colors
autoload -U compinit && compinit
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
PROMPT='%F{red}root%f@%F{blue}%m%f:%F{yellow}%~%f# '
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
