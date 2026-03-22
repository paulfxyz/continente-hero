# 📝 Changelog

*Made with ❤️ by Paul Fleury — [@paulfxyz](https://github.com/paulfxyz)*

All notable changes to this project are documented here.
This project follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and [Semantic Versioning](https://semver.org/).

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
- 📖 `feat:` `README.md` — full project documentation with quick start, shopping list format, report sample, how-it-works deep dive
- 📦 `feat:` `INSTALL.md` — step-by-step installation guide, all auth options, CLI reference, troubleshooting table
- 📝 `feat:` `CHANGELOG.md` — this file

---

*Designed and built in collaboration with [Perplexity Computer](https://www.perplexity.ai/)*
