#!/usr/bin/env bash
# run.sh — Start the Continente Cart Bot
# Usage:
#   ./run.sh                  # normal headless run
#   ./run.sh --visible        # show browser window
#   ./run.sh --save-session   # one-time manual login to save cookies

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
ACTIVATE="$VENV_DIR/bin/activate"

if [[ ! -f "$ACTIVATE" ]]; then
    echo ""
    echo "  ✗  Virtual environment not found."
    echo "     Run ./install.sh first."
    echo ""
    exit 1
fi

source "$ACTIVATE"

exec python "$SCRIPT_DIR/continente.py" "$@"
