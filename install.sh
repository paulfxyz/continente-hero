#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  install.sh — continente-hero  |  macOS setup script
# ─────────────────────────────────────────────────────────────────────────────
#
#  Usage (run once after cloning, or any time to repair/upgrade):
#    chmod +x install.sh && ./install.sh
#
#  What this script does — in order:
#    1. Checks you are on macOS
#    2. Finds Python 3.11–3.13  (3.14+ is blocked — see WHY below)
#       └─ If missing: offers to run  brew install python@3.13  for you
#    3. Wipes any existing .venv entirely and rebuilds it clean
#       └─ This is intentional — a stale venv from the wrong Python causes
#          silent, hard-to-debug failures. Always start fresh.
#    4. Installs all Python packages from requirements.txt
#    5. Downloads the Playwright Chromium browser binary
#    6. Scaffolds .env, session/, and reports/ if not already present
#       └─ config.yaml and session/cookies.json are NEVER touched
#
#  WHY Python 3.14 is blocked:
#    Playwright depends on  greenlet  — a C extension that needs a pre-built
#    binary wheel to install. As of early 2026, greenlet publishes no wheel
#    for Python 3.14, and building it from source fails on macOS because
#    Apple's Clang ships without some C++ standard library headers that
#    greenlet's source expects. The fix is simply to use Python 3.13.
#
#  Safe to re-run: session cookies and config.yaml are never modified.
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail   # -e intentionally omitted: we handle errors explicitly

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

# Resolve the directory containing this script.
# BASH_SOURCE[0] is preferred (works for  source  and  ./install.sh).
# Fall back to $0 for shells that don't set BASH_SOURCE.
_src="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$_src")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  CONTINENTE HERO — Installer  (v1.2.4)"
echo "══════════════════════════════════════════════════════════════"
echo ""

# ── 0. Permissions ────────────────────────────────────────────────────────────
section "0 / 5  Permissions"
# git clone does not preserve execute bits on .sh files. Fix them all up front
# so the user never sees "permission denied" when running run.sh, edit.sh, etc.
chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true
info "All .sh scripts marked executable"

# ── 1. macOS ──────────────────────────────────────────────────────────────────
section "1 / 5  System check"

if [[ "$(uname)" != "Darwin" ]]; then
    warn "This script targets macOS. Continuing anyway — results may vary."
else
    info "macOS detected"
fi

# ── 2. Python version check ───────────────────────────────────────────────────
section "2 / 5  Python"

# python_ver BIN
#   Prints the "major minor" (space-separated integers) for BIN, or returns 1.
#   Does NOT print anything on failure — caller decides what to say.
python_ver() {
    local bin="$1"
    command -v "$bin" &>/dev/null || return 1
    "$bin" -c "
import sys, os
v = sys.version_info
print(v.major, v.minor)
" 2>/dev/null || return 1
}

PYTHON_BIN=""
BLOCKED_VER=""

# Ordered preference: 3.13 → 3.12 → 3.11
# We try explicit versioned binaries first.
# The bare  python3  alias is checked last because on many Homebrew setups it
# points to the most-recently-installed Python — which may be 3.14.
for candidate in python3.13 python3.12 python3.11 python3; do
    ver_str=$(python_ver "$candidate" 2>/dev/null || true)
    [[ -z "$ver_str" ]] && continue

    # Parse major and minor safely — works for "3 13", "3 14", etc.
    read -r major minor <<< "$ver_str"

    if [[ "$major" -ne 3 ]]; then
        continue
    fi

    if [[ "$minor" -ge 14 ]]; then
        # Record the blocked version for the error message, keep scanning.
        BLOCKED_VER="$major.$minor"
        continue
    fi

    if [[ "$minor" -ge 11 ]]; then
        PYTHON_BIN="$candidate"
        info "Found $candidate ($major.$minor)"
        break
    fi
    # < 3.11: skip silently
done

# Apple Silicon Homebrew puts versioned binaries here even when not in PATH
if [[ -z "$PYTHON_BIN" ]]; then
    for hb_bin in \
        /opt/homebrew/bin/python3.13 \
        /opt/homebrew/bin/python3.12 \
        /opt/homebrew/bin/python3.11 \
        /usr/local/bin/python3.13 \
        /usr/local/bin/python3.12 \
        /usr/local/bin/python3.11; do
        ver_str=$(python_ver "$hb_bin" 2>/dev/null || true)
        [[ -z "$ver_str" ]] && continue
        read -r major minor <<< "$ver_str"
        if [[ "$major" -eq 3 && "$minor" -ge 11 && "$minor" -lt 14 ]]; then
            PYTHON_BIN="$hb_bin"
            info "Found $hb_bin ($major.$minor)"
            break
        fi
    done
fi

