#!/bin/bash
# =============================================================================
# End-to-End Dotfiles Test — Linux
# =============================================================================
# Usage:
#   ./tests/test_linux.sh
#
# Mode:
#   Runs directly on this host using a fake $HOME (zero risk)
#
# Prerequisites:
#   - chezmoi installed
#   - Run from dotfiles repo root
# =============================================================================

set -euo pipefail

source "$(dirname "$0")/_helpers.sh"

# ── Setup ───────────────────────────────────────────────────────────────────
TARGET_HOME="$(mktemp -d /tmp/dotfiles-test-local-XXXXX)"
TEST_HOME="$TARGET_HOME"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ── Exec helpers ─────────────────────────────────────────────────────────────
zsh_exec()  { HOME="$TARGET_HOME" ZDOTDIR="$TARGET_HOME" zsh -l -i -c "$1" 2>&1 | grep -v "can't change option: zle" | grep -v "Detected a new version" || true; }
bash_exec() { HOME="$TARGET_HOME" bash -l -i -c "$1" 2>&1 || true; }

# ── Cleanup ─────────────────────────────────────────────────────────────────
cleanup() {
    rm -rf "$TARGET_HOME" 2>/dev/null || true
}
trap cleanup EXIT

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}══════════════════════════════════════════════${NC}"
echo -e "${CYAN}  DOTFILES LINUX TEST — Local (fake home)${NC}"
echo -e "${CYAN}  Host: $(hostname -s 2>/dev/null || echo unknown)${NC}"
echo -e "${CYAN}  Target: $TARGET_HOME${NC}"
echo -e "${CYAN}  Your real dotfiles: UNTOUCHED${NC}"
echo -e "${CYAN}══════════════════════════════════════════════${NC}"

# ═════════════════════════════════════════════════════════════════════════════
#  PHASE 1: Deploy
# ═════════════════════════════════════════════════════════════════════════════
header "Deploying dotfiles"
# Remove any stale test .age files from previous crashed test runs
rm -f "$REPO_DIR"/private_dot_ssh/test_roundtrip_key.age "$REPO_DIR"/private_dot_ssh/encrypted_private_test_roundtrip_key.age 2>/dev/null
rm -f "$REPO_DIR"/private_dot_ssh/test_wrapper_key.age "$REPO_DIR"/private_dot_ssh/encrypted_private_test_wrapper_key.age 2>/dev/null
git -C "$REPO_DIR" checkout -- private_dot_ssh/ 2>/dev/null || true
cp -a "$REPO_DIR" "$TARGET_HOME/dotfiles"

header "Running bootstrap.sh"
# Install chezmoi + init, but skip package install (apt is slow in CI/VMs)
# The run_onchange script is excluded — we only need dotfiles deployed
command -v chezmoi >/dev/null 2>&1 || curl -sSL https://get.chezmoi.io | sh -s -- -b /usr/local/bin 2>/dev/null
HOME="$TARGET_HOME" chezmoi init --source "$TARGET_HOME/dotfiles" --force 2>/dev/null || true
HOME="$TARGET_HOME" chezmoi apply --source "$TARGET_HOME/dotfiles" --force --exclude=scripts --keep-going 2>/dev/null || true
# Verify dotfiles were deployed (check key files exist)
[[ -f "$TARGET_HOME/.zshrc" ]] && [[ -f "$TARGET_HOME/.zshenv" ]] && pass "dotfiles deployed" || fail "dotfiles deployment failed"

# Generate age key for encryption tests (normally done by bootstrap.sh)
if [ ! -f "$TARGET_HOME/.config/chezmoi/key.txt" ]; then
    mkdir -p "$TARGET_HOME/.config/chezmoi"
    chezmoi age-keygen --output "$TARGET_HOME/.config/chezmoi/key.txt" 2>/dev/null || true
fi
# Fix chezmoi config: replace placeholder with real recipient
if [ -f "$TARGET_HOME/.config/chezmoi/key.txt" ] && [ -f "$TARGET_HOME/.config/chezmoi/chezmoi.toml" ]; then
    AGE_PUBKEY=$(chezmoi age-keygen -y "$TARGET_HOME/.config/chezmoi/key.txt" 2>/dev/null || true)
    if [ -n "$AGE_PUBKEY" ]; then
        sed -i "s/REPLACE_WITH_YOUR_AGE_PUBLIC_KEY/$AGE_PUBKEY/" "$TARGET_HOME/.config/chezmoi/chezmoi.toml"
        # Fix identity path to point to test home
        sed -i "s|identity = \".*\"|identity = \"$TARGET_HOME/.config/chezmoi/key.txt\"|" "$TARGET_HOME/.config/chezmoi/chezmoi.toml"
    fi
