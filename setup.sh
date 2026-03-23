#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  setup.sh — continente-hero  |  curl-based one-liner installer
# ─────────────────────────────────────────────────────────────────────────────
#
#  Run with a single curl command — no prior clone needed:
#
#    curl -fsSL https://raw.githubusercontent.com/paulfxyz/continente-hero/main/setup.sh | bash
#
#  Or, if you prefer to inspect first:
#
#    curl -fsSL https://raw.githubusercontent.com/paulfxyz/continente-hero/main/setup.sh -o setup.sh
#    cat setup.sh          # read it
#    bash setup.sh         # run it
#
#  What this script does — in order:
#    1. Checks you are on macOS
#    2. Finds Python 3.11–3.13  (3.14+ is blocked — greenlet has no wheel yet)
#       └─ If missing: offers to run  brew install python@3.13  for you
#    3. Clones the repo to ~/continente-hero  (or pulls latest if already there)
#       └─ Uses  git reset --hard origin/main  to bypass local-change conflicts
#    4. chmod +x  all .sh scripts in the repo
#    5. Creates a fresh .venv (always wiped — prevents stale-env bugs)
#    6. Installs all Python packages from requirements.txt
#    7. Downloads the Playwright Chromium browser binary (~170 MB)
#    8. Scaffolds .env, session/, and reports/ if not already present
#    9. Prints next steps
#
#  Override the install directory:
#    CONTINENTE_DIR=~/projects/continente-hero bash setup.sh
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

