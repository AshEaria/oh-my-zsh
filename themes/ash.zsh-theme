# vim:ft=zsh ts=2 sw=2 sts=2
#
# agnoster's Theme - https://gist.github.com/3712874
# A Powerline-inspired theme for ZSH
#
# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://github.com/Lokaltog/powerline-fonts).
# Make sure you have a recent version: the code points that Powerline
# uses changed in 2012, and older versions will display incorrectly,
# in confusing ways.
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](http://www.iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# # Goals
#
# The aim of this theme is to only show you *relevant* information. Like most
# prompts, it will only show git information when in a git working directory.
# However, it goes a step further: everything from the current user and
# hostname to whether the last call exited with an error to whether background
# jobs are running in this shell will all be displayed automatically when
# appropriate.

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

CURRENT_BG='NONE'

# Special Powerline characters

() {
  local LC_ALL="" LC_CTYPE="en_US.UTF-8"
  # NOTE: This segment separator character is correct.  In 2012, Powerline changed
  # the code points they use for their special characters. This is the new code point.
  # If this is not working for you, you probably have an old version of the
  # Powerline-patched fonts installed. Download and install the new version.
  # Do not submit PRs to change this unless you have reviewed the Powerline code point
  # history and have new information.
  # This is defined using a Unicode escape sequence so it is unambiguously readable, regardless of
  # what font the user is viewing this source code in. Do not replace the
  # escape sequence with a single literal character.
  # Do not change this! Do not make it '\u2b80'; that is the old, wrong code point.
  SEGMENT_SEPARATOR=$'\ue0b0'
}

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  if [[ "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    prompt_segment black default "%(!.%{%F{yellow}%}.)%m"
  fi
}

# Git: branch/detached head
prompt_git() {
  (( $+commands[git] )) || return
  local PL_BRANCH_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_BRANCH_CHAR=$'\ue0a0'         # 
  }
  local ref dirty mode repo_path
  repo_path=$(git rev-parse --git-dir 2>/dev/null)

  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    # Show repo name first
    prompt_segment red white $(basename "`git rev-parse --show-toplevel`")

    #dirty=$(parse_git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
    #if [[ -n $dirty ]]; then
    #  prompt_segment yellow black
    #else
    prompt_segment green black
    #fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    echo -n "${ref/refs\/heads\//$PL_BRANCH_CHAR }${mode}"
  fi
}

prompt_bzr() {
    (( $+commands[bzr] )) || return
    if (bzr status >/dev/null 2>&1); then
        status_mod=`bzr status | head -n1 | grep "modified" | wc -m`
        status_all=`bzr status | head -n1 | wc -m`
        revision=`bzr log | head -n2 | tail -n1 | sed 's/^revno: //'`
        if [[ $status_mod -gt 0 ]] ; then
            prompt_segment yellow black
            echo -n "bzr@"$revision "✚ "
        else
            if [[ $status_all -gt 0 ]] ; then
                prompt_segment yellow black
                echo -n "bzr@"$revision

            else
                prompt_segment green black
                echo -n "bzr@"$revision
            fi
        fi
    fi
}

prompt_hg() {
  (( $+commands[hg] )) || return
  local rev status
  if $(hg id >/dev/null 2>&1); then
    if $(hg prompt >/dev/null 2>&1); then
      if [[ $(hg prompt "{status|unknown}") = "?" ]]; then
        # if files are not added
        prompt_segment red white
        st='±'
      elif [[ -n $(hg prompt "{status|modified}") ]]; then
        # if any modification
        prompt_segment yellow black
        st='±'
      else
        # if working copy is clean
        prompt_segment green black
      fi
      echo -n $(hg prompt "☿ {rev}@{branch}") $st
    else
      st=""
      rev=$(hg id -n 2>/dev/null | sed 's/[^-0-9]//g')
      branch=$(hg id -b 2>/dev/null)
      if `hg st | grep -q "^\?"`; then
        prompt_segment red black
        st='±'
      elif `hg st | grep -q "^[MA]"`; then
        prompt_segment yellow black
        st='±'
      else
        prompt_segment green black
      fi
      echo -n "☿ $rev@$branch" $st
    fi
  fi
}

# Dir: current working directory
prompt_dir() {
  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    prompt_segment blue black /`git rev-parse --show-prefix`
  else
    prompt_segment blue black '%~'
  fi
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    prompt_segment blue black "(`basename $virtualenv_path`)"
  fi
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local symbols
  symbols=()
  #[[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}✘"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}⚙"

  [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}

## Main prompt
build_prompt() {
  RETVAL=$?
  prompt_virtualenv
  prompt_context
  prompt_status
  prompt_git
  prompt_dir
  #prompt_bzr
  #prompt_hg
  prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt) '
RPROMPT='%D{%H:%M - %a %d}'



######################## ALL THE ALIASES ###################################

##### Aliases
alias addalias="sub ~/.oh-my-zsh/themes/ash.zsh-theme"
alias realias="source ~/.oh-my-zsh/themes/ash.zsh-theme"
alias zconf="sub ~/.zshrc"

## Run in background
bag() {
  $* >/dev/null 2>&1 &!
}

## Run Sublime in background
sub() {
  subl $1 >/dev/null 2>&1 &!
}

## Search
alias getit="grep -rn '.' -e"
alias find="find . | grep"

## Don't delete stuff
alias rm="trash"

## git shortcuts
alias add="git add --all ."
alias commit="git commit -m"
alias amend="git commit --amend --no-edit"
alias log="git log"
alias pull="git pull"
alias push="git push"
alias shove="git push --force"
throw() {
  git add --all .
  git commit -m "$*"
  git push
}
slingshot() {
  git add --all .
  git commit --amend --no-edit
  git push --force
}
alias ungit="git reset --hard HEAD~"

## SSH
hack() {
  ssh root@"$@"
}


## Commands run often: Instavets
alias webpack="pushd ~/Documents/Anima/Instavets/instavets_3.0/static_files/js/react_instavets/ ; nodejs node_modules/webpack/bin/webpack.js ; popd"

## Ping related
alias p8="ping 8.8.8.8"
alias pol="p8 | lolcat &"

alias gofish="bag nautilus ."

## Todo
alias t="~/quick/todo.txt/todo.sh"

## get working
alias work="~/quick/workhorse.sh"

alias mettaton="cd ~/Uni/mettaton/ ; clear"
alias rainbound="cd /media/jaime/DATA/Mis\ documentos/Universidad/Y\ Cuarto\ año/Segundo\ semestre/Redes\ 2/bots ; gnome-terminal -x sh -c 'ssh rainbound.cloudapp.net'"
alias tis="rainbound"

alias wbb="cd ~/Documents/Anima/Wobybi/wobybi"
alias microwd="cd ~/Documents/Anima/Microwd/web/httpdocs"
alias tuuu="cd ~/Documents/Anima/TuuuLibreria/web/httpdocs"
alias instavets="cd ~/Documents/Anima/Instavets/instavets_3.0"

alias tfg="cd ~/Documents/Universidad/A\ TFG/tfg"

## apt-get
alias update="sudo apt-get update ; sudo apt-get upgrade -y"
alias install="sudo apt-get install"

## Rotate screen
alias rotate="xrandr --output LVDS1 --rotate left; synclient Orientation=1"
alias bedme="xrandr --output LVDS1 --rotate right; synclient Orientation=3"
alias normal="xrandr --output LVDS1 --rotate normal; synclient Orientation=0"

## Internet related

track() {
  if [ "$#" = 3 ]; then
    bag /home/jaime/quick/webtracker/tracker.sh $1 $2 $3
    echo "bag /home/jaime/quick/webtracker/tracker.sh $1 $2 $3"  >> /home/jaime/quick/webtracker/tracking
    echo "Began tracking $3 under name $1 every $2 minutes"
  else 
    echo "Usage: track <name> <minutes> <URL>"
  fi
}
tracking() {
  cat /home/jaime/quick/webtracker/tracking | grep tracker | sed -n -e 's/^.*tracker.sh //p'
}
untrack() {
  grep -v "tracker.sh $1 " /home/jaime/quick/webtracker/tracking > ~/temp && mv ~/temp /home/jaime/quick/webtracker/tracking 
  murder $1
}
checktracker() {
  diff ~/quick/webtracker/$1_new.html ~/quick/webtracker/$1_old.html
}



alias scannet="sudo arp-scan --interface=wlan0 --localnet"

alias falert="date; sleep 600; alert"



## sHIT
alias mkae="make"
alias celan="clear"
alias clean="clear"
alias celar="clear"
alias et="exit"
alias psa='ps ax | grep -v "grep" | grep'
murder() {
  #psa "$1" | cut -d' ' -f1
  kill -9 $(psa "$1""\( \|$\)" | sed -e 's/^[[:space:]]*//' | cut -d' ' -f1)
}

## Sharing
alias share="sudo nc -v -l 7173 <"
alias serve="python -m SimpleHTTPServer"