# 📝 Changelog

*Made with ❤️ by Paul Fleury — [@paulfxyz](https://github.com/paulfxyz)*

All notable changes to this project are documented here.
This project follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and [Semantic Versioning](https://semver.org/).

---

## 🔖 [2.0.4] — 2026-03-23

### 🔧 Audit — stale version banners in `install.sh` and `uninstall.sh`

Full cross-file version audit revealed two files that were missed in previous bumps:

- `install.sh` banner still read `v2.0.2` — corrected to `v2.0.4`
- `uninstall.sh` banner still read `CONTINENTE CART BOT — Uninstall` (the old pre-rename branding from v1.x) — corrected to `CONTINENTE HERO — Uninstall  (v2.0.4)`

No functional changes — purely a consistency and branding audit pass.

#### Changes in this patch

- 🏷️ `fix:` `install.sh` — banner version corrected from v2.0.2 → v2.0.4
- 🏷️ `fix:` `uninstall.sh` — banner renamed from `CONTINENTE CART BOT` → `CONTINENTE HERO` + version added
- 🏷️ `bump:` version banners → v2.0.4 in `shop.sh`, `setup.sh`, `update.sh`
- 📖 `docs:` `README.md` — badge + menu display updated to v2.0.4

---

## 🔖 [2.0.3] — 2026-03-23

### ✨ Feature — Option 4 is now a full list management sub-menu

The old Option 4 ("Switch shopping list") was a single flat numbered picker. Useful, but limited: to get to a list you had to already know it existed. There was no way to inspect, add, or organise lists without dropping to the Finder or using a text editor outside the app.

v2.0.3 replaces that single screen with a three-option sub-menu:

```
📂  Manage Shopping Lists

  1)  ✅  Select active list   (choose which list the bot runs)
  2)  📂  Open lists folder    (browse, edit, add or delete lists in Finder)
  3)  ✨  Create new list      (copies current config as a starting point)

  4)  ↩  Back to main menu
```

---

#### Sub-option breakdown

**✅ Select active list** — the picker now shows a `● active` marker next to whichever list is currently selected. If only the default `config.yaml` exists, the picker tells you so and directs you to the other two options instead of presenting a useless one-item list.

**📂 Open lists folder** — runs `open "$CONFIGS_DIR"` (macOS Finder). This is the most requested UX pattern: letting people manage files with the tools they already know. Rename, duplicate, drag in a list from another machine, delete — all without learning any shell commands. If `configs/` is empty, it auto-creates `weekly.yaml` as a sample so Finder doesn't open to a blank folder.

**✨ Create new list** — prompts for a name, sanitises it (strips anything that isn’t alphanumeric, dash, or underscore), copies the current active config as the starting template, and asks whether to activate the new list immediately. This means you can go from zero to a second named list in about 10 seconds without leaving the terminal.

---

#### The symlink design (why config.yaml is always the active file)

This is worth explaining once because it shapes the entire multi-config system.

`continente.py` always reads `config.yaml`. It has no knowledge of `configs/`, list names, or any switching logic. This is intentional: keeping the Python bot simple means the shell layer can evolve independently.

When you switch lists, `shop.sh` does one of two things:
- **Activating a `configs/*.yaml`**: `ln -sf configs/weekly.yaml config.yaml` — config.yaml becomes a symlink pointing into `configs/`.
- **Reverting to the default**: if config.yaml is currently a symlink, it is removed and replaced with a real file (copied from the symlink target), so the default standalone config is restored.

This means:
1. Backups are automatic — all lists live in `configs/`, never overwritten by switching
2. `continente.py` never needs a flag like `--config=weekly.yaml`
3. Finder and any editor work correctly — they follow the symlink transparently

---

#### Bottleneck: symlink vs real-file duality

The tricky edge case was the transition between a symlink `config.yaml` and a real-file `config.yaml`. The first time you ever use multi-config, `config.yaml` is a real file (no symlink). You create `configs/weekly.yaml` as a copy of it, activate `weekly.yaml` — now `config.yaml` is a symlink. If you later revert to "default", we can’t just `rm config.yaml` (that would leave nothing). We also can’t just create a new symlink back to itself. The fix:

```bash
# Before creating the first symlink, always save the real file into configs/
if [[ ! -L "$ACTIVE_CONFIG" ]]; then
    cp "$ACTIVE_CONFIG" "$CONFIGS_DIR/_config_backup.yaml"
fi
ln -sf "$selected_path" "$ACTIVE_CONFIG"
```

And when reverting to the default:
```bash
if [[ -L "$ACTIVE_CONFIG" ]]; then
    backup_src=$(readlink "$ACTIVE_CONFIG")
    rm "$ACTIVE_CONFIG"
    cp "$backup_src" "$ACTIVE_CONFIG"   # materialise back to a real file
fi
```

This ensures config.yaml always exists as a readable file regardless of what state the multi-config system is in.

---

#### Changes in this release

- ✨ `feat:` `shop.sh` — `_switch_list()` replaced by `_manage_lists()` sub-menu with three sub-functions:
  - `_select_list()` — numbered picker with `● active` marker, graceful empty-state message
  - `_open_lists_folder()` — `open "$CONFIGS_DIR"` (Finder), auto-creates `weekly.yaml` sample if empty
  - `_create_list()` — name prompt, sanitisation, copy-from-active, optional immediate activation
- 🏷️ `fix:` main menu label updated: `Switch shopping list` → `Manage shopping lists`
- 🏷️ `bump:` version banners → v2.0.3 in `shop.sh`, `setup.sh`, `update.sh`
- 📖 `docs:` `README.md` — badge v2.0.3, menu block updated, Option 4 section rewritten with sub-menu breakdown and symlink design explanation
- 📖 `docs:` `CHANGELOG.md` — this entry

---

## 🔖 [2.0.2] — 2026-03-23

### 🐛 Critical fix — `greenlet` wheel missing on macOS 26 + Python 3.14 now supported

This patch fixes the installer crash on macOS 26 (Tahoe/Sequoia) — the `cstdlib file not found` compilation error that affected both Python 3.13 and 3.14.

---

#### Root cause

`requirements.txt` previously pinned `playwright==1.44.0`, which resolves `greenlet==3.0.3` as a dependency. `greenlet` is a C extension. When pip cannot find a pre-built wheel for the current OS/Python combination, it falls back to compiling from source.

`greenlet 3.0.3` was released before macOS 26 (Tahoe) existed. Its wheel tag is `macosx_11_0_arm64`, which pip correctly identifies as compatible with newer macOS versions — but the pip wheel resolver on macOS 26 reports the platform tag as `macosx_26_0_arm64`, and the fallback source build fails because Apple's SDK ships without the `<cstdlib>` C++ header that `greenlet` requires:

```
src/greenlet/greenlet.cpp:9:10: fatal error: 'cstdlib' file not found
```

This happened regardless of whether Python 3.13 or 3.14 was used.

#### The fix

Updated `requirements.txt` to `playwright>=1.50.0`. Playwright 1.50+ depends on `greenlet>=3.1.1`, which ships a pre-built `macosx_11_0_universal2` wheel for every Python version including 3.13 and 3.14. Universal2 wheels work on all macOS versions — no compilation, no SDK dependency.

Added `--upgrade` flag to `pip install` in both `setup.sh` and `install.sh` to ensure stale cached wheels are never reused.

#### Python 3.14 now supported

Previous versions blocked Python 3.14 explicitly. With `greenlet 3.3+` having a `cp314-cp314-macosx_11_0_universal2` wheel, Python 3.14 works correctly. The Python version check has been updated to accept 3.11–3.14.

---

#### Changes in this patch

- 🐛 `fix:` `requirements.txt` — `playwright==1.44.0` → `playwright>=1.50.0` (resolves greenlet 3.3+ with universal2 wheels)
- 🐛 `fix:` `setup.sh` — `pip install --upgrade` to bust stale cached wheels
- 🐛 `fix:` `install.sh` — same `pip install --upgrade` fix
- ✅ `feat:` `setup.sh` + `install.sh` — Python 3.14 unblocked, now accepted
- 🐛 `fix:` `setup.sh` — banner version corrected to v2.0.2 (was showing v2.0.1)
- 🐛 `fix:` `install.sh` — banner version corrected to v2.0.2 (was showing v1.2.4)
- 💬 `ux:` `setup.sh` — final output now shows a standalone bold `source ~/.zshrc` command as the required next step, with explanation of why the subshell can’t do it automatically
- 🏷️ `fix:` `shop.sh` + `update.sh` banners updated to v2.0.2
- 📖 `docs:` `README.md` — version badge 2.0.2, Python badge 3.11–3.14, greenlet fix explained, new bottleneck #10 (subshell isolation)
- 📖 `docs:` `INSTALL.md` — header updated to v2.0.2

---

#### Why `shop` wasn’t working after install (subshell isolation)

This is worth explaining because it confused nearly every user.

When the installer runs as `curl URL | bash`, bash is a **child process** of the user’s zsh session. The installer correctly writes `alias shop='...'` to `~/.zshrc`. But then it exits — and with it, its entire environment. The parent zsh never reloads `~/.zshrc` just because a child wrote to it.

This is not a bug. It is a fundamental POSIX rule: **no process can modify the environment of its parent.** macOS, Linux, every Unix system works this way. Even Homebrew can’t work around it — which is why `brew install` also tells you to run `eval "$(brew shellenv)"` after first install.

**The only solutions:**
1. Source the rc file manually: `source ~/.zshrc`
2. Open a new terminal tab (loads rc file on startup)
3. Use the alias-free fallback: `bash ~/continente-hero/shop.sh`

v2.0.2 makes option 1 unmissable — it’s now the first thing you see after a successful install, displayed as a large bold standalone command.

---

## 🔖 [2.0.1] — 2026-03-23

### 🐛 Critical fix — `curl | bash` stdin pipe contamination

This patch resolves the root cause of every installation failure reported since v1.3.0: the `curl -fsSL URL | bash` pipe was being contaminated by stdout output from subprocesses (`brew`, `git`, `pip`, `playwright`), causing bash to interpret tool output as commands.

---

#### The bug — technical explanation

When bash is invoked as `curl URL | bash`, it reads its script from **stdin** — the same file descriptor connected to curl's output. This is how the pipe works: curl writes the script, bash reads it.

The problem is that stdin remains "live" throughout the script's execution. Any child process that writes to **stdout** is writing to the same file descriptor that bash is using to read its next commands. Bash then interprets that output as shell code.

`brew install python@3.13` is a prime offender. It outputs:
- Download progress lines (harmless but noisy)
- Path configuration blocks that look like shell commands
- Lines matching the variable names used in our script (`section`, `REPO_URL`, etc.)

The result was non-deterministic: the installer appeared to succeed but skipped critical steps, or it crashed mid-run with errors like `command not found: section`, or the `shop` alias was never written because the alias-writing block had already been "consumed" from stdin.

#### The fix

Every subprocess that writes to stdout now redirects to stderr:

```bash
brew install python@3.13                     >&2
git clone "$REPO_URL" "$CONTINENTE_DIR"      >&2
git reset --hard origin/main                  >&2
pip install -r requirements.txt               >&2
"$VENV_DIR/bin/playwright" install chromium  >&2
```

Stderr (`>&2`) always flows to the terminal — users still see all output. But it does **not** enter the curl pipe. Stdin stays clean for bash to read the actual script.

---

#### Changes in this patch

- 🐛 `fix:` `brew install python@3.13 >&2` — prevents brew stdout entering curl pipe
- 🐛 `fix:` `git clone ... >&2` — same fix for clone output
- 🐛 `fix:` `git reset --hard ... >&2` — same fix for reset output
- 🐛 `fix:` `pip install ... >&2` — same fix for pip install output
- 🐛 `fix:` `playwright install chromium >&2` — same fix for Chromium download
- 🏷️ `fix:` `shop.sh` version banner updated to `v2.0.1`
- 🏷️ `fix:` `update.sh` version banner updated to `v2.0.1`
- 📖 `docs:` `INSTALL.md` — full rewrite for v2 era: curl installer walkthrough, session deep-dive, `shop` alias setup, troubleshooting table with every known error and fix
- 📖 `docs:` `README.md` — version badge updated to 2.0.1; new “Challenges, bottlenecks & how we solved them” section documenting all 9 technical problems with code examples

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
