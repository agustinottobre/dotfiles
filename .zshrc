# =============================================================================
# ZIM + Starship Configuration
# Pure zsh setup (no shell_profile)
# =============================================================================

# Initialize Zim Framework
ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim
# Download zimfw plugin manager if missing.
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  if (( ${+commands[curl]} )); then
    curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  else
    mkdir -p ${ZIM_HOME} && wget -nv -O ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  fi
fi
# Install missing modules, and update ${ZIM_HOME}/init.zsh if missing or outdated.
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZIM_CONFIG_FILE:-${ZDOTDIR:-${HOME}}/.zimrc} ]]; then
  source ${ZIM_HOME}/zimfw.zsh init
fi
# Initialize modules.
source ${ZIM_HOME}/init.zsh

# =============================================================================
# Completions & FZF (must be sourced early)
# =============================================================================

# Source FZF first (provides keybindings)
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Explicitly bind fzf keys (ensures they work if overridden elsewhere)
bindkey '^X^F' fzf-file-widget
bindkey '^R' fzf-history-widget
bindkey '^T' fzf-file-widget

# Dart completion
[[ -f $HOME/.dart-cli-completion/zsh-config.zsh ]] && . $HOME/.dart-cli-completion/zsh-config.zsh || true

# =============================================================================
# Keybindings
# =============================================================================

# Edit command line in vim when pressing 'v' in normal mode
bindkey -M vicmd v edit-command-line

# History substring search (vi mode: k/j, emacs: arrow keys / ctrl+p/n)
bindkey -M vicmd "k" history-substring-search-up
bindkey -M vicmd "j" history-substring-search-down
bindkey '^P' history-substring-search-up
bindkey '^N' history-substring-search-down
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Disable "r" command to avoid conflict with "r" language binary
disable r

# =============================================================================
# Git compdefs (after completions are loaded)
# =============================================================================

compdef config=git
compdef wiki=git

# =============================================================================
# Aliases
# =============================================================================

# General
alias ll='ls -lha'

# Editors
NVIM_PATH=$(command -v nvim || command -v vim)
alias vi="$NVIM_PATH"
alias vim="$NVIM_PATH"
alias vimdiff="$NVIM_PATH -d"

# Utils
alias calc='qalc'
alias composer='php /usr/local/bin/composer.phar'
alias resetlast="git reset --soft 'HEAD^'"
alias git_use_vim="git config --global core.editor $NVIM_PATH"

# Git
alias gittree='git log --tags --pretty="%H %d" --decorate=full --graph'
alias glog='git log --date-order --all --graph --format="%C(green)%h%Creset %C(yellow)%an%Creset %C(blue bold)%ar%Creset %C(red bold)%d %Creset%s"'
alias conflicts='vim $(git diff --name-only --diff-filter=U | fzf-tmux)'

# Docker
alias dm='docker-machine'
alias 'dmenvdefault'='eval "$(dm env default)"'
alias 'dmenvdev'='eval "$(dm env dev)"'

# Wiki/Diary
alias diary='vim -c :VimwikiDiaryIndex'
alias todo='vim -c "botright Todo"'

# =============================================================================
# Functions
# =============================================================================

# Dotfiles management
function config(){
  local dot_dir="$HOME/dotfiles"
  if [[ $# == 0 ]]
  then
    # Use git -C to run git commands in the dotfiles directory
    configfile=$(git -C "$dot_dir" ls-tree -r HEAD --name-only | fzf-tmux --height 40% --layout=reverse)
    if [ ! -z ${configfile} ]
    then 
      # Open the file in the repository (Vim handles symlink resolution if we edit the home version, but this is cleaner)
      vim "$dot_dir/$configfile"
    fi
  else
    git -C "$dot_dir" "${@:1}"
  fi
}

# Secret management
function secrets() {
    local dot_dir="$HOME/dotfiles"
    case "$1" in
        decrypt|encrypt|cleanup)
            "$dot_dir/bootstrap.sh" --"$1"
            ;;
        add)
            if [[ -z "$2" ]]; then
                echo "Usage: secrets add <file>"
                return 1
            fi
            # Logic to encrypt a new file and add .sops extension
            local pubkey_file="$HOME/.dotfiles_public_key"
            local sops_yaml="$dot_dir/.sops.yaml"
            if [[ -f "$sops_yaml" ]]; then
                sops --encrypt --input-type binary "$2" > "$2.sops"
            elif [[ -f "$pubkey_file" ]]; then
                sops --encrypt --input-type binary --age "$(cat "$pubkey_file")" "$2" > "$2.sops"
            else
                echo "Public key not found. Run 'secrets encrypt' once to set it up, or create .sops.yaml"
                return 1
            fi
            echo "Encrypted $2 to $2.sops"
            ;;
        *)
            echo "Usage: secrets [decrypt|encrypt|cleanup|add <file>]"
            ;;
    esac
}

