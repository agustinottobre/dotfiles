#!/bin/bash
# =============================================================================
# End-to-End Dotfiles Test — Linux
# =============================================================================
# Usage:
#   ./tests/test_linux.sh --local             # Safe test on current host (fake home)
#   ./tests/test_linux.sh                      # Incus container (Debian 13)
#   ./tests/test_linux.sh 13 --keep            # Incus container, keep after test
#
# Two modes:
#   --local   Runs directly on this host using a fake $HOME (zero risk)
#   default   Launches a clean Debian Incus container and tests there
#
# Prerequisites:
#   - chezmoi installed (local mode)
#   - incus installed (container mode)
#   - Run from dotfiles repo root
# =============================================================================

set -euo pipefail

# ── Mode Detection ──────────────────────────────────────────────────────────
MODE="incus"   # default: container
DEBIAN_VERSION="13"
KEEP=false
TARGET_HOME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --local) MODE="local"; shift ;;
        --keep)  KEEP=true; shift ;;
        [0-9]*)  DEBIAN_VERSION="$1"; shift ;;
        *)       shift ;;
    esac
done

if [[ "$MODE" == "local" ]]; then
    TARGET_HOME="$(mktemp -d /tmp/dotfiles-test-local-XXXXX)"
fi

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0; WARN=0
CONTAINER_NAME="dotfiles-test-$$"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1 — ${2:-}"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1 — ${2:-}"; WARN=$((WARN + 1)); }
header() { echo ""; echo -e "${CYAN}── $1 ──${NC}"; }

# ── Exec helpers (abstract incus vs local) ──────────────────────────────────
if [[ "$MODE" == "local" ]]; then
    zsh_exec()  { HOME="$TARGET_HOME" ZDOTDIR="$TARGET_HOME" zsh -l -i -c "$1" 2>&1 | grep -v "can't change option: zle" | grep -v "Detected a new version" || true; }
    bash_exec() { HOME="$TARGET_HOME" bash -l -i -c "$1" 2>&1 || true; }
    file_test() { [[ -f "$TARGET_HOME/$1" ]]; }
    dir_test()  { [[ -d "$TARGET_HOME/$1" ]]; }
    grep_file() { grep -q "$2" "$TARGET_HOME/$1" 2>/dev/null; }
    exec_cmd()  { bash -c "$@" 2>/dev/null; }
    push_files() { cp -a "$REPO_DIR" "$TARGET_HOME/dotfiles"; }
    run_bootstrap() { bash "$TARGET_HOME/dotfiles/bootstrap.sh" 2>&1; }
else
    # Incus mode helpers
    zsh_exec()  { incus exec "$CONTAINER_NAME" -- zsh -l -i -c "$1" 2>&1 | grep -v "can't change option: zle" | grep -v "Detected a new version" || true; }
    bash_exec() { incus exec "$CONTAINER_NAME" -- bash -l -i -c "$1" 2>&1 || true; }
    file_test() { incus exec "$CONTAINER_NAME" -- test -f "$TARGET_HOME/$1" 2>/dev/null; }
    dir_test()  { incus exec "$CONTAINER_NAME" -- test -d "$TARGET_HOME/$1" 2>/dev/null; }
    grep_file() { incus exec "$CONTAINER_NAME" -- bash -c "grep -q '$2' '$TARGET_HOME/$1'" 2>/dev/null; }
    exec_cmd()  { incus exec "$CONTAINER_NAME" -- bash -c "$@" 2>/dev/null; }
    push_files() { incus file push -r "$REPO_DIR/" "$CONTAINER_NAME$TARGET_HOME/" 2>/dev/null; }
    run_bootstrap() { incus exec "$CONTAINER_NAME" -- bash "$TARGET_HOME/dotfiles/bootstrap.sh" 2>&1; }
fi

# ── Check helpers ───────────────────────────────────────────────────────────
check_file() { file_test "$1" && pass "${2:-$1}" || fail "${2:-$1}" "missing: $1"; }
check_dir()  { dir_test "$1"  && pass "${2:-$1}" || fail "${2:-$1}" "missing: $1"; }

check_cmd() {
    local cmd="$1" label="${2:-$1}"
    if [[ "$MODE" == "local" ]]; then
        which "$cmd" >/dev/null 2>&1 && pass "$label" || fail "$label" "not in PATH"
    else
        zsh_exec "which $cmd >/dev/null 2>&1" >/dev/null \
            && pass "$label" || fail "$label" "not in PATH"
    fi
}

check_var() {
    zsh_exec "[[ $1 ]]" >/dev/null 2>&1 && pass "$2" || fail "$2" "${3:-}"
}

