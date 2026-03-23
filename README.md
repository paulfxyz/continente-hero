# 🦸 continente-hero

[![Version](https://img.shields.io/badge/Version-2.0.4-brightgreen?style=for-the-badge)](https://github.com/paulfxyz/continente-hero/releases/latest)
[![Python](https://img.shields.io/badge/Python-3.11--3.14-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
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
  ║   🦸  continente-hero  ·  v2.0.4               ║
  ╚══════════════════════════════════════════════════╝

  Active list: config.yaml

  ──────────────────────────────────────────────────────

  1)  🛒  Fill my cart              (run the bot)
  2)  🔐  Save / refresh session    (log in once)
  3)  ✏️   Edit shopping list        (opens editor)
  4)  📂  Manage shopping lists    (select, browse, create)
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

1. Open `shop`, choose **Option 4 — Manage shopping lists**
2. Pick a sub-option:
   - **✅ Select active list** — numbered picker, shows which list is currently active with a `● active` marker
   - **📂 Open lists folder** — opens `configs/` in Finder so you can browse, rename, duplicate or delete lists like any normal files
   - **✨ Create new list** — prompts for a name, copies current config as a starting point, and optionally activates it immediately
3. The menu always shows which list is active at the top of every screen
4. Switching sets `config.yaml` to symlink to the chosen list (the bot always reads `config.yaml` — no changes needed to `continente.py`)

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

**Supported: Python 3.11, 3.12, 3.13, 3.14.** Python 3.13 is preferred.

### Why 3.14 previously failed (and is now fixed)

Earlier versions of continente-hero pinned `playwright==1.44.0`, which pulled `greenlet==3.0.3` as a dependency. `greenlet` is a C extension that must be compiled from source if no pre-built wheel exists. `greenlet 3.0.3` had no wheel for macOS 26 (Tahoe/Sequoia), and compilation failed:

```
src/greenlet/greenlet.cpp:9:10: fatal error: 'cstdlib' file not found
```

**The fix (v2.0.2):** `requirements.txt` now pins `playwright>=1.50.0`, which requires `greenlet>=3.1.1`. `greenlet 3.3+` ships a pre-built `universal2` wheel for every Python version including 3.14 — no compilation needed. This fix also resolves the failure on macOS 26 (Tahoe) regardless of Python version.

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

## 🧱 Challenges, bottlenecks & how we solved them

This section documents the hard problems encountered while building continente-hero — the kind of things that don't appear in any tutorial. If you're building a similar macOS automation tool, this is the part worth reading carefully.

---

### 1. The `curl | bash` stdin pipe contamination bug

**Problem:** The recommended way to distribute a shell installer is `curl -fsSL URL | bash`. When you pipe into bash, bash reads its script from **stdin** — the same file descriptor that the curl pipe is writing to. Any program run inside the script that writes to **stdout** also writes to that same pipe, and bash attempts to interpret it as shell commands.

`brew install python@3.13` outputs several hundred lines including:
- Download progress
- Path configuration advice
- Text like `section "3 / 6 Repository"` — which contains our actual script section headers
- Shell-looking fragments like `export PATH=...`

Bash read all of this as commands and either executed them as garbage or exited with an error. Symptoms varied: the installer appeared to complete but the `shop` alias was never written; the script printed brew output mid-section; a variable like `section` was invoked as a command and returned `command not found`.

**Fix:** Add `>&2` to every external command that writes to stdout:

```bash
brew install python@3.13 >&2
git clone "$REPO_URL" "$CONTINENTE_DIR" >&2
git reset --hard origin/main >&2
pip install -r requirements.txt >&2
"$VENV_DIR/bin/playwright" install chromium >&2
```

Redirecting stdout to stderr (`>&2`) means those outputs appear on the terminal (stderr is always shown), but they are **not** fed back into the curl pipe that bash is reading. Stdin stays clean. This is the canonical fix for any `curl | bash` installer that runs subprocesses.

---

### 2. `${answer,,}` bashism crashing under `/bin/sh`

**Problem:** `${var,,}` is a bash-only lowercase expansion. macOS's `/bin/sh` is actually dash, not bash. Some environments (and `curl | bash` if the shebang is missing or wrong) invoke the script under dash, which treats `${answer,,}` as a syntax error and exits immediately.

**Fix:** Replaced all lowercase expansions with explicit comparisons:
```bash
# Before (bash-only):
if [[ "${answer,,}" == "y" ]]; then

# After (POSIX-safe):
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
```

---

### 3. `SCRIPT_DIR` double-nesting under non-bash shells

**Problem:** The standard pattern for getting a script's own directory is:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```
`${BASH_SOURCE[0]}` is bash-only. Under dash/sh it expands to empty string, so `dirname ""` returns `.`, and the script resolves relative to whatever the current working directory happens to be — which is wrong when launched via `curl | bash` from `/`.

