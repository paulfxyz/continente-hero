# 📝 Changelog

*Made with ❤️ by Paul Fleury — [@paulfxyz](https://github.com/paulfxyz)*

All notable changes to this project are documented here.
This project follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and [Semantic Versioning](https://semver.org/).

---

## 🔖 [2.0.0] — 2026-03-23

### 🚀 Major release — interactive menu, multi-config, shell alias

This release introduces a complete workflow overhaul. The primary way to use continente-hero is now the `shop` command — a single alias that opens an interactive menu covering every operation.

---

#### `shop.sh` — new interactive menu launcher

- 🎛️ `feat:` New `shop.sh` — interactive TUI menu with 6 options:
  - **1) Fill my cart** — runs the bot, offers visible/headless choice
  - **2) Save / refresh session** — guided browser login flow
  - **3) Edit shopping list** — opens in best available editor (VS Code → Cursor → Sublime → TextEdit → nano)
  - **4) Switch shopping list** — multi-config management (see below)
  - **5) Update continente-hero** — pulls latest code + refreshes dependencies
  - **6) Quit**
- 🗂️ `feat:` **Multi-config support** — maintain multiple `.yaml` shopping lists in a `configs/` folder, switch between them from the menu. Active list is always `config.yaml`
- 🏷️ `feat:` Active list name shown at the top of every menu screen
- 🏗️ `feat:` Create new lists from within the menu — copies current config as a starting point
- 🛡️ `feat:` venv guard at startup — prints the curl install command if the venv doesn't exist yet
- 🔄 `feat:` Update option uses `git reset --hard origin/main` — never fails due to local modifications

---

#### `setup.sh` — curl installer now fully automatic

- 🤖 `feat:` Python 3.13 is now **installed automatically via Homebrew** when missing — no prompt, no manual step, works when piped through `curl | bash`
- 🏷️ `feat:` Shell alias `shop` registered in `~/.zshrc` (or `~/.bashrc`) automatically during install
- 🔄 `feat:` Alias update logic — if `shop` alias already exists, it is updated in-place (handles re-installs to a different path)
- 📌 `feat:` Version bumped to v2.0 in the banner

---

#### `update.sh` — rewritten

- 🔄 `fix:` Replaced `git pull` with `git fetch + git reset --hard origin/main` — `git pull` aborts when local files have been modified (e.g. by `chmod +x`); `reset --hard` always succeeds
- 📦 `fix:` Playwright updated using `$VENV_DIR/bin/playwright` full path — the bare `playwright` command is unreliable in zsh after venv activation
- 🏷️ `fix:` Banner updated from "CONTINENTE CART BOT" to "CONTINENTE HERO"

---

#### `README.md` — complete v2 rewrite

- 🚀 `feat:` `shop` alias documented as the primary entry point
- 🗂️ `feat:` Multi-config usage guide — `configs/` folder, switching, creating new lists
- 🔐 `feat:` Session connection deep-dive — cookie anatomy table, full flow diagram, security notes
- ⚠️ `feat:` Python 3.14 incompatibility explained with the exact compiler error
- 🛠️ `feat:` Full "how it works" section — browser engine, product resolution strategy, failover guarantee, run report format
- 🏷️ `feat:` Version badge updated to 2.0.0, links to GitHub Releases

---

## 🔖 [1.4.0] — 2026-03-23

### ✨ setup.sh — curl installer improvements

- 🤖 `feat:` Python 3.13 installation is now attempted automatically (not just when stdin is a terminal)
- 🏷️ `feat:` Shell alias `shop` registered during install
- 📌 `feat:` Version bumped to v1.4.0

---

## 🔖 [1.3.0] — 2026-03-23

### ✨ New — curl one-liner installer

**`setup.sh` — new curl-based installer (zero prior clone required)**
- 🚀 `feat:` Added `setup.sh` — full installation from one curl command
- 📁 `feat:` Auto-clones the repo to `~/continente-hero` on first run
- 🔄 `feat:` Uses `git fetch + git reset --hard origin/main` to bypass local-change conflicts
- 🛡️ `feat:` Explicit guards on `git clone`, `pip install`, and `playwright install chromium`
- 🪤 `feat:` `trap EXIT` handler — prints exit code and debug instructions on failure
- 📂 `feat:` `CONTINENTE_DIR` env var override for custom install path

---

## 🔖 [1.2.4] — 2026-03-23

### 🐛 Hotfix — shell compatibility bugs

- 🐛 `fix:` `${answer,,}` bash-only lowercase expansion replaced with explicit comparison
- 📂 `fix:` `SCRIPT_DIR` double-nesting bug — `${BASH_SOURCE[0]:-$0}` fallback added
- 📌 `fix:` Version bumped to v1.2.4

---

## 🔖 [1.2.3] — 2026-03-23

### 🐛 Hotfix

- 🛡️ `fix:` All `.sh` scripts `chmod +x`'d at install start — fresh git clone strips execute bits
- 📦 `fix:` Playwright installed using `$VENV_DIR/bin/playwright` full path

---

## 🔖 [1.2.2] — 2026-03-23

### 🐛 `install.sh` — full rewrite

- 🗑️ `fix:` `.venv` always wiped and rebuilt clean on every run
- 🍺 `fix:` Auto-brew python@3.13 offered interactively if no compatible Python found
- 🛇 `fix:` Python version parsing rewritten to use `print(v.major, v.minor)` (space-separated integers)
- 🏷️ `fix:` Banner corrected from "CONTINENTE CART BOT" to "CONTINENTE HERO"

---

## 🔖 [1.2.1] — 2026-03-22

### 🐛 Hotfix

- 🚫 `fix:` Hard-blocked Python 3.14+ with a clear error message
- 🔍 `fix:` Versioned binaries tried before bare `python3`

---

## 🔖 [1.2.0] — 2026-03-22

### ✨ Session tutorial

- 📖 `feat:` Full "how the session connection works" section in README and INSTALL.md
- 🍪 `feat:` Cookie anatomy table — `dwsid`, `dwanonymous`, `dw_*`
- 🔄 `feat:` Three-tier credential priority diagram
- 🔒 `feat:` Security notes — what is and isn't stored

---

## 🔖 [1.1.0] — 2026-03-22

### ✨ Improvements

- 🛠️ `feat:` Added `edit.sh` — opens config in best available editor
- 📖 `feat:` README full beginner-friendly rewrite
- 🏷️ `feat:` Renamed repo from `continente-cart` to `continente-hero`

---

## 🔖 [1.0.0] — 2026-03-22

### 🎉 Initial release

- 🛒 `feat:` Full Playwright (Chromium) automation for continente.pt cart building
- 🔐 `feat:` Three-tier authentication: saved cookies → env vars → config.yaml
- 🔍 `feat:` Dual product resolution — direct URL + search with brand filter
- 🛡️ `feat:` Per-product try/except — no single failure aborts the full run
- 📄 `feat:` Timestamped run reports saved to `reports/`
- 💾 `feat:` Session persistence via `session/cookies.json`
- 🖥️ `feat:` `--visible` and `--save-session` CLI flags
- 🤖 `feat:` Anti-detection: real Chrome UA, `--disable-blink-features=AutomationControlled`

---

*Designed and built in collaboration with [Perplexity Computer](https://www.perplexity.ai/)*