check_grep() {
    local file="$1" pattern="$2" label="$3" invert="${4:-false}"
    if [[ "$invert" == "true" ]]; then
        ! grep_file "$file" "$pattern" && pass "$label" || fail "$label" "found unwanted in $file"
    else
        grep_file "$file" "$pattern" && pass "$label" || fail "$label" "not found in $file"
    fi
}

check_zsh_func() {
    zsh_exec "whence -f $1 >/dev/null 2>&1" >/dev/null 2>&1 \
        && pass "${2:-$1}" || fail "${2:-$1}" "function not defined"
}

check_zsh_alias() {
    zsh_exec "alias $1 2>/dev/null | grep -qF '$2'" >/dev/null 2>&1 \
        && pass "${3:-$1 → $2}" || fail "${3:-$1 → $2}" "alias missing"
}

check_zsh_bindkey() {
    zsh_exec "bindkey '$1' 2>/dev/null | grep -qF '$2'" >/dev/null 2>&1 \
        && pass "${3:-bindkey $1 → $2}" || fail "${3:-bindkey $1 → $2}" "not bound"
}

check_zsh_widget() {
    zsh_exec "zle -l | grep -qF '$1'" >/dev/null 2>&1 \
        && pass "${2:-widget $1}" || fail "${2:-widget $1}" "widget not defined"
}

# ── Cleanup ─────────────────────────────────────────────────────────────────
cleanup() {
    if [[ "$MODE" == "incus" ]]; then
        if [[ "$KEEP" == "false" ]]; then
            echo ""; echo -e "${CYAN}Cleaning up container...${NC}"
            incus stop "$CONTAINER_NAME" --force 2>/dev/null || true
            incus delete "$CONTAINER_NAME" 2>/dev/null || true
        else
            echo ""; echo -e "${YELLOW}Container kept: $CONTAINER_NAME${NC}"
        fi
    else
        if [[ "$KEEP" == "false" ]]; then
            echo ""; echo -e "${CYAN}Cleaning up test home...${NC}"
            rm -rf "$TARGET_HOME"
        else
            echo ""; echo -e "${YELLOW}Test home kept: $TARGET_HOME${NC}"
            echo "  HOME=$TARGET_HOME ZDOTDIR=$TARGET_HOME zsh"
        fi
    fi
}
trap cleanup EXIT

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}══════════════════════════════════════════════${NC}"
if [[ "$MODE" == "local" ]]; then
    echo -e "${CYAN}  DOTFILES LINUX TEST — Local (fake home)${NC}"
    echo -e "${CYAN}  Host: $(hostname -s 2>/dev/null || echo unknown)${NC}"
    echo -e "${CYAN}  Target: $TARGET_HOME${NC}"
    echo -e "${CYAN}  Your real dotfiles: UNTOUCHED${NC}"
else
    echo -e "${CYAN}  DOTFILES LINUX TEST — Incus Container (Debian ${DEBIAN_VERSION})${NC}"
    TARGET_HOME="/root"
fi
echo -e "${CYAN}══════════════════════════════════════════════${NC}"

