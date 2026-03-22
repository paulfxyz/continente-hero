# 🦸 Continente Hero

[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![Playwright](https://img.shields.io/badge/Playwright-Chromium-45ba4b?style=for-the-badge&logo=playwright&logoColor=white)](https://playwright.dev/)
[![macOS](https://img.shields.io/badge/macOS-native-000000?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.1.0-brightgreen?style=for-the-badge)](CHANGELOG.md)

**Automated cart builder for [continente.pt](https://www.continente.pt)**. Define your shopping list once in a YAML file. Run one command. Come back to a full cart.

---

## 👨‍💻 The Story Behind This

I shop at Continente regularly — same products, week after week. Opening the site, searching each item, clicking _Adicionar ao carrinho_ eight times in a row, every single week. That's the kind of repetitive clicking that should never be done by a human.

So I built this. One config file with my list, one command to run it, and I open my browser to a pre-filled cart ready to check out.

---

## 🌟 What does it do?

A Python + Playwright bot that:

- 🔐 **Logs in to your Continente account** — via saved session (recommended), `.env` credentials, or one-time manual login capture
- 🔍 **Searches for each product** — or navigates directly to a product URL if you provide one
- 🛒 **Adds everything to your cart** — with full quantity support
- 🧠 **Never crashes on missing products** — out-of-stock, not found, errors: all caught and reported gracefully
- 📄 **Prints a clear run report** — exactly what was added and what was skipped, saved to `reports/`
- 💾 **Persists your session** — logs in once, reuses cookies on every future run

---

## 📦 What's in the box

| File | Purpose |
|---|---|
| `continente.py` | Main Playwright automation script |
| `config.yaml` | Your shopping list (product names, quantities, URLs) |
| `install.sh` | One-shot setup: Python venv + packages + Chromium |
| `run.sh` | Single command to activate venv and run the bot |
| `edit.sh` | Opens `config.yaml` in the best editor available on your Mac |
| `update.sh` | Pull latest changes and refresh all dependencies |
| `uninstall.sh` | Clean teardown — removes venv, session, reports, Chromium cache |
| `requirements.txt` | Python dependencies (managed automatically) |
| `.env.example` | Credentials template |
| `session/` | Auto-created — stores your login cookies locally |
| `reports/` | Auto-created — timestamped run reports after each run |

---

## 🚀 Complete beginner? Start here.

This is the full workflow, from zero to a filled cart. Takes about 5 minutes the first time.

---

### Step 1 — Get the code

Open **Terminal** (press `⌘ Space`, type `Terminal`, press Enter) and run:

```bash
git clone https://github.com/paulfxyz/continente-hero.git
cd continente-hero
```

> 💡 Don't have `git`? Run `xcode-select --install` first, or install [Homebrew](https://brew.sh) and then `brew install git`.

---

### Step 2 — Install everything

One command does it all (Python check, virtual environment, packages, Chromium browser):

```bash
chmod +x install.sh && ./install.sh
```

This downloads ~170 MB of browser files the first time. You'll see progress on screen. It ends with `✅ Installation complete!`.

> 💡 It says Python not found? Run `brew install python@3.12` and try again.

---

### Step 3 — Log in once (saves your session forever)

```bash
./run.sh --save-session
```

A browser window opens on the continente.pt login page. Log in with your account normally — the bot does nothing here, it just watches. Once you see your homepage, switch back to the Terminal window and press **Enter**.

Your session is now saved. You will **never need to log in again** unless your session expires (usually weeks or months later).

---

### Step 4 — Edit your shopping list

```bash
./edit.sh
```

This opens `config.yaml` in the best editor available on your Mac (VS Code, Sublime, or TextEdit). Your shopping list looks like this:

```yaml
products:

  - name: "Leite Meio Gordo Mimosa"
    url: "https://www.continente.pt/produto/leite-uht-meio-gordo-mimosa-6879912.html"
    quantity: 2

  - name: "Azeite Extra Virgem Gallo"
    query: "azeite extra virgem"
    brand: "Gallo"
    quantity: 1
```

Replace the example products with your own. Save the file and close the editor.

> 💡 **How to get a product URL:** Open continente.pt in your browser, navigate to the product, and copy the URL from the address bar. Paste it as the `url:` field. This is the most reliable method — the bot goes straight to the page without searching.

---

### Step 5 — Run it

```bash
./run.sh
```

The bot runs silently (no window). You'll see each product being processed in the terminal. When it's done, it opens your cart automatically and prints a report.

Go to [continente.pt/checkout/carrinho/](https://www.continente.pt/checkout/carrinho/) and check out.

---

## 🛠️ CLI flags

```bash
./run.sh                   # normal headless run (no browser window)
./run.sh --visible         # shows the browser so you can watch it work
./run.sh --save-session    # re-opens browser to log in and refresh session
./edit.sh                  # open shopping list in your editor
./update.sh                # pull latest code + refresh all packages
./uninstall.sh             # remove everything cleanly from your machine
```

---

## 📋 Shopping list format

Every field except `name` is optional:

| Field | Required | What it does |
|---|---|---|
| `name` | ✅ | Label shown in the terminal and in the report |
| `query` | optional | Search term sent to continente.pt. Defaults to `name` if not set |
| `quantity` | optional | How many to add. Defaults to `1` |
| `url` | optional | Direct product page URL — skip search entirely. **Most reliable.** |
| `brand` | optional | Prefer results from this brand. Falls back to the first result if no match |

### Examples

```yaml
products:

  # Go straight to the product page (most reliable)
  - name: "Leite Meio Gordo Mimosa"
    url: "https://www.continente.pt/produto/leite-uht-meio-gordo-mimosa-6879912.html"
    quantity: 2

  # Search by keyword
  - name: "Pão de Forma Integral"
    query: "pão de forma integral"
    quantity: 1

  # Search + prefer a specific brand
  - name: "Azeite Extra Virgem Gallo"
    query: "azeite extra virgem"
    brand: "Gallo"
    quantity: 1

  # If out of stock, the report says so — no crash
  - name: "Bacalhau Salgado Seco"
    query: "bacalhau salgado seco"
    quantity: 1
```

---

## 🔐 Authentication

Three ways to authenticate — in order of recommendation:

### Option A — Save session (best, zero maintenance)
```bash
./run.sh --save-session
```
Opens a browser window. You log in manually once. Cookies are saved to `session/cookies.json`. All future runs are silent — no browser opens, no credentials needed.

> 🔁 If the bot says it can't log in, just run `./run.sh --save-session` again to refresh.

### Option B — `.env` file
```bash
cp .env.example .env
open .env
```
```env
CONTINENTE_USER=your@email.com
CONTINENTE_PASS=yourpassword
```

### Option C — `config.yaml` fields
```yaml
username: "your@email.com"
password: "yourpassword"
```
> ⚠️ `config.yaml` is gitignored — never committed. Still, Option A is the safest approach.

---

## 📄 Run report

After every run, a report is printed to your terminal and saved to `reports/`:

```
════════════════════════════════════════════════════════════════
  CONTINENTE CART BOT
════════════════════════════════════════════════════════════════

  [1/8] 'Leite Meio Gordo Mimosa'  (qty: 2)
    → ✅ Added (pid=6879912)
  [2/8] 'Pão de Forma Integral'  (qty: 1)
    → Searching: https://www.continente.pt/pesquisa/?q=pão de forma integral
    → ✅ Added (pid=3021847)
  [3/8] 'Bacalhau Salgado Seco'  (qty: 1)
    → Searching: https://www.continente.pt/pesquisa/?q=bacalhau salgado seco
    → Not found.

  ════════════════════════════════════════════════════════════
  CONTINENTE CART — RUN REPORT
  2026-03-22 18:45:01
  ════════════════════════════════════════════════════════════

  Total products in list : 8
  ✅  Added to cart       : 6
  ❌  Not found           : 1
  🚫  Out of stock        : 1
  ⚠️   Errors              : 0

  ──────────────────────────────────────────────────────────────
  ✅  ADDED TO CART
  ──────────────────────────────────────────────────────────────
  • Leite Meio Gordo Mimosa
    qty: 2   pid: 6879912
  • Pão de Forma Integral
    qty: 1   pid: 3021847

  ──────────────────────────────────────────────────────────────
  ❌  NOT FOUND
  ──────────────────────────────────────────────────────────────
  • Bacalhau Salgado Seco
    search query : bacalhau salgado seco
    reason       : No search results for query: 'bacalhau salgado seco'

  ──────────────────────────────────────────────────────────────
  🚫  OUT OF STOCK
  ──────────────────────────────────────────────────────────────
  • Café Delta Q Cápsulas  (pid: 9912312)
    Add-to-cart button is disabled (likely out of stock)
```

---

## 🧠 How it works — under the hood

### The browser

The bot runs a real **Chromium browser** (the same engine as Google Chrome), controlled by [Playwright](https://playwright.dev/). It behaves exactly like a human opening the site — JavaScript runs, cookies are set, sessions work. There is no API hacking or HTML parsing. The browser visits the actual pages.

By default the browser runs **headless** (invisible). Run with `--visible` to watch it work in real time.

### Login

On every run, the bot navigates to `continente.pt` and checks for a logged-in UI element (the account menu). If it finds one, it's authenticated and skips login entirely.

If not, it looks for credentials in this order:
1. `session/cookies.json` — saved from a previous `--save-session` run
2. `CONTINENTE_USER` / `CONTINENTE_PASS` environment variables (or `.env` file)
3. `username` / `password` fields in `config.yaml`

Continente uses a **React SSO system** hosted at `login.continente.pt` — the login form is injected by JavaScript, not static HTML. The bot tries multiple selector strategies to handle this robustly. After any successful login, it refreshes and saves the cookies immediately.

### Finding products

For each product in your list, the bot chooses the best strategy:

**Direct URL** (`url:` field set) — navigates straight to the product detail page and clicks _Adicionar ao carrinho_. Zero ambiguity. This is the recommended approach for products you buy regularly.

**Search** (`query:` or falling back to `name`) — navigates to `/pesquisa/?q=<term>`, waits for the Salesforce Commerce Cloud tile grid to render, then scans the results:
- If `brand:` is set, it reads each tile's text and picks the first one that contains the brand name (case-insensitive)
- If no brand match is found, it logs a warning and uses the first result
- If there are no results at all, the product is marked `not_found`

### Adding to cart

Once the right product tile (or product page) is found:
1. The bot checks whether the _Adicionar ao carrinho_ button exists and is **not disabled**. A disabled button means out of stock.
2. It scrolls the button into view, pauses briefly (to behave like a human), and clicks.
3. For quantities > 1, it attempts to use the quantity stepper input or the `+` button. If neither works, it logs a warning — you can adjust manually in the cart.

### Failover guarantee

Every product is wrapped in a `try/except`. The four possible outcomes are:

| Status | What happened |
|---|---|
| `✅ added` | Successfully in cart |
| `❌ not_found` | Zero search results, or no add-to-cart button in the tile |
| `🚫 out_of_stock` | Button found but disabled |
| `⚠️ error` | Unexpected exception — timeout, layout change, network issue |

**No single product failure can stop the run.** The bot processes every item in your list and gives you a complete picture at the end.

### Session persistence

After every successful run, the bot saves the current browser cookies to `session/cookies.json`. This means:
- Future runs reuse the session without logging in
- The session stays fresh as long as you run the bot regularly
- The file is gitignored — it never leaves your machine

### Anti-detection

The bot runs with a realistic Chrome user-agent string, sets the locale to `pt-PT`, the timezone to `Europe/Lisbon`, and disables Playwright's automation fingerprint flag. Continente uses Cloudflare and Salesforce behavioral tracking — the session-based approach (logging in once via a real browser) is the cleanest way to stay invisible.

---

## 🔄 Update

```bash
./update.sh
```

---

## 🗑️ Uninstall

```bash
./uninstall.sh
```

Removes the virtual environment, saved session, run reports, and the downloaded Chromium binary (~170 MB). Keeps `config.yaml` and `.env` intact.

---

## 🤝 Contributing

1. Fork the repo
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Commit: `git commit -m 'feat: add my feature'`
4. Push: `git push origin feat/my-feature`
5. Open a Pull Request

---

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full version history.

---

## 📜 License

[MIT](LICENSE) — free to use, fork, and modify.

---

## 👤 Author

**Paul Fleury**
🌐 [paulfleury.com](https://paulfleury.com) · 💼 [LinkedIn](https://www.linkedin.com/in/paulfxyz/) · 🐙 [GitHub](https://github.com/paulfxyz)

---

> ⭐ If this saves you a few minutes every week, drop a star — it helps others find it! ⭐

---

*Designed and built in collaboration with [Perplexity Computer](https://www.perplexity.ai/)*
