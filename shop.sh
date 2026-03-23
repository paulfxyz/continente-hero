#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  shop.sh — continente-hero  |  Interactive menu launcher
# ─────────────────────────────────────────────────────────────────────────────
#
#  Usage:
#    ./shop.sh              # interactive menu
#    shop                   # same, via shell alias (registered by setup.sh)
#
#  Menu options:
#    1) Run the bot         — fills your cart using the active shopping list
#    2) Save / refresh session — opens a browser so you can log in once
#    3) Edit shopping list  — opens config in the best available editor
#    4) Switch shopping list — pick from multiple saved config files
#    5) Update continente-hero — pull latest code + refresh all dependencies
#    6) Quit
#
#  Multi-config support:
#    Save any number of .yaml files in the configs/ directory.
#    The active config is always config.yaml (shop.sh manages the symlink/copy).
#    Naming convention: configs/groceries.yaml, configs/party.yaml, etc.
#
#  The  shop  alias is registered to your ~/.zshrc (or ~/.bashrc) by setup.sh.
#  To add it manually:
#    alias shop='bash ~/continente-hero/shop.sh'
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

# ── Resolve paths ─────────────────────────────────────────────────────────────
_src="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$_src")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
CONFIGS_DIR="$SCRIPT_DIR/configs"
ACTIVE_CONFIG="$SCRIPT_DIR/config.yaml"

# ── Colours ───────────────────────────────────────────────────────────────────
BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
BLUE="\033[0;34m"
RESET="\033[0m"

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET}   $*"; }
err()     { echo -e "  ${RED}✗${RESET}  $*" >&2; }
hr()      { echo -e "${DIM}──────────────────────────────────────────────────────${RESET}"; }

# ── Guard: venv must exist ────────────────────────────────────────────────────
if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
    echo ""
    err "Not installed yet. Run the installer first:"
    echo ""
    echo -e "    ${CYAN}curl -fsSL https://raw.githubusercontent.com/paulfxyz/continente-hero/main/setup.sh | bash${RESET}"
    echo ""
    exit 1
fi

# ── Source venv (so we can call python and playwright directly) ───────────────
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"

# ── Get active config name (for display) ─────────────────────────────────────
_active_config_name() {
    # If config.yaml is a symlink, show the target name.
    # Otherwise show "config.yaml".
    if [[ -L "$ACTIVE_CONFIG" ]]; then
        basename "$(readlink "$ACTIVE_CONFIG")"
    else
        "config.yaml"
    fi
}

# ── Draw the menu ─────────────────────────────────────────────────────────────
_draw_menu() {
    clear 2>/dev/null || echo ""

    echo ""
    echo -e "${BOLD}${CYAN}  ╔══════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}  ║   🦸  continente-hero  ·  v2.0.1                 ║${RESET}"
    echo -e "${BOLD}${CYAN}  ╚══════════════════════════════════════════════════╝${RESET}"
    echo ""

    # Show active config
    local active
    active=$(_active_config_name)
    echo -e "  ${DIM}Active list: ${RESET}${BOLD}$active${RESET}"
    echo ""
    hr

    echo -e "  ${BOLD}${GREEN}1)${RESET}  🛒  Fill my cart              ${DIM}(run the bot)${RESET}"
    echo -e "  ${BOLD}${GREEN}2)${RESET}  🔐  Save / refresh session    ${DIM}(log in once)${RESET}"
    echo -e "  ${BOLD}${GREEN}3)${RESET}  ✏️   Edit shopping list        ${DIM}(opens editor)${RESET}"
    echo -e "  ${BOLD}${GREEN}4)${RESET}  📂  Switch shopping list      ${DIM}(multi-config)${RESET}"
    echo -e "  ${BOLD}${GREEN}5)${RESET}  🔄  Update continente-hero    ${DIM}(pull latest)${RESET}"
    echo -e "  ${BOLD}${RED}6)${RESET}  👋  Quit"
    echo ""
    hr
    echo ""
}

# ── Option 1 — Run the bot ────────────────────────────────────────────────────
_run_bot() {
    echo ""
    echo -e "${BOLD}${CYAN}  🛒  Filling your cart…${RESET}"
    echo ""

    # Offer visible mode
    printf "  Run with browser window visible? [y/N] → "
    read -r vis </dev/tty
    echo ""

    local flags=""
    if [[ "$vis" == "y" || "$vis" == "Y" ]]; then
        flags="--visible"
    fi

    echo -e "  ${DIM}Press Ctrl+C to stop at any time.${RESET}"
    echo ""
    hr
    echo ""

    # Run and capture exit code — never let a failure abort the menu
    python "$SCRIPT_DIR/continente.py" $flags || {
        echo ""
        warn "The bot exited with an error. Check the output above."
        echo ""
    }

    echo ""
    echo -e "  ${DIM}Done. Reports are saved in ${BOLD}reports/${RESET}${DIM}.${RESET}"
    echo ""
    printf "  Press Enter to return to the menu…"
    read -r </dev/tty
}

