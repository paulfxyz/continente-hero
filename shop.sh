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
#    4) Manage shopping lists — sub-menu:
#         a) Select active list  — pick which list the bot runs
#         b) Open lists folder   — opens configs/ in Finder so you can edit/add/remove files
#         c) Create new list     — copies current config as a starting point
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
        echo "config.yaml"
    fi
}

# ── Draw the menu ─────────────────────────────────────────────────────────────
_draw_menu() {
    clear 2>/dev/null || echo ""

    echo ""
    echo -e "${BOLD}${CYAN}  ╔══════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}  ║   🦸  continente-hero  ·  v2.0.4                 ║${RESET}"
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
    echo -e "  ${BOLD}${GREEN}4)${RESET}  📂  Manage shopping lists    ${DIM}(select, browse, create)${RESET}"
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

# ── Option 4 — Manage shopping lists (sub-menu) ──────────────────────────────
#
#  This replaces the old single-screen switch. It now has three sub-options:
#
#    a) Select active list  — numbered picker, sets which list the bot uses
#    b) Open lists folder   — opens configs/ in Finder (macOS) so you can
#                             browse, rename, duplicate, or delete .yaml files
#                             outside the terminal
#    c) Create new list     — prompts for a name, copies current config as base
#
#  The active list is always config.yaml (or a symlink pointing to a file in
#  configs/). This design means continente.py never needs to know about the
#  multi-config system — it always reads config.yaml.

# ── 4a — Select which list is active ─────────────────────────────────────────
_select_list() {
    echo ""
    echo -e "${BOLD}${CYAN}  ✅  Select Active List${RESET}"
    echo ""
    echo -e "  ${DIM}The bot always runs whichever list is marked  ${GREEN}● active${RESET}${DIM}.${RESET}"
    echo ""

    # Ensure configs/ exists
    mkdir -p "$CONFIGS_DIR"

    # Collect all .yaml files in configs/
    local yaml_files=()
    while IFS= read -r -d '' f; do
        yaml_files+=("$f")
    done < <(find "$CONFIGS_DIR" -maxdepth 1 -name "*.yaml" -print0 2>/dev/null | sort -z)

    # Build display list: config.yaml (default) first, then configs/*.yaml
    local display_paths=()
    local display_labels=()

    # Determine what config.yaml currently points to (if symlink)
    local active_target
    if [[ -L "$ACTIVE_CONFIG" ]]; then
        active_target=$(readlink "$ACTIVE_CONFIG")
    else
        active_target="$ACTIVE_CONFIG"
    fi

    # Always include the standalone config.yaml as option 1
    display_paths+=("$ACTIVE_CONFIG")
    local marker_default=""
    if [[ "$active_target" == "$ACTIVE_CONFIG" ]]; then
        marker_default="  ${GREEN}● active${RESET}"
    fi
    display_labels+=("config.yaml  ${DIM}(default)${RESET}$marker_default")

    # Add each file from configs/
    for f in "${yaml_files[@]}"; do
        local fname
        fname=$(basename "$f")
        local marker=""
        if [[ "$active_target" == "$f" ]]; then
            marker="  ${GREEN}● active${RESET}"
        fi
        display_paths+=("$f")
        display_labels+=("$fname$marker")
    done

    if [[ ${#display_paths[@]} -eq 1 ]]; then
        # Only the default config exists — nothing to switch to
        echo "  Only one list exists right now: ${BOLD}config.yaml${RESET}"
        echo ""
        echo -e "  ${DIM}Use  📂 Open lists folder  to add more .yaml files,"
        echo -e "  or  ✨ Create new list  to make one from scratch.${RESET}"
        echo ""
        printf "  Press Enter to go back…"
        read -r </dev/tty
        return
    fi

    # Print numbered list
    local total=${#display_paths[@]}
    for (( i=0; i<total; i++ )); do
        echo -e "  ${BOLD}${GREEN}$(( i+1 )))${RESET}  ${display_labels[$i]}"
    done
    echo ""
    echo -e "  ${BOLD}${RED}$(( total+1 )))${RESET}  Back"
    echo ""

    printf "  Choose [1–$(( total+1 ))] → "
    read -r choice </dev/tty
    echo ""

    # Validate
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt $(( total+1 )) ]]; then
        warn "Invalid choice."
        printf "  Press Enter to go back…"
        read -r </dev/tty
        return
    fi

    [[ "$choice" -eq $(( total+1 )) ]] && return  # Back

    local selected_path="${display_paths[$(( choice-1 ))]}"

    if [[ "$selected_path" == "$ACTIVE_CONFIG" ]]; then
        # User picked option 1 — the standalone config.yaml
        if [[ -L "$ACTIVE_CONFIG" ]]; then
            # Currently a symlink → materialise it back to a real file
            local backup_src
            backup_src=$(readlink "$ACTIVE_CONFIG")
            rm "$ACTIVE_CONFIG"
            cp "$backup_src" "$ACTIVE_CONFIG"
            info "Switched to standalone config.yaml"
        else
            info "config.yaml is already the active list — nothing to change"
        fi
    else
        # Point config.yaml at the chosen file via symlink
        # If config.yaml is currently a real file (not a symlink), back it up first
        if [[ ! -L "$ACTIVE_CONFIG" ]]; then
            cp "$ACTIVE_CONFIG" "$CONFIGS_DIR/_config_backup.yaml"
        fi
        ln -sf "$selected_path" "$ACTIVE_CONFIG"
        info "Active list → ${BOLD}$(basename "$selected_path")${RESET}"
        echo ""
        echo -e "  ${DIM}The bot will use this list next time you run option 1.${RESET}"
    fi

    echo ""
    printf "  Press Enter to go back…"
    read -r </dev/tty
}

# ── 4b — Open configs folder in Finder ───────────────────────────────────────
#
#  Opens the configs/ directory in macOS Finder. This lets the user:
#    - See all their .yaml files
#    - Rename, duplicate, or delete lists using normal file operations
#    - Open any list in their preferred editor by double-clicking
#    - Drag in new .yaml files from elsewhere
#
#  Falls back to revealing the path in the terminal if `open` is unavailable.
_open_lists_folder() {
    echo ""
    echo -e "${BOLD}${CYAN}  📂  Open Lists Folder${RESET}"
    echo ""

    # Ensure the folder exists before we try to open it
    mkdir -p "$CONFIGS_DIR"

    # Create a sample list if the folder is empty, so Finder isn't blank
    if [[ -z "$(ls -A "$CONFIGS_DIR" 2>/dev/null)" ]]; then
        cp "$ACTIVE_CONFIG" "$CONFIGS_DIR/weekly.yaml"
        info "Created a sample list: configs/weekly.yaml"
        echo -e "  ${DIM}(copied from your current config as a starting point)${RESET}"
        echo ""
    fi

    echo "  Opening: ${BOLD}$CONFIGS_DIR${RESET}"
    echo ""
    echo -e "  ${DIM}Add, rename, or delete .yaml files there."
    echo -e "  Each file becomes a selectable list in this menu.${RESET}"
    echo ""

    if command -v open &>/dev/null; then
        # macOS: open in Finder
        open "$CONFIGS_DIR"
        info "Folder opened in Finder"
    else
        warn "'open' not available — navigate here manually:"
        echo ""
        echo "    $CONFIGS_DIR"
    fi

    echo ""
    printf "  Press Enter to go back…"
    read -r </dev/tty
}

# ── 4c — Create a new list ────────────────────────────────────────────────────
_create_list() {
    echo ""
    echo -e "${BOLD}${CYAN}  ✨  Create New List${RESET}"
    echo ""
    echo "  Enter a name for the new list (without .yaml)."
    echo -e "  ${DIM}Examples: weekly, party, pantry, bulk${RESET}"
    echo ""
    printf "  Name → "
    read -r new_name </dev/tty
    echo ""

    if [[ -z "$new_name" ]]; then
        warn "Name cannot be empty."
        printf "  Press Enter to go back…"
        read -r </dev/tty
        return
    fi

    # Strip anything that isn't alphanumeric, dash, or underscore
    new_name=$(echo "$new_name" | tr -cd '[:alnum:]_-')

    if [[ -z "$new_name" ]]; then
        warn "Name contained no valid characters. Use letters, numbers, - or _."
        printf "  Press Enter to go back…"
        read -r </dev/tty
        return
    fi

    mkdir -p "$CONFIGS_DIR"
    local new_file="$CONFIGS_DIR/$new_name.yaml"

    if [[ -f "$new_file" ]]; then
        warn "configs/$new_name.yaml already exists."
        echo ""
        echo "  Use  ✅ Select active list  to switch to it."
    else
        # Copy current active config as the starting point
        cp "$ACTIVE_CONFIG" "$new_file"
        info "Created ${BOLD}configs/$new_name.yaml${RESET}"
        echo ""
        echo -e "  ${DIM}It's a copy of your current list — edit it in Finder"
        echo -e "  or use  ✏️  Edit shopping list  after activating it.${RESET}"
        echo ""

        # Ask if user wants to activate it now
        printf "  Activate this list now? [Y/n] → "
        read -r activate </dev/tty
        echo ""
        if [[ "$activate" != "n" && "$activate" != "N" ]]; then
            if [[ ! -L "$ACTIVE_CONFIG" ]]; then
                cp "$ACTIVE_CONFIG" "$CONFIGS_DIR/_config_backup.yaml"
            fi
            ln -sf "$new_file" "$ACTIVE_CONFIG"
            info "Active list → ${BOLD}$new_name.yaml${RESET}"
        fi
    fi

    echo ""
    printf "  Press Enter to go back…"
    read -r </dev/tty
}

# ── Option 4 — Manage lists (sub-menu) ───────────────────────────────────────
_manage_lists() {
    while true; do
        clear 2>/dev/null || echo ""
        echo ""
        echo -e "${BOLD}${CYAN}  📂  Manage Shopping Lists${RESET}"
        echo ""

        # Show current active list at the top
        local active
        active=$(_active_config_name)
        echo -e "  ${DIM}Active list:${RESET} ${BOLD}$active${RESET}"
        echo ""
        hr
        echo ""

        echo -e "  ${BOLD}${GREEN}1)${RESET}  ✅  Select active list   ${DIM}(choose which list the bot runs)${RESET}"
        echo -e "  ${BOLD}${GREEN}2)${RESET}  📂  Open lists folder    ${DIM}(browse, edit, add or delete lists in Finder)${RESET}"
        echo -e "  ${BOLD}${GREEN}3)${RESET}  ✨  Create new list      ${DIM}(copies current config as a starting point)${RESET}"
        echo ""
        echo -e "  ${BOLD}${RED}4)${RESET}  ↩  Back to main menu"
        echo ""
        hr
        echo ""

        printf "  Choose [1–4] → "
        read -r sub_choice </dev/tty
        echo ""

        case "$sub_choice" in
            1) _select_list    ;;
            2) _open_lists_folder ;;
            3) _create_list    ;;
            4|b|B|q|Q) return  ;;
            *)
                warn "Enter 1, 2, 3, or 4."
                sleep 1
                ;;
        esac
    done
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
        4) _manage_lists   ;;
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
