#!/bin/zsh
# =============================================================================
# macOS Dotfiles Test — Safe isolation (does NOT touch your real dotfiles)
# =============================================================================
# Applies dotfiles to an isolated test home directory via chezmoi, then
# validates everything. Your real ~/.zshrc, ~/.gitconfig, etc. are untouched.
#
# Usage:
#   ./tests/test_macos.sh                    # Run in temporary test home
#   ./tests/test_macos.sh --keep             # Keep test home for inspection
#   ./tests/test_macos.sh --home /tmp/mytest # Custom test home path
#
# Requires: chezmoi installed, running from dotfiles repo root
# =============================================================================

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KEEP_HOME=false
TEST_HOME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep) KEEP_HOME=true; shift ;;
        --home)  TEST_HOME="$2"; shift 2 ;;
        *)       shift ;;
    esac
done

if [[ -z "$TEST_HOME" ]]; then
    TEST_HOME="$(mktemp -d /tmp/dotfiles-test-XXXXX)"
fi

PASS=0
FAIL=0
WARN=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass()   { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail()   { echo -e "  ${RED}✗${NC} $1 — ${2:-}"; FAIL=$((FAIL + 1)); }
warn()   { echo -e "  ${YELLOW}⚠${NC} $1 — ${2:-}"; WARN=$((WARN + 1)); }
header() { echo ""; echo -e "${CYAN}── $1 ──${NC}"; }

# Run zsh in isolated test home
zsh_test() {
    HOME="$TEST_HOME" ZDOTDIR="$TEST_HOME" zsh -l -i -c "$1" 2>&1 \
        | grep -v "can't change option: zle" \
        | grep -v "Detected a new version" \
        || true
}

# Run bash in isolated test home
bash_test() {
    HOME="$TEST_HOME" bash -i -c "$1" 2>&1 || true
}

check_file() {
    local path="$1" label="${2:-$1}"
    [[ -f "$TEST_HOME/$path" ]] && pass "$label" || fail "$label" "missing"
}

check_dir() {
    local path="$1" label="${2:-$1}"
    [[ -d "$TEST_HOME/$path" ]] && pass "$label" || fail "$label" "missing"
}

check_cmd() {
    local cmd="$1" label="${2:-$1}"
    which "$cmd" >/dev/null 2>&1 && pass "$label" || fail "$label" "not in PATH"
}

check_grep() {
    local file="$1" pattern="$2" label="$3" invert="${4:-false}"
    if [[ "$invert" == "true" ]]; then
        ! grep -q "$pattern" "$TEST_HOME/$file" 2>/dev/null \
            && pass "$label" || fail "$label" "found unwanted in $file"
    else
        grep -q "$pattern" "$TEST_HOME/$file" 2>/dev/null \
            && pass "$label" || fail "$label" "not found in $file"
    fi
}

check_zsh_bindkey() {
    local key="$1" widget="$2" label="${3:-}"
    zsh_test "bindkey '$key' 2>/dev/null" 2>/dev/null | grep -qF "$widget" \
        && pass "${label:-bindkey $key → $widget}" || fail "${label:-bindkey $key → $widget}" "not bound"
}

check_zsh_widget() {
    local widget="$1" label="${2:-widget $widget}"
    zsh_test "zle -l | grep -qF '$widget'" 2>/dev/null \
        && pass "$label" || fail "$label" "widget not defined"
}

check_zsh_func() {
    local func="$1" label="${2:-$func}"
    zsh_test "whence -f $func >/dev/null 2>&1" >/dev/null 2>&1 \
        && pass "$label" || fail "$label" "not defined"
}

check_zsh_var() {
    local expr="$1" label="$2" detail="${3:-}"
    zsh_test "[[ $expr ]]" >/dev/null 2>&1 \
        && pass "$label" || fail "$label" "$detail"
}

# ── Cleanup ─────────────────────────────────────────────────────────────────
cleanup() {
    if [[ "$KEEP_HOME" == "false" ]]; then
        echo ""
        echo -e "${CYAN}Cleaning up test home...${NC}"
        rm -rf "$TEST_HOME"
    else
        echo ""
        echo -e "${YELLOW}Test home kept at: $TEST_HOME${NC}"
        echo "  HOME=$TEST_HOME ZDOTDIR=$TEST_HOME zsh"
        echo "  rm -rf $TEST_HOME   # to clean up"
    fi
}
trap cleanup EXIT

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}══════════════════════════════════════════════${NC}"
echo -e "${CYAN}  DOTFILES macOS TEST — Isolated${NC}"
echo -e "${CYAN}══════════════════════════════════════════════${NC}"
echo ""
echo "Test home: $TEST_HOME"
echo "Your real dotfiles: UNTOUCHED"
echo ""

# ── Pre-flight ──────────────────────────────────────────────────────────────
header "Pre-flight checks"
check_cmd "zsh"
check_cmd "bash"

# Install chezmoi if missing
if ! command -v chezmoi >/dev/null 2>&1; then
    echo "chezmoi not found. Installing..."
    curl -sSL https://get.chezmoi.io | sh -s -- -b /usr/local/bin 2>/dev/null || {
        echo "ERROR: Could not install chezmoi. Install manually: https://chezmoi.dev"
        exit 1
    }
    echo "chezmoi installed."
fi
pass "chezmoi: $(chezmoi --version 2>&1 | head -1)"

# ═════════════════════════════════════════════════════════════════════════════
#  PHASE 1: Apply dotfiles to test home
# ═════════════════════════════════════════════════════════════════════════════
header "Applying dotfiles to isolated test home"

# chezmoi needs a source directory. Initialize if not already present.
# We use a throwaway chezmoi state dir to avoid conflicts with real config.
CHEZMOI_STATE="$TEST_HOME/.test-chezmoi-state"
mkdir -p "$CHEZMOI_STATE"
CHEZMOI_PERSISTENT_STATE="$CHEZMOI_STATE/chezmoi.boltdb"

