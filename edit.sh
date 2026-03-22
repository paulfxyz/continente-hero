#!/usr/bin/env bash
# edit.sh — Open your shopping list in a text editor
#
# Opens config.yaml in the best available editor on your Mac.
# Priority: VS Code → Cursor → Sublime Text → TextEdit (GUI) → nano (terminal)
#
# Usage: ./edit.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/config.yaml"

if [[ ! -f "$CONFIG" ]]; then
    echo ""
    echo "  ✗  config.yaml not found."
    echo "     Run ./install.sh first to set up the project."
    echo ""
    exit 1
fi

echo ""
echo "  Opening your shopping list: config.yaml"
echo ""

# VS Code
if command -v code &>/dev/null; then
    echo "  → Opening in Visual Studio Code…"
    code "$CONFIG"
    exit 0
fi

# Cursor
if command -v cursor &>/dev/null; then
    echo "  → Opening in Cursor…"
    cursor "$CONFIG"
    exit 0
fi

# Sublime Text
if command -v subl &>/dev/null; then
    echo "  → Opening in Sublime Text…"
    subl "$CONFIG"
    exit 0
fi

# TextEdit (macOS native — always available)
if [[  "$(uname)" == "Darwin" ]]; then
    echo "  → Opening in TextEdit (macOS)…"
    echo ""
    echo "  ┌─────────────────────────────────────────────────────────────────┐"
    echo "  │  ⚠️  IMPORTANT: TextEdit may open in Rich Text mode.             │"
    echo "  │                                                                 │"
    echo "  │  If you see formatting controls (bold, italic, font picker):    │"
    echo "  │  → Go to Format menu → click \"Make Plain Text\"                  │"
    echo "  │  → Then edit and save normally.                                 │"
    echo "  │                                                                 │"
    echo "  │  YAML files MUST be saved as plain text, not rich text.         │"
    echo "  └─────────────────────────────────────────────────────────────────┘"
    echo ""
    open -a TextEdit "$CONFIG"
    exit 0
fi

# nano (terminal fallback — always available on macOS)
echo "  → Opening in nano (terminal editor)…"
echo ""
echo "  nano controls:"
echo "    Ctrl+O  → Save"
echo "    Ctrl+X  → Exit"
echo "    Ctrl+K  → Cut line"
echo "    Ctrl+U  → Paste line"
echo ""
sleep 1
nano "$CONFIG"
