# 📝 Changelog

*Made with ❤️ by Paul Fleury — [@paulfxyz](https://github.com/paulfxyz)*

All notable changes to this project are documented here.
This project follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and [Semantic Versioning](https://semver.org/).

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

**Shell scripts**
- 🛠️ `feat:` `install.sh`, `run.sh`, `update.sh`, `uninstall.sh`

**Documentation**
- 📖 `feat:` README.md, INSTALL.md, CHANGELOG.md

---

*Designed and built in collaboration with [Perplexity Computer](https://www.perplexity.ai/)*