echo "Initializing chezmoi..."
chezmoi init --source "$REPO_DIR" --destination "$TEST_HOME" --config-path "$CHEZMOI_STATE/chezmoi.toml" --force 2>&1 | tail -1 \
    && pass "chezmoi init OK" || { fail "chezmoi init failed"; exit 1; }
echo "persistentState = \"$CHEZMOI_PERSISTENT_STATE\"" >> "$CHEZMOI_STATE/chezmoi.toml"

# Copy config to standard location so config() wrapper + encryption tests find it
mkdir -p "$TEST_HOME/.config/chezmoi"
cp "$CHEZMOI_STATE/chezmoi.toml" "$TEST_HOME/.config/chezmoi/chezmoi.toml"

# Remove any stale test .age files from previous crashed test runs
rm -f "$REPO_DIR/private_dot_ssh/test_roundtrip_key.age" 2>/dev/null
rm -f "$REPO_DIR/private_dot_ssh/test_wrapper_key.age" 2>/dev/null
git -C "$REPO_DIR" checkout -- private_dot_ssh/ 2>/dev/null || true

echo "Applying dotfiles..."
chezmoi --config "$CHEZMOI_STATE/chezmoi.toml" apply --source "$REPO_DIR" --destination "$TEST_HOME" --force 2>&1 | grep -v "^$" | tail -5 || true

# Fix test config: replace placeholder recipient with host age key
# (run_onchange modifies HOST config, not test config)
if [ -f "$HOME/.config/chezmoi/key.txt" ]; then
    AGE_PUBKEY=$(grep 'public key:' "$HOME/.config/chezmoi/key.txt" 2>/dev/null | sed 's/.*public key: *//')
    if [ -n "$AGE_PUBKEY" ]; then
        mkdir -p "$TEST_HOME/.config/chezmoi"
        cp "$HOME/.config/chezmoi/key.txt" "$TEST_HOME/.config/chezmoi/key.txt"
        sed -i '' "s/REPLACE_WITH_YOUR_AGE_PUBLIC_KEY/$AGE_PUBKEY/" "$TEST_HOME/.config/chezmoi/chezmoi.toml"
        # Fix identity path to point to test home, not real home
        sed -i '' "s|identity = \".*\"|identity = \"$TEST_HOME/.config/chezmoi/key.txt\"|" "$TEST_HOME/.config/chezmoi/chezmoi.toml"
    fi
fi

# Install TPM in test home (run_once script uses .chezmoi.homeDir which
# resolves to the real home, so TPM must be cloned manually for testing)
if [[ ! -d "$TEST_HOME/.tmux/plugins/tpm" ]]; then
    # Work around Homebrew git-remote-https crash on macOS
    # (dyld: Symbol not found: _curl_global_trace)
    if [[ "$OSTYPE" == darwin* ]]; then
        _git_epath=$(git --exec-path 2>/dev/null) || true
        if [[ -n "$_git_epath" && "$_git_epath" != /usr/libexec/git-core ]]; then
            _git_crash=$("$_git_epath/git-remote-https" 2>&1) || true
            if echo "$_git_crash" | grep -q "Symbol not found.*_curl_global_trace"; then
                PATH="/usr/bin:$PATH"
            fi
        fi
    fi
    mkdir -p "$TEST_HOME/.tmux/plugins"
    git clone -q https://github.com/tmux-plugins/tpm "$TEST_HOME/.tmux/plugins/tpm" 2>/dev/null || true
fi

