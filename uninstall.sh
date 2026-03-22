#!/usr/bin/env bash
# uninstall.sh — Remove all bot artefacts from this machine
#
# Removes: .venv/, session/, reports/, Playwright Chromium cache
# Keeps: config.yaml, .env (your data)
#
# Usage: ./uninstall.sh

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  CONTINENTE CART BOT — Uninstall"
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "  This will remove:"
echo "    • .venv/   (Python virtual environment)"
echo "    • session/ (saved login cookies)"
echo "    • reports/ (run reports)"
echo "    • Playwright Chromium browser cache (~170 MB)"
echo ""
read -rp "  Continue? [y/N] " confirm
echo ""

if [[  "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "  Cancelled."
    echo ""
    exit 0
fi

removed=0

_remove() {
    local path="$1"
    if [[ -e "$path" ]]; then
        rm -rf "$path"
        echo -e "  ${GREEN}✓${RESET}  Removed: $path"
        ((removed++))
    else
        echo -e "  ${YELLOW}–${RESET}  Not found: $path (skipped)"
    fi
}

_remove "$SCRIPT_DIR/.venv"
_remove "$SCRIPT_DIR/session"
_remove "$SCRIPT_DIR/reports"

PW_CACHE=""
if [[ -d "$HOME/Library/Caches/ms-playwright" ]]; then
    PW_CACHE="$HOME/Library/Caches/ms-playwright"
elif [[ -d "$HOME/.cache/ms-playwright" ]]; then
    PW_CACHE="$HOME/.cache/ms-playwright"
fi

if [[ -n "$PW_CACHE" ]]; then
    _remove "$PW_CACHE"
else
    echo -e "  ${YELLOW}–${RESET}  Playwright cache not found (already removed or never installed)"
fi

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  ✅  Uninstall complete ($removed item(s) removed)."
echo ""
echo "  config.yaml and .env were intentionally kept."
echo "  To fully remove the project: cd .. && rm -rf continente-cart"
echo "══════════════════════════════════════════════════════════════"
echo ""
