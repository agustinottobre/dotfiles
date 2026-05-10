#!/usr/bin/env zsh
# Initialize Zim framework after chezmoi apply
# This runs once after chezmoi apply completes
# MUST use zsh — zimfw.zsh requires zsh builtins (autoload, etc.)

# Ensure Zim framework is downloaded
ZIM_HOME="${ZDOTDIR:-${HOME}}/.zim"

if [[ ! -f "${ZIM_HOME}/zimfw.zsh" ]]; then
  mkdir -p "${ZIM_HOME}"
  if (( ${+commands[curl]} )); then
    curl -fsSL "https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh" -o "${ZIM_HOME}/zimfw.zsh"
  elif (( ${+commands[wget]} )); then
    wget -nv -O "${ZIM_HOME}/zimfw.zsh" "https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh"
  fi
fi

# Ensure Zim is initialized (modules downloaded, init.zsh generated)
if [[ ! -f "${ZIM_HOME}/init.zsh" ]] || [[ "${ZIM_CONFIG_FILE:-${ZDOTDIR:-${HOME}}/.zimrc}" -nt "${ZIM_HOME}/init.zsh" ]]; then
  source "${ZIM_HOME}/zimfw.zsh" init
fi
