#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  setup.sh — continente-hero  |  curl-based one-liner installer
# ─────────────────────────────────────────────────────────────────────────────
#
#  Run with a single curl command — no prior clone needed:
#
#    curl -fsSL https://raw.githubusercontent.com/paulfxyz/continente-hero/main/setup.sh | bash
#
#  Or, if you prefer to inspect the script before running it:
#
#    curl -fsSL https://raw.githubusercontent.com/paulfxyz/continente-hero/main/setup.sh -o setup.sh
#    cat setup.sh          # read it
#    bash setup.sh         # run it
#
#  What this script does — in order:
#    1. Checks you are on macOS
#    2. Finds Python 3.11–3.13  (3.14+ is blocked — greenlet has no wheel)
#       └─ If missing and Homebrew is available: installs python@3.13 automatically
#    3. Clones the repo to ~/continente-hero  (or updates it if already there)
#       └─ Uses  git reset --hard origin/main  — bypasses local-change conflicts
#    4. chmod +x  all .sh scripts
#    5. Creates a fresh .venv (always wiped — prevents stale-env bugs)
#    6. Installs all Python packages from requirements.txt
#    7. Downloads the Playwright Chromium browser binary (~170 MB)
#    8. Scaffolds .env, session/, and reports/ if not already present
#    9. Registers the  shop  shell alias
#   10. Prints next steps
#
#  Override the install directory:
#    CONTINENTE_DIR=~/projects/continente-hero bash setup.sh
#
#  WHY Python 3.14 is blocked:
#    Playwright depends on  greenlet  — a C extension that needs a pre-built
#    binary wheel. As of early 2026, no wheel exists for Python 3.14, and
#    building from source fails because Apple's Clang is missing C++ headers
#    that greenlet requires. Python 3.13 is the correct version to use.
#
#  Safe to re-run: session cookies and config.yaml are never modified.
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail   # -e intentionally omitted — we handle errors explicitly

# ── Colours & helpers ─────────────────────────────────────────────────────────
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

info()    { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET}   $*"; }
err()     { echo -e "  ${RED}✗${RESET}  $*" >&2; }
section() { echo -e "\n${BOLD}${CYAN}── $* ──${RESET}"; }
die()     { err "$*"; echo ""; exit 1; }

# ── Trap: catch unexpected exits ──────────────────────────────────────────────
_trap_exit() {
    local code=$?
    if [[ $code -ne 0 ]]; then
        echo ""
        echo -e "  ${RED}${BOLD}Setup exited with an error (code $code).${RESET}"
        echo ""
        echo "  Download the script and re-run with debug output:"
        echo -e "    ${CYAN}curl -fsSL https://raw.githubusercontent.com/paulfxyz/continente-hero/main/setup.sh -o setup.sh${RESET}"
        echo -e "    ${CYAN}bash -x setup.sh${RESET}"
        echo ""
        echo "  Or open an issue: https://github.com/paulfxyz/continente-hero/issues"
        echo ""
    fi
}
trap '_trap_exit' EXIT

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  CONTINENTE HERO — Quick Installer  (v2.0)"
echo "══════════════════════════════════════════════════════════════"
echo ""

# ── Install directory ─────────────────────────────────────────────────────────
INSTALL_DIR="${CONTINENTE_DIR:-$HOME/continente-hero}"
VENV_DIR="$INSTALL_DIR/.venv"

echo -e "  Install directory: ${BOLD}$INSTALL_DIR${RESET}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 — macOS check
# ─────────────────────────────────────────────────────────────────────────────
section "1 / 6  System check"

if [[ "$(uname)" != "Darwin" ]]; then
    warn "This script targets macOS. Continuing — results may vary on other systems."
else
    info "macOS detected"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 — Find Python 3.11–3.13  (auto-install 3.13 via Homebrew if missing)
# ─────────────────────────────────────────────────────────────────────────────
section "2 / 6  Python"

# python_ver BIN  →  prints "major minor" or returns 1 silently
python_ver() {
    local bin="$1"
    command -v "$bin" &>/dev/null || return 1
    "$bin" -c "
import sys
v = sys.version_info
print(v.major, v.minor)
" 2>/dev/null || return 1
}

find_python() {
    # Try explicit versioned binaries first (3.13 → 3.12 → 3.11), then bare python3.
    # Bare python3 is last because on many Homebrew setups it points to 3.14.
    for candidate in python3.13 python3.12 python3.11 python3 \
        /opt/homebrew/bin/python3.13 /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 \
        /usr/local/bin/python3.13  /usr/local/bin/python3.12  /usr/local/bin/python3.11; do
        local ver_str
        ver_str=$(python_ver "$candidate" 2>/dev/null || true)
        [[ -z "$ver_str" ]] && continue
        local major minor
        read -r major minor <<< "$ver_str"
        [[ "$major" -ne 3 ]] && continue
        [[ "$minor" -lt 11 || "$minor" -ge 14 ]] && continue
        echo "$candidate"
        return 0
    done
    return 1
}

