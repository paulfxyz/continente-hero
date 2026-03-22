# 🛒 continente-cart

[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![Playwright](https://img.shields.io/badge/Playwright-Chromium-45ba4b?style=for-the-badge&logo=playwright&logoColor=white)](https://playwright.dev/)
[![macOS](https://img.shields.io/badge/macOS-native-000000?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.0-brightgreen?style=for-the-badge)](CHANGELOG.md)

**Automated cart builder for [continente.pt](https://www.continente.pt)**. Define your shopping list once in a YAML file. Run one command. Come back to a full cart.

---

## 👨‍💻 The Story Behind This

I shop at Continente regularly — same products, week after week. Opening the site, searching each item, clicking _Adicionar ao carrinho_ eight times in a row, every single week. That's the kind of repetitive clicking that should never be done by a human.

So I built this. One config file with my list, one command to run it, and I open my browser to a pre-filled cart ready to check out.

---

## 🌟 What is this?

A Python + Playwright bot that:

- 🔐 **Logs in to your Continente account** — via saved session (recommended), `.env` credentials, or manual one-time login capture
- 🔍 **Searches for each product** — or navigates directly to a product URL if you provide one
- 🛒 **Adds everything to your cart** — including quantity support
- 🧠 **Never crashes on missing products** — out-of-stock, not found, errors: all caught and reported
- 📄 **Prints a clear run report** — exactly what was added and what was skipped, saved to `reports/`
- 💾 **Persists your session** — logs in once, reuses cookies forever (until they expire)

---

## 📦 What's in the box

| File | Purpose |
|---|---|
| `continente.py` | Main Playwright automation script |
| `config.yaml` | Your shopping list (product names, quantities, URLs) |
| `install.sh` | One-shot setup: Python venv + packages + Chromium |
| `run.sh` | Single command to activate venv and run the bot |
| `update.sh` | Pull latest changes and refresh all dependencies |
| `uninstall.sh` | Clean teardown — removes venv, session, reports, Chromium cache |
| `requirements.txt` | Python dependencies |
| `.env.example` | Credentials template |
| `session/` | Auto-created — stores your login cookies locally |
| `reports/` | Auto-created — timestamped run reports |

---

## 🚀 Quick Start

**1. Clone the repo:**
```bash
git clone https://github.com/paulfxyz/continente-cart.git
cd continente-cart
```

**2. Install everything (one command):**
```bash
chmod +x install.sh && ./install.sh
```

**3. Save your session (one-time — opens a real browser):**
```bash
./run.sh --save-session
```
> 💡 This opens Chromium, you log in to continente.pt manually, and your session is saved. You'll never need to enter credentials again unless your session expires.

**4. Edit your shopping list:**
```bash
nano config.yaml
```

**5. Run the bot:**
```bash
./run.sh
```

That's it. The bot runs, adds everything to your cart, and prints a report. Then go to [continente.pt/checkout/carrinho/](https://www.continente.pt/checkout/carrinho/) and check out.

---

## 🛠️ CLI Flags

```bash
./run.sh                   # headless run (no browser window)
./run.sh --visible         # shows the browser window (great for debugging)
./run.sh --save-session    # opens browser for manual login, saves cookies
```

---

## 📋 Shopping List Format

Edit `config.yaml` to define your products. Every field except `name` is optional:

```yaml
products:

  # Most reliable — paste the URL directly from your browser
  - name: "Leite Meio Gordo Mimosa"
    url: "https://www.continente.pt/produto/leite-uht-meio-gordo-mimosa-6879912.html"
    quantity: 2

  # Search-based — bot finds the best match
  - name: "Pão de Forma Integral"
    query: "pão de forma integral"
    quantity: 1

  # Search with brand preference
  - name: "Azeite Extra Virgem Gallo"
    query: "azeite extra virgem"
    brand: "Gallo"
    quantity: 1
```

| Field | Required | Description |
|---|---|---|
| `name` | ✅ | Label shown in logs and report |
| `query` | optional | Search term. Defaults to `name` if omitted |
| `quantity` | optional | Units to add. Defaults to `1` |
| `url` | optional | Direct product page URL — fastest and most reliable |
| `brand` | optional | Preferred brand. Falls back to first result if no match |

---

## 🔐 Authentication

Three ways to authenticate — in order of recommendation:

### Option A — Save session (best)
```bash
./run.sh --save-session
```
Opens a browser, you log in once, cookies are saved to `session/cookies.json`. All future runs are fully silent.

### Option B — `.env` file
```bash
cp .env.example .env
nano .env
```
```env
CONTINENTE_USER=your@email.com
CONTINENTE_PASS=yourpassword
```

### Option C — `config.yaml`
```yaml
username: "your@email.com"
password: "yourpassword"
```
> ⚠️ `config.yaml` is in `.gitignore` — never gets committed. Still, Option A is safest.

See [INSTALL.md](INSTALL.md) for the full authentication walkthrough.

---

## 📄 Run Report

After every run, a report is printed to your terminal and saved to `reports/`:

```
══════════════════════════════════════════════════════════════
  CONTINENTE CART — RUN REPORT
  2026-03-22 18:45:01
══════════════════════════════════════════════════════════════

  Total products in list : 8
  ✅  Added to cart       : 6
  ❌  Not found           : 1
  🚫  Out of stock        : 1
  ⚠️   Errors              : 0

  ──────────────────────────────────────────────────────────
  ✅  ADDED TO CART
  ──────────────────────────────────────────────────────────
  • Leite Meio Gordo Mimosa
    qty: 2   pid: 6879912
  • Pão de Forma Integral
    qty: 1   pid: 3021847
  ...

  ──────────────────────────────────────────────────────────
  ❌  NOT FOUND
  ──────────────────────────────────────────────────────────
  • Bacalhau Salgado Seco
    search query : bacalhau salgado seco
    reason       : No search results for query: 'bacalhau salgado seco'

  ──────────────────────────────────────────────────────────
  🚫  OUT OF STOCK
  ──────────────────────────────────────────────────────────
  • Café Delta Q Cápsulas  (pid: 9912312)
    Add-to-cart button is disabled (likely out of stock)
```

---

## 🧠 How It Works

### Login flow
The bot first checks if saved cookies give a valid authenticated session (`session/cookies.json`). If yes, it skips the full login. If not, it navigates to `login.continente.pt` (an SSO React SPA) and fills in the credentials. After any successful run, cookies are refreshed.

### Product resolution
For each product, the strategy is:

1. **Direct URL** (`url:` field) — navigate straight to the product page, click _Adicionar ao carrinho_, done. Most reliable.
2. **Search** — navigate to `/pesquisa/?q=<query>`, wait for Salesforce Commerce Cloud to render the tile grid, pick the best matching tile (brand-filtered if specified, first result otherwise), click add-to-cart.

### Failover logic
Every product is wrapped in a try/except. The outcomes are:

| Status | Meaning |
|---|---|
| `added` | Successfully added to cart |
| `not_found` | Zero search results, or no add-to-cart button in tile |
| `out_of_stock` | Add-to-cart button found but disabled |
| `error` | Unexpected exception (timeout, layout change, etc.) |

No failure stops the bot — it moves on to the next product and includes all outcomes in the final report.

### Session persistence
Cookies are saved to `session/cookies.json` (gitignored). This file contains live auth tokens — keep it private, the same way you'd treat a password.

---

## 🔄 Update

```bash
./update.sh
```

Pulls the latest code from GitHub and updates all Python packages and the Playwright Chromium binary.

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
3. Commit your changes: `git commit -m 'feat: add my feature'`
4. Push: `git push origin feat/my-feature`
5. Open a Pull Request

Bug reports and feature ideas welcome via [Issues](https://github.com/paulfxyz/continente-cart/issues).

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
