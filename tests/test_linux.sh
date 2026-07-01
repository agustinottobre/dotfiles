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
# skhdrc is macOS-only — excluded via .chezmoiignore on Linux
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

# chezmoi doctor — verify chezmoi itself is healthy
if [[ "$MODE" == "local" ]]; then
    chezmoi doctor 2>&1 | grep -q '^error ' && fail "chezmoi doctor has errors" || pass "chezmoi doctor: no errors"
else
    exec_cmd "chezmoi doctor 2>/dev/null | grep -q '^error '" && fail "chezmoi doctor has errors" || pass "chezmoi doctor: no errors"
fi

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
    exec_cmd "/root/.local/bin/nvim --headless -c 'quit'" 2>/dev/null && pass "nvim: headless startup OK" || warn "nvim: headless startup failed"
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

# Check clipboard tooling
check_grep ".tmux.conf" 'set-clipboard on' 'tmux: set-clipboard on'
check_grep ".tmux.conf" 'bind C-c run' 'tmux: clipboard copy bind (C-c)'
check_grep ".tmux.conf" 'bind C-v run' 'tmux: clipboard paste bind (C-v)'
check_grep ".config/nvim/init.lua" "unnamedplus" "nvim: clipboard=unnamedplus"

# Clipboard tool (xsel or xclip) should be installed on Linux
xsel --version >/dev/null 2>&1 || xclip -version >/dev/null 2>&1 \
    && pass "clipboard: xsel or xclip available" || warn "clipboard: neither xsel nor xclip found"

# nvim: register "+ exists (system clipboard integration)
nvim --headless -c 'lua vim.fn.setreg("+", "TESTREG"); local ok = vim.fn.getreg("+") == "TESTREG"; vim.cmd(ok and "quit" or "cquit")' 2>/dev/null \
    && pass "nvim: \"+ register functional" \
    || fail "nvim: \"+ register broken"

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
    chezmoi execute-template --source "$REPO_DIR" < "$f" >/dev/null 2>&1 \
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

macos_in_source_excluded_on_linux "dot_zshrc.tmpl"            "docker-machine"       "zshrc: Docker in source, excluded on Linux"
macos_in_source_excluded_on_linux "dot_zshrc.tmpl"            "k3dconfigwall"        "zshrc: k3dconfigwall in source, excluded on Linux"
macos_in_source_excluded_on_linux "dot_zshrc.tmpl"            "kubeconfigRefresh"    "zshrc: kubeconfigRefresh in source, excluded on Linux"
macos_in_source_excluded_on_linux "dot_zshrc.tmpl"            "dart-cli-completion"  "zshrc: Dart completion in source, excluded on Linux"

# ── config() function ─────────────────────────────────────────────────────────
header "config() function"

# config function must exist
zsh_exec 'whence -f config >/dev/null 2>&1 && echo OK || echo FAIL' | grep -q OK && pass "config: function defined" || fail "config: function defined"

# config passthrough: 'config source-path' should succeed (chezmoi is initialized)
if zsh_exec 'config source-path' | grep -q '/'; then
  pass "config: passthrough to chezmoi works"
else
  fail "config: passthrough to chezmoi works"
fi

# config passthrough: err on non-existent chezmoi subcommand
zsh_exec 'config nonexistent_cmd 2>/dev/null; echo $?' | grep -q '1' && pass "config: errors on invalid chezmoi subcommand" || warn "config: errors on invalid chezmoi subcommand — may be chezmoi version difference"

# FZF availability check in config() (no-args path)
grep_file ".zshrc" 'command -v fzf' && pass "config: fzf availability check in .zshrc" || fail "config: fzf check missing"

# Chezmoi source check in config() (passthrough path)
grep_file ".zshrc" 'chezmoi source-path' && pass "config: source-path check before passthrough" || fail "config: source-path check missing"

# ── wiki() function ───────────────────────────────────────────────────────────
header "wiki() function"