PYTHON_BIN=""
BLOCKED_VER=""

# Check for a blocked (3.14+) version so we can report it clearly
for candidate in python3.14 python3; do
    ver_str=$(python_ver "$candidate" 2>/dev/null || true)
    [[ -z "$ver_str" ]] && continue
    read -r major minor <<< "$ver_str"
    if [[ "$major" -eq 3 && "$minor" -ge 14 ]]; then
        BLOCKED_VER="$major.$minor"
        break
    fi
done

PYTHON_BIN=$(find_python 2>/dev/null || true)

# ── No compatible Python — attempt automatic install via Homebrew ─────────────
if [[ -z "$PYTHON_BIN" ]]; then
    echo ""
    if [[ -n "$BLOCKED_VER" ]]; then
        warn "Python $BLOCKED_VER is installed but NOT compatible."
        echo ""
        echo -e "  ${BOLD}Why Python $BLOCKED_VER doesn't work:${RESET}"
        echo "  Playwright's  greenlet  dependency has no pre-built wheel for 3.14+."
        echo "  Building from source fails because Apple's Clang is missing required"
        echo "  C++ headers. Python 3.13 is the correct version to use."
    else
        warn "No compatible Python found (need 3.11–3.13)."
    fi
    echo ""

    if command -v brew &>/dev/null; then
        # Whether running interactively or via curl | bash:
        # just install python@3.13 automatically. This is what a curl installer
        # is expected to do — get everything ready without asking questions.
        echo -e "  ${BOLD}Installing Python 3.13 via Homebrew…${RESET}"
        echo ""
        if brew install python@3.13; then
            echo ""
            # Homebrew may not have updated PATH in this shell session yet.
            # Check well-known absolute paths explicitly.
            for new_bin in python3.13 /opt/homebrew/bin/python3.13 /usr/local/bin/python3.13; do
                ver_str=$(python_ver "$new_bin" 2>/dev/null || true)
                [[ -z "$ver_str" ]] && continue
                read -r major minor <<< "$ver_str"
                if [[ "$major" -eq 3 && "$minor" -eq 13 ]]; then
                    PYTHON_BIN="$new_bin"
                    info "Python 3.13 ready — continuing setup…"
                    break
                fi
            done
            if [[ -z "$PYTHON_BIN" ]]; then
                die "Homebrew installed python@3.13 but the binary wasn't found in PATH or known locations. Open a new Terminal tab and re-run: curl -fsSL https://raw.githubusercontent.com/paulfxyz/continente-hero/main/setup.sh | bash"
            fi
        else
            die "brew install python@3.13 failed. Check the output above, then try again."
        fi
    else
        # No Homebrew — we can't auto-install. Give clear steps.
        err "Homebrew is not installed. We need it to install Python 3.13."
        echo ""
        echo "  Run these commands in your Terminal:"
        echo ""
        echo "  1) Install Homebrew:"
        echo "     /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo ""
        echo "  2) Install Python 3.13:"
        echo "     brew install python@3.13"
        echo ""
        echo "  3) Re-run this installer:"
        echo -e "     ${CYAN}curl -fsSL https://raw.githubusercontent.com/paulfxyz/continente-hero/main/setup.sh | bash${RESET}"
        echo ""
        exit 1
    fi
else
    # Confirm what we found
    ver_str=$(python_ver "$PYTHON_BIN" 2>/dev/null)
    read -r major minor <<< "$ver_str"
    info "Found $PYTHON_BIN ($major.$minor)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 — Clone or update the repo
# ─────────────────────────────────────────────────────────────────────────────
section "3 / 6  Repository"

if ! command -v git &>/dev/null; then
    echo ""
    err "git is not installed."
    echo ""
    echo "  Install it with:  xcode-select --install"
    echo "  Or via Homebrew:  brew install git"
    echo ""
    exit 1
fi

if [[ -d "$INSTALL_DIR/.git" ]]; then
    # Repo exists — update it.
    # We use  git fetch + git reset --hard  instead of  git pull  because
    # git pull aborts when local files differ from the remote (e.g. after a
    # chmod +x on install.sh). reset --hard brings the tree to exactly what
    # is on GitHub — which is correct for an install/repair script.
    info "Repo found at $INSTALL_DIR — updating to latest…"
    cd "$INSTALL_DIR"
    if ! git fetch --quiet origin main; then
        die "git fetch failed. Check your internet connection and try again."
    fi
    git reset --hard origin/main
    info "Repo updated to $(git log -1 --format='%h %s')"