# ── No valid Python found ─────────────────────────────────────────────────────
if [[ -z "$PYTHON_BIN" ]]; then
    echo ""
    if [[ -n "$BLOCKED_VER" ]]; then
        err "Python $BLOCKED_VER is installed, but is NOT compatible."
        echo ""
        echo -e "  ${BOLD}Why Python $BLOCKED_VER does not work:${RESET}"
        echo "  Playwright depends on a C extension called  greenlet."
        echo "  greenlet has no pre-built binary wheel for Python 3.14+,"
        echo "  and building it from source fails on macOS because Apple's"
        echo "  Clang does not ship the C++ headers that greenlet needs."
        echo "  The fix: use Python 3.13."
        echo ""
        echo "  Supported range: Python 3.11 – 3.13"
    else
        err "No compatible Python found. Need Python 3.11–3.13."
    fi
    echo ""

    # ── Offer automatic install via Homebrew ──────────────────────────────────
    if command -v brew &>/dev/null; then
        echo -e "  ${BOLD}Homebrew is available.${RESET}"
        echo -e "  Install Python 3.13 now? (runs: ${CYAN}brew install python@3.13${RESET})"
        echo ""
        printf "  [y/N] → "
        read -r answer </dev/tty
        echo ""

        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            echo "  Running: brew install python@3.13"
            echo ""
            if brew install python@3.13; then
                echo ""
                # After Homebrew install, check the well-known paths explicitly
                # because the shell PATH may not have updated yet.
                for new_bin in \
                    python3.13 \
                    /opt/homebrew/bin/python3.13 \
                    /usr/local/bin/python3.13; do
                    ver_str=$(python_ver "$new_bin" 2>/dev/null || true)
                    [[ -z "$ver_str" ]] && continue
                    read -r major minor <<< "$ver_str"
                    if [[ "$major" -eq 3 && "$minor" -eq 13 ]]; then
                        PYTHON_BIN="$new_bin"
                        info "python3.13 ready ($major.$minor) — continuing…"
                        break
                    fi
                done
                if [[ -z "$PYTHON_BIN" ]]; then
                    die "Homebrew installed python@3.13 but the binary wasn't found in PATH or /opt/homebrew/bin. Try: open a new terminal tab and re-run ./install.sh"
                fi
            else
                die "brew install python@3.13 failed. Check the output above, then re-run ./install.sh."
            fi
        else
            echo "  Run this manually, then re-run install.sh:"
            echo ""
            echo "    brew install python@3.13"
            echo ""
            exit 1
        fi
    else
        echo "  Install Homebrew first:"
        echo "    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo ""
        echo "  Then: brew install python@3.13"
        echo "  Then: ./install.sh"
        echo ""
        exit 1
    fi
fi

# ── 3. Virtual environment ─────────────────────────────────────────────────────
section "3 / 5  Virtual environment"

# Always wipe and rebuild. A venv created with the wrong Python (e.g. 3.14)
# will fail silently or with cryptic errors when pip tries to install compiled
# extensions. The only safe approach is a clean rebuild every time.
if [[ -d "$VENV_DIR" ]]; then
    warn "Removing existing .venv and rebuilding clean…"
    rm -rf "$VENV_DIR"
fi

WANT_VER=$("$PYTHON_BIN" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
"$PYTHON_BIN" -m venv "$VENV_DIR"
info "Created .venv with Python $WANT_VER"

# Activate
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"
pip install --quiet --upgrade pip
info "pip upgraded"

# ── 4. Python packages ────────────────────────────────────────────────────────
section "4 / 5  Python packages"

# Show package install progress (not --quiet) so the user sees something
# happening during the ~30-second Playwright wheel download.
pip install -r "$SCRIPT_DIR/requirements.txt"
info "All packages installed"

# ── 5. Playwright Chromium ────────────────────────────────────────────────────
section "5 / 5  Playwright Chromium browser"

echo "  Downloading Chromium (~170 MB) — this takes a minute on first run…"
"$VENV_DIR/bin/playwright" install chromium
info "Chromium ready"

# ── Scaffold .env, session/, reports/ ─────────────────────────────────────────
echo ""
if [[ ! -f "$SCRIPT_DIR/.env" && -f "$SCRIPT_DIR/.env.example" ]]; then
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    warn ".env created from .env.example — open it to add credentials (optional)."
fi

mkdir -p "$SCRIPT_DIR/session" "$SCRIPT_DIR/reports"
info "session/ and reports/ directories ready"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  ✅  continente-hero is ready!"
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "  Next steps:"
echo ""
echo "  1) Save your login session (one-time — opens a browser window):"
echo "       ./run.sh --save-session"
echo ""
echo "  2) Edit your shopping list:"
echo "       ./edit.sh"
echo ""
echo "  3) Run the bot:"
echo "       ./run.sh"
echo ""
echo "  Full guide: INSTALL.md"
echo ""