# ── Option 2 — Save / refresh session ────────────────────────────────────────
_save_session() {
    echo ""
    echo -e "${BOLD}${CYAN}  🔐  Save / Refresh Session${RESET}"
    echo ""
    echo "  A browser window will open on the Continente login page."
    echo "  Log in with your account — the bot only watches, it never"
    echo "  types your password for you."
    echo ""
    echo "  Once you see your account homepage, come back here and"
    echo "  press Enter. Your session will be saved for future runs."
    echo ""
    printf "  Ready? Press Enter to open the browser…"
    read -r </dev/tty
    echo ""

    python "$SCRIPT_DIR/continente.py" --save-session || {
        echo ""
        warn "Session save encountered an error. Check the output above."
        echo ""
    }

    echo ""
    printf "  Press Enter to return to the menu…"
    read -r </dev/tty
}

# ── Option 3 — Edit shopping list ────────────────────────────────────────────
_edit_list() {
    echo ""
    echo -e "${BOLD}${CYAN}  ✏️   Edit Shopping List${RESET}"
    echo ""

    # Try editors in priority order
    local opened=0
    for editor_cmd in \
        "code $ACTIVE_CONFIG" \
        "cursor $ACTIVE_CONFIG" \
        "subl $ACTIVE_CONFIG" \
        "open -a TextEdit $ACTIVE_CONFIG" \
        "nano $ACTIVE_CONFIG"; do

        local cmd
        cmd=$(echo "$editor_cmd" | awk '{print $1}')
        if command -v "$cmd" &>/dev/null; then
            info "Opening in: $cmd"
            echo ""

            # TextEdit warning — it can silently corrupt YAML by curling quotes
            if [[ "$cmd" == "open" ]]; then
                warn "TextEdit is a rich-text editor. Before editing, go to:"
                echo "         Format → Make Plain Text"
                echo "         (otherwise it will corrupt your YAML)"
                echo ""
            fi

            if [[ "$cmd" == "nano" ]]; then
                echo -e "  ${DIM}nano controls:  Ctrl+O save  ·  Ctrl+X exit  ·  Ctrl+G help${RESET}"
                echo ""
            fi

            eval "$editor_cmd"
            opened=1
            break
        fi
    done

    if [[ $opened -eq 0 ]]; then
        warn "No editor found. Edit this file manually:"
        echo ""
        echo "    $ACTIVE_CONFIG"
        echo ""
    fi

    echo ""
    printf "  Press Enter to return to the menu…"
    read -r </dev/tty
}