else
    mkdir -p "$(dirname "$INSTALL_DIR")"
    echo "  Cloning into $INSTALL_DIR…"
    if ! git clone https://github.com/paulfxyz/continente-hero.git "$INSTALL_DIR"; then
        die "git clone failed. Check your internet connection and try again."
    fi
    cd "$INSTALL_DIR"
    info "Cloned successfully"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 — Permissions
# ─────────────────────────────────────────────────────────────────────────────
section "4 / 6  Permissions"

chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true
info "All .sh scripts marked executable"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 — Virtual environment + packages
# ─────────────────────────────────────────────────────────────────────────────
section "5 / 6  Python environment"

# Always wipe and rebuild. A venv built with the wrong Python version will
# fail silently or with cryptic errors. Starting clean every time is safer.
if [[ -d "$VENV_DIR" ]]; then
    warn "Removing existing .venv — rebuilding clean…"
    rm -rf "$VENV_DIR"
fi

WANT_VER=$("$PYTHON_BIN" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
"$PYTHON_BIN" -m venv "$VENV_DIR"
info "Created .venv with Python $WANT_VER"

# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"
pip install --quiet --upgrade pip
info "pip upgraded"

if ! pip install -r "$INSTALL_DIR/requirements.txt"; then
    die "pip install failed. Check the output above for details."
fi
info "All packages installed"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 6 — Playwright Chromium
# ─────────────────────────────────────────────────────────────────────────────
section "6 / 6  Playwright Chromium browser"

echo "  Downloading Chromium (~170 MB) — takes a minute on first run…"
# Always use full venv path — zsh doesn't always rehash PATH after venv
# activation, so the bare  playwright  command may silently resolve to nothing.
if ! "$VENV_DIR/bin/playwright" install chromium; then
    die "Playwright Chromium install failed. Check the output above."
fi
info "Chromium ready"

# ─────────────────────────────────────────────────────────────────────────────
# Scaffold config files
# ─────────────────────────────────────────────────────────────────────────────
echo ""
if [[ ! -f "$INSTALL_DIR/.env" && -f "$INSTALL_DIR/.env.example" ]]; then
    cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
    warn ".env created from .env.example (open it to add credentials — optional)."
fi
mkdir -p "$INSTALL_DIR/session" "$INSTALL_DIR/reports"
info "session/ and reports/ directories ready"

# ─────────────────────────────────────────────────────────────────────────────
# Register the  shop  alias
# ─────────────────────────────────────────────────────────────────────────────
echo ""
section "Shell alias"

# Determine which rc file to write to (zsh on modern macOS, bash otherwise)
RC_FILE=""
if [[ "${SHELL:-}" == */zsh ]]; then
    RC_FILE="$HOME/.zshrc"
elif [[ "${SHELL:-}" == */bash ]]; then
    RC_FILE="$HOME/.bashrc"
fi

ALIAS_LINE="alias shop='bash $INSTALL_DIR/shop.sh'"
ALIAS_COMMENT="# continente-hero — added by setup.sh"

if [[ -n "$RC_FILE" ]]; then
    if grep -qF "alias shop=" "$RC_FILE" 2>/dev/null; then
        # Already exists — update it in case the path changed
        # Use a temp file to do the replacement portably (no GNU sed -i on macOS)
        tmp=$(mktemp)
        grep -v "alias shop=" "$RC_FILE" > "$tmp"
        { echo "$ALIAS_COMMENT"; echo "$ALIAS_LINE"; } >> "$tmp"
        mv "$tmp" "$RC_FILE"
        info "Updated  shop  alias in $RC_FILE"
    else
        echo "" >> "$RC_FILE"
        echo "$ALIAS_COMMENT" >> "$RC_FILE"
        echo "$ALIAS_LINE" >> "$RC_FILE"
        info "Registered  shop  alias in $RC_FILE"
    fi
    warn "Run  source $RC_FILE  (or open a new Terminal tab) to activate the alias."
else
    warn "Could not detect shell rc file — add this line manually to ~/.zshrc or ~/.bashrc:"
    echo ""
    echo "    $ALIAS_LINE"
    echo ""
fi

# ─────────────────────────────────────────────────────────────────────────────
# Done — print next steps
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  ✅  continente-hero is ready!"
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "  Installed at: $INSTALL_DIR"
echo ""
echo "  ❶  Activate the  shop  alias (once per Terminal session until you reopen):"
echo -e "       ${CYAN}source $RC_FILE${RESET}"
echo ""
echo "  ❷  Launch the menu:"
echo -e "       ${CYAN}shop${RESET}"
echo ""
echo "  Or go straight to the folder:"
echo -e "       ${CYAN}cd $INSTALL_DIR && ./shop.sh${RESET}"
echo ""
