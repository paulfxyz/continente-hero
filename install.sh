#!/usr/bin/env bash
# install.sh — One-shot setup for continente-cart on macOS
# Run once after cloning:
#   chmod +x install.sh && ./install.sh

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

info()    { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}⚠️ ${RESET}  $*"; }
error()   { echo -e "  ${RED}✗${RESET}  $*"; }
section() { echo -e "\n${BOLD}$*${RESET}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  CONTINENTE CART BOT — Installer"
echo "══════════════════════════════════════════════════════════════"

section "[ 1 / 5 ]  Checking system…"

if [[ "$(uname)" != "Darwin" ]]; then
    warn "This installer targets macOS. Continuing anyway — adjust as needed."
fi

section "[ 2 / 5 ]  Python…"

PYTHON_BIN=""
for candidate in python3.13 python3.12 python3.11 python3; do
    if command -v "$candidate" &>/dev/null; then
        ver=$("$candidate" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        major="${ver%%.*}"
        minor="${ver##*.}"
        if [[ "$major" -ge 3 && "$minor" -ge 11 ]]; then
            PYTHON_BIN="$candidate"
            info "Found $PYTHON_BIN ($ver)"
            break
        fi
    fi
done

if [[ -z "$PYTHON_BIN" ]]; then
    echo ""
    error "Python 3.11 or higher is required but not found."
    echo ""
    echo "  Install it with Homebrew:"
    echo "    brew install python@3.12"
    echo ""
    echo "  Or download from: https://www.python.org/downloads/"
    echo ""
    exit 1
fi

section "[ 3 / 5 ]  Virtual environment…"

if [[ -d "$VENV_DIR" ]]; then
    warn ".venv already exists — skipping creation. Run ./update.sh to refresh."
else
    "$PYTHON_BIN" -m venv "$VENV_DIR"
    info "Created virtual environment at .venv"
fi

source "$VENV_DIR/bin/activate"
pip install --quiet --upgrade pip

section "[ 4 / 5 ]  Installing Python packages…"

pip install --quiet -r "$SCRIPT_DIR/requirements.txt"
info "playwright, pyyaml, python-dotenv installed"

section "[ 5 / 5 ]  Installing Playwright Chromium…"

playwright install chromium
info "Chromium browser downloaded"

if [[ ! -f "$SCRIPT_DIR/.env" && -f "$SCRIPT_DIR/.env.example" ]]; then
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    warn ".env created from .env.example — edit it with your credentials (optional)."
fi

mkdir -p "$SCRIPT_DIR/session" "$SCRIPT_DIR/reports"

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
echo "       nano config.yaml"
echo ""
echo "  3) Run the bot:"
echo "       ./run.sh"
echo ""
echo "  See INSTALL.md for full setup options and credential docs."
echo ""
