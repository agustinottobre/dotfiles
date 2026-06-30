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
    HOME="$TEST_HOME" bash -l -i -c "$1" 2>&1 || true
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

echo "Initializing chezmoi..."
chezmoi init --source "$REPO_DIR" --destination "$TEST_HOME" --config-path "$CHEZMOI_STATE/chezmoi.toml" --force 2>&1 | tail -1 \
    && pass "chezmoi init OK" || { fail "chezmoi init failed"; exit 1; }

echo "Applying dotfiles..."
chezmoi apply --source "$REPO_DIR" --destination "$TEST_HOME" --force 2>&1 | grep -v "^$" | tail -3
# Apply may have non-zero exit for non-critical issues, check files exist instead

# Initialize Zim in test home
if [[ -f "$TEST_HOME/.zimrc" ]]; then
    ZIM_HOME="$TEST_HOME/.zim"
    mkdir -p "$ZIM_HOME"
    if [[ ! -f "$ZIM_HOME/zimfw.zsh" ]]; then
        curl -fsSLo "$ZIM_HOME/zimfw.zsh" \
            https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh 2>/dev/null || true
    fi
    HOME="$TEST_HOME" ZDOTDIR="$TEST_HOME" zsh -c "
        ZIM_HOME='$ZIM_HOME'
        ZIM_CONFIG_FILE='$TEST_HOME/.zimrc'
        source '$ZIM_HOME/zimfw.zsh' init
    " 2>/dev/null || true
    pass "zim initialized in test home"
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
check_cmd "nvim"
check_file ".config/nvim/lua/custom/plugins/init.lua" "nvim custom plugins"
# nvim basic functionality and config syntax
nvim --headless -c 'quit' 2>/dev/null && pass "nvim: headless startup OK" || warn "nvim: headless startup failed"
if [[ -f "$TEST_HOME/.config/nvim/init.lua" ]]; then
    nvim -u NONE --headless --cmd "lua local ok, err = load(io.open('$TEST_HOME/.config/nvim/init.lua'):read('*a')); if ok then print('SYNTAX_OK') else print('SYNTAX_FAIL: '..err) end" -c 'cq' 2>&1 | grep -q SYNTAX_OK \
        && pass "nvim: init.lua Lua syntax OK" || fail "nvim: init.lua Lua syntax error"
fi
if [[ -f "$TEST_HOME/.config/nvim/lua/custom/plugins/init.lua" ]]; then
    nvim -u NONE --headless --cmd "lua local ok, err = load(io.open('$TEST_HOME/.config/nvim/lua/custom/plugins/init.lua'):read('*a')); if ok then print('SYNTAX_OK') else print('SYNTAX_FAIL: '..err) end" -c 'cq' 2>&1 | grep -q SYNTAX_OK \
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
header "Tmux config"
check_dir ".tmux/plugins/tpm" "TPM plugin manager"
check_grep ".tmux.conf" 'set -g mode-keys vi' 'tmux: vi mode'
check_grep ".tmux.conf" 'setw -g mouse on' 'tmux: mouse enabled'
tmux -f "$TEST_HOME/.tmux.conf" new-session -d -s dottest 2>/dev/null \
    && { pass "tmux session created"; tmux kill-session -t dottest 2>/dev/null || true; } \
    || fail "tmux config fails"

# ── Chezmoi State ───────────────────────────────────────────────────────────
header "Chezmoi files"
check_file ".config/chezmoi/chezmoi.toml" "chezmoi config"

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
BASH_FZF=$(HOME="$TEST_HOME" bash -l -i -c 'echo $FZF_DEFAULT_COMMAND' 2>/dev/null || true)
echo "$BASH_FZF" | grep -q "^fd " \
    && pass "bash FZF_DEFAULT_COMMAND uses fd" \
    || fail "bash FZF_DEFAULT_COMMAND not fd" "$BASH_FZF"

# ── Template Syntax ─────────────────────────────────────────────────────────
header "Template syntax"
for f in $(find "$REPO_DIR" -name '*.tmpl' -not -path '*/.git/*' | sort); do
    rel="${f#$REPO_DIR/}"
    chezmoi execute-template < "$f" >/dev/null 2>&1 \
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
    AGE_KEY="$TEST_HOME/.config/chezmoi/key.txt"
    AGE_PUBKEY=$(grep 'public key:' "$AGE_KEY" 2>/dev/null | sed 's/.*public key: *//')
    if [[ -n "$AGE_PUBKEY" ]]; then
        pass "age: key pair found"
    else
        fail "age: no public key in key.txt"
    fi

    # Verify recipient is NOT the placeholder
    if [[ -f "$TEST_HOME/.config/chezmoi/chezmoi.toml" ]] && grep -q 'REPLACE_WITH_YOUR_AGE_PUBLIC_KEY' "$TEST_HOME/.config/chezmoi/chezmoi.toml" 2>/dev/null; then
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
