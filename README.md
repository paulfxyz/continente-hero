# 🦸 continente-hero

[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![Playwright](https://img.shields.io/badge/Playwright-Chromium-45ba4b?style=for-the-badge&logo=playwright&logoColor=white)](https://playwright.dev/)
[![macOS](https://img.shields.io/badge/macOS-native-000000?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.2.0-brightgreen?style=for-the-badge)](CHANGELOG.md)

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

> 🔁 Session expired? Just run `./run.sh --save-session` again — takes 30 seconds.

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

## 🔐 Authentication — full guide

The bot needs to be logged in to your Continente account to add things to your cart. There are three ways to handle this. **Option A is what everyone should use.**

---

### Option A — Save session (recommended)

**What is a "session" and why does saving it matter?**

When you log in to a website in your browser, the site issues a set of small tokens called **cookies**. These cookies are stored in your browser and sent automatically with every request, so the site knows you're authenticated. That's why you don't have to type your password every time you open a new tab.

`--save-session` captures those exact cookies after you log in manually, and saves them to a file: `session/cookies.json`. On every future run, the bot loads that file into its own private Chromium browser before visiting the site — so continente.pt sees an already-authenticated session. No password is ever stored. No automated login happens. The site just thinks it's you.

**Step-by-step walkthrough:**

Run this in your terminal:

```bash
./run.sh --save-session
```

**1.** The terminal prompts you:
```
════════════════════════════════════════════════════════════════
  SAVE SESSION
════════════════════════════════════════════════════════════════

  A browser window will open at the continente.pt login page.
  Log in with your account, then come back here and press Enter.

  Press Enter to open the browser…
```
Press **Enter**.

**2.** A real Chromium browser window opens on the continente.pt login page. This is not a screenshot or a simulation — it's a full browser. You can see the page, click things, use 2-factor authentication, solve captchas, everything you'd do in Chrome or Safari.

**3.** Log in to your Continente account the way you normally do:
- Type your email and password
- Complete SMS verification or 2FA if your account uses it
- Wait until you land on the homepage and see your account name or icon in the header — that confirms you're fully logged in

**4.** Switch back to the Terminal window (the browser can stay open). Press **Enter** when you see:
```
  → Browser is open. Log in to continente.pt.
  → Once you see your account / homepage, come back here.

  Press Enter once you are logged in…
```

**5.** The bot reads all the cookies from the browser, writes them to `session/cookies.json`, and prints:
```
  ✓ Session saved (47 cookies).
  You can now run the bot normally:

      ./run.sh
```
The browser closes. You're done.

---

**What does `session/cookies.json` actually contain?**

It's a plain JSON file — you can open it in any text editor to see what's inside. It looks roughly like this:

```json
[
  {
    "name": "dwsid",
    "value": "Xk92nPqR7mT...",
    "domain": ".continente.pt",
    "path": "/",
    "expires": 1742000000.0,
    "httpOnly": true,
    "secure": true,
    "sameSite": "None"
  },
  {
    "name": "dwanonymous_4f8a",
    "value": "abcXYZ...",
    "domain": ".continente.pt"
  }
]
```

There are typically 40–60 cookies. The critical one is `dwsid` — the **Salesforce Commerce Cloud session token** that proves authentication. As long as it's valid, the bot is in.

---

**How the bot uses this file on every run:**

```
./run.sh
  │
  ├─ Chromium starts (headless — invisible)
  ├─ Loads all cookies from session/cookies.json into the browser
  ├─ Navigates to continente.pt
  ├─ Checks for account menu element (logged-in indicator)
  │     ✓ Found → authenticated, proceed with cart run
  │     ✗ Not found → session expired → falls back to credentials
  │
  └─ After run: saves refreshed cookies back to session/cookies.json
```

The session check takes about 3 seconds. If the session is valid, the bot never visits the login page.

---

**How long does the session last?**

Continente sessions typically stay valid for **2 to 4 weeks**. If you run the bot regularly, the session refreshes automatically each time — the bot saves updated cookies at the end of every successful run. In practice, as long as you use the bot once a week, you'll never see a session expiry.

If the session expires, the bot will print:
```
  [LOGIN] ✗ Saved session has expired or is no longer valid.
```
Run `./run.sh --save-session` again. Takes 30 seconds.

---

**Is this safe?**

- `session/cookies.json` is in `.gitignore` — it will **never** be committed to git or uploaded anywhere, even if you push the rest of the project to GitHub.
- The file lives only at `continente-hero/session/cookies.json` on your local machine.
- The cookies are sent only to `continente.pt`. You can verify this by running `./run.sh --visible` and watching the browser — it only ever visits continente.pt pages.
- Treat this file the way you'd treat a saved password: don't share it, don't email it, don't sync it to a public cloud folder.

> 🔁 **Session expired or the bot can't log in?**
> ```bash
> ./run.sh --save-session
> ```
> Redo the steps above. 30 seconds, done.

---

### Option B — `.env` credentials file

This stores your email and password in a local file that the bot reads at startup. Useful if you prefer fully automated logins without ever opening a browser window.

```bash
cp .env.example .env
./edit.sh    # or: nano .env
```

Fill in your credentials:

```env
CONTINENTE_USER=your@email.com
CONTINENTE_PASS=yourpassword
```

Save and close. On every run, if there are no valid saved cookies, the bot will:

1. Navigate to the continente.pt login page
2. Fill in your email and password automatically
3. Submit the form and wait for the redirect
4. Confirm authentication
5. Save the resulting cookies to `session/cookies.json`

After that first automated login, the behaviour is identical to Option A — future runs reuse the saved cookies and never touch the password.

> ⚠️ `.env` is in `.gitignore` — never committed to git. But it does contain your plaintext password, so don't share the file or put the project folder in a public location.

---

### Option C — `config.yaml` fields

Quickest option for a one-off test. Add these two lines to `config.yaml` (outside the `products:` block):

```yaml
username: "your@email.com"
password: "yourpassword"
```

> ⚠️ `config.yaml` is also gitignored. But Option A or B are cleaner for regular use.

---

### How the bot decides which method to use

On every run, the decision happens in this exact order:

```
1. Does session/cookies.json exist?
      → Load cookies → visit continente.pt → is the account menu visible?
            YES → authenticated, skip login, start the cart run
            NO  → session expired, fall through to step 2

2. Is CONTINENTE_USER set? (from .env file or shell export)
            YES → automated login with those credentials
            NO  → check config.yaml

3. Is username set in config.yaml?
            YES → automated login with those credentials
            NO  → print setup instructions and exit
```

If you have valid saved cookies, your password is never read or used.

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

  ══════════════════════════════════════════════════════════════
  CONTINENTE CART — RUN REPORT
  2026-03-22 18:45:01
  ══════════════════════════════════════════════════════════════

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

Continente uses a **React SSO system** hosted at `login.continente.pt` — the login form is injected by JavaScript, not static HTML. The bot tries multiple selector strategies to handle this robustly. After any successful login, it refreshes and saves the cookies immediately.

### Finding products

For each product in your list, the bot chooses the best strategy:

**Direct URL** (`url:` field set) — navigates straight to the product detail page and clicks _Adicionar ao carrinho_. Zero ambiguity. Recommended for products you buy regularly.

**Search** (`query:` or falling back to `name`) — navigates to `/pesquisa/?q=<term>`, waits for the Salesforce Commerce Cloud tile grid to render, then scans the results:
- If `brand:` is set, reads each tile's text and picks the first one matching the brand (case-insensitive)
- If no brand match, logs a warning and uses the first result
- If no results at all, marks the product as `not_found`

### Adding to cart

1. Checks whether _Adicionar ao carrinho_ exists and is **not disabled** (disabled = out of stock)
2. Scrolls into view, pauses briefly, clicks
3. For qty > 1, attempts stepper input or `+` button; warns if neither works

### Failover guarantee

| Status | What happened |
|---|---|
| `✅ added` | Successfully in cart |
| `❌ not_found` | Zero search results, or no add-to-cart button |
| `🚫 out_of_stock` | Button found but disabled |
| `⚠️ error` | Timeout, layout change, network issue |

No single failure stops the run. Every product is tried, every outcome reported.

### Anti-detection

Realistic Chrome user-agent, `pt-PT` locale, `Europe/Lisbon` timezone, `--disable-blink-features=AutomationControlled`. The session-based approach (logging in once via a real browser) is the cleanest way to stay invisible to Cloudflare and Salesforce tracking.

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

Removes venv, session, reports, and Chromium (~170 MB). Keeps `config.yaml` and `.env`.

---

## 🤝 Contributing

1. Fork → `git checkout -b feat/my-feature` → commit → push → Pull Request
2. Issues and ideas welcome at [github.com/paulfxyz/continente-hero/issues](https://github.com/paulfxyz/continente-hero/issues)

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
