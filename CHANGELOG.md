# 📝 Changelog

*Made with ❤️ by Paul Fleury — [@paulfxyz](https://github.com/paulfxyz)*

All notable changes to this project are documented here.
This project follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and [Semantic Versioning](https://semver.org/).

---

## 🔖 [1.2.2] — 2026-03-23

### 🐛 Hotfix — `install.sh` complete rewrite

**All-in-one, self-healing installer**
- 🔄 `fix:` Stale `.venv` auto-detected and wiped — if the existing environment was built with the wrong Python (e.g. 3.14), it is automatically deleted and rebuilt with the correct interpreter; no manual cleanup needed
- 🍺 `fix:` If no compatible Python is found AND Homebrew is available, the installer now offers to run `brew install python@3.13` interactively — one `y` keypress and it installs Python, then continues setup automatically
- 🚫 `fix:` Python 3.14+ hard-blocked with a clear explanation — "Playwright's greenlet dependency has no pre-built wheel for Python 3.14+"
- 🏷️ `fix:` Banner corrected from "CONTINENTE CART BOT" to "CONTINENTE HERO"
- 🎨 `fix:` Cyan section headers for better terminal readability
- 📋 `fix:` Installer header documents exactly what each step does, safe-to-rerun guarantee, and that session/config files are never touched

---

## 🔖 [1.2.1] — 2026-03-22

### 🐛 Hotfix

**`install.sh` — Python 3.14 compatibility block**
- 🚫 `fix:` Hard-blocked Python 3.14+ with a clear error message and `brew install python@3.13` instructions — Playwright's `greenlet` dependency has no pre-built wheel for 3.14 and the C++ source compilation fails on current macOS toolchains
- 🔍 `fix:` Removed `python3` bare command from the candidate search order — on many macOS setups `python3` resolves to whatever Homebrew last installed, which may be 3.14+; explicit versioned binaries (`python3.13`, `python3.12`, `python3.11`) are now tried first and the bare `python3` is only checked as a last resort (and still subject to the version cap)
- ✅ `fix:` Version check helper now returns a `BLOCKED:<ver>` sentinel so the installer can report the exact blocked version to the user even if it keeps scanning for a valid one
- 📋 `fix:` Updated supported range note in script header: `Python 3.11 – 3.13`
- 🛠️ `fix:` "Next steps" section now says `./edit.sh` instead of `nano config.yaml`

---

## 🔖 [1.2.0] — 2026-03-22

### ✨ Improvements

**README.md + INSTALL.md — full session tutorial**
- 📖 `feat:` Added deep-dive "How the session connection works" section to both docs — explains cookies/tokens concept in plain English
- 🍪 `feat:` Cookie anatomy table added — describes each key cookie (`dwsid`, `dwanonymous`, `dw_*`) and its role
- 🔑 `feat:` Step-by-step `--save-session` walkthrough with exact expected terminal output
- 🔄 `feat:` Flow diagram (ASCII) showing the three-tier credential priority: saved cookies → env vars → config.yaml
- 🔒 `feat:` Security notes section — explains what is and isn't stored, and why session files are gitignored
- ❓ `feat:` FAQ entries added: session expiry, re-authentication, headless vs. visible mode

---

## 🔖 [1.1.0] — 2026-03-22

### ✨ Improvements

**`edit.sh` — new shopping list editor launcher**
- 🛠️ `feat:` Added `edit.sh` — opens `config.yaml` in the best available editor on your Mac
- 🔍 `feat:` Editor priority: VS Code → Cursor → Sublime Text → TextEdit (GUI) → nano (terminal)
- ⚠️ `feat:` TextEdit warning displayed when macOS GUI editor is selected — reminds user to use plain text mode (critical for YAML)
- 📖 `feat:` nano controls cheatsheet printed when terminal fallback is used

**README.md — complete rewrite for clarity**
- 📖 `feat:` Full beginner-friendly walkthrough added (Step 1 → Step 5 with zero assumed knowledge)
- 🧠 `feat:` New "How it works — under the hood" section covering: browser engine, login flow, product resolution strategy, add-to-cart logic, failover guarantee, session persistence, anti-detection approach
- 🛒 `feat:` Full example terminal output added to show exactly what a run looks like
- 📋 `feat:` Shopping list format table expanded with descriptions for each field
- 🔗 `feat:` All GitHub URLs updated from `continente-cart` → `continente-hero`

**Repository**
- 🏷️ `feat:` Renamed from `continente-cart` to `continente-hero`

---

## 🔖 [1.0.0] — 2026-03-22

### 🎉 Initial release

**Core bot (`continente.py`)**
- 🛒 `feat:` Full Playwright (Chromium) automation for continente.pt cart building
- 🔐 `feat:` Three-tier authentication: saved session cookies → env vars → config.yaml
- 🔍 `feat:` Dual product resolution — direct URL (PDP) with search fallback
- 🏷️ `feat:` Brand preference filter on search results with graceful fallback to first result
- 🔢 `feat:` Quantity support — stepper input and + button click strategies
- 🍪 `feat:` Automatic GDPR cookie banner dismissal on first run
- 💾 `feat:` Session persistence — cookies saved and reloaded across runs
- 📄 `feat:` Timestamped run reports saved to `reports/` with four status categories: `added`, `not_found`, `out_of_stock`, `error`
- 🛡️ `feat:` Per-product try/except — no single failure can abort the full run
- 🖥️ `feat:` `--visible` flag to run with browser window open (debug mode)
- 🔑 `feat:` `--save-session` interactive flow — opens browser for manual login, captures and saves cookies
- 🤖 `feat:` Anti-detection: real Chrome UA, `--disable-blink-features=AutomationControlled`, pt-PT locale, Europe/Lisbon timezone

**Config (`config.yaml`)**
- 📝 `feat:` YAML shopping list with `name`, `query`, `quantity`, `url`, `brand` fields
- ✅ `feat:` `headless` and `slow_mo` tunable settings

**Shell scripts**
- 🛠️ `feat:` `install.sh` — one-shot macOS setup: Python version check, venv creation, pip install, Playwright Chromium download
- ▶️ `feat:` `run.sh` — venv-aware launcher, passes all CLI flags through to `continente.py`
- 🔄 `feat:` `update.sh` — git pull + pip upgrade + playwright browser update
- 🗑️ `feat:` `uninstall.sh` — clean teardown of venv, session, reports, and Playwright Chromium cache

**Documentation**
- 📖 `feat:` `README.md` — full project documentation
- 📦 `feat:` `INSTALL.md` — step-by-step installation guide, all auth options, CLI reference, troubleshooting table
- 📝 `feat:` `CHANGELOG.md` — this file

---

*Designed and built in collaboration with [Perplexity Computer](https://www.perplexity.ai/)*