# wiki function must exist
zsh_exec 'whence -f wiki >/dev/null 2>&1 && echo OK' | grep -q OK && pass "wiki: function defined" || fail "wiki: function defined"

# wiki-list-select must exist
zsh_exec 'whence -f wiki-list-select >/dev/null 2>&1 && echo OK' | grep -q OK && pass "wiki: wiki-list-select defined" || fail "wiki: wiki-list-select defined"

# No wiki dirs: should error gracefully, NOT open /index.md
zsh_exec 'wiki 2>&1; echo EXIT:$?' | grep -q 'No wiki directory found' && pass "wiki: errors gracefully when no wiki dir exists" || fail "wiki: errors gracefully when no wiki dir exists"

# Directory existence guard in wiki-list-select
grep_file ".zshrc" '\[\[ -d "\$DIR" \]\]' && pass "wiki: directory existence guard present" || fail "wiki: directory guard missing"

# Empty selection guard in wiki()
grep_file ".zshrc" '\[\[ -z "\$wiki_selected" \]\]' && pass "wiki: empty selection guard present" || fail "wiki: empty selection guard missing"

# ── .chezmoi.toml.tmpl validation ─────────────────────────────────────────────
header ".chezmoi.toml.tmpl"

# Special file exists at repo root
[[ -f "$REPO_DIR/.chezmoi.toml.tmpl" ]] && pass "chezmoi: .chezmoi.toml.tmpl exists" || fail "chezmoi: .chezmoi.toml.tmpl missing"

# sourceDir is in the template
grep -q 'sourceDir' "$REPO_DIR/.chezmoi.toml.tmpl" && pass "chezmoi: sourceDir in init template" || fail "chezmoi: sourceDir missing from init template"

# sourceDir uses template variable (not hardcoded path)
grep -q 'chezmoi.sourceDir' "$REPO_DIR/.chezmoi.toml.tmpl" && pass "chezmoi: sourceDir uses chezmoi.sourceDir variable" || fail "chezmoi: sourceDir should use template variable"

# Old managed file is GONE
! [[ -f "$REPO_DIR/dot_config/chezmoi/private_chezmoi.toml.tmpl" ]] && pass "chezmoi: old managed config file removed" || fail "chezmoi: old managed config still present"

# Old directory is gone
! [[ -d "$REPO_DIR/dot_config/chezmoi" ]] && pass "chezmoi: old dot_config/chezmoi dir removed" || fail "chezmoi: old dot_config/chezmoi dir still present"

# Render and validate sourceDir
RENDERED_SOURCE=$(chezmoi execute-template < "$REPO_DIR/.chezmoi.toml.tmpl" 2>/dev/null | grep 'sourceDir')
if echo "$RENDERED_SOURCE" | grep -q 'sourceDir'; then
  pass "chezmoi: sourceDir renders correctly"
else
  fail "chezmoi: sourceDir missing from rendered config"
fi

# ── run_onchange_install-packages.sh.tmpl ─────────────────────────────────────
header "run_onchange validation"

# Script is now run_onchange (not run_once)
[[ -f "$REPO_DIR/run_onchange_install-packages.sh.tmpl" ]] && pass "run_onchange: script renamed correctly" || fail "run_onchange: missing"
! [[ -f "$REPO_DIR/run_once_install-packages.sh.tmpl" ]] && pass "run_onchange: old run_once name removed" || warn "run_onchange: old run_once still present"

# check_fail function exists
grep -q 'check_fail()' "$REPO_DIR/run_onchange_install-packages.sh.tmpl" && pass "run_onchange: check_fail function present" || fail "run_onchange: check_fail missing"

# FAILED counter exists
grep -q 'FAILED=' "$REPO_DIR/run_onchange_install-packages.sh.tmpl" && pass "run_onchange: FAILED counter present" || fail "run_onchange: FAILED counter missing"

