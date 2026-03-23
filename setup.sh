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
#    2. Finds Python 3.11+  (3.14 now works — greenlet 3.3+ ships a cp314 wheel)
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
#  Python version support:
#    Python 3.11–3.14 are all supported. The installer prefers 3.13 (most
#    tested). If you only have 3.14, it will work — playwright>=1.50 depends
#    on greenlet>=3.1.1 which ships pre-built wheels for all versions.
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
echo "  CONTINENTE HERO — Quick Installer  (v2.0.3)"
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
# STEP 2 — Find Python 3.11+  (auto-install 3.13 via Homebrew if missing)
# ─────────────────────────────────────────────────────────────────────────────
# Python 3.11+ is supported. 3.14 now works — greenlet 3.3+ has a cp314 wheel.
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
    # Try explicit versioned binaries first (3.13 preferred → 3.14 → 3.12 → 3.11),
    # then fall back to bare python3.
    # NOTE: Python 3.14 is now supported — greenlet 3.3+ ships a cp314 wheel.
    for candidate in python3.13 python3.14 python3.12 python3.11 python3 \
        /opt/homebrew/bin/python3.13 /opt/homebrew/bin/python3.14 \
        /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 \
        /usr/local/bin/python3.13  /usr/local/bin/python3.14 \
        /usr/local/bin/python3.12  /usr/local/bin/python3.11; do
        local ver_str
        ver_str=$(python_ver "$candidate" 2>/dev/null || true)
        [[ -z "$ver_str" ]] && continue
        local major minor
        read -r major minor <<< "$ver_str"
        [[ "$major" -ne 3 ]] && continue
        [[ "$minor" -lt 11 ]] && continue
        echo "$candidate"
        return 0
    done
    return 1
}

PYTHON_BIN=$(find_python 2>/dev/null || true)

# ── No compatible Python — attempt automatic install via Homebrew ─────────────
if [[ -z "$PYTHON_BIN" ]]; then
    echo ""
    warn "No compatible Python found (need 3.11 or higher)."
    echo ""

    if command -v brew &>/dev/null; then
        # Whether running interactively or via curl | bash:
        # just install python@3.13 automatically. This is what a curl installer
        # is expected to do — get everything ready without asking questions.
        echo -e "  ${BOLD}Installing Python 3.13 via Homebrew…${RESET}"
        echo ""
        # IMPORTANT: redirect brew stdout to stderr.
        # When this script runs via  curl | bash  the shell reads its
        # instructions from stdin (the curl pipe). Any command that writes to
        # stdout feeds back into that pipe and gets interpreted as shell code.
        # brew install outputs hundreds of lines (download progress, caveats,
        # shell script fragments) — without >&2 those lines become bash input
        # and cause spectacular failures. Redirecting to stderr keeps all output
        # visible in the terminal but keeps stdin clean for bash.
        if brew install python@3.13 >&2; then
            echo ""
            # Homebrew may not have updated PATH in this shell session yet.
            # Check well-known absolute paths explicitly.
            for new_bin in python3.13 /opt/homebrew/bin/python3.13 /usr/local/bin/python3.13; do
                ver_str=$(python_ver "$new_bin" 2>/dev/null || true)
                [[ -z "$ver_str" ]] && continue
                read -r major minor <<< "$ver_str"
                if [[ "$major" -eq 3 && "$minor" -ge 11 ]]; then
                    PYTHON_BIN="$new_bin"
                    info "Python 3.13 ready — continuing setup…"
                    break
                fi
            done
            if [[ -z "$PYTHON_BIN" ]]; then
                die "Homebrew installed python@3.13 but the binary wasn't found. Open a new Terminal tab and re-run: curl -fsSL https://raw.githubusercontent.com/paulfxyz/continente-hero/main/setup.sh | bash"
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
        echo "  2) Install Python (3.13 recommended, any 3.11+ works):"
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
    if ! git fetch --quiet origin main >&2; then
        die "git fetch failed. Check your internet connection and try again."
    fi
    git reset --hard origin/main >&2
    info "Repo updated to $(git -C "$INSTALL_DIR" log -1 --format='%h %s')"
else
    mkdir -p "$(dirname "$INSTALL_DIR")"
    echo "  Cloning into $INSTALL_DIR…"
    if ! git clone https://github.com/paulfxyz/continente-hero.git "$INSTALL_DIR" >&2; then
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
"$PYTHON_BIN" -m venv "$VENV_DIR" >&2
info "Created .venv with Python $WANT_VER"

# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"
pip install --quiet --upgrade pip >&2
info "pip upgraded"

# Use --upgrade so pip always resolves fresh versions and doesn't reuse
# a cached broken wheel (e.g. greenlet 3.0.3 built against a stale SDK).
if ! pip install --upgrade -r "$INSTALL_DIR/requirements.txt" >&2; then
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
if ! "$VENV_DIR/bin/playwright" install chromium >&2; then
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
# ── Why you must copy-paste the next command ───────────────────────────────────
# This installer runs inside  curl | bash  — a subshell.
# Any  source ~/.zshrc  run here only affects the subshell, not your Terminal.
# When the subshell exits the alias disappears. The only fix is to source
# the rc file in your own shell session, which requires one copy-paste.
# This is a fundamental Unix process isolation rule, not a bug in this script.
echo -e "  ${BOLD}${YELLOW}⚠️  One step left — copy and run this in your Terminal:${RESET}"
echo ""
echo -e "  ${BOLD}${CYAN}  source ${RC_FILE:-~/.zshrc}${RESET}"
echo ""
echo "  That loads the  shop  alias into your current session."
echo "  After that, just type:"
echo ""
echo -e "  ${BOLD}${CYAN}  shop${RESET}"
echo ""
echo -e "  ${GREEN}(You only need to do this once. New Terminal tabs/windows work automatically.)${RESET}"
echo ""