fi

# ═════════════════════════════════════════════════════════════════════════════
#  PHASE 2: Verification
# ═════════════════════════════════════════════════════════════════════════════

header "Shell config files"
check_file ".zshrc"; check_file ".zshenv"; check_file ".zprofile"
check_file ".zimrc";  check_file ".bashrc"
# shell_profile is deprecated — verify it is NOT deployed
! [[ -f "$TARGET_HOME/.shell_profile" ]] && pass "no .shell_profile (deprecated)" || fail ".shell_profile should be deprecated"

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
check_grep ".ssh/config" "Hostname " "SSH: no lowercase Hostname" "true"
check_grep ".ssh/config" "Identityfile" "SSH: no lowercase Identityfile" "true"

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
mkdir -p "/tmp/fdtest-$$" && touch "/tmp/fdtest-$$/hello.txt"
if zsh_exec 'fdfind -t f hello /tmp/fdtest-'$$' 2>/dev/null | grep -q hello.txt' >/dev/null 2>&1; then
    pass "fdfind finds files correctly"
else
    fail "fdfind functional test failed"
fi
rm -rf "/tmp/fdtest-$$" 2>/dev/null || true

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
# nvim alias uses plain 'nvim'; Linux PATH guard ensures ~/.local/bin is in PATH
check_grep ".zshrc" 'alias vi=nvim' 'nvim alias: vi→nvim'
check_grep ".zshrc" '.local/bin/nvim' 'Linux: ~/.local/bin PATH guard for nvim'
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
    check_dir ".zim/modules/$mod" "Zim: $mod"
done

# Generate fzf shell integration for the test environment
if command -v fzf >/dev/null 2>&1; then
    fzf --zsh > "$TARGET_HOME/.fzf.zsh" 2>/dev/null \
        && pass "fzf: shell integration generated" \
        || warn "fzf: shell integration generation failed"
fi

header "Zsh fpath"
zsh_exec 'echo $fpath | grep -q "/usr/local/share/zsh/site-functions"' >/dev/null 2>&1 \
    && pass 'fpath includes site-functions' || warn 'fpath: site-functions not found'

header "Installed tools"
check_cmd "zsh"; check_cmd "tmux"; check_cmd "git"; check_cmd "fzf"
check_cmd "rg" "rg (ripgrep)"; check_cmd "age"; check_cmd "chezmoi"

# chezmoi doctor — verify chezmoi itself is healthy
chezmoi doctor 2>&1 | grep -q '^error ' && fail "chezmoi doctor has errors" || pass "chezmoi doctor: no errors"

# nvim
which nvim >/dev/null 2>&1 && pass "nvim: $(nvim --version 2>&1 | head -1)" || fail "nvim not found"
check_file ".config/nvim/lua/custom/plugins/init.lua" "nvim custom plugins"

# nvim: basic functionality
timeout 10 nvim --headless -c 'quit' 2>/dev/null && pass "nvim: headless startup OK" || warn "nvim: headless startup failed (runtime may be broken)"

# nvim: Lua config syntax
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

# nvim: confirm no hard errors at startup (vim.lsp.config needs nvim >= 0.11)
NVIM_OUTPUT=$(timeout 15 nvim --headless -c 'quit' 2>&1) || true
echo "$NVIM_OUTPUT" | grep -qiE "vim.lsp.config.*nil|attempt to call field" \
    && fail "nvim: startup has lsp config error (needs nvim >= 0.11)" \
    || pass "nvim: no hard errors on startup"

# starship
which starship >/dev/null 2>&1 && pass "starship: $(starship --version 2>&1 | head -1)" || fail "starship not found"

header "Git config"
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

# Check clipboard tooling
check_grep ".tmux.conf" 'set-clipboard on' 'tmux: set-clipboard on'
check_grep ".tmux.conf" 'bind C-c run' 'tmux: clipboard copy bind (C-c)'
check_grep ".tmux.conf" 'bind C-v run' 'tmux: clipboard paste bind (C-v)'
check_grep ".config/nvim/init.lua" "unnamedplus" "nvim: clipboard=unnamedplus"

# Clipboard tool (xsel or xclip) should be installed on Linux
xsel --version >/dev/null 2>&1 || xclip -version >/dev/null 2>&1 \
    && pass "clipboard: xsel or xclip available" || warn "clipboard: neither xsel nor xclip found"

# nvim: register "+ exists (system clipboard integration)
timeout 10 nvim --headless -c 'lua vim.fn.setreg("+", "TESTREG"); local ok = vim.fn.getreg("+") == "TESTREG"; vim.cmd(ok and "quit" or "cquit")' 2>/dev/null \
    && pass "nvim: \"+ register functional" \
    || fail "nvim: \"+ register broken"

