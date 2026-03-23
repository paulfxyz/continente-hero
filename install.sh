#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  install.sh — One-shot setup for continente-hero on macOS
# ─────────────────────────────────────────────────────────────────────────────
#  Run once after cloning, or re-run at any time to repair/upgrade:
#    chmod +x install.sh && ./install.sh
#
#  What this script does, in order:
#    1. Verifies you are on macOS
#    2. Finds Python 3.11–3.13 (offers to install 3.13 via Homebrew if missing)
#    3. Wipes any existing .venv that was built with the wrong Python
#    4. Creates a fresh .venv and installs all Python packages
#    5. Downloads the Playwright Chromium browser
#    6. Creates .env, session/, and reports/ if they don't exist yet
#
#  Safe to re-run: existing session cookies and config.yaml are never touched.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

info()    { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET}   $*"; }
error()   { echo -e "  ${RED}✗${RESET}  $*" >&2; }
section() { echo -e "
${BOLD}${CYAN}$*${RESET}"; }
die()     { error "$*"; echo ""; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  CONTINENTE HERO — Installer"
echo "══════════════════════════════════════════════════════════════"
echo ""

# ── 1. macOS check ────────────────────────────────────────────────────────────
section "[ 1 / 5 ]  System check"

if [[ "$(uname)" != "Darwin" ]]; then
    warn "This script targets macOS. Continuing anyway — results may vary."
else
    info "macOS detected"
fi

# ── 2. Python 3.11–3.13 ───────────────────────────────────────────────────────
section "[ 2 / 5 ]  Python"

# Returns 0 and prints "major.minor" if the binary exists and is in range.
# Prints nothing and returns 1 otherwise.
# Prints "BLOCKED:major.minor" (exit 0) if >= 3.14.
python_status() {
    local bin="$1"
    command -v "$bin" &>/dev/null || return 1
    local ver
    ver=$("$bin" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null) || return 1
    local major="${ver%%.*}" minor="${ver##*.}"
    [[ "$major" -ne 3 ]] && return 1
    if   [[ "$minor" -ge 14 ]]; then echo "BLOCKED:$ver"
    elif [[ "$minor" -ge 11 ]]; then echo "OK:$ver"
    fi
}

PYTHON_BIN=""
BLOCKED_VER=""

for candidate in python3.13 python3.12 python3.11; do
    status=$(python_status "$candidate" || true)
    case "$status" in
        OK:*)      PYTHON_BIN="$candidate"; info "Found $candidate (${status#OK:})"; break ;;
        BLOCKED:*) BLOCKED_VER="${status#BLOCKED:}" ;;
    esac
done

# Bare python3 as last resort — same cap applies
if [[ -z "$PYTHON_BIN" ]]; then
    status=$(python_status python3 || true)
    case "$status" in
        OK:*)      PYTHON_BIN="python3"; info "Found python3 (${status#OK:})" ;;
        BLOCKED:*) BLOCKED_VER="${status#BLOCKED:}" ;;
    esac
fi

# ── Nothing valid found ───────────────────────────────────────────────────────
if [[ -z "$PYTHON_BIN" ]]; then
    echo ""
    if [[ -n "$BLOCKED_VER" ]]; then
        error "Python $BLOCKED_VER is installed but is NOT supported."
        echo ""
        echo "  Playwright's greenlet dependency has no pre-built wheel for"
        echo "  Python 3.14+ and source compilation fails on current macOS."
        echo "  Supported range: Python 3.11 – 3.13"
    else
        error "No compatible Python found (need 3.11 – 3.13)."
    fi
    echo ""

    # ── Offer to install python@3.13 via Homebrew automatically ───────────────
    if command -v brew &>/dev/null; then
        echo -e "  ${BOLD}Homebrew is available. Install Python 3.13 now?${RESET}"
        echo -e "  This runs: ${CYAN}brew install python@3.13${RESET}"
        echo ""
        read -r -p "  [y/N] → " answer
        echo ""
        if [[ "${answer,,}" == "y" ]]; then
            echo "  Installing python@3.13 via Homebrew…"
            brew install python@3.13
            echo ""
            status=$(python_status python3.13 || true)
            if [[ "$status" == OK:* ]]; then
                PYTHON_BIN="python3.13"
                info "python3.13 ready (${status#OK:})"
            else
                die "python3.13 install succeeded but binary not found. Try opening a new terminal and re-running install.sh."
            fi
        else
            echo "  Run this manually, then re-run install.sh:"
            echo ""
            echo "    brew install python@3.13"
            echo ""
            exit 1
        fi
    else
        echo "  Install Homebrew first (https://brew.sh), then run:"
        echo ""
        echo "    brew install python@3.13"
        echo ""
        echo "  Then re-run: ./install.sh"
        echo ""
        exit 1
    fi
fi

# ── 3. Virtual environment ─────────────────────────────────────────────────────
section "[ 3 / 5 ]  Virtual environment"

WANT_VER=$("$PYTHON_BIN" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")

if [[ -d "$VENV_DIR" ]]; then
    VENV_VER=""
    if [[ -x "$VENV_DIR/bin/python" ]]; then
        VENV_VER=$("$VENV_DIR/bin/python" -c \
            "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || true)
    fi

    if [[ "$VENV_VER" == "$WANT_VER" ]]; then
        info "Existing .venv (Python $VENV_VER) matches — reusing"
    else
        warn "Existing .venv was built with Python ${VENV_VER:-unknown} — need $WANT_VER. Wiping and rebuilding…"
        rm -rf "$VENV_DIR"
        "$PYTHON_BIN" -m venv "$VENV_DIR"
        info "Rebuilt .venv with Python $WANT_VER"
    fi
else
    "$PYTHON_BIN" -m venv "$VENV_DIR"
    info "Created .venv with Python $WANT_VER"
fi

# Activate and upgrade pip silently
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"
pip install --quiet --upgrade pip

# ── 4. Python packages ────────────────────────────────────────────────────────
section "[ 4 / 5 ]  Python packages"

pip install --quiet -r "$SCRIPT_DIR/requirements.txt"
info "playwright, pyyaml, python-dotenv installed"

# ── 5. Playwright Chromium ────────────────────────────────────────────────────
section "[ 5 / 5 ]  Playwright Chromium browser"

playwright install chromium
info "Chromium downloaded"

# ── Scaffolding ───────────────────────────────────────────────────────────────
if [[ ! -f "$SCRIPT_DIR/.env" && -f "$SCRIPT_DIR/.env.example" ]]; then
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    warn ".env created from .env.example — fill in your credentials if needed."
fi

mkdir -p "$SCRIPT_DIR/session" "$SCRIPT_DIR/reports"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  ✅  All done!  continente-hero is ready."
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "  Next steps:"
echo ""
echo "  1) Save your login session (one-time, opens a browser window):"
echo "       ./run.sh --save-session"
echo ""
echo "  2) Edit your shopping list:"
echo "       ./edit.sh"
echo ""
echo "  3) Run the bot:"
echo "       ./run.sh"
echo ""
echo "  See INSTALL.md for all options."
echo ""
