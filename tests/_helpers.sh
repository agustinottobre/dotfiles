# =============================================================================
# Shared test helpers — sourced by test_macos.sh, test_linux.sh
# =============================================================================
# Requires the sourcing script to set:
#   TEST_HOME         — path to the isolated test home directory
#   set -euo pipefail — assumed active in the sourcing script
# =============================================================================

# ── Color Variables ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Counters ─────────────────────────────────────────────────────────────────
PASS=0
FAIL=0
WARN=0

# ── Reporting Helpers ────────────────────────────────────────────────────────
pass()   { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail()   { echo -e "  ${RED}✗${NC} $1 — ${2:-}"; FAIL=$((FAIL + 1)); }
warn()   { echo -e "  ${YELLOW}⚠${NC} $1 — ${2:-}"; WARN=$((WARN + 1)); }
header() { echo ""; echo -e "${CYAN}── $1 ──${NC}"; }

# ── Timeout Fallback (macOS / systems without GNU timeout) ──────────────────
if ! command -v timeout >/dev/null 2>&1; then
    timeout() {
        local t="$1"; shift
        "$@" &
        local pid=$!
        ( sleep "$t"; kill $pid 2>/dev/null ) &
        wait $pid 2>/dev/null
        local ret=$?
        kill $! 2>/dev/null
        return "${ret:-143}"
    }
fi

# ── Common Zsh Exec Helper ───────────────────────────────────────────────────
# Used by check_zsh_* functions. Runs zsh in the isolated test home.
zsh_exec() {
    HOME="$TEST_HOME" ZDOTDIR="$TEST_HOME" zsh -l -i -c "$1" 2>&1 \
        | grep -v "can't change option: zle" \
        | grep -v "Detected a new version" \
        || true
}

# ── File/Directory/Command Checks ────────────────────────────────────────────
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

# ── Zsh Checks ───────────────────────────────────────────────────────────────
# These use zsh_exec to evaluate expressions within the isolated test home.

check_zsh_func() {
    local func="$1" label="${2:-$func}"
    zsh_exec "whence -f $func >/dev/null 2>&1" >/dev/null 2>&1 \
        && pass "$label" || fail "$label" "not defined"
}

check_zsh_bindkey() {
    local key="$1" widget="$2" label="${3:-}"
    zsh_exec "bindkey '$key' 2>/dev/null" 2>/dev/null | grep -qF "$widget" \
        && pass "${label:-bindkey $key → $widget}" || fail "${label:-bindkey $key → $widget}" "not bound"
}

check_zsh_widget() {
    local widget="$1" label="${2:-widget $widget}"
    zsh_exec "zle -l | grep -qF '$widget'" 2>/dev/null \
        && pass "$label" || fail "$label" "widget not defined"
}

check_zsh_var() {
    local expr="$1" label="$2" detail="${3:-}"
    zsh_exec "[[ $expr ]]" >/dev/null 2>&1 \
        && pass "$label" || fail "$label" "$detail"
}

check_zsh_alias() {
    local name="$1" value="$2" label="${3:-}"
    zsh_exec "alias $name 2>/dev/null | grep -qF '$value'" >/dev/null 2>&1 \
        && pass "${label:-$name → $value}" || fail "${label:-$name → $value}" "alias missing"
}

# Backwards-compat alias (Linux script uses check_var)
check_var() { check_zsh_var "$@"; }