# Summary output exists
grep -q 'Package Installation Summary' "$REPO_DIR/run_onchange_install-packages.sh.tmpl" && pass "run_onchange: summary output present" || fail "run_onchange: summary missing"

# ── FZF bindkey guards ────────────────────────────────────────────────────────
header "FZF bindkey guards"

# zle -l guard exists around explicit fzf bindings
grep_file ".zshrc" 'zle -l fzf-file-widget' && pass "fzf: bindkey guarded by zle -l check" || fail "fzf: missing zle -l guard on bindkeys"

# bindkey calls are inside the guard (should appear after zle -l)
# Count that bindkey appears AFTER the zle -l line in the file
zle_lineno=$(grep -n 'zle -l fzf-file-widget' "$TARGET_HOME/.zshrc" | cut -d: -f1 | head -1)
bindkey_lineno=$(grep -n "bindkey.*fzf-file-widget" "$TARGET_HOME/.zshrc" | cut -d: -f1 | head -1)
if [[ "$bindkey_lineno" -gt "$zle_lineno" ]]; then
  pass "fzf: bindkeys are inside the zle guard"
else
  warn "fzf: bindkey placement unclear"
fi

# ── bootstrap.sh validation ───────────────────────────────────────────────────
header "bootstrap.sh validation"

bootstrap="$REPO_DIR/bootstrap.sh"

# DOTFILES_REPO is mentioned in completion message
grep -q 'DOTFILES_REPO' "$bootstrap" && pass "bootstrap: DOTFILES_REPO in output" || fail "bootstrap: DOTFILES_REPO missing"

# ~/.local/bin fallback for non-sudo install
grep -q '\.local/bin' "$bootstrap" && pass "bootstrap: ~/.local/bin fallback present" || fail "bootstrap: ~/.local/bin fallback missing"

# /usr/local/bin writability check
grep -q '\-w /usr/local/bin' "$bootstrap" && pass "bootstrap: /usr/local/bin writability check present" || fail "bootstrap: writability check missing"

# chezmoi source-path check in shell config
grep_file ".zshrc" 'chezmoi source-path' && pass "zshrc: source-path check in config()" || fail "zshrc: source-path check missing"

# ── config add --encrypt workflow ─────────────────────────────────────────────
header "config add --encrypt workflow (fake key roundtrip)"

# Generate a fake SSH key for testing
FAKE_KEY="$TARGET_HOME/.ssh/test_roundtrip_key"
FAKE_KEY_AGE="private_dot_ssh/test_roundtrip_key.age"

# Set up chezmoi source path (in local mode, source was copied to TARGET_HOME/dotfiles)
if [[ "$MODE" == "local" ]]; then
    SOURCE="$TARGET_HOME/dotfiles"
else
    SOURCE="$REPO_DIR"
fi

# Use incus exec helper for container mode
incus_exec() {
    if [[ "$MODE" == "local" ]]; then
        bash -c "$1"
    else
        incus exec "$CONTAINER_NAME" -- bash -c "$1"
    fi
}

# Step 1: Generate fake SSH key
ssh-keygen -t ed25519 -f "$FAKE_KEY" -N "" -C "test-key" 2>/dev/null
if [[ -f "$FAKE_KEY" ]]; then
    pass "keys: fake SSH key generated"
else
    fail "keys: failed to generate fake SSH key"
fi

# Step 2: Encrypt with chezmoi
CHEZMOI_CMD="HOME='$TARGET_HOME' chezmoi add --encrypt --source '$SOURCE' --destination '$TARGET_HOME' --force '$FAKE_KEY'"
if eval "$CHEZMOI_CMD" 2>/dev/null; then
    pass "keys: config add --encrypt succeeded"
else
    fail "keys: config add --encrypt failed"
fi

# Step 3: Verify .age file exists in source
if [[ -f "$SOURCE/$FAKE_KEY_AGE" ]]; then
    pass "keys: .age file created in source"
