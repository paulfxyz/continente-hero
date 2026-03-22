#!/usr/bin/env bash
# update.sh — Pull latest changes and refresh dependencies
# Usage: ./update.sh

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
RESET="\033[0m"

info()    { echo -e "  ${GREEN}✓${RESET}  $*"; }
section() { echo -e "
${BOLD}$*${RESET}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  CONTINENTE CART BOT — Update"
echo "══════════════════════════════════════════════════════════════"

section "[ 1 / 3 ]  Pulling latest changes from GitHub…"

if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    git -C "$SCRIPT_DIR" pull --ff-only
    info "Repository up to date."
else
    echo "  (Not a git repository — skipping git pull)"
fi

section "[ 2 / 3 ]  Updating Python dependencies…"

if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
    echo ""
    echo "  ✗  Virtual environment not found — run ./install.sh first."
    echo ""
    exit 1
fi

source "$VENV_DIR/bin/activate"
pip install --quiet --upgrade pip
pip install --quiet --upgrade -r "$SCRIPT_DIR/requirements.txt"
info "Python packages updated."

section "[ 3 / 3 ]  Updating Playwright Chromium…"

playwright install chromium
info "Chromium browser updated."

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  ✅  Update complete — run ./run.sh to start the bot."
echo "══════════════════════════════════════════════════════════════"
echo ""