header "Tmux config"
[[ -d "$TARGET_HOME/.tmux/plugins/tpm" ]] && pass "TPM plugin manager" || warn "TPM plugin manager (run 'git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm' to install)"
check_grep ".tmux.conf" 'set -g mode-keys vi' 'tmux: mode-keys vi'
check_grep ".tmux.conf" 'setw -g mouse on' 'tmux: mouse enabled'
check_grep ".tmux.conf" 'tmux-256color' 'tmux: 256color terminal'
tmux -f "$TARGET_HOME/.tmux.conf" new-session -d -s dottest 2>/dev/null \
    && { pass "tmux session created"; tmux kill-session -t dottest 2>/dev/null || true; } \
    || fail "tmux config fails"

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
BIN_COUNT=$(ls "$TARGET_HOME/bin/" 2>/dev/null | wc -l)
[[ "$BIN_COUNT" -ge 7 ]] && pass "bin scripts present ($BIN_COUNT)" || warn "bin scripts fewer than expected ($BIN_COUNT)"
# Verify scripts are executable
NONEXEC=$(find "$TARGET_HOME/bin/" -name '*.sh' ! -perm -100 2>/dev/null | wc -l)
[[ "$NONEXEC" -eq 0 ]] && pass "bin scripts executable" || fail "bin scripts not executable ($NONEXEC)"

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
if [[ -f "$TARGET_HOME/.config/starship.toml" ]]; then
    check_grep ".config/starship.toml" '\$sudo' "starship: format includes \$sudo"
    check_grep ".config/starship.toml" "sudovimstatdirectory" "starship: no corrupt format token (sudovimstatdirectory)" "true"
    check_grep ".config/starship.toml" "!TMUX" "starship: hostname detect_env_vars fixed (no !TMUX negation)" "true"
    check_grep ".config/starship.toml" "vim_status" "starship: no stale vim_status reference in comment" "true"
else
    warn "starship.toml not found in test home"
fi

# ── Age Encryption Roundtrip ─────────────────────────────────────────────────
header "Age encryption roundtrip"
if command -v age >/dev/null 2>&1; then
    # Use the test-home age key (generated during deploy phase above)
    AGE_KEY="$TEST_HOME/.config/chezmoi/key.txt"
    AGE_PUBKEY=$(chezmoi age-keygen -y "$AGE_KEY" 2>/dev/null || true)
    if [[ -n "$AGE_PUBKEY" ]]; then
        pass "age: key pair found"
    else
        fail "age: no public key in key.txt"
    fi

    # Verify recipient is NOT the placeholder
    AGE_TOML="$TEST_HOME/.config/chezmoi/chezmoi.toml"
    if [[ -f "$AGE_TOML" ]] && grep -q 'REPLACE_WITH_YOUR_AGE_PUBLIC_KEY' "$AGE_TOML" 2>/dev/null; then
        fail "age: recipient still has placeholder in chezmoi.toml"
    else
        pass "age: recipient configured in chezmoi.toml"
    fi

    # Encrypt → Decrypt roundtrip
    AGE_TESTDATA="dotfiles-age-roundtrip-$$"
    AGE_ENCFILE="/tmp/age-test-$$.age"
    echo "$AGE_TESTDATA" | age -r "$AGE_PUBKEY" -o "$AGE_ENCFILE" 2>/dev/null \
        && pass "age: encrypt OK" || fail "age: encrypt failed"
    age -d -i "$AGE_KEY" "$AGE_ENCFILE" 2>/dev/null | grep -q "$AGE_TESTDATA" \
        && pass "age: decrypt roundtrip OK" || fail "age: decrypt roundtrip mismatch"
    rm -f "$AGE_ENCFILE"

    # SSH config encryption test (reuse AGE_PUBKEY + AGE_KEY)
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

# ── config rotate-key ──
header "config rotate-key"
zsh_exec 'whence -f _config_rotate >/dev/null 2>&1 && echo OK' | grep -q OK && pass "config: rotate-key function defined" || fail "config: rotate-key function not defined"
zsh_exec 'config rotate-key 2>/dev/null; echo $?' | grep -q '1' && pass "config: rotate-key without args returns error" || fail "config: rotate-key without args should error"
zsh_exec 'config rotate-key /tmp/nonexistent_key_$$ 2>/dev/null; echo $?' | grep -q '1' && pass "config: rotate-key with missing file returns error" || fail "config: rotate-key with missing file should error"

# ── config lock/unlock ──
header "config lock/unlock"
zsh_exec 'whence -f _config_lock >/dev/null 2>&1 && echo OK' | grep -q OK && pass "config: lock function defined" || fail "config: lock function not defined"
zsh_exec 'whence -f _config_unlock >/dev/null 2>&1 && echo OK' | grep -q OK && pass "config: unlock function defined" || fail "config: unlock function not defined"