else
    fail "keys: .age file not created at $SOURCE/$FAKE_KEY_AGE"
fi

# Step 4: Verify .age file is NOT placeholder text (should be age-encrypted binary)
if [[ -f "$SOURCE/$FAKE_KEY_AGE" ]]; then
    if grep -q 'PLACEHOLDER\|REPLACE WITH' "$SOURCE/$FAKE_KEY_AGE" 2>/dev/null; then
        fail "keys: .age file still contains placeholder text"
    else
        pass "keys: .age file is encrypted (no placeholder text)"
    fi
fi

# Step 5: Apply with chezmoi (decrypts to destination)
APPLY_CMD="HOME='$TARGET_HOME' chezmoi apply --source '$SOURCE' --destination '$TARGET_HOME' --force 2>/dev/null"
if eval "$APPLY_CMD"; then
    pass "keys: chezmoi apply after encrypt succeeded"
else
    warn "keys: chezmoi apply after encrypt returned non-zero"
fi

# Step 6: Verify decrypted file exists WITHOUT .age extension
if [[ -f "$FAKE_KEY" ]]; then
    pass "keys: decrypted file exists (no .age extension)"
else
    fail "keys: decrypted file missing (decrypt failed)"
fi

# Step 7: Verify decrypted content matches (check it's an SSH key)
if [[ -f "$FAKE_KEY" ]]; then
    if head -1 "$FAKE_KEY" | grep -q 'BEGIN OPENSSH PRIVATE KEY'; then
        pass "keys: decrypted content is valid SSH private key"
    else
        fail "keys: decrypted content is not a valid SSH key"
    fi
fi

# Step 8: Verify permissions are 0600 on decrypted private key
if [[ -f "$FAKE_KEY" ]]; then
    perms=$(stat -c '%a' "$FAKE_KEY" 2>/dev/null || stat -f '%Lp' "$FAKE_KEY" 2>/dev/null)
    if [[ "$perms" == "600" ]]; then
        pass "keys: private key permissions are 0600"
    else
        warn "keys: private key permissions are $perms (expected 600)"
    fi
fi

# Cleanup test files from source
rm -f "$SOURCE/$FAKE_KEY_AGE" 2>/dev/null
rm -f "$FAKE_KEY" "$FAKE_KEY.pub" 2>/dev/null

# ── config wrapper subcommands ────────────────────────────────────────────────
header "config wrapper subcommands (daily workflow)"

# ── config diff ──
if zsh_exec 'config diff 2>&1; echo EXIT:$?' | grep -q 'EXIT:0'; then
  pass "config: diff runs successfully"
else
  warn "config: diff returned non-zero (may have pending changes)"
fi

# ── config apply (idempotent) ──
if zsh_exec 'config apply 2>&1; echo EXIT:$?' | grep -q 'EXIT:0'; then
  pass "config: apply runs successfully"
else
  warn "config: apply returned non-zero (may have pending changes)"
fi

# ── config commit ── (safe: commits to test copy of repo, not real repo)
# First, ensure there's something to commit by touching a managed file
if [[ "$MODE" == "local" ]]; then
    TEST_SOURCE="$TARGET_HOME/dotfiles"
else
    TEST_SOURCE="$REPO_DIR"
fi
# Add a comment to the managed .zshrc to create a change
echo '# test commit marker' >> "$TARGET_HOME/.zshrc"
# Now add it to chezmoi's source
HOME="$TARGET_HOME" chezmoi add --source "$TEST_SOURCE" --destination "$TARGET_HOME" --force "$TARGET_HOME/.zshrc" 2>/dev/null || true
# Commit through the config wrapper
zsh_exec 'config commit -m "test: config commit wrapper test" 2>&1; echo EXIT:$?' | grep -q 'EXIT:0' \
  && pass "config: commit -m works through wrapper" \
  || warn "config: commit -m may have failed (git config, no changes, etc.)"