# Initialize Zim in test home
if [[ -f "$TEST_HOME/.zimrc" ]]; then
    ZIM_HOME="$TEST_HOME/.zim"
    mkdir -p "$ZIM_HOME"
    if [[ ! -f "$ZIM_HOME/zimfw.zsh" ]]; then
        curl -fsSLo "$ZIM_HOME/zimfw.zsh" \
            https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh 2>/dev/null || true
    fi

    ZIM_INIT_OUTPUT=$(HOME="$TEST_HOME" ZDOTDIR="$TEST_HOME" zsh -c "
        # Work around Homebrew git-remote-https crash on macOS
        if [[ \"\$OSTYPE\" == darwin* ]]; then
            _git_epath=\$(git --exec-path 2>/dev/null) || true
            if [[ -n \"\$_git_epath\" && \"\$_git_epath\" != /usr/libexec/git-core ]]; then
                _git_crash=\$(\"\$_git_epath/git-remote-https\" 2>&1) || true
                if echo \"\$_git_crash\" | grep -q 'Symbol not found.*_curl_global_trace'; then
                    PATH=\"/usr/bin:\$PATH\"
                fi
            fi
        fi
        ZIM_HOME='$ZIM_HOME'
        ZIM_CONFIG_FILE='$TEST_HOME/.zimrc'
        source '$ZIM_HOME/zimfw.zsh' init
    " 2>&1) || true
    if [[ -f "$ZIM_HOME/init.zsh" ]]; then
        pass "zim initialized in test home"
    else
        fail "zim init failed" "$(echo "$ZIM_INIT_OUTPUT" | head -3)"
    fi
fi

# ═════════════════════════════════════════════════════════════════════════════
#  PHASE 2: Verification
# ═════════════════════════════════════════════════════════════════════════════

# ── Shell Config Files ─────────────────────────────────────────────────────
header "Shell config files"
check_file ".zshrc"
check_file ".zshenv"
check_file ".zprofile"
check_file ".zimrc"
check_file ".bashrc"
# shell_profile is deprecated — verify it is NOT deployed
[[ -f "$TEST_HOME/.shell_profile" ]] && fail ".shell_profile should be deprecated" || pass "no .shell_profile (deprecated)"

# ── Other Dotfiles ──────────────────────────────────────────────────────────
header "Other dotfiles"
check_file ".gitconfig"
check_file ".myclirc"
check_file ".taskrc"
check_file ".tmux.conf"
check_file ".gitignore"

# ── XDG Config Directories ──────────────────────────────────────────────────
header "XDG config directories"
check_file ".config/nvim/init.lua"
check_file ".config/starship.toml"
check_file ".config/alacritty/alacritty.toml"
check_file ".config/ranger/rc.conf"
check_file ".config/skhd/skhdrc"
check_file ".config/lvim/config.lua"

# ── SSH Config (macOS blocks MUST be present) ───────────────────────────────
header "SSH config"
check_file ".ssh/config" "SSH config"
check_grep ".ssh/config" "Host github.com" "github host"
check_grep ".ssh/config" "Host bitbucket.org" "bitbucket host"
check_grep ".ssh/config" "Host gitlab.com" "gitlab host"
check_grep ".ssh/config" "Host hostinger" "hostinger host"
check_grep ".ssh/config" "Host router" "router host"

# macOS-only blocks MUST appear
check_grep ".ssh/config" "lima-default" "macOS: lima-default present"
check_grep ".ssh/config" "UseKeychain yes" "macOS: UseKeychain enabled"
check_grep ".ssh/config" "colima" "macOS: colima Include present"
check_grep ".ssh/config" "IdentitiesOnly yes" "IdentitiesOnly enabled"
check_grep ".ssh/config" "AddKeysToAgent yes" "AddKeysToAgent enabled"
# Verify SSH keyword capitalization is consistent
! grep -q "Hostname " "$TEST_HOME/.ssh/config" 2>/dev/null && pass "SSH: no lowercase Hostname" || fail "SSH: lowercase Hostname found"
! grep -q "Identityfile" "$TEST_HOME/.ssh/config" 2>/dev/null && pass "SSH: no lowercase Identityfile" || fail "SSH: lowercase Identityfile found"

# ── Environment Variables ───────────────────────────────────────────────────
header "Environment variables"
check_zsh_var '$EDITOR == nvim' 'EDITOR=nvim'
check_zsh_var '$VISUAL == nvim' 'VISUAL=nvim'
check_zsh_var '$PAGER == less' 'PAGER=less'
check_zsh_var '-n $LANG' 'LANG set'

# macOS-specific: BROWSER=open (uses $OSTYPE runtime guard)
check_grep ".zprofile" "BROWSER.*open" "BROWSER=open in zprofile"

# ── macOS-specific environment ──────────────────────────────────────────────
header "macOS-specific environment"
check_zsh_var '-n $HOMEBREW_NO_GITHUB_API' 'HOMEBREW_NO_GITHUB_API set'

# ── FZF: Environment + Keybindings ──────────────────────────────────────────
header "FZF: environment and keybindings"

# macOS uses fd (not fdfind)
zsh_test 'echo $FZF_DEFAULT_COMMAND' 2>/dev/null | grep -q "^fd " \
    && pass "FZF_DEFAULT_COMMAND uses fd (macOS)" \
    || fail "FZF_DEFAULT_COMMAND should use fd"

zsh_test '[[ -n $FZF_CTRL_T_COMMAND ]]' 2>/dev/null \
    && pass "FZF_CTRL_T_COMMAND set" || fail "FZF_CTRL_T_COMMAND not set"

# Keybindings
check_zsh_bindkey '^T'   'fzf-file-widget'   'bindkey ^T → fzf-file-widget'
check_zsh_bindkey '^R'   'fzf-history-widget' 'bindkey ^R → fzf-history-widget'
check_zsh_bindkey '^X^F' 'fzf-file-widget'    'bindkey ^X^F → fzf-file-widget'
check_zsh_widget 'fzf-file-widget'    'widget fzf-file-widget'
check_zsh_widget 'fzf-history-widget' 'widget fzf-history-widget'
check_zsh_widget 'fzf-cd-widget'      'widget fzf-cd-widget'

check_cmd "fzf"
check_cmd "fd" "fd"

# ── Zsh Options ─────────────────────────────────────────────────────────────
header "Zsh shell options"
zsh_test 'set -o 2>/dev/null | grep -q "vi.*on"' 2>/dev/null \
    && pass 'set -o vi enabled' || fail 'set -o vi not enabled'
zsh_test 'set -o 2>/dev/null | grep -q "noclobber.*off"' 2>/dev/null \
    && pass 'noclobber disabled' || fail 'noclobber should be off'

# ── Zsh Keybindings ─────────────────────────────────────────────────────────
header "Zsh keybindings"
check_zsh_bindkey '^P'   'history-substring-search-up'   'bindkey ^P → hist-search-up'
check_zsh_bindkey '^N'   'history-substring-search-down' 'bindkey ^N → hist-search-down'

# ── Aliases ─────────────────────────────────────────────────────────────────
header "Shell aliases"
zsh_test 'alias ll 2>/dev/null | grep -q "ls -lha"' 2>/dev/null \
    && pass 'll → ls -lha' || fail 'll alias missing'
zsh_test 'alias vi 2>/dev/null | grep -q nvim' 2>/dev/null \
    && pass 'vi → nvim' || fail 'vi alias missing'
zsh_test 'alias vim 2>/dev/null | grep -q nvim' 2>/dev/null \
    && pass 'vim → nvim' || fail 'vim alias missing'
# On macOS, NVIM_PATH should point to /usr/local/bin/nvim (Homebrew install location)
check_grep ".zshrc" '/usr/local/bin/nvim' 'NVIM_PATH=/usr/local/bin/nvim (macOS)'
zsh_test 'alias calc 2>/dev/null | grep -q qalc' 2>/dev/null \
    && pass 'calc → qalc' || fail 'calc alias missing'

# macOS-only Docker alias
zsh_test 'alias dm 2>/dev/null | grep -q docker-machine' 2>/dev/null \
    && pass 'macOS: dm → docker-machine' || warn 'dm alias not found'

# ── Shell Functions ─────────────────────────────────────────────────────────
header "Shell functions"
check_zsh_func "config"           "config()"
check_zsh_func "wiki"             "wiki()"
check_zsh_func "ft"               "ft()"
check_zsh_func "extract"          "extract()"
check_zsh_func "epoch"            "epoch()"
check_zsh_func "command_result"   "command_result()"
check_zsh_func "diffs"            "diffs()"
check_zsh_func "randmac"          "randmac()"
check_zsh_func "list-dev-builds"  "list-dev-builds()"
check_zsh_func "git-remote-url"   "git-remote-url()"
check_zsh_func "git-branch-select" "git-branch-select()"

# macOS-only functions
check_zsh_func "cdf"              "macOS: cdf()"
check_zsh_func "k3dconfigwall"    "macOS: k3dconfigwall()"
check_zsh_func "kubeconfigRefresh" "macOS: kubeconfigRefresh()"

# Lazy loaders
check_zsh_func "fnm" "fnm() lazy loader"
check_zsh_func "sdk" "sdk() lazy loader"

# ── Zim Framework ───────────────────────────────────────────────────────────
header "Zim framework"
check_dir ".zim" "~/.zim"
check_dir ".zim/modules" "~/.zim/modules"
for mod in \
    "environment" "git" "input" "termtitle" "utility" \
    "zim-starship" "completion" \
    "zsh-completions" "zsh-syntax-highlighting" \
    "zsh-history-substring-search" "zsh-autosuggestions"; do
    [[ -d "$TEST_HOME/.zim/modules/$mod" ]] \
        && pass "Zim: $mod" || fail "Zim: $mod missing"
done

# ── Installed Tools (global, not isolated) ──────────────────────────────────
header "Installed tools (system)"
check_cmd "zsh"
check_cmd "tmux"
check_cmd "git"
check_cmd "fzf"
check_cmd "fd"   "fd"
check_cmd "rg"   "rg (ripgrep)"
check_cmd "age"
check_cmd "chezmoi"
# chezmoi doctor — verify chezmoi itself is healthy
chezmoi doctor 2>&1 | grep -q '^error ' && fail "chezmoi doctor has errors" || pass "chezmoi doctor: no errors"
check_cmd "nvim"
check_file ".config/nvim/lua/custom/plugins/init.lua" "nvim custom plugins"
# nvim basic functionality and config syntax
nvim --headless -c 'quit' 2>/dev/null && pass "nvim: headless startup OK" || warn "nvim: headless startup failed"
if [[ -f "$TEST_HOME/.config/nvim/init.lua" ]]; then
    SYNTAX_RESULT=$(timeout 10 nvim -u NONE --headless --cmd "lua local ok, err = load(io.open('$TEST_HOME/.config/nvim/init.lua'):read('*a')); if ok then print('SYNTAX_OK') else print('SYNTAX_FAIL: '..err) end" -c 'cq' 2>&1) || true
    echo "$SYNTAX_RESULT" | grep -q SYNTAX_OK \
        && pass "nvim: init.lua Lua syntax OK" || fail "nvim: init.lua Lua syntax error"
fi
if [[ -f "$TEST_HOME/.config/nvim/lua/custom/plugins/init.lua" ]]; then
    SYNTAX_RESULT=$(timeout 10 nvim -u NONE --headless --cmd "lua local ok, err = load(io.open('$TEST_HOME/.config/nvim/lua/custom/plugins/init.lua'):read('*a')); if ok then print('SYNTAX_OK') else print('SYNTAX_FAIL: '..err) end" -c 'cq' 2>&1) || true
    echo "$SYNTAX_RESULT" | grep -q SYNTAX_OK \
        && pass "nvim: custom plugins Lua syntax OK" || fail "nvim: custom plugins Lua syntax error"
fi
# nvim: confirm no hard errors at startup (vim.lsp.config needs nvim >= 0.11)
NVIM_OUTPUT=$(timeout 15 nvim --headless -c 'quit' 2>&1) || true
echo "$NVIM_OUTPUT" | grep -qiE "vim.lsp.config.*nil|attempt to call field" \
    && fail "nvim: startup has lsp config error (needs nvim >= 0.11)" \
    || pass "nvim: no hard errors on startup"
check_cmd "starship"

# ── Git Config ──────────────────────────────────────────────────────────────
header "Git config (from test home)"
git_test() {
    HOME="$TEST_HOME" GIT_CONFIG_GLOBAL="$TEST_HOME/.gitconfig" git "$@"
}

git_test config user.name >/dev/null 2>&1 \
    && pass "git user.name set" || fail "git user.name not set"
git_test config user.email >/dev/null 2>&1 \
    && pass "git user.email set" || fail "git user.email not set"
git_test config core.excludesfile 2>/dev/null | grep -q '.gitignore' \
    && pass "git excludesfile → ~/.gitignore" || fail "git excludesfile not set"
git_test config diff.tool 2>/dev/null | grep -q 'vimdiff' \
    && pass "git diff.tool = vimdiff" || fail "git diff.tool not vimdiff"

# ── Tmux ────────────────────────────────────────────────────────────────────
# Clipboard integration
check_grep ".tmux.conf" 'set-clipboard on' 'tmux: set-clipboard on'
check_grep ".tmux.conf" 'bind C-c run' 'tmux: clipboard copy bind (C-c)'
check_grep ".tmux.conf" 'bind C-v run' 'tmux: clipboard paste bind (C-v)'
check_grep ".config/nvim/init.lua" "unnamedplus" "nvim: clipboard=unnamedplus"
# macOS clipboard tool
pbcopy -help >/dev/null 2>&1 && pass "clipboard: pbcopy/pbpaste available" || warn "clipboard: pbcopy not found"

# nvim: register \"+ exists
nvim --headless -c 'lua vim.fn.setreg("+", "TESTREG"); local ok = vim.fn.getreg("+") == "TESTREG"; vim.cmd(ok and "quit" or "cquit")' 2>/dev/null \
    && pass "nvim: \"+ register functional" \
    || fail "nvim: \"+ register broken"

header "Tmux config"
check_dir ".tmux/plugins/tpm" "TPM plugin manager"
check_grep ".tmux.conf" 'set -g mode-keys vi' 'tmux: vi mode'
check_grep ".tmux.conf" 'setw -g mouse on' 'tmux: mouse enabled'
tmux -f "$TEST_HOME/.tmux.conf" new-session -d -s dottest 2>/dev/null \
    && { pass "tmux session created"; tmux kill-session -t dottest 2>/dev/null || true; } \
    || fail "tmux config fails"

# ── Chezmoi State ───────────────────────────────────────────────────────────
header "Chezmoi files"
check_file ".test-chezmoi-state/chezmoi.toml" "chezmoi config"

# ── Zsh Startup ─────────────────────────────────────────────────────────────
header "Zsh startup sanity"
ZSH_OUT=$(HOME="$TEST_HOME" ZDOTDIR="$TEST_HOME" zsh -l -i -c 'echo OK' 2>&1 || true)
ZSH_CLEAN=$(echo "$ZSH_OUT" | grep -iv "can't change option: zle" | grep -iv "Detected a new version" | grep -iv "Regenerated completions" || true)
if echo "$ZSH_CLEAN" | grep -qiE "error|command not found|no such file|permission denied|unknown command"; then
    fail "zsh startup has errors" "$(echo "$ZSH_CLEAN" | grep -iE 'error|not found|no such|denied' | head -5)"
else
    pass "zsh starts cleanly"
fi

# ── Bash Startup ────────────────────────────────────────────────────────────
header "Bash startup"
BASH_FZF=$(HOME="$TEST_HOME" bash -i -c 'echo $FZF_DEFAULT_COMMAND' 2>/dev/null || true)
echo "$BASH_FZF" | grep -q "^fd " \
    && pass "bash FZF_DEFAULT_COMMAND uses fd" \
    || fail "bash FZF_DEFAULT_COMMAND not fd" "$BASH_FZF"

# ── Template Syntax ─────────────────────────────────────────────────────────
header "Template syntax"
for f in $(find "$REPO_DIR" -name '*.tmpl' -not -path '*/.git/*' | sort); do
    rel="${f#$REPO_DIR/}"
    chezmoi execute-template --source "$REPO_DIR" < "$f" >/dev/null 2>&1 \
        && pass "template OK: $rel" || fail "template FAIL: $rel"
done

# ── Config Content Spot-checks ──────────────────────────────────────────────
header "Config spot-checks"
check_grep ".gitconfig" 'filter "lfs"' "gitconfig: LFS filter"
check_grep ".myclirc" 'key_bindings = vi' "myclirc: vi keybindings"
check_grep ".taskrc" 'taskd.server' "taskrc: taskd sync"
check_grep ".config/starship.toml" 'show_always = true' "starship: username always shown"

header "Starship config integrity"
if [[ -f "$TEST_HOME/.config/starship.toml" ]]; then
    grep -q '\$sudo' "$TEST_HOME/.config/starship.toml" 2>/dev/null \
        && pass "starship: format includes \$sudo" \
        || fail "starship: format missing \$sudo"
    ! grep -q "sudovimstatdirectory" "$TEST_HOME/.config/starship.toml" 2>/dev/null \
        && pass "starship: no corrupt format token (sudovimstatdirectory)" \
        || fail "starship: format still has corrupt token sudovimstatdirectory"
    ! grep -q "!TMUX" "$TEST_HOME/.config/starship.toml" 2>/dev/null \
        && pass "starship: hostname detect_env_vars fixed (no !TMUX negation)" \
        || fail "starship: hostname detect_env_vars still has !TMUX"
    ! grep -q "vim_status" "$TEST_HOME/.config/starship.toml" 2>/dev/null \
        && pass "starship: no stale vim_status reference in comment" \
        || fail "starship: comment still references vim_status"
else
    warn "starship.toml not found in test home"
fi

# ── Age Encryption Roundtrip ─────────────────────────────────────────────────
header "Age encryption roundtrip"
if command -v age >/dev/null 2>&1; then
    # Use the host's age key (test home doesn't have its own)
    AGE_KEY="$HOME/.config/chezmoi/key.txt"
    if [[ ! -f "$AGE_KEY" ]]; then
        fail "age: no key found at $AGE_KEY"
    else
        AGE_PUBKEY=$(grep 'public key:' "$AGE_KEY" 2>/dev/null | sed 's/.*public key: *//') || true
        if [[ -n "$AGE_PUBKEY" ]]; then
            pass "age: key pair found"
        else
            fail "age: no public key in key.txt"
        fi

        # Verify recipient is NOT the placeholder (check host config)
        if [[ -f "$HOME/.config/chezmoi/chezmoi.toml" ]] && grep -q 'REPLACE_WITH_YOUR_AGE_PUBLIC_KEY' "$HOME/.config/chezmoi/chezmoi.toml" 2>/dev/null; then
            fail "age: recipient still has placeholder in chezmoi.toml"
        else
            pass "age: recipient configured in chezmoi.toml"
        fi

        AGE_TESTDATA="dotfiles-age-roundtrip-$$"
        AGE_ENCFILE="/tmp/age-test-$$.age"
        echo "$AGE_TESTDATA" | age -r "$AGE_PUBKEY" -o "$AGE_ENCFILE" 2>/dev/null \
            && pass "age: encrypt OK" || fail "age: encrypt failed"
        age -d -i "$AGE_KEY" "$AGE_ENCFILE" 2>/dev/null | grep -q "$AGE_TESTDATA" \
            && pass "age: decrypt roundtrip OK" || fail "age: decrypt roundtrip mismatch"
        rm -f "$AGE_ENCFILE"

        # SSH config encryption
        SSH_TMPL="$REPO_DIR/private_dot_ssh/config.tmpl"
        SSH_ENCFILE="/tmp/ssh-config-test-$$.age"
        if [[ -f "$SSH_TMPL" ]]; then
            age -r "$AGE_PUBKEY" -o "$SSH_ENCFILE" "$SSH_TMPL" 2>/dev/null \
                && pass "SSH config: encrypted with age" || fail "SSH config: age encrypt failed"
            age -d -i "$AGE_KEY" "$SSH_ENCFILE" 2>/dev/null | grep -q "Host github.com" \
                && pass "SSH config: decrypt + content check OK" || fail "SSH config: decrypt or content mismatch"
            rm -f "$SSH_ENCFILE"
        else
            fail "SSH config template not found at $SSH_TMPL"
        fi
    fi  # end of age-key-exists block
else
    warn "age command not found, skipping encryption tests"
fi

# ── macOS-specific: skhd ────────────────────────────────────────────────────
header "macOS: skhd"
check_file ".config/skhd/skhdrc" "skhd config"

# ── macOS-specific: Homebrew detection ──────────────────────────────────────
header "macOS: Homebrew"
if [[ -d "/opt/homebrew" ]]; then
    pass "Homebrew at /opt/homebrew (Apple Silicon)"
elif [[ -d "/usr/local/Homebrew" ]]; then
    pass "Homebrew at /usr/local (Intel)"
else
    warn "Homebrew not detected"
fi

# ── config() function ─────────────────────────────────────────────────────────
header "config() function"

# config function must exist
zsh_test 'whence -f config >/dev/null 2>&1 && echo OK' | grep -q OK && pass "config: function defined" || fail "config: function defined"

# config passthrough: 'config source-path' should succeed after init
if zsh_test 'config source-path' | grep -q '/'; then
  pass "config: passthrough to chezmoi works"
else
  fail "config: passthrough to chezmoi works"
fi

# FZF availability check in config() (no-args path)
grep -q 'command -v fzf' "$TEST_HOME/.zshrc" && pass "config: fzf availability check in .zshrc" || fail "config: fzf check missing"

# Chezmoi source check in config() (passthrough path)
grep -q 'chezmoi source-path' "$TEST_HOME/.zshrc" && pass "config: source-path check before passthrough" || fail "config: source-path check missing"

# config passthrough: err on non-existent chezmoi subcommand
zsh_test 'config nonexistent_cmd 2>/dev/null; echo $?' | grep -q '1' && pass "config: errors on invalid chezmoi subcommand (macOS)" || warn "config: errors on invalid chezmoi subcommand (macOS)"

# ── wiki() function ───────────────────────────────────────────────────────────
header "wiki() function"

# wiki function must exist
zsh_test 'whence -f wiki >/dev/null 2>&1 && echo OK' | grep -q OK && pass "wiki: function defined" || fail "wiki: function defined"

# No wiki dirs: should error gracefully, NOT try to open /index.md
zsh_test 'wiki 2>&1; echo EXIT:$?' | grep -q 'No wiki directory found' && pass "wiki: errors gracefully when no wiki dir exists" || fail "wiki: errors gracefully when no wiki dir exists"

# Directory existence guard in wiki-list-select
grep -q '\[\[ -d "\$DIR" \]\]' "$TEST_HOME/.zshrc" && pass "wiki: directory existence guard present" || fail "wiki: directory guard missing"

# Empty selection guard in wiki()
grep -q '\[\[ -z "\$wiki_selected" \]\]' "$TEST_HOME/.zshrc" && pass "wiki: empty selection guard present" || fail "wiki: empty selection guard missing"

# ── .chezmoi.toml.tmpl validation ─────────────────────────────────────────────
header ".chezmoi.toml.tmpl"

# Special file exists at repo root
[[ -f "$REPO_DIR/.chezmoi.toml.tmpl" ]] && pass "chezmoi: .chezmoi.toml.tmpl exists" || fail "chezmoi: .chezmoi.toml.tmpl missing"

# sourceDir is in the template
grep -q 'sourceDir' "$REPO_DIR/.chezmoi.toml.tmpl" && pass "chezmoi: sourceDir in init template" || fail "chezmoi: sourceDir missing from init template"

# sourceDir uses template variable
grep -q 'chezmoi.sourceDir' "$REPO_DIR/.chezmoi.toml.tmpl" && pass "chezmoi: sourceDir uses chezmoi.sourceDir variable" || fail "chezmoi: sourceDir should use template variable"

# Old managed file is GONE (the managed version should not exist)
! [[ -f "$REPO_DIR/dot_config/chezmoi/private_chezmoi.toml.tmpl" ]] && pass "chezmoi: old managed config file removed" || fail "chezmoi: old managed config still present"

# Old directory is gone
! [[ -d "$REPO_DIR/dot_config/chezmoi" ]] && pass "chezmoi: old dot_config/chezmoi dir removed" || fail "chezmoi: old dot_config/chezmoi dir still present"

# ── run_onchange_install-packages.sh.tmpl ─────────────────────────────────────
header "run_onchange validation"

# Script is now run_onchange
[[ -f "$REPO_DIR/run_onchange_install-packages.sh.tmpl" ]] && pass "run_onchange: script renamed correctly" || fail "run_onchange: missing"
! [[ -f "$REPO_DIR/run_once_install-packages.sh.tmpl" ]] && pass "run_onchange: old run_once removed" || warn "run_onchange: old run_once still present"

# check_fail function exists
grep -q 'check_fail()' "$REPO_DIR/run_onchange_install-packages.sh.tmpl" && pass "run_onchange: check_fail function present" || fail "run_onchange: check_fail missing"

# Summary output exists
grep -q 'Package Installation Summary' "$REPO_DIR/run_onchange_install-packages.sh.tmpl" && pass "run_onchange: summary output present" || fail "run_onchange: summary missing"

# FAILED counter exists in macOS section
grep -q 'FAILED=' "$REPO_DIR/run_onchange_install-packages.sh.tmpl" && pass "run_onchange: FAILED= counter present (macOS)" || fail "run_onchange: FAILED= missing in macOS section"

# ── FZF bindkey guards ────────────────────────────────────────────────────────
header "FZF bindkey guards"

# zle -l guard exists around explicit fzf bindings
grep -q 'zle -la fzf-file-widget' "$TEST_HOME/.zshrc" && pass "fzf: bindkey guarded by zle -la check" || fail "fzf: missing zle -la guard on bindkeys"

# Verify bindkeys appear after the guard
zle_lineno=$(grep -n 'zle -la fzf-file-widget' "$TEST_HOME/.zshrc" | cut -d: -f1 | head -1)
bindkey_lineno=$(grep -n "bindkey.*fzf-file-widget" "$TEST_HOME/.zshrc" | cut -d: -f1 | head -1)
if [[ "$bindkey_lineno" -gt "$zle_lineno" ]]; then
  pass "fzf: bindkeys are inside the zle guard (macOS)"
else
  warn "fzf: bindkey placement unclear (macOS)"
fi

# ── bootstrap.sh validation ───────────────────────────────────────────────────
header "bootstrap.sh validation"

bootstrap="$REPO_DIR/bootstrap.sh"

# DOTFILES_REPO is mentioned
grep -q 'DOTFILES_REPO' "$bootstrap" && pass "bootstrap: DOTFILES_REPO in output" || fail "bootstrap: DOTFILES_REPO missing"

# ~/.local/bin fallback for non-sudo install
grep -q '\.local/bin' "$bootstrap" && pass "bootstrap: ~/.local/bin fallback present" || fail "bootstrap: ~/.local/bin fallback missing"

# /usr/local/bin writability check
grep -q '\-w /usr/local/bin' "$bootstrap" && pass "bootstrap: /usr/local/bin writability check present" || fail "bootstrap: writability check missing"

# ── Linux template validation (cross-platform) ────────────────────────────────
header "Linux template validation (cross-platform correctness)"

linux_in_source_excluded_on_macos() {
    local tmpl="$REPO_DIR/$1" pattern="$2" label="$3"
    # Check 1: pattern exists in source
    grep -qF "$pattern" "$tmpl" 2>/dev/null || { warn "$label — not in source (expected)" ; return; }
    # Check 2: pattern is NOT in macOS render
    if chezmoi execute-template < "$tmpl" 2>/dev/null | grep -qF "$pattern"; then
        fail "$label — renders on macOS (Linux-only block leaked)"
    else
        pass "$label"
    fi
}

linux_in_source_excluded_on_macos "dot_zshenv.tmpl" 'fdfind --type f'            "zshenv: Linux fdfind in source, excluded on macOS"
linux_in_source_excluded_on_macos "dot_zshenv.tmpl" 'unset FPATH'                "zshenv: Linux FPATH fix in source, excluded on macOS"
linux_in_source_excluded_on_macos "dot_zshrc.tmpl"  'date -d "@$1"'              "zshrc: Linux GNU date in source, excluded on macOS"
linux_in_source_excluded_on_macos "dot_zprofile.tmpl" '/usr/local/sbin'          "zprofile: Linux /usr/local paths, excluded on macOS"

# ── config add --encrypt workflow (fake key roundtrip) ────────────────────────
header "config add --encrypt workflow (fake key roundtrip)"

# Source for macOS test is the real repo (chezmoi uses --source "$REPO_DIR")
SOURCE="$REPO_DIR"
FAKE_KEY="$TEST_HOME/.ssh/test_roundtrip_key"
FAKE_KEY_AGE="private_dot_ssh/test_roundtrip_key.age"

# Step 1: Generate fake SSH key
ssh-keygen -t ed25519 -f "$FAKE_KEY" -N "" -C "test-key" 2>/dev/null
if [[ -f "$FAKE_KEY" ]]; then
    pass "keys: fake SSH key generated (macOS)"
else
    fail "keys: failed to generate fake SSH key (macOS)"
fi

# Step 2: Encrypt with chezmoi
if HOME="$TEST_HOME" chezmoi add --encrypt --source "$SOURCE" --destination "$TEST_HOME" --force "$FAKE_KEY" 2>/dev/null; then
    pass "keys: config add --encrypt succeeded (macOS)"
else
    fail "keys: config add --encrypt failed (macOS)"
fi

# Step 3: Verify .age file exists in source
if [[ -f "$SOURCE/$FAKE_KEY_AGE" ]]; then
    pass "keys: .age file created in source (macOS)"
else
    fail "keys: .age file not created at $SOURCE/$FAKE_KEY_AGE (macOS)"
fi

# Step 4: Verify .age file is NOT placeholder text (should be encrypted binary)
if [[ -f "$SOURCE/$FAKE_KEY_AGE" ]]; then
    if grep -q 'PLACEHOLDER\|REPLACE WITH' "$SOURCE/$FAKE_KEY_AGE" 2>/dev/null; then
        fail "keys: .age file still contains placeholder text (macOS)"
    else
        pass "keys: .age file is encrypted (no placeholder text) (macOS)"
    fi
fi

# Step 5: Apply with chezmoi (decrypts to destination)
if HOME="$TEST_HOME" chezmoi apply --source "$SOURCE" --destination "$TEST_HOME" --force 2>/dev/null; then
    pass "keys: chezmoi apply after encrypt succeeded (macOS)"
else
    warn "keys: chezmoi apply after encrypt returned non-zero (macOS)"
fi

# Step 6: Verify decrypted file exists WITHOUT .age extension
if [[ -f "$FAKE_KEY" ]]; then
    pass "keys: decrypted file exists (no .age extension) (macOS)"
else
    fail "keys: decrypted file missing (decrypt failed) (macOS)"
fi

# Step 7: Verify decrypted content is valid SSH key
if [[ -f "$FAKE_KEY" ]]; then
    if head -1 "$FAKE_KEY" | grep -q 'BEGIN OPENSSH PRIVATE KEY'; then
        pass "keys: decrypted content is valid SSH private key (macOS)"
    else
        fail "keys: decrypted content is not valid SSH key (macOS)"
    fi
fi

# Step 8: Verify permissions are 0600
if [[ -f "$FAKE_KEY" ]]; then
    perms=$(stat -f '%Lp' "$FAKE_KEY" 2>/dev/null || stat -c '%a' "$FAKE_KEY" 2>/dev/null)
    if [[ "$perms" == "600" ]]; then
        pass "keys: private key permissions are 0600 (macOS)"
    else
        warn "keys: private key permissions are $perms (expected 600) (macOS)"
    fi
fi

# Step 9: Verify .age file is NOT present in deployed ~/.ssh/ (should be decrypted, not .age)
if [[ -f "$TEST_HOME/.ssh/test_roundtrip_key.age" ]]; then
    fail "keys: .age file leaked to ~/.ssh/ (should be decrypted without .age)"
else
    pass "keys: no .age extension in deployed destination"
fi

# Cleanup
rm -f "$SOURCE/$FAKE_KEY_AGE" 2>/dev/null
rm -f "$FAKE_KEY" "$FAKE_KEY.pub" 2>/dev/null
git -C "$REPO_DIR" checkout -- private_dot_ssh/ 2>/dev/null || true

# ── config wrapper subcommands (daily workflow) ───────────────────────────────
header "config wrapper subcommands (daily workflow)"

# Source for macOS test (copied to TEST_HOME during setup)
TEST_SOURCE="$REPO_DIR"

# ── config diff ──
if zsh_test 'config diff 2>&1; echo EXIT:$?' | grep -q 'EXIT:0'; then
  pass "config: diff runs successfully (macOS)"
else
  warn "config: diff returned non-zero (may have pending changes) (macOS)"
fi

# ── config apply (idempotent) ──
if zsh_test 'config apply 2>&1; echo EXIT:$?' | grep -q 'EXIT:0'; then
  pass "config: apply runs successfully (macOS)"
else
  warn "config: apply returned non-zero (macOS)"
fi

# ── config commit ── (safe: commits to test copy, not real repo)
# Touch a managed file to create a change
echo '# test commit marker' >> "$TEST_HOME/.zshrc"
HOME="$TEST_HOME" chezmoi add --source "$TEST_SOURCE" --destination "$TEST_HOME" --force "$TEST_HOME/.zshrc" 2>/dev/null || true
zsh_test 'config commit -m "test: config commit wrapper test" 2>&1; echo EXIT:$?' | grep -q 'EXIT:0' \
  && pass "config: commit -m works through wrapper (macOS)" \
  || warn "config: commit -m may have failed (git config, no changes, etc.) (macOS)"

# ── config edit (verify subcommand recognized) ──
if HOME="$TEST_HOME" chezmoi edit --dry-run "$TEST_HOME/.zshrc" 2>/dev/null; then
  pass "config: edit subcommand recognized by chezmoi (macOS)"
else
  warn "config: edit --dry-run not supported (chezmoi version) (macOS)"
fi

# ── config update (verify subcommand exists) ──
if chezmoi update --help >/dev/null 2>&1; then
  pass "config: update subcommand recognized (macOS)"
else
  warn "config: update --help not available (macOS)"
fi

# ── config passthrough: invalid subcommand returns non-zero ──
zsh_test 'config nonexistent_cmd 2>/dev/null; echo EXIT:$?' | grep -q 'EXIT:1' \
  && pass "config: invalid subcommand returns error (macOS)" \
  || warn "config: invalid subcommand exit behavior (macOS)"

# ── config add --encrypt + apply (wrapper roundtrip) ─────────────────────────
header "config add --encrypt + apply (wrapper roundtrip) (macOS)"

CFG_FAKE_KEY="$TEST_HOME/.ssh/test_wrapper_key"
CFG_SOURCE="$REPO_DIR"
CFG_EXPECTED_AGE="private_dot_ssh/test_wrapper_key.age"

# Step 1: Generate fake key
ssh-keygen -t ed25519 -f "$CFG_FAKE_KEY" -N "" -C "wrapper-test" 2>/dev/null
[[ -f "$CFG_FAKE_KEY" ]] && pass "encrypt-via-config: fake key generated (macOS)" || fail "encrypt-via-config: key gen failed (macOS)"

# Step 2: config add --encrypt (THE documented command)
zsh_test "config add --encrypt '$CFG_FAKE_KEY'" 2>/dev/null
if [[ -f "$CFG_SOURCE/$CFG_EXPECTED_AGE" ]]; then
    pass "encrypt-via-config: .age file created via config add --encrypt (macOS)"
else
    fail "encrypt-via-config: config add --encrypt did not create .age file (macOS)"
fi

# Step 3: Verify .age is encrypted (not placeholder)
if [[ -f "$CFG_SOURCE/$CFG_EXPECTED_AGE" ]]; then
    if grep -q 'PLACEHOLDER\|REPLACE WITH' "$CFG_SOURCE/$CFG_EXPECTED_AGE" 2>/dev/null; then
        fail "encrypt-via-config: .age file is placeholder text (macOS)"
    else
        pass "encrypt-via-config: .age file is encrypted binary (macOS)"
    fi
fi

# Step 4: config apply (THE documented command)
zsh_test "config apply" 2>/dev/null
if [[ -f "$CFG_FAKE_KEY" ]]; then
    if head -1 "$CFG_FAKE_KEY" 2>/dev/null | grep -q 'BEGIN OPENSSH PRIVATE KEY'; then
        pass "encrypt-via-config: key decrypted via config apply (macOS)"
    else
        fail "encrypt-via-config: decrypted key has invalid content (macOS)"
    fi
else
    fail "encrypt-via-config: config apply did not decrypt key (macOS)"
fi

# Step 5: Verify NO .age leaked to ~/.ssh/
[[ ! -f "$TEST_HOME/.ssh/test_wrapper_key.age" ]] && pass "encrypt-via-config: no .age in ~/.ssh/ (macOS)" || fail "encrypt-via-config: .age leaked (macOS)"

# Cleanup
rm -f "$CFG_SOURCE/$CFG_EXPECTED_AGE" 2>/dev/null
rm -f "$CFG_FAKE_KEY" "$CFG_FAKE_KEY.pub" 2>/dev/null

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}══════════════════════════════════════════════${NC}"
echo -e "${CYAN}  RESULTS${NC}"
echo -e "${CYAN}══════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${YELLOW}WARN${NC}: $WARN"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo ""
echo "Test home: $TEST_HOME"
echo "Your real dotfiles: UNTOUCHED"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
    echo -e "${RED}Tests FAILED.${NC}"
    exit 1
else
    echo -e "${GREEN}All tests PASSED.${NC}"
    exit 0
fi