**Fix:** Use the POSIX fallback:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
```
`$0` is POSIX-standard and always contains the script path.

---

### 4. `playwright: command not found` after venv activation

**Problem:** After `source .venv/bin/activate`, the `playwright` binary is on `PATH` inside an interactive shell. But `curl | bash` runs in a non-interactive subshell that doesn't fully source the venv activation — or in zsh, PATH changes in a subshell are not always inherited. The bare `playwright` command would silently fail or not be found.

**Fix:** Always use the full absolute path to the venv binary:
```bash
"$VENV_DIR/bin/playwright" install chromium >&2
```
No PATH manipulation needed. Works in every shell and every invocation context.

---

### 5. `permission denied: ./run.sh` after git clone

**Problem:** `git clone` does not preserve execute bits from the remote. A freshly cloned repo has all `.sh` files as mode `644` (read/write, no execute). Running `./run.sh` or `./shop.sh` immediately fails with `permission denied`.

**Fix:** The very first step of every installer is:
```bash
chmod +x "$CONTINENTE_DIR"/*.sh
```
This runs before anything else, so by the time the user touches any script, all `.sh` files are executable.

---

### 6. Stale `.venv` with wrong Python on reinstall

**Problem:** If a user had previously installed with Python 3.11 (or 3.14), the `.venv` exists pointing to that Python binary. Running `install.sh` or `setup.sh` again would reuse the stale venv instead of rebuilding for the correct Python version, causing mysterious import errors.

**Fix:** The installer always deletes and rebuilds the venv:
```bash
rm -rf "$VENV_DIR"
python3.13 -m venv "$VENV_DIR"
```
A clean venv is always faster than debugging a corrupted one.

---

### 7. `git pull` aborted by local `chmod +x` changes

**Problem:** After install, local `.sh` files have their execute bit set (mode `755`). The remote files are mode `644`. `git pull` sees this as a local modification and refuses to pull when there's a conflict, printing `error: Your local changes to the following files would be overwritten by merge`.

**Fix:** The update flow uses `git fetch` + `git reset --hard origin/main` instead of `git pull`:
```bash
git fetch origin >&2
git reset --hard origin/main >&2
```
`reset --hard` discards all local changes unconditionally. The chmod step that follows re-applies execute bits on the freshly reset files.

---

### 8. Python version parsing returning the patch number

**Problem:** The original version check used:
```bash
ver=$(python3 -c "import sys; print(sys.version_info.minor)")
```
This returned the minor version (e.g. `13` for 3.13), but an earlier version used `${ver##*.}` string manipulation on the full `3.13.2` output string — `##*.` strips everything up to and including the last dot, returning `2` (the patch), not `13` (the minor). So Python 3.13.2 was evaluated as "version 2" and passed the `>= 11` check for the wrong reasons.

**Fix:** Read both major and minor as separate integers:
```bash
read major minor <<< $(python3 -c "import sys as v; print(v.version_info.major, v.version_info.minor)")
```
Then check both:
```bash
if [ "$major" -eq 3 ] && [ "$minor" -ge 11 ] && [ "$minor" -le 13 ]; then
```

---

### 10. `shop` alias not active after install — subshell isolation

**Problem:** After `curl -fsSL URL | bash` finishes and prints "alias registered", the user types `shop` and gets `zsh: command not found: shop`. The script even says to run `source ~/.zshrc` — but users naturally skip it or don't notice.

The root cause is a fundamental Unix rule: **a child process cannot modify the environment of its parent process.** When bash runs via `curl | bash`, it's a subshell — a child of the user's zsh session. Any `source ~/.zshrc` run inside that child only modifies the child's environment. When the child exits, those changes evaporate. The parent zsh session is completely unaffected.

There is no technical way around this. No shell script can inject an alias into a parent shell's environment. Even Apple's own installers can't do it — they ask you to open a new terminal.

**Why this is confusing:** The script writes the alias to `~/.zshrc` correctly. The alias is permanently saved. But the current terminal session loaded `~/.zshrc` at startup and hasn't re-read it since. It doesn't know the alias was added.

**Fix:** Two changes in v2.0.2:
1. The installer's final output now shows a big, hard-to-miss `source ~/.zshrc` command as the single required next step — not buried in a paragraph, but displayed as a standalone bold command
2. Every failure path prints `cd ~/continente-hero && ./shop.sh` as an alias-free fallback that always works

```bash
# After install, run exactly this — once, in your current terminal:
source ~/.zshrc

# Then:
shop

# Or skip the alias entirely — always works:
bash ~/continente-hero/shop.sh
```

---

### 11. Salesforce Commerce Cloud (SFCC) as the automation target

Continente.pt runs on Salesforce Commerce Cloud (formerly Demandware). The platform is a React SPA — there is no server-rendered HTML to parse. Every product tile, cart button, and search result is rendered by JavaScript after the page loads. This rules out simple HTTP clients like `requests` or `httpx`.

Playwright with Chromium is the right tool: it runs a real browser engine, waits for JS to render, clicks actual DOM elements, and handles network requests exactly as a human session would. Anti-detection mitigations (real Chrome user-agent, `--disable-blink-features=AutomationControlled`, `pt-PT` locale, Europe/Lisbon timezone) are included because SFCC has bot-detection logic built into its session handling.

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