# ── Option 4 — Switch shopping list ──────────────────────────────────────────
_switch_list() {
    echo ""
    echo -e "${BOLD}${CYAN}  📂  Switch Shopping List${RESET}"
    echo ""

    # Ensure configs/ directory exists
    mkdir -p "$CONFIGS_DIR"

    # Collect available configs: all .yaml files in configs/ + config.yaml itself
    local configs=()

    # Main config always first
    configs+=("config.yaml  ${DIM}(current)${RESET}")

    # Scan configs/ directory
    local yaml_files=()
    while IFS= read -r -d '' f; do
        yaml_files+=("$f")
    done < <(find "$CONFIGS_DIR" -maxdepth 1 -name "*.yaml" -print0 2>/dev/null | sort -z)

    if [[ ${#yaml_files[@]} -eq 0 ]]; then
        echo "  No extra configs found in ${BOLD}configs/${RESET} yet."
        echo ""
        echo "  To create a new shopping list:"
        echo "    1) Copy your current config:  cp config.yaml configs/weekly.yaml"
        echo "    2) Edit it:                   nano configs/weekly.yaml"
        echo "    3) Come back here to switch to it"
        echo ""
        printf "  Press Enter to return to the menu…"
        read -r </dev/tty
        return
    fi

    # List the found configs
    echo "  Available lists:"
    echo ""
    local i=1
    local display_names=()

    # Current config.yaml always option 1
    echo -e "  ${BOLD}${GREEN}1)${RESET}  config.yaml  ${DIM}(default)${RESET}"
    display_names+=("$ACTIVE_CONFIG")
    i=2

    for f in "${yaml_files[@]}"; do
        local fname
        fname=$(basename "$f")
        # Mark currently active symlink target
        local marker=""
        if [[ -L "$ACTIVE_CONFIG" && "$(readlink "$ACTIVE_CONFIG")" == "$f" ]]; then
            marker="  ${GREEN}← active${RESET}"
        fi
        echo -e "  ${BOLD}${GREEN}$i)${RESET}  $fname$marker"
        display_names+=("$f")
        (( i++ ))
    done

    echo ""
    echo -e "  ${BOLD}${GREEN}$i)${RESET}  ${DIM}Create a new list${RESET}"
    local new_option=$i
    (( i++ ))
    echo -e "  ${BOLD}${RED}$i)${RESET}  Back"
    echo ""

    printf "  Choose [1–$i] → "
    read -r choice </dev/tty
    echo ""

    # Validate input
    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        warn "Invalid choice."
        printf "  Press Enter to return to the menu…"
        read -r </dev/tty
        return
    fi

    if [[ "$choice" -eq $i ]]; then
        return  # Back
    fi

    if [[ "$choice" -eq $new_option ]]; then
        # Create new config
        echo -e "  ${BOLD}New list name${RESET} (without .yaml, e.g. 'weekly' or 'party'):"
        printf "  → "
        read -r new_name </dev/tty
        echo ""

        if [[ -z "$new_name" ]]; then
            warn "Name cannot be empty."
            printf "  Press Enter to return to the menu…"
            read -r </dev/tty
            return
        fi

        # Sanitise — only alphanumeric, dash, underscore
        new_name=$(echo "$new_name" | tr -cd '[:alnum:]_-')
        local new_file="$CONFIGS_DIR/$new_name.yaml"

        if [[ -f "$new_file" ]]; then
            warn "$new_name.yaml already exists."
        else
            cp "$ACTIVE_CONFIG" "$new_file"
            info "Created configs/$new_name.yaml (copied from current config)"
            echo ""
            echo "  Edit it now, then use this menu option again to activate it."
        fi
        printf "  Press Enter to return to the menu…"
        read -r </dev/tty
        return
    fi

    # Activate selected config
    local idx=$(( choice - 1 ))
    if [[ $idx -lt 0 || $idx -ge ${#display_names[@]} ]]; then
        warn "Invalid choice."
        printf "  Press Enter to return to the menu…"
        read -r </dev/tty
        return
    fi

    local selected="${display_names[$idx]}"

    if [[ "$selected" == "$ACTIVE_CONFIG" ]]; then
        # Option 1 — revert to default config.yaml (remove symlink if exists)
        if [[ -L "$ACTIVE_CONFIG" ]]; then
            local backup
            backup=$(readlink "$ACTIVE_CONFIG")
            rm "$ACTIVE_CONFIG"
            cp "$backup" "$ACTIVE_CONFIG"
            info "Reverted to standalone config.yaml"
        else
            info "config.yaml is already the active (standalone) config"
        fi
    else
        # Replace config.yaml with a symlink to the selected file
        # Preserve the original config.yaml content if it's not already a symlink
        if [[ ! -L "$ACTIVE_CONFIG" && ! -f "$CONFIGS_DIR/config.yaml.bak" ]]; then
            cp "$ACTIVE_CONFIG" "$CONFIGS_DIR/config.yaml.bak"
        fi
        ln -sf "$selected" "$ACTIVE_CONFIG"
        info "Switched active list → $(basename "$selected")"
    fi

    echo ""
    printf "  Press Enter to return to the menu…"
    read -r </dev/tty
}

# ── Option 5 — Update ─────────────────────────────────────────────────────────
_update() {
    echo ""
    echo -e "${BOLD}${CYAN}  🔄  Updating continente-hero…${RESET}"
    echo ""

    # Pull latest code via reset --hard (avoids git pull conflicts)
    if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
        echo -e "  ${DIM}Fetching latest from GitHub…${RESET}"
        if git -C "$SCRIPT_DIR" fetch --quiet origin main; then
            git -C "$SCRIPT_DIR" reset --hard origin/main
            info "Code updated to $(git -C "$SCRIPT_DIR" log -1 --format='%h %s')"
        else
            warn "Could not reach GitHub. Check your internet connection."
        fi
    else
        warn "Not a git repo — skipping code update."
    fi

    echo ""
    echo -e "  ${DIM}Refreshing Python packages…${RESET}"
    pip install --quiet --upgrade pip
    pip install --quiet --upgrade -r "$SCRIPT_DIR/requirements.txt"
    info "Python packages up to date"

    echo ""
    echo -e "  ${DIM}Updating Playwright Chromium…${RESET}"
    "$VENV_DIR/bin/playwright" install chromium
    info "Chromium up to date"

    echo ""
    # Re-chmod in case new .sh files were added
    chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true
    info "Permissions refreshed"

    echo ""
    printf "  Press Enter to return to the menu…"
    read -r </dev/tty
}

# ── Main loop ─────────────────────────────────────────────────────────────────
while true; do
    _draw_menu

    printf "  Choose [1–6] → "
    read -r choice </dev/tty
    echo ""

    case "$choice" in
        1) _run_bot        ;;
        2) _save_session   ;;
        3) _edit_list      ;;
        4) _switch_list    ;;
        5) _update         ;;
        6|q|Q|quit|exit)
            echo ""
            echo -e "  ${DIM}Later. 👋${RESET}"
            echo ""
            exit 0
            ;;
        *)
            warn "Invalid choice — enter a number from 1 to 6."
            sleep 1
            ;;
    esac
done
