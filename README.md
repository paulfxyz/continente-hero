# 🦸 continente-hero

[![Version](https://img.shields.io/badge/Version-2.0.0-brightgreen?style=for-the-badge)](https://github.com/paulfxyz/continente-hero/releases/latest)
[![Python](https://img.shields.io/badge/Python-3.11--3.13-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![Playwright](https://img.shields.io/badge/Playwright-Chromium-45ba4b?style=for-the-badge&logo=playwright&logoColor=white)](https://playwright.dev/)
[![macOS](https://img.shields.io/badge/macOS-native-000000?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

**Automated cart builder for [continente.pt](https://www.continente.pt).**  
Define your weekly shopping list once in a YAML file. Type `shop`. Come back to a full cart.

---

## ⚡️ Install in one command

Open **Terminal** and paste this. No git clone, no setup steps — it handles everything:

```bash
curl -fsSL https://raw.githubusercontent.com/paulfxyz/continente-hero/main/setup.sh | bash
```

That single command:
- Installs Python 3.13 via Homebrew if needed (fully automatic)
- Clones the repo to `~/continente-hero`
- Creates a Python virtual environment
- Installs all packages (Playwright, PyYAML, python-dotenv)
- Downloads the Chromium browser (~170 MB)
- Registers a `shop` alias in your shell

When it finishes, type `shop` to open the menu.

> **Want to read the script before running it?** That's a healthy habit:
> ```bash
> curl -fsSL https://raw.githubusercontent.com/paulfxyz/continente-hero/main/setup.sh -o setup.sh
> cat setup.sh   # read it
> bash setup.sh  # run it
> ```

---

## 🛒 Using continente-hero

After installation, every interaction goes through one command:

```bash
shop
```

That opens an interactive menu:

```
  ╔══════════════════════════════════════════════════╗
  ║   🦸  continente-hero  ·  v2.0                  ║
  ╚══════════════════════════════════════════════════╝

  Active list: config.yaml

  ──────────────────────────────────────────────────────

  1)  🛒  Fill my cart              (run the bot)
  2)  🔐  Save / refresh session    (log in once)
  3)  ✏️   Edit shopping list        (opens editor)
  4)  📂  Switch shopping list      (multi-config)
  5)  🔄  Update continente-hero    (pull latest)
  6)  👋  Quit

  ──────────────────────────────────────────────────────

  Choose [1–6] →
```

### First time? Do this in order:

1. **Option 2** — Save your session. A browser window opens on the Continente login page. Log in normally. Press Enter in the Terminal when done. You'll never need to do this again unless your session expires.
2. **Option 3** — Edit your shopping list. Add your products.
3. **Option 1** — Fill your cart. The bot runs silently, adds everything, and prints a report.
4. Open [continente.pt/checkout/carrinho/](https://www.continente.pt/checkout/carrinho/) and check out.

---

## 👨‍💻 The story behind this

I shop at Continente regularly — same products, week after week. Opening the site, searching each item, clicking _Adicionar ao carrinho_ eight times in a row. Every. Single. Week. That's the kind of repetitive clicking that should never be done by a human.

So I built this. One config file, one command, full cart.

---

## 🌟 What it does

- 🔐 **Logs in to your Continente account** — via saved session cookies (recommended), `.env` credentials, or `config.yaml`
- 🔍 **Finds each product** — direct URL navigation or keyword search, with optional brand preference
- 🛒 **Adds everything to your cart** — with full quantity support
- 🧠 **Never crashes on missing products** — out-of-stock, not found, any error: caught gracefully and reported
- 📄 **Saves a timestamped run report** — in `reports/`, showing exactly what was added and what was skipped
- 💾 **Persists your session** — log in once, reuse cookies on every future run

---

## 📦 What's in the box

| File | Purpose |
|---|---|
| `continente.py` | Main bot — Playwright automation, login, cart logic, report |
| `config.yaml` | Your active shopping list |
| `configs/` | Extra shopping lists (weekly, party, etc.) — switch via `shop` menu |
| `shop.sh` | **Interactive menu launcher** — the main entry point |
| `setup.sh` | **curl one-liner installer** — clones + full setup, no prior steps needed |
| `install.sh` | Local installer (use if you already have the repo cloned) |
| `update.sh` | Pull latest code + refresh all dependencies |
| `edit.sh` | Opens `config.yaml` in the best available editor |
| `uninstall.sh` | Clean teardown — removes venv, session, reports, Chromium cache |
| `requirements.txt` | Python dependencies (auto-managed) |
| `.env.example` | Credentials template |
| `session/` | Auto-created — stores your login cookies locally |
| `reports/` | Auto-created — timestamped run reports |

---

## 📝 Your shopping list

Your list lives in `config.yaml`. Open it via **Option 3** in the `shop` menu, or directly:

```yaml
products:

  # Most reliable: direct product URL
  - name: "Leite Meio Gordo Mimosa"
    url: "https://www.continente.pt/produto/leite-uht-meio-gordo-mimosa-6879912.html"
    quantity: 2

  # Search by keyword
  - name: "Pão de Forma Integral"
    query: "pão de forma integral"
    quantity: 1

  # Search with brand preference (picks the first result that matches the brand)
  - name: "Azeite Extra Virgem Gallo"
    query: "azeite extra virgem"
    brand: "Gallo"
    quantity: 1
```

**Fields at a glance:**

| Field | Required | Description |
|---|---|---|
| `name` | ✅ | Human label — shown in logs and the run report |
| `url` | optional | Direct product page URL — most reliable, skips search entirely |
| `query` | optional | Search keyword — defaults to `name` if omitted |
| `brand` | optional | Preferred brand — scans results for this text, falls back to first result |
| `quantity` | optional | Units to add — defaults to `1` |

> 💡 **How to get a product URL:** Go to continente.pt in your browser, find the product, and copy the URL from the address bar. Products with a `url:` field are added instantly — no searching, no guessing.

---

## 🗂️ Multiple shopping lists

You can maintain multiple lists (weekly groceries, party supplies, etc.) and switch between them from the `shop` menu (**Option 4**).

Lists are stored in the `configs/` folder:

```
~/continente-hero/
├── config.yaml          ← active list (what the bot reads)
└── configs/
    ├── weekly.yaml      ← your regular weekly shop
    ├── party.yaml       ← drinks, snacks, etc.
    └── pantry.yaml      ← dry goods top-up
```

**How it works:**

1. Open `shop`, choose **Option 4 — Switch shopping list**
2. Select a list, or create a new one (it copies your current config as a starting point)
3. The menu shows which list is active at the top of every screen
4. Switching sets `config.yaml` to point to the chosen list

---

## 🔐 How the session connection works

This is the recommended authentication method — and it's important to understand why it's safe.

### The flow

```
You run:  ./run.sh --save-session  (or Option 2 in the shop menu)
            ↓
  Playwright opens a real Chromium browser window
  on the continente.pt login page.
            ↓
  You type your email and password yourself.
  The bot is not involved — it just holds the window open.
            ↓
  You press Enter in the Terminal.
            ↓
  Playwright reads the browser's cookie jar and saves it
  to:  session/cookies.json
            ↓
  On every future run, the bot loads these cookies
  and is immediately logged in — no password ever used.
```

### What gets stored

`session/cookies.json` contains only HTTP session cookies — the same tokens your browser stores when you log in to any website. No password is ever written to disk. The file looks like:

```json
[
  { "name": "dwsid",      "value": "abc123...", "domain": ".continente.pt", ... },
  { "name": "dwanonymous", "value": "...",      "domain": ".continente.pt", ... }
]
```

| Cookie | Role |
|---|---|
| `dwsid` | Salesforce Commerce Cloud session ID — authenticates your session |
| `dwanonymous` | Guest/anonymous tracking token |
| `dw_*` | Demandware (SFCC) preference and cart state cookies |

### Security

- `session/cookies.json` is in `.gitignore` — it is **never committed** to GitHub
- `config.yaml` is also in `.gitignore`
- Sessions typically last weeks to months
- If the bot says "not logged in", just run **Option 2** again — takes 30 seconds

### Credential priority

The bot checks these in order, using the first one that works:

```
1. session/cookies.json   ← saved session (recommended, most stable)
2. CONTINENTE_USER / CONTINENTE_PASS environment variables
3. username / password in config.yaml
```

---

## ⚠️ Python version compatibility

**Supported: Python 3.11, 3.12, 3.13. Python 3.14 is blocked.**

### Why 3.14 is blocked

Playwright's `greenlet` dependency is a C extension that must be compiled from source if no pre-built binary wheel is available. As of 2026, `greenlet` publishes no wheel for Python 3.14, and compilation fails on macOS because Apple's Clang toolchain is missing `<cstdlib>` — a C++ standard library header that `greenlet`'s source includes.

The error looks like this:
```
src/greenlet/greenlet.cpp:9:10: fatal error: 'cstdlib' file not found
```

**The fix:** `setup.sh` automatically detects Python 3.14 and installs Python 3.13 via Homebrew before continuing. You don't need to do anything — the installer handles it.

---

## 🔄 Staying up to date

Use **Option 5** in the `shop` menu, or run directly:

```bash
./update.sh
```

This pulls the latest code from GitHub (using `git reset --hard` to bypass any local change conflicts), upgrades all Python packages, and updates the Chromium binary.

---

## 🧹 Uninstall

```bash
./uninstall.sh
```

Removes: `.venv`, `session/`, `reports/`, and the Playwright Chromium cache. Your `config.yaml` and `configs/` folder are preserved. To remove everything including the repo:

```bash
rm -rf ~/continente-hero
```

And remove the alias from `~/.zshrc`:
```bash
# Delete the line:  alias shop='bash ~/continente-hero/shop.sh'
```

---

## 🛠️ How it works under the hood

### Browser engine

Uses [Playwright](https://playwright.dev/) with Chromium — a full real browser, not an HTTP client. This means:
- JavaScript-heavy pages (Continente.pt is a React SPA on Salesforce Commerce Cloud) work correctly
- The bot behaves like a real user — real mouse clicks, real typing, real page loads
- Anti-detection: real Chrome user-agent string, `--disable-blink-features=AutomationControlled`, Portuguese locale (`pt-PT`), Lisbon timezone

### Product resolution strategy

For each product, the bot tries two methods in order:

```
Has a url: field?
  ├── YES → Navigate directly to the product page (PDP)
  │         Fastest, most reliable, no ambiguity.
  └── NO  → Search using the query: field (or name: if no query)
            ├── Filter results by brand: if provided
            ├── Pick first matching brand tile
            └── Fall back to first result if no brand match
```

### Failover guarantee

Every single product is wrapped in an individual `try/except`. If a product fails — for any reason — the bot:
1. Records it as `not_found`, `out_of_stock`, or `error` with a description
2. Continues to the next product without interruption
3. Reports all outcomes at the end

The bot **never exits early** because one item failed.

### Run report

After each run, a timestamped report is saved to `reports/` and printed in the terminal:

```
══════════════════════════════════════════════════════════════
  CONTINENTE HERO — RUN REPORT  ·  2026-03-23 01:15:42
══════════════════════════════════════════════════════════════

  ✓  ADDED          Leite Meio Gordo Mimosa         ×2
  ✓  ADDED          Pão de Forma Integral           ×1
  ✓  ADDED          Azeite Extra Virgem Gallo       ×1
  ✗  OUT OF STOCK   Bacalhau Salgado Seco
  ✓  ADDED          Cerveja Super Bock 33cl         ×6

══════════════════════════════════════════════════════════════
  5 products  ·  4 added  ·  1 skipped
══════════════════════════════════════════════════════════════
```

---

## 🤝 Contributing

Pull requests are welcome. To run locally:

```bash
git clone https://github.com/paulfxyz/continente-hero.git
cd continente-hero
bash setup.sh
```

Open issues for bugs or feature requests: [github.com/paulfxyz/continente-hero/issues](https://github.com/paulfxyz/continente-hero/issues)

---

*Designed and built in collaboration with [Perplexity Computer](https://www.perplexity.ai/)*  
*[@paulfxyz](https://github.com/paulfxyz) · MIT License*