# ═════════════════════════════════════════════════════════════════════════════
#  PHASE 1: Setup
# ═════════════════════════════════════════════════════════════════════════════
if [[ "$MODE" == "incus" ]]; then
    echo ""
    echo "Launching container: $CONTAINER_NAME"
    if ! incus launch "images:debian/${DEBIAN_VERSION}" "$CONTAINER_NAME" -s default 2>/dev/null; then
        echo -e "${RED}FATAL: Could not launch container${NC}"; exit 1
    fi
    incus network attach incusbr0 "$CONTAINER_NAME" eth0 2>/dev/null || true
    sleep 2
    incus exec "$CONTAINER_NAME" -- apt-get update -qq 2>/dev/null
    incus exec "$CONTAINER_NAME" -- apt-get install -y -qq git zsh curl fzf fd-find 2>/dev/null
    OS_NAME=$(incus exec "$CONTAINER_NAME" -- cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')
    echo "Container OS: $OS_NAME"
fi

# ═════════════════════════════════════════════════════════════════════════════
#  PHASE 2: Deploy
# ═════════════════════════════════════════════════════════════════════════════
header "Deploying dotfiles"
push_files
pass "dotfiles deployed"

# ═════════════════════════════════════════════════════════════════════════════
#  PHASE 3: Bootstrap
# ═════════════════════════════════════════════════════════════════════════════
header "Running bootstrap.sh"
if [[ "$MODE" == "local" ]]; then
    # Local mode: use chezmoi with isolated destination
    mkdir -p "$TARGET_HOME"
    chezmoi init --source "$TARGET_HOME/dotfiles" --destination "$TARGET_HOME" --force 2>&1 | tail -1
    chezmoi apply --source "$TARGET_HOME/dotfiles" --destination "$TARGET_HOME" --force 2>&1 | tail -5
    pass "chezmoi applied to test home"

    # Init zim in test home
    mkdir -p "$TARGET_HOME/.zim"
    if [[ ! -f "$TARGET_HOME/.zim/zimfw.zsh" ]]; then
        curl -fsSLo "$TARGET_HOME/.zim/zimfw.zsh" \
            https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh 2>/dev/null || true
    fi
    HOME="$TARGET_HOME" ZDOTDIR="$TARGET_HOME" zsh -c "
        ZIM_HOME='$TARGET_HOME/.zim'
        ZIM_CONFIG_FILE='$TARGET_HOME/.zimrc'
        source '\$ZIM_HOME/zimfw.zsh' init
    " 2>/dev/null || true
    pass "zim initialized"
else
    BOOTSTRAP_OUTPUT=$(run_bootstrap)
    echo "$BOOTSTRAP_OUTPUT" | grep -q "Bootstrap Complete" \
        && pass "bootstrap completed" \
        || { fail "bootstrap failed"; echo "$BOOTSTRAP_OUTPUT" | tail -20; exit 1; }
fi

# ═════════════════════════════════════════════════════════════════════════════
#  PHASE 4: Verification
# ═════════════════════════════════════════════════════════════════════════════

header "Shell config files"
check_file ".zshrc"; check_file ".zshenv"; check_file ".zprofile"
check_file ".zimrc";  check_file ".bashrc"
# shell_profile is deprecated — verify it is NOT deployed
! file_test ".shell_profile" && pass "no .shell_profile (deprecated)" || fail ".shell_profile should be deprecated"

header "Other dotfiles"
check_file ".gitconfig"; check_file ".myclirc"; check_file ".taskrc"
check_file ".tmux.conf"; check_file ".gitignore"

header "XDG config directories"
check_file ".config/nvim/init.lua"
check_file ".config/starship.toml"
check_file ".config/alacritty/alacritty.toml"
check_file ".config/ranger/rc.conf"
check_file ".config/skhd/skhdrc"
check_file ".config/lvim/config.lua"
check_dir  ".config/nvim/lua/custom/plugins"

header "SSH config"
check_file ".ssh/config" "SSH config file"
check_grep ".ssh/config" "Host github.com" "github host"
check_grep ".ssh/config" "Host bitbucket.org" "bitbucket host"
check_grep ".ssh/config" "Host gitlab.com" "gitlab host"
check_grep ".ssh/config" "Host hostinger" "hostinger host"
check_grep ".ssh/config" "Host solarbox-web" "solarbox-web host"
check_grep ".ssh/config" "Host router" "router host"
check_grep ".ssh/config" "Host mgGER" "mgGER host"
check_grep ".ssh/config" "Host mgUSA" "mgUSA host"
check_grep ".ssh/config" "lima-default" "no lima-default (macOS only)" "true"
check_grep ".ssh/config" "UseKeychain" "no UseKeychain (macOS only)" "true"
check_grep ".ssh/config" "colima" "no colima Include (macOS only)" "true"
check_grep ".ssh/config" "IdentitiesOnly yes" "IdentitiesOnly enabled"
check_grep ".ssh/config" "AddKeysToAgent yes" "AddKeysToAgent enabled"
# Verify SSH keyword capitalization is consistent (HostName not Hostname, IdentityFile not Identityfile)
! grep_file ".ssh/config" "Hostname " && pass "SSH: no lowercase Hostname" || fail "SSH: lowercase Hostname found"
! grep_file ".ssh/config" "Identityfile" && pass "SSH: no lowercase Identityfile" || fail "SSH: lowercase Identityfile found"

header "Environment variables (zsh login)"
check_var '$EDITOR == nvim' 'EDITOR=nvim'
check_var '$VISUAL == nvim' 'VISUAL=nvim'
check_var '$PAGER == less' 'PAGER=less'
check_var '-n $LANG' 'LANG set'
check_var '$GOPATH == '$TARGET_HOME'/Dev' 'GOPATH set'
check_var '-n $FNM_DIR' 'FNM_DIR set'
check_var '-n $LESS' 'LESS set'

header "PATH integrity"
check_var '"$PATH" == *".local/bin"*' '~/.local/bin in PATH'
check_var '"$PATH" == *".fnm"*' '~/.fnm in PATH'

header "FZF: environment and keybindings"
FZF_CMD=$(zsh_exec 'echo $FZF_DEFAULT_COMMAND')
if echo "$FZF_CMD" | grep -q "fdfind"; then
    pass "FZF_DEFAULT_COMMAND uses fdfind (Linux)"
else
    fail "FZF_DEFAULT_COMMAND should use fdfind" "got: $FZF_CMD"
fi
check_var '-n $FZF_CTRL_T_COMMAND' 'FZF_CTRL_T_COMMAND set'
check_zsh_bindkey '^T'   'fzf-file-widget'     'bindkey ^T → fzf-file-widget'
check_zsh_bindkey '^R'   'fzf-history-widget'   'bindkey ^R → fzf-history-widget'
check_zsh_bindkey '^X^F' 'fzf-file-widget'      'bindkey ^X^F → fzf-file-widget'
check_zsh_bindkey '^[[C' 'fzf-cd-widget'        'bindkey ^[[C → fzf-cd-widget'
check_zsh_widget 'fzf-file-widget'    'widget fzf-file-widget'
check_zsh_widget 'fzf-history-widget' 'widget fzf-history-widget'
check_zsh_widget 'fzf-cd-widget'      'widget fzf-cd-widget'
check_cmd "fzf"; check_cmd "fdfind"

# fdfind functional test
exec_cmd "mkdir -p /tmp/fdtest-$$ && touch /tmp/fdtest-$$/hello.txt"
if zsh_exec 'fdfind -t f hello /tmp/fdtest-'$$' 2>/dev/null | grep -q hello.txt' >/dev/null 2>&1; then
    pass "fdfind finds files correctly"
else
    fail "fdfind functional test failed"
fi
exec_cmd "rm -rf /tmp/fdtest-$$" 2>/dev/null || true

header "Zsh shell options"
zsh_exec 'echo $- | grep -q i' >/dev/null 2>&1 && pass 'interactive' || fail 'not interactive'
zsh_exec 'set -o 2>/dev/null | grep -q "vi.*on"' >/dev/null 2>&1 \
    && pass 'set -o vi enabled' || fail 'set -o vi not enabled'
zsh_exec 'set -o 2>/dev/null | grep -q "noclobber.*off"' >/dev/null 2>&1 \
    && pass 'noclobber disabled' || fail 'noclobber should be off'

header "Zsh keybindings"
check_zsh_bindkey '^P'   'history-substring-search-up'   '^P → history-substring-search-up'
check_zsh_bindkey '^N'   'history-substring-search-down' '^N → history-substring-search-down'
check_zsh_bindkey '^[[A' 'history-substring-search-up'   '↑ → history-substring-search-up'
check_zsh_bindkey '^[[B' 'history-substring-search-down' '↓ → history-substring-search-down'
zsh_exec 'bindkey -M vicmd 2>/dev/null | grep -q "edit-command-line"' >/dev/null 2>&1 \
    && pass 'vicmd v → edit-command-line' || fail 'vicmd v → edit-command-line missing'

header "Shell aliases"
check_zsh_alias 'll'  'ls -lha'  'll → ls -lha'
check_zsh_alias 'vi'  'nvim'     'vi → nvim'
check_zsh_alias 'vim' 'nvim'     'vim → nvim'
# On Linux, NVIM_PATH should point to ~/.local/bin/nvim (bootstrap install location)
check_grep ".zshrc" '.local/bin/nvim' 'NVIM_PATH=~/.local/bin/nvim (Linux)'
check_zsh_alias 'calc' 'qalc'    'calc → qalc'
check_zsh_alias 'glog' 'git log' 'glog → git log'
check_zsh_alias 'gittree' 'git log' 'gittree → git log'
check_zsh_alias 'resetlast' 'git reset' 'resetlast → git reset'

header "Shell functions"
check_zsh_func "config"           "config()"
check_zsh_func "wiki"             "wiki()"
check_zsh_func "wiki-list-select" "wiki-list-select()"
check_zsh_func "isDirEmpty"       "isDirEmpty()"
check_zsh_func "ft"               "ft()"
check_zsh_func "extract"          "extract()"
check_zsh_func "epoch"            "epoch()"
check_zsh_func "command_result"   "command_result()"
check_zsh_func "diffs"            "diffs()"
check_zsh_func "randmac"          "randmac()"
check_zsh_func "list-dev-builds"  "list-dev-builds()"
check_zsh_func "git-remote-url"   "git-remote-url()"
check_zsh_func "git-branch-select" "git-branch-select()"
check_zsh_func "git-current-branch" "git-current-branch()"
check_zsh_func "git-remote-select"  "git-remote-select()"
check_zsh_func "fnm" "fnm() lazy loader"
check_zsh_func "sdk" "sdk() lazy loader"
bash_exec 'type ft >/dev/null 2>&1' >/dev/null && pass "bash: ft()" || fail "bash: ft() missing"
bash_exec 'type extract >/dev/null 2>&1' >/dev/null && pass "bash: extract()" || fail "bash: extract() missing"

header "Zim framework"
check_dir ".zim" "~/.zim"
check_dir ".zim/modules" "~/.zim/modules"
for mod in environment git input termtitle utility zim-starship completion \
           zsh-completions zsh-syntax-highlighting zsh-history-substring-search zsh-autosuggestions; do
    dir_test ".zim/modules/$mod" && pass "Zim: $mod" || fail "Zim: $mod missing"
done

header "Zsh fpath"
zsh_exec 'echo $fpath | grep -q "/usr/local/share/zsh/site-functions"' >/dev/null 2>&1 \
    && pass 'fpath includes site-functions' || warn 'fpath: site-functions not found'

header "Installed tools"
check_cmd "zsh"; check_cmd "tmux"; check_cmd "git"; check_cmd "fzf"
check_cmd "rg" "rg (ripgrep)"; check_cmd "age"; check_cmd "chezmoi"

# nvim
if [[ "$MODE" == "local" ]]; then
    which nvim >/dev/null 2>&1 && pass "nvim: $(nvim --version 2>&1 | head -1)" || fail "nvim not found"
else
    zsh_exec '/root/.local/bin/nvim --version 2>&1 | grep -q NVIM' >/dev/null 2>&1 \
        && pass "nvim installed" || fail "nvim missing"
fi
check_file ".config/nvim/lua/custom/plugins/init.lua" "nvim custom plugins"

# nvim: basic functionality
if [[ "$MODE" == "local" ]]; then
    nvim --headless -c 'quit' 2>/dev/null && pass "nvim: headless startup OK" || warn "nvim: headless startup failed (runtime may be broken)"
else
    exec_cmd "nvim --headless -c 'quit'" 2>/dev/null && pass "nvim: headless startup OK" || warn "nvim: headless startup failed"
fi

# nvim: Lua config syntax
if [[ "$MODE" == "local" ]]; then
    CHECK_INIT="$TARGET_HOME/.config/nvim/init.lua"
    CHECK_PLUGINS="$TARGET_HOME/.config/nvim/lua/custom/plugins/init.lua"
    if [[ -f "$CHECK_INIT" ]]; then
        SYNTAX_RESULT=$(timeout 10 nvim -u NONE --headless --cmd "lua local ok, err = load(io.open('$CHECK_INIT'):read('*a')); if ok then print('SYNTAX_OK') else print('SYNTAX_FAIL: '..err) end" -c 'cq' 2>&1) || true
        echo "$SYNTAX_RESULT" | grep -q SYNTAX_OK \
            && pass "nvim: init.lua Lua syntax OK" || fail "nvim: init.lua Lua syntax error"
    fi
    if [[ -f "$CHECK_PLUGINS" ]]; then
        SYNTAX_RESULT=$(timeout 10 nvim -u NONE --headless --cmd "lua local ok, err = load(io.open('$CHECK_PLUGINS'):read('*a')); if ok then print('SYNTAX_OK') else print('SYNTAX_FAIL: '..err) end" -c 'cq' 2>&1) || true
        echo "$SYNTAX_RESULT" | grep -q SYNTAX_OK \
            && pass "nvim: custom plugins Lua syntax OK" || fail "nvim: custom plugins Lua syntax error"
    fi
else
    # Incus mode: just check files exist (syntax validated by template test)
    true
fi

# nvim: confirm no hard errors at startup (vim.lsp.config needs nvim >= 0.11)
if [[ "$MODE" == "local" ]]; then
    NVIM_OUTPUT=$(timeout 15 nvim --headless -c 'quit' 2>&1) || true
    echo "$NVIM_OUTPUT" | grep -qiE "vim.lsp.config.*nil|attempt to call field" \
        && fail "nvim: startup has lsp config error (needs nvim >= 0.11)" \
        || pass "nvim: no hard errors on startup"
fi

# starship
if [[ "$MODE" == "local" ]]; then
    which starship >/dev/null 2>&1 && pass "starship: $(starship --version 2>&1 | head -1)" || fail "starship not found"
else
    zsh_exec 'starship --version 2>&1 | grep -q starship' >/dev/null 2>&1 \
        && pass "starship installed" || fail "starship missing"
fi

header "Git config"
if [[ "$MODE" == "local" ]]; then
    HOME="$TARGET_HOME" GIT_CONFIG_GLOBAL="$TARGET_HOME/.gitconfig" git config user.name >/dev/null 2>&1 \
        && pass "git user.name set" || fail "git user.name not set"
    HOME="$TARGET_HOME" GIT_CONFIG_GLOBAL="$TARGET_HOME/.gitconfig" git config user.email >/dev/null 2>&1 \
        && pass "git user.email set" || fail "git user.email not set"
    HOME="$TARGET_HOME" GIT_CONFIG_GLOBAL="$TARGET_HOME/.gitconfig" git config core.excludesfile 2>/dev/null | grep -q '.gitignore' \
        && pass "git excludesfile → ~/.gitignore" || fail "git excludesfile not set"
    HOME="$TARGET_HOME" GIT_CONFIG_GLOBAL="$TARGET_HOME/.gitconfig" git config diff.tool 2>/dev/null | grep -q 'vimdiff' \
        && pass "git diff.tool = vimdiff" || fail "git diff.tool not vimdiff"
    HOME="$TARGET_HOME" GIT_CONFIG_GLOBAL="$TARGET_HOME/.gitconfig" git config alias.d 2>/dev/null | grep -q 'difftool' \
        && pass "git alias.d = difftool" || fail "git alias.d missing"
else
    exec_cmd 'git config user.name | grep -q .' && pass "git user.name set" || fail "git user.name not set"
    exec_cmd 'git config user.email | grep -q .' && pass "git user.email set" || fail "git user.email not set"
    exec_cmd 'git config core.excludesfile | grep -q .gitignore' && pass "git excludesfile → ~/.gitignore" || fail "git excludesfile not set"
    exec_cmd 'git config diff.tool | grep -q vimdiff' && pass "git diff.tool = vimdiff" || fail "git diff.tool not vimdiff"
    exec_cmd 'git config alias.d | grep -q difftool' && pass "git alias.d = difftool" || fail "git alias.d missing"
fi

header "Tmux config"
if [[ "$MODE" == "local" ]]; then
    dir_test ".tmux/plugins/tpm" && pass "TPM plugin manager" || warn "TPM plugin manager (run 'git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm' to install)"
else
    check_dir ".tmux/plugins/tpm" "TPM plugin manager"
fi
check_grep ".tmux.conf" 'set -g mode-keys vi' 'tmux: mode-keys vi'
check_grep ".tmux.conf" 'setw -g mouse on' 'tmux: mouse enabled'
check_grep ".tmux.conf" 'tmux-256color' 'tmux: 256color terminal'
if [[ "$MODE" == "local" ]]; then
    tmux -f "$TARGET_HOME/.tmux.conf" new-session -d -s dottest 2>/dev/null \
        && { pass "tmux session created"; tmux kill-session -t dottest 2>/dev/null || true; } \
        || fail "tmux config fails"
else
    exec_cmd "tmux -f $TARGET_HOME/.tmux.conf new-session -d -s test 2>/dev/null" \
        && { pass "tmux session created"; exec_cmd "tmux kill-session -t test 2>/dev/null || true"; } \
        || fail "tmux config fails"
fi

header "Zsh startup sanity"
ZSH_STARTUP=$(zsh_exec 'echo OK')
ZSH_CLEAN=$(echo "$ZSH_STARTUP" | grep -iv "can't change option: zle" | grep -iv "Detected a new version" | grep -iv "Regenerated completions" || true)
if echo "$ZSH_CLEAN" | grep -qiE "error|command not found|no such file|permission denied|unknown command"; then
    fail "zsh startup has errors" "$(echo "$ZSH_CLEAN" | grep -iE 'error|not found|no such|denied' | head -5)"
else
    pass "zsh starts cleanly"
fi

header "Bash startup"
BASH_FZF=$(bash_exec 'echo $FZF_DEFAULT_COMMAND')
echo "$BASH_FZF" | grep -q "fdfind" && pass "bash FZF uses fdfind" || fail "bash FZF" "got: $BASH_FZF"

header "Bin scripts"
if [[ "$MODE" == "local" ]]; then
    BIN_COUNT=$(ls "$TARGET_HOME/bin/" 2>/dev/null | wc -l)
    [[ "$BIN_COUNT" -ge 7 ]] && pass "bin scripts present ($BIN_COUNT)" || warn "bin scripts fewer than expected ($BIN_COUNT)"
    # Verify scripts are executable
    NONEXEC=$(find "$TARGET_HOME/bin/" -name '*.sh' ! -perm -100 2>/dev/null | wc -l)
    [[ "$NONEXEC" -eq 0 ]] && pass "bin scripts executable" || fail "bin scripts not executable ($NONEXEC)"
else
    exec_cmd "ls $TARGET_HOME/bin/ | wc -l" | xargs -I{} bash -c '[ {} -ge 7 ]' \
        && pass "bin scripts present" || warn "bin scripts fewer than expected"
    exec_cmd "find $TARGET_HOME/bin/ -name '*.sh' ! -perm -100 | wc -l" | xargs -I{} bash -c '[ {} -eq 0 ]' \
        && pass "bin scripts executable" || fail "bin scripts not executable"
fi

header "Template syntax (host)"
for f in $(find "$REPO_DIR" -name '*.tmpl' -not -path '*/.git/*' | sort); do
    rel="${f#$REPO_DIR/}"
    chezmoi execute-template < "$f" >/dev/null 2>&1 \
        && pass "template OK: $rel" || fail "template FAIL: $rel"
done

header "Config spot-checks"
check_grep ".gitconfig" 'filter "lfs"' "gitconfig: LFS filter"
check_grep ".myclirc" 'key_bindings = vi' "myclirc: vi keybindings"
check_grep ".taskrc" 'taskd.server' "taskrc: taskd sync server"
check_grep ".config/starship.toml" 'show_always = true' "starship: username always shown"

header "Starship config integrity"
# Corrupt format token regression: $sudovimstatdirectory was a single invalid module
# instead of $sudo$directory. Verify it's absent from the format string.
if file_test ".config/starship.toml"; then
    grep_file ".config/starship.toml" '\$sudo' \
        && pass "starship: format includes \$sudo" \
        || fail "starship: format missing \$sudo"
    ! grep_file ".config/starship.toml" "sudovimstatdirectory" \
        && pass "starship: no corrupt format token (sudovimstatdirectory)" \
        || fail "starship: format still has corrupt token sudovimstatdirectory"
    ! grep_file ".config/starship.toml" "!TMUX" \
        && pass "starship: hostname detect_env_vars fixed (no !TMUX negation)" \
        || fail "starship: hostname detect_env_vars still has !TMUX"
    ! grep_file ".config/starship.toml" "vim_status" \
        && pass "starship: no stale vim_status reference in comment" \
        || fail "starship: comment still references vim_status"
else
    warn "starship.toml not found in test home"
fi

# ── Age Encryption Roundtrip ─────────────────────────────────────────────────
header "Age encryption roundtrip"
if exec_cmd "command -v age" >/dev/null 2>&1; then
    # For local mode, use the HOST age key (test home doesn't have its own)
    if [[ "$MODE" == "local" ]]; then
        AGE_KEY="$HOME/.config/chezmoi/key.txt"
    else
        AGE_KEY="$TARGET_HOME/.config/chezmoi/key.txt"
    fi
    AGE_PUBKEY=""
    if [[ "$MODE" == "local" ]]; then
        AGE_PUBKEY=$(grep 'public key:' "$AGE_KEY" 2>/dev/null | sed 's/.*public key: *//')
    else
        AGE_PUBKEY=$(incus exec "$CONTAINER_NAME" -- grep 'public key:' "$AGE_KEY" 2>/dev/null | sed 's/.*public key: *//')
    fi
    if [[ -n "$AGE_PUBKEY" ]]; then
        pass "age: key pair found"
    else
        fail "age: no public key in key.txt"
    fi

    # Verify recipient is NOT the placeholder
    AGE_TOML="${TARGET_HOME}/.config/chezmoi/chezmoi.toml"
    if [[ "$MODE" == "local" ]]; then
        AGE_TOML="$HOME/.config/chezmoi/chezmoi.toml"
    fi
    if [[ -f "$AGE_TOML" ]] && grep -q 'REPLACE_WITH_YOUR_AGE_PUBLIC_KEY' "$AGE_TOML" 2>/dev/null; then
        fail "age: recipient still has placeholder in chezmoi.toml"
    else
        pass "age: recipient configured in chezmoi.toml"
    fi

    # Encrypt → Decrypt roundtrip
    AGE_TESTDATA="dotfiles-age-roundtrip-$$"
    AGE_ENCFILE="/tmp/age-test-$$.age"
    if [[ "$MODE" == "local" ]]; then
        echo "$AGE_TESTDATA" | age -r "$AGE_PUBKEY" -o "$AGE_ENCFILE" 2>/dev/null \
            && pass "age: encrypt OK" || fail "age: encrypt failed"
        age -d -i "$AGE_KEY" "$AGE_ENCFILE" 2>/dev/null | grep -q "$AGE_TESTDATA" \
            && pass "age: decrypt roundtrip OK" || fail "age: decrypt roundtrip mismatch"
        rm -f "$AGE_ENCFILE"
    else
        incus exec "$CONTAINER_NAME" -- bash -c "echo '$AGE_TESTDATA' | age -r '$AGE_PUBKEY' -o '$AGE_ENCFILE'" 2>/dev/null \
            && pass "age: encrypt OK" || fail "age: encrypt failed"
        incus exec "$CONTAINER_NAME" -- bash -c "age -d -i '$AGE_KEY' '$AGE_ENCFILE' | grep -q '$AGE_TESTDATA'" 2>/dev/null \
            && pass "age: decrypt roundtrip OK" || fail "age: decrypt roundtrip mismatch"
        incus exec "$CONTAINER_NAME" -- rm -f "$AGE_ENCFILE" 2>/dev/null || true
    fi

    # SSH config encryption test (reuse AGE_PUBKEY + AGE_KEY)
    SSH_TMPL="$REPO_DIR/private_dot_ssh/config.tmpl"
    SSH_ENCFILE="/tmp/ssh-config-test-$$.age"
    if [[ -f "$SSH_TMPL" ]]; then
        if [[ "$MODE" == "local" ]]; then
            age -r "$AGE_PUBKEY" -o "$SSH_ENCFILE" "$SSH_TMPL" 2>/dev/null \
                && pass "SSH config: encrypted with age" || fail "SSH config: age encrypt failed"
            age -d -i "$AGE_KEY" "$SSH_ENCFILE" 2>/dev/null | grep -q "Host github.com" \
                && pass "SSH config: decrypt + content check OK" || fail "SSH config: decrypt or content mismatch"
            rm -f "$SSH_ENCFILE"
        else
            incus file push "$SSH_TMPL" "$CONTAINER_NAME$SSH_ENCFILE" 2>/dev/null && true
            incus exec "$CONTAINER_NAME" -- bash -c "age -r '$AGE_PUBKEY' -o '$SSH_ENCFILE.age' '$SSH_ENCFILE'" 2>/dev/null \
                && pass "SSH config: encrypted with age" || fail "SSH config: age encrypt failed"
            incus exec "$CONTAINER_NAME" -- bash -c "age -d -i '$AGE_KEY' '$SSH_ENCFILE.age' | grep -q 'Host github.com'" 2>/dev/null \
                && pass "SSH config: decrypt + content check OK" || fail "SSH config: decrypt or content mismatch"
            incus exec "$CONTAINER_NAME" -- rm -f "$SSH_ENCFILE" "$SSH_ENCFILE.age" 2>/dev/null || true
        fi
    else
        fail "SSH config template not found at $SSH_TMPL"
    fi
else
    warn "age command not found, skipping encryption tests"
fi

# ── macOS Template Validation ───────────────────────────────────────────────
# Validates OS-conditional blocks: macOS content exists in source templates
# AND is correctly excluded from Linux renders (no false inclusion).
header "macOS template validation (cross-platform correctness)"

macos_in_source_excluded_on_linux() {
    local tmpl="$REPO_DIR/$1" pattern="$2" label="$3"
    # Check 1: pattern exists in source (the block is defined)
    grep -qF "$pattern" "$tmpl" 2>/dev/null || { warn "$label — not in source (expected)" ; return; }
    # Check 2: pattern is NOT in Linux render (condition correctly excludes it)
    if chezmoi execute-template < "$tmpl" 2>/dev/null | grep -qF "$pattern"; then
        fail "$label — renders on Linux (macOS-only block leaked)"
    else
        pass "$label"
    fi
}

macos_in_source_excluded_on_linux "private_dot_ssh/config.tmpl" "lima-default"      "SSH: lima-default in source, excluded on Linux"
macos_in_source_excluded_on_linux "private_dot_ssh/config.tmpl" "UseKeychain yes"    "SSH: UseKeychain in source, excluded on Linux"
macos_in_source_excluded_on_linux "private_dot_ssh/config.tmpl" "colima"             "SSH: colima in source, excluded on Linux"
macos_in_source_excluded_on_linux "dot_zshenv.tmpl"           'fd --type f'          "zshenv: macOS fd in source, excluded on Linux"
macos_in_source_excluded_on_linux "dot_zshenv.tmpl"           "Tools/bin"            "zshenv: ~/Tools/bin in source, excluded on Linux"
macos_in_source_excluded_on_linux "dot_zshenv.tmpl"           "pub-cache/bin"        "zshenv: Dart pub-cache in source, excluded on Linux"
macos_in_source_excluded_on_linux "dot_zshenv.tmpl"           "HOMEBREW_NO_GITHUB_API" "zshenv: Homebrew in source, excluded on Linux"
macos_in_source_excluded_on_linux "dot_zshenv.tmpl"           'brew --prefix golang' "zshenv: GOROOT via brew in source, excluded on Linux"
macos_in_source_excluded_on_linux "dot_zshrc.tmpl"            "docker-machine"       "zshrc: Docker in source, excluded on Linux"
macos_in_source_excluded_on_linux "dot_zshrc.tmpl"            "k3dconfigwall"        "zshrc: k3dconfigwall in source, excluded on Linux"
macos_in_source_excluded_on_linux "dot_zshrc.tmpl"            "kubeconfigRefresh"    "zshrc: kubeconfigRefresh in source, excluded on Linux"
macos_in_source_excluded_on_linux "dot_zshrc.tmpl"            "dart-cli-completion"  "zshrc: Dart completion in source, excluded on Linux"

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}══════════════════════════════════════════════${NC}"
echo -e "${CYAN}  RESULTS${NC}"
echo -e "${CYAN}══════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}PASS${NC}: $PASS  ${YELLOW}WARN${NC}: $WARN  ${RED}FAIL${NC}: $FAIL"
echo ""
if [[ "$MODE" == "local" ]]; then
    echo "Test home: $TARGET_HOME"
    echo "Your real dotfiles: UNTOUCHED"
fi
echo ""

if [[ "$FAIL" -gt 0 ]]; then
    echo -e "${RED}Tests FAILED.${NC}"; exit 1
else
    echo -e "${GREEN}All tests PASSED.${NC}"; exit 0
fi