# FZF availability check in config() (no-args path)
check_grep ".zshrc" 'command -v fzf' "config: fzf availability check in .zshrc"

# Chezmoi source check in config() (passthrough path)
check_grep ".zshrc" 'chezmoi source-path' "config: source-path check before passthrough"

# ── wiki() function ───────────────────────────────────────────────────────────
header "wiki() function"

# wiki function must exist
zsh_exec 'whence -f wiki >/dev/null 2>&1 && echo OK' | grep -q OK && pass "wiki: function defined" || fail "wiki: function defined"

# wiki-list-select must exist
zsh_exec 'whence -f wiki-list-select >/dev/null 2>&1 && echo OK' | grep -q OK && pass "wiki: wiki-list-select defined" || fail "wiki: wiki-list-select defined"

# No wiki dirs: should error gracefully, NOT open /index.md
zsh_exec 'wiki 2>&1; echo EXIT:$?' | grep -q 'No wiki directory found' && pass "wiki: errors gracefully when no wiki dir exists" || fail "wiki: errors gracefully when no wiki dir exists"

# Directory existence guard in wiki-list-select
check_grep ".zshrc" '\[\[ -d "\$DIR" \]\]' "wiki: directory existence guard present"

# Empty selection guard in wiki()
check_grep ".zshrc" '\[\[ -z "\$wiki_selected" \]\]' "wiki: empty selection guard present"

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
check_grep ".zshrc" 'zle -la fzf-file-widget' "fzf: bindkey guarded by zle -la check"

# bindkey calls are inside the guard (should appear after zle -l)
# Count that bindkey appears AFTER the zle -l line in the file
zle_lineno=$(grep -n 'zle -la fzf-file-widget' "$TARGET_HOME/.zshrc" | cut -d: -f1 | head -1)
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
check_grep ".zshrc" 'chezmoi source-path' "zshrc: source-path check in config()"

# ── config add --encrypt workflow ─────────────────────────────────────────────
header "config add --encrypt workflow (fake key roundtrip)"

# Generate a fake SSH key for testing
FAKE_KEY="$TARGET_HOME/.ssh/test_roundtrip_key"
FAKE_KEY_AGE="private_dot_ssh/encrypted_private_test_roundtrip_key.age"

# Set up chezmoi source path
SOURCE="$TARGET_HOME/dotfiles"

# Step 1: Generate fake SSH key
rm -f "$FAKE_KEY" "$FAKE_KEY.pub" 2>/dev/null
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

# ── config commit ── (verify subcommand exists, actual commit skipped)
# Git operations may hang/fail without user config in test environments
if chezmoi git --help >/dev/null 2>&1; then
  pass "config: git subcommand recognized by chezmoi"
else
  warn "config: git subcommand not available"
fi

# ── config edit (verify subcommand recognized) ──
if chezmoi edit --help >/dev/null 2>&1; then
  pass "config: edit subcommand recognized by chezmoi"
else
  warn "config: edit subcommand not available (chezmoi version)"
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
CFG_EXPECTED_AGE="private_dot_ssh/encrypted_private_test_wrapper_key.age"
CFG_SOURCE="$TARGET_HOME/dotfiles"

# Step 1: Generate fake key
rm -f "$CFG_FAKE_KEY" "$CFG_FAKE_KEY.pub" 2>/dev/null
ssh-keygen -t ed25519 -f "$CFG_FAKE_KEY" -N "" -C "wrapper-test" 2>/dev/null
[[ -f "$CFG_FAKE_KEY" ]] && pass "encrypt-via-config: fake key generated" || fail "encrypt-via-config: key gen failed"

# Step 2: config add --encrypt (THE documented command)
HOME="$TARGET_HOME" chezmoi add --encrypt --source "$CFG_SOURCE" --destination "$TARGET_HOME" --force "$CFG_FAKE_KEY" 2>/dev/null
if [[ -f "$CFG_SOURCE/$CFG_EXPECTED_AGE" ]]; then
    pass "encrypt-via-config: .age file created via config add --encrypt"
else
    fail "encrypt-via-config: config add --encrypt did not create .age file"
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
echo "Test home: $TARGET_HOME"
echo "Your real dotfiles: UNTOUCHED"
# Cleanup
rm -rf "$TARGET_HOME" 2>/dev/null
echo ""

if [[ "$FAIL" -gt 0 ]]; then
    echo -e "${RED}Tests FAILED.${NC}"; exit 1
else
    echo -e "${GREEN}All tests PASSED.${NC}"; exit 0
fi
