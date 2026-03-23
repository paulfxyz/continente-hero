#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  install.sh — One-shot setup for continente-hero on macOS
# ─────────────────────────────────────────────────────────────────────────────
#  Run once after cloning:
#    chmod +x install.sh && ./install.sh
#
#  Requires: Python 3.11 – 3.13  (Python 3.14+ is NOT yet supported)
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

info()    { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}⚠️ ${RESET}  $*"; }
error()   { echo -e "  ${RED}✗${RESET}  $*"; }
section() { echo -e "
${BOLD}$*${RESET}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  CONTINENTE HERO BOT — Installer"
echo "══════════════════════════════════════════════════════════════"

# ── 1. Check macOS ────────────────────────────────────────────────────────────
section "[ 1 / 5 ]  Checking system…"

if [[ "$(uname)" != "Darwin" ]]; then
    warn "This installer targets macOS. Continuing anyway — adjust as needed."
fi

# ── 2. Python 3.11 – 3.13 ────────────────────────────────────────────────────
section "[ 2 / 5 ]  Python…"

# Helper: given a python binary, return its "major.minor" or empty string if
# the binary doesn't exist or is outside the supported range (3.11 – 3.13).
check_python() {
    local bin="$1"
    command -v "$bin" &>/dev/null || return 1

    local ver
    ver=$("$bin" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null) || return 1

    local major minor
    major="${ver%%.*}"
    minor="${ver##*.}"

    # Must be Python 3.x
    [[ "$major" -ne 3 ]] && return 1

    # Hard block: Python 3.14+ has no pre-built wheels for Playwright's
    # greenlet dependency and cannot compile from source on current macOS
    # toolchains. Block until upstream support lands.
    if [[ "$minor" -ge 14 ]]; then
        echo "BLOCKED:$ver"
        return 0
    fi

    # Must be at least 3.11
    if [[ "$minor" -lt 11 ]]; then
        return 1
    fi

    echo "OK:$ver"
}

PYTHON_BIN=""
BLOCKED_VER=""

# Preference order: 3.13 → 3.12 → 3.11
# We intentionally do NOT fall back to the bare `python3` command because on
# many macOS systems `python3` resolves to whatever Homebrew last installed —
# which may be 3.14 or newer. The explicit versioned binaries are safer.
for candidate in python3.13 python3.12 python3.11; do
    result=$(check_python "$candidate" || true)
    if [[ "$result" == OK:* ]]; then
        ver="${result#OK:}"
        PYTHON_BIN="$candidate"
        info "Found $PYTHON_BIN ($ver) ✓"
        break
    elif [[ "$result" == BLOCKED:* ]]; then
        ver="${result#BLOCKED:}"
        BLOCKED_VER="$ver"
        # keep looking — a lower versioned binary might still exist
    fi
done

# Last resort: check the bare `python3` command, but still enforce the cap
if [[ -z "$PYTHON_BIN" ]]; then
    result=$(check_python python3 || true)
    if [[ "$result" == OK:* ]]; then
        ver="${result#OK:}"
        PYTHON_BIN="python3"
        info "Found python3 ($ver) ✓"
    elif [[ "$result" == BLOCKED:* ]]; then
        ver="${result#BLOCKED:}"
        BLOCKED_VER="$ver"
    fi
fi

# ── Hard block for Python 3.14+ ───────────────────────────────────────────────
if [[ -z "$PYTHON_BIN" && -n "$BLOCKED_VER" ]]; then
    echo ""
    error "Python $BLOCKED_VER detected — not yet supported."
    echo ""
    echo "  Playwright's greenlet dependency has no pre-built wheel for"
    echo "  Python 3.14+ and the C++ source build fails on current macOS"
    echo "  toolchains. Python 3.11 – 3.13 is required."
    echo ""
    echo "  ──────────────────────────────────────────────────────────"
    echo "  Install Python 3.13 via Homebrew (recommended):"
    echo ""
    echo "    brew install python@3.13"
    echo ""
    echo "  Then re-run this installer — it will find python3.13"
    echo "  automatically and use it."
    echo "  ──────────────────────────────────────────────────────────"
    echo ""
    exit 1
fi

# ── No supported Python found at all ─────────────────────────────────────────
if [[ -z "$PYTHON_BIN" ]]; then
    echo ""
    error "Python 3.11 – 3.13 is required but was not found."
    echo ""
    echo "  Install Python 3.13 via Homebrew:"
    echo ""
    echo "    brew install python@3.13"
    echo ""
    echo "  Or download from: https://www.python.org/downloads/"
    echo ""
    exit 1
fi

# ── 3. Virtual environment ────────────────────────────────────────────────────
section "[ 3 / 5 ]  Virtual environment…"

if [[ -d "$VENV_DIR" ]]; then
    # Check whether the existing venv was built with the same Python we just
    # selected. If Python changed (e.g. user had 3.14, now has 3.13) the old
    # venv must be removed — mixing interpreters corrupts native extensions.
    VENV_PYTHON="$VENV_DIR/bin/python"
    VENV_VER=""
    if [[ -x "$VENV_PYTHON" ]]; then
        VENV_VER=$("$VENV_PYTHON" -c \
            "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || true)
    fi

    WANT_VER=$("$PYTHON_BIN" -c \
        "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")

    if [[ "$VENV_VER" != "$WANT_VER" ]]; then
        warn "Existing .venv was built with Python $VENV_VER — need $WANT_VER. Rebuilding…"
        rm -rf "$VENV_DIR"
        "$PYTHON_BIN" -m venv "$VENV_DIR"
        info "Rebuilt virtual environment with Python $WANT_VER"
    else
        info ".venv already exists with Python $VENV_VER — reusing"
    fi
else
    "$PYTHON_BIN" -m venv "$VENV_DIR"
    info "Created virtual environment at .venv"
fi

# Activate
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"
pip install --quiet --upgrade pip

# ── 4. Python dependencies ────────────────────────────────────────────────────
section "[ 4 / 5 ]  Installing Python packages…"

pip install --quiet -r "$SCRIPT_DIR/requirements.txt"
info "playwright, pyyaml, python-dotenv installed"

# ── 5. Playwright Chromium browser ───────────────────────────────────────────
section "[ 5 / 5 ]  Installing Playwright Chromium…"

playwright install chromium
info "Chromium browser downloaded"

# ── Create .env from example if not present ───────────────────────────────────
if [[ ! -f "$SCRIPT_DIR/.env" && -f "$SCRIPT_DIR/.env.example" ]]; then
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    warn ".env created from .env.example — edit it with your credentials (optional)."
fi

# ── Create session + reports dirs ─────────────────────────────────────────────
mkdir -p "$SCRIPT_DIR/session" "$SCRIPT_DIR/reports"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  ✅  Installation complete!"
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "  Next steps:"
echo ""
echo "  1) Authenticate (recommended — one-time manual login):"
echo "       ./run.sh --save-session"
echo ""
echo "  2) Edit your shopping list:"
echo "       ./edit.sh"
echo ""
echo "  3) Run the bot:"
echo "       ./run.sh"
echo ""
echo "  See INSTALL.md for full setup options and credential docs."
echo ""