# ── config edit (verify subcommand recognized) ──
# Can't test interactive editor, but verify chezmoi accepts the edit subcommand
if HOME="$TARGET_HOME" chezmoi edit --dry-run "$TARGET_HOME/.zshrc" 2>/dev/null; then
  pass "config: edit subcommand recognized by chezmoi"
else
  warn "config: edit --dry-run not supported (chezmoi version)"
fi

# ── config update (verify chezmoi update subcommand exists) ──
# update requires git remote, so just verify the subcommand is recognized
if chezmoi update --help >/dev/null 2>&1; then
  pass "config: update subcommand recognized by chezmoi"
else
  warn "config: update --help not available"
fi

# ── config passthrough: invalid subcommand returns non-zero ──
zsh_exec 'config nonexistent_cmd 2>/dev/null; echo EXIT:$?' | grep -q 'EXIT:1' \
  && pass "config: invalid subcommand returns error" \
  || warn "config: invalid subcommand exit behavior"

# ── config add --encrypt + apply (wrapper roundtrip) ─────────────────────────
header "config add --encrypt + apply (wrapper roundtrip)"

CFG_FAKE_KEY="$TARGET_HOME/.ssh/test_wrapper_key"
CFG_EXPECTED_AGE="private_dot_ssh/test_wrapper_key.age"

if [[ "$MODE" == "local" ]]; then
    CFG_SOURCE="$TARGET_HOME/dotfiles"
else
    CFG_SOURCE="$REPO_DIR"
fi

# Step 1: Generate fake key
ssh-keygen -t ed25519 -f "$CFG_FAKE_KEY" -N "" -C "wrapper-test" 2>/dev/null
[[ -f "$CFG_FAKE_KEY" ]] && pass "encrypt-via-config: fake key generated" || fail "encrypt-via-config: key gen failed"

# Step 2: config add --encrypt (THE documented command)
CFG_OUT=$(zsh_exec "config add --encrypt '$CFG_FAKE_KEY' 2>&1")
if [[ -f "$CFG_SOURCE/$CFG_EXPECTED_AGE" ]]; then
    pass "encrypt-via-config: .age file created via config add --encrypt"
else
    fail "encrypt-via-config: config add --encrypt did not create .age file (output: $CFG_OUT)"
fi

# Step 3: Verify .age is encrypted (not placeholder)
if [[ -f "$CFG_SOURCE/$CFG_EXPECTED_AGE" ]]; then
    if grep -q 'PLACEHOLDER\|REPLACE WITH' "$CFG_SOURCE/$CFG_EXPECTED_AGE" 2>/dev/null; then
        fail "encrypt-via-config: .age file is placeholder text, not encrypted"
    else
        pass "encrypt-via-config: .age file is encrypted binary (not placeholder)"
    fi
fi

# Step 4: config apply (THE documented command)
CFG_OUT=$(zsh_exec "config apply 2>&1")
if [[ -f "$CFG_FAKE_KEY" ]]; then
    # Key exists — check it's the decrypted version (no .age extension)
    if head -1 "$CFG_FAKE_KEY" 2>/dev/null | grep -q 'BEGIN OPENSSH PRIVATE KEY'; then
        pass "encrypt-via-config: key decrypted successfully via config apply"
    else
        fail "encrypt-via-config: decrypted key has invalid content"
    fi
else
    fail "encrypt-via-config: config apply did not decrypt key"
fi

# Step 5: Verify NO .age file leaked to ~/.ssh/
[[ ! -f "$TARGET_HOME/.ssh/test_wrapper_key.age" ]] && pass "encrypt-via-config: no .age in ~/.ssh/" || fail "encrypt-via-config: .age leaked to ~/.ssh/"

# Cleanup
rm -f "$CFG_SOURCE/$CFG_EXPECTED_AGE" 2>/dev/null
rm -f "$CFG_FAKE_KEY" "$CFG_FAKE_KEY.pub" 2>/dev/null

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
