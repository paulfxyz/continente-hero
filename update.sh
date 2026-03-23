#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  update.sh — continente-hero  |  Pull latest code + refresh all dependencies
# ─────────────────────────────────────────────────────────────────────────────
#
#  Usage:
#    ./update.sh
#
#  What this does:
#    1. Pulls the latest code from GitHub
#       └─ Uses  git fetch + git reset --hard  (bypasses local-change conflicts)
#    2. Upgrades all Python packages
#    3. Updates the Playwright Chromium browser binary
#    4. Re-applies  chmod +x  on all .sh scripts
#
#  Your config.yaml and session/cookies.json are never touched.
#  Safe to run at any time.
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

info()    { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET}   $*"; }
section() { echo -e "\n${BOLD}${CYAN}── $* ──${RESET}"; }

_src="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$_src")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  CONTINENTE HERO — Update  (v2.0)"
echo "══════════════════════════════════════════════════════════════"

# ── 1. Pull latest from GitHub ────────────────────────────────────────────────
section "1 / 4  Code"

if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    if git -C "$SCRIPT_DIR" fetch --quiet origin main; then
        git -C "$SCRIPT_DIR" reset --hard origin/main
        info "Updated to: $(git -C "$SCRIPT_DIR" log -1 --format='%h %s')"
    else
        warn "Could not reach GitHub — skipping code update."
    fi
else
    warn "Not a git repository — skipping code update."
fi

# ── 2. Update Python packages ─────────────────────────────────────────────────
section "2 / 4  Python packages"

if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
    echo ""
    echo "  Virtual environment not found. Run the installer first:"
    echo -e "    ${CYAN}curl -fsSL https://raw.githubusercontent.com/paulfxyz/continente-hero/main/setup.sh | bash${RESET}"
    echo ""
    exit 1
fi

# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"
pip install --quiet --upgrade pip
pip install --quiet --upgrade -r "$SCRIPT_DIR/requirements.txt"
info "All packages up to date"

# ── 3. Update Playwright Chromium ────────────────────────────────────────────
section "3 / 4  Playwright Chromium"

"$VENV_DIR/bin/playwright" install chromium
info "Chromium up to date"

# ── 4. Permissions ────────────────────────────────────────────────────────────
section "4 / 4  Permissions"

chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true
info "All .sh scripts marked executable"

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  ✅  Update complete."
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "  Run the bot:    shop  or  ./shop.sh"
echo ""