# ── Safety flags ──────────────────────────────────────────────────────────────
# -u  : treat unset variables as errors
# -o pipefail : a pipe fails if any command in it fails
# -e is intentionally omitted — we handle errors explicitly and want to keep
#    running (e.g. showing a helpful message) even when a step fails.
set -uo pipefail

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
# When piped through  curl ... | bash  the script runs in a subshell.
# If it exits for any reason other than a clean exit 0, print a pointer so the
# user knows something went wrong and where to look.
_trap_exit() {
    local code=$?
    if [[ $code -ne 0 ]]; then
        echo ""
        echo -e "  ${RED}${BOLD}Setup exited with an error (code $code).${RESET}"
        echo ""
        echo "  If this was unexpected, re-run with full debug output:"
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
echo "  CONTINENTE HERO — Quick Installer  (v1.3.0)"
echo "══════════════════════════════════════════════════════════════"
echo ""

# ── Install directory ─────────────────────────────────────────────────────────
# Default: ~/continente-hero
# Override: CONTINENTE_DIR=/some/other/path bash setup.sh
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
# STEP 2 — Find a compatible Python (3.11 – 3.13)
# ─────────────────────────────────────────────────────────────────────────────
section "2 / 6  Python"

# python_ver BIN
#   Prints "major minor" (space-separated integers) for BIN, or returns 1.
#   Never prints anything on failure — caller decides what to say.
python_ver() {
    local bin="$1"
    command -v "$bin" &>/dev/null || return 1
    "$bin" -c "
import sys
v = sys.version_info
print(v.major, v.minor)
" 2>/dev/null || return 1
}

PYTHON_BIN=""
BLOCKED_VER=""

# Try versioned binaries first — explicit order: 3.13 → 3.12 → 3.11 → bare python3
# The bare  python3  alias is tried last because on many Homebrew setups it
# points to the most recently installed Python, which may be 3.14.
for candidate in python3.13 python3.12 python3.11 python3; do
    ver_str=$(python_ver "$candidate" 2>/dev/null || true)
    [[ -z "$ver_str" ]] && continue

    read -r major minor <<< "$ver_str"

    [[ "$major" -ne 3 ]] && continue

    if [[ "$minor" -ge 14 ]]; then
        # Record but keep scanning — there may be a valid version installed too.
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

# Apple Silicon Homebrew installs to /opt/homebrew/bin, Intel Macs to /usr/local/bin.
# If the versioned binary isn't in PATH, check these paths explicitly.
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

    # Offer automatic Homebrew install — but only if stdin is a terminal.
    # When piped through  curl | bash  stdin is the pipe, not the keyboard.
    # Reading a prompt from a closed pipe produces an empty answer and looks
    # broken. We detect this and give clear instructions instead.
    if command -v brew &>/dev/null; then
        echo -e "  ${BOLD}Homebrew is available.${RESET}"
        echo ""

        if [[ -t 0 ]]; then
            # stdin is a terminal — safe to prompt interactively
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
                    # Check known Homebrew paths explicitly — the new binary may
                    # not yet be in PATH within this same shell session.
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
                        die "Homebrew installed python@3.13 but the binary wasn't found. Try: open a new terminal and re-run setup.sh"
                    fi
                else
                    die "brew install python@3.13 failed. Check the output above, then re-run setup.sh."
                fi
            else
                echo "  Run this manually, then re-run setup.sh:"
                echo ""
                echo "    brew install python@3.13"
                echo ""
                exit 1
            fi
        else
            # stdin is a pipe (curl | bash) — cannot prompt interactively.
            # Print clear instructions and exit cleanly.
            echo "  Run the following commands in your Terminal, then re-run setup.sh:"
            echo ""
            echo -e "    ${CYAN}brew install python@3.13${RESET}"
            echo -e "    ${CYAN}curl -fsSL https://raw.githubusercontent.com/paulfxyz/continente-hero/main/setup.sh | bash${RESET}"
            echo ""
            exit 1
        fi
    else
        echo "  Install Homebrew first:"
        echo "    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo ""
        echo "  Then: brew install python@3.13"
        echo "  Then re-run setup.sh:"
        echo -e "    ${CYAN}curl -fsSL https://raw.githubusercontent.com/paulfxyz/continente-hero/main/setup.sh | bash${RESET}"
        echo ""
        exit 1
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 — Clone or update the repo
# ─────────────────────────────────────────────────────────────────────────────
section "3 / 6  Repository"

# Ensure git is available
if ! command -v git &>/dev/null; then
    echo ""
    err "git is not installed."
    echo ""
    echo "  Install it with:"
    echo "    xcode-select --install"
    echo ""
    echo "  Or via Homebrew:"
    echo "    brew install git"
    echo ""
    exit 1
fi

if [[ -d "$INSTALL_DIR/.git" ]]; then
    # Repo already exists — update it.
    # We use  git fetch + git reset --hard origin/main  instead of  git pull
    # because git pull aborts if there are any local file modifications
    # (e.g. a  chmod +x  on install.sh shows up as a diff and blocks the pull).
    # reset --hard discards local changes and brings the tree to exactly
    # what is on GitHub — which is what we want for an install/repair script.
    info "Repo already cloned at $INSTALL_DIR — updating to latest…"
    cd "$INSTALL_DIR"
    if ! git fetch --quiet origin main; then
        die "git fetch failed. Check your internet connection and try again."
    fi
    git reset --hard origin/main
    info "Repo updated to $(git log -1 --format='%h %s')"
else
    # Fresh install — clone into the parent directory.
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

# git clone does not preserve execute bits.
# Fix all .sh files up front so the user never hits "permission denied".
chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true
info "All .sh scripts marked executable"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 — Virtual environment + packages
# ─────────────────────────────────────────────────────────────────────────────
section "5 / 6  Python environment"

# Always wipe and rebuild the venv. A venv created with the wrong Python
# (e.g. 3.14) will fail silently or with cryptic errors. A fresh venv
# also ensures the correct Python binary is baked into the venv's pyvenv.cfg.
if [[ -d "$VENV_DIR" ]]; then
    warn "Removing existing .venv and rebuilding clean…"
    rm -rf "$VENV_DIR"
fi

WANT_VER=$("$PYTHON_BIN" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
"$PYTHON_BIN" -m venv "$VENV_DIR"
info "Created .venv with Python $WANT_VER"

# Activate and upgrade pip quietly
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"
pip install --quiet --upgrade pip
info "pip upgraded"

# Install packages — not quiet so the user sees download progress
# during the ~30-second Playwright wheel install
if ! pip install -r "$INSTALL_DIR/requirements.txt"; then
    die "pip install failed. Check the output above for details."
fi
info "All packages installed"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 6 — Playwright Chromium browser
# ─────────────────────────────────────────────────────────────────────────────
section "6 / 6  Playwright Chromium browser"

echo "  Downloading Chromium (~170 MB) — this takes a minute on first run…"
# Always use the full venv path. On zsh (macOS default), rehashing the command
# cache mid-script is unreliable — the bare  playwright  command may not be
# found even after venv activation. Full path is always correct.
if ! "$VENV_DIR/bin/playwright" install chromium; then
    die "Playwright Chromium install failed. Check the output above for details."
fi
info "Chromium ready"

# ─────────────────────────────────────────────────────────────────────────────
# Scaffold config files (never overwrite existing ones)
# ─────────────────────────────────────────────────────────────────────────────
echo ""

# .env — only scaffold if missing
if [[ ! -f "$INSTALL_DIR/.env" && -f "$INSTALL_DIR/.env.example" ]]; then
    cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
    warn ".env created from .env.example — open it to add credentials (optional)."
fi

# Create session/ and reports/ directories if they don't exist.
# These are gitignored and must be created at install time.
mkdir -p "$INSTALL_DIR/session" "$INSTALL_DIR/reports"
info "session/ and reports/ directories ready"

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
echo "  Next steps:"
echo ""
echo "  1) Move into the project folder:"
echo -e "       ${CYAN}cd $INSTALL_DIR${RESET}"
echo ""
echo "  2) Save your login session (one-time — opens a browser window):"
echo -e "       ${CYAN}./run.sh --save-session${RESET}"
echo ""
echo "  3) Edit your shopping list:"
echo -e "       ${CYAN}./edit.sh${RESET}"
echo ""
echo "  4) Run the bot:"
echo -e "       ${CYAN}./run.sh${RESET}"
echo ""
echo "  Full guide: $INSTALL_DIR/INSTALL.md"
echo ""