# Wiki
function wiki-list-select(){
  local wiki=$HOME/wiki
  local wiki_work=$HOME/wiki_work

  for DIR in $wiki $wiki_work
  do
    if [ $(isDirEmpty "$DIR") -eq 0 ]
    then
      if [ -z $wiki_list ]
      then
       local wiki_list=$DIR
      else
       local wiki_list=$wiki_list"\n"$DIR
      fi
    fi
  done
  echo $wiki_list | fzf --select-1
}

function isDirEmpty(){
  DIR=$1
  if [ "$(ls -A $DIR)" ]; then
    echo 0
  else
    echo 1
  fi
}

function wiki(){
  local wiki_selected=$(wiki-list-select)
  if [[ $# == 0 ]]
  then
    vim $wiki_selected/index.md
  else
    git -C $wiki_selected ${@:1}
  fi
}

# Git functions
function git-remote-url(){
 local rmt=$1; shift || return 1
 local url
 url=`git config --get remote.${rmt}.url`
 [[ "$url" == git@* ]] && { url="https://github.com/${url##*:}" >&2; } || { url="${url%%.git}" >&2; };
 printf "%s\n" "$url"
}

function git-branch-select(){
  git branch | fzf-tmux -q '*' | cut -c3-
}

function git-current-branch(){
  git rev-parse --abbrev-ref HEAD
}

function git-remote-select(){
  git remote | fzf-tmux --select-1
}

# Find grep
ft () {
  if [[ -d "$1" && "" != $2 ]] ; then
    find $1 -name "*" | xargs fgrep $2 2>/dev/null
  else
    echo "Usage: findgrep <PATH> <TEXT_TO_FIND>"
  fi
}

# Extract archives
extract () {
   if [ -f "$1" ] ; then
       case $1 in
           *.tar.bz2)   tar xvjf -- "$1"    ;;
           *.tar.gz)    tar xvzf -- "$1"    ;;
           *.bz2)       bunzip2 -- "$1"     ;;
           *.rar)       unrar x -- "$1"     ;;
           *.gz)        gunzip -- "$1"      ;;
           *.tar)       tar xvf -- "$1"     ;;
           *.tbz2)      tar xvjf -- "$1"    ;;
           *.tgz)       tar xvzf -- "$1"    ;;
           *.zip)       unzip -- "$1"       ;;
           *.Z)         uncompress -- "$1"  ;;
           *.7z)        7z x -- "$1"        ;;
           *)           echo "don't know how to extract '$1'..." ;;
       esac
   else
       echo "'$1' is not a valid file"
   fi
}

# Epoch conversion
epoch() {
  TESTREG="[\d{10}]"
  if [[ "$1" =~ $TESTREG ]]; then
    date -d @$*
  else
    if [ $# -gt 0 ]; then
      date +%s --date="$*"
    else
      date +%s
    fi
  fi
}

# Command result indicator
function command_result (){
    if [ $? = 0 ]; then
        echo -ne "${GREEN_HI}[OK]${NC}";
    else
        echo -ne "${RED_HI}[NO]${NC}";
    fi
}

# Finder cd
cdf() {
  target=`osascript -e 'tell application "Finder" to if (count of Finder windows) > 0 then get POSIX path of (target of front Finder window as text)'`
  if [ "$target" != "" ]; then
    cd "$target"; pwd
  else
    echo 'No Finder window found' >&2
  fi
}

# Diff sorted
function diffs() {
    diff  <(sort $1) <(sort $2)
}

# k3d config
function k3dconfigwall(){
  k3d cluster list --no-headers -o string | cut -d' ' -f1 | xargs k3d kubeconfig write
}

# Kubernetes config
function kubeconfigRefresh() {
  export KUBECONFIG=$(find "$HOME/.kube" "$HOME/.config/k3d" -name "config*" -o -name "kubeconfig*" | awk '{printf "%s:", $0} END {print ""}')
}
kubeconfigRefresh

# Brew
function brew-list-sizes(){
  du -sch $(brew --cellar)/*/* | sed "s|$(brew --cellar)/\([^/]*\)/.*|\1|" | sort -k1h
}

# Dev builds
function list-dev-builds(){
  if [[ $# == 0 ]]
  then
    echo "Usage: list-dev-builds <PATH> <MAXDEPTH>"
    return -1
  fi
  find $1 -maxdepth $2 -type d \( -name "build" -o -name "node_modules" -o -name ".nx" -o -name ".next" -o -name "dist" \)
}

# RandMAC
function randmac() {
  openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//'
}

# =============================================================================
# Lazy Loaded Tools
# =============================================================================

# NVM (Node Version Manager)
nvm() {
  unset -f nvm
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  nvm "$@"
}

# SDKMAN (Java/Rust toolchain manager)
sdk() {
  unset -f sdk
  export SDKMAN_DIR="$HOME/.sdkman"
  source "$HOME/.sdkman/bin/sdkman-init.sh"
  sdk "$@"
}

# =============================================================================
# Shell Options
# =============================================================================

set -o vi
set +o noclobber
bindkey "^[[C" fzf-cd-widget
