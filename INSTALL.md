# continente-hero — Installation Guide

A macOS-native bot with no Docker, no build steps, and no cloud accounts required. Everything runs locally on your machine.

---

## Requirements

| Requirement | Minimum | Notes |
|---|---|---|
| **macOS** | 12 Monterey | Also works on Linux with minor path adjustments |
| **Python** | 3.11 | 3.12 or 3.13 work fine too |
| **Disk space** | ~300 MB | ~170 MB for Playwright Chromium + ~50 MB for the Python venv |
| **Network** | Any | The bot runs locally; only continente.pt is accessed |

---

## Step 1 — Clone the repo

Open **Terminal** (press `⌘ Space`, type `Terminal`, press Enter) and run:

```bash
git clone https://github.com/paulfxyz/continente-hero.git
cd continente-hero
```

> 💡 **No git?** Run `xcode-select --install` in Terminal. macOS will prompt you to install the Command Line Tools, which includes git. Takes about 2 minutes.

---

## Step 2 — Install everything

```bash
chmod +x install.sh && ./install.sh
```

This single command:
1. Checks your macOS version and confirms you're on a supported system
2. Finds the highest available Python version (3.13, 3.12, 3.11 — in that order)
3. Creates a `.venv/` virtual environment inside the project folder so nothing touches your system Python
4. Upgrades pip silently
5. Installs `playwright`, `pyyaml`, and `python-dotenv` from `requirements.txt`
6. Downloads the Playwright Chromium browser (~170 MB — this is the actual Chrome binary the bot uses)
7. Creates `session/` and `reports/` directories
8. Copies `.env.example` → `.env` if you don't have a `.env` yet

You'll see progress for each step. It ends with `✅ Installation complete!`.

> ⚠️ **Python not found?**
> ```bash
> brew install python@3.12
> ```
> No Homebrew? Install it from [brew.sh](https://brew.sh) — one command, takes 5 minutes. Or download Python directly from [python.org/downloads](https://www.python.org/downloads/).

---

## Step 3 — Authenticate (read this carefully)

This is the most important step. The bot needs to be logged in to your Continente account to add items to your cart. There are three ways to handle this — **Option A is strongly recommended** and is what most people should use.

---

### 🔑 Option A — Save session (recommended)

**What this does in plain English:**

When you log in to a website in your browser, the site gives your browser a set of "cookies" — small tokens that say "this person is authenticated, let them in." Your browser stores these cookies and sends them automatically every time you visit the site. That's why you don't have to log in again every time you open a new tab.

`--save-session` does exactly the same thing, but for the bot. It opens a real browser window, you log in normally, and the bot captures those cookies and saves them to a file called `session/cookies.json`. From that point on, every time the bot runs, it loads those cookies into its browser before visiting the site — so the site thinks it's already logged in. No username or password is ever stored anywhere.

**How to do it:**

```bash
./run.sh --save-session
```

Here's the exact sequence of events:

**1.** The terminal shows:
```
════════════════════════════════════════════════════════════════
  SAVE SESSION
════════════════════════════════════════════════════════════════

  A browser window will open at the continente.pt login page.
  Log in with your account, then come back here and press Enter.

  Press Enter to open the browser…
```
Press **Enter**.

**2.** A Chromium browser window opens on the continente.pt login page. This is a real browser — not a screenshot, not a simulation. You can click, type, scroll, use 2FA — everything works exactly as in Chrome or Safari.

**3.** Log in to your Continente account as you normally would:
- Enter your email and password
- Complete any 2-factor authentication if your account uses it
- Wait until you see your account homepage (you should see your name or account icon in the header)

**4.** Switch back to the Terminal window (the browser can stay open). You'll see:
```
  → Browser is open. Log in to continente.pt.
  → Once you see your account / homepage, come back here.

  Press Enter once you are logged in…
```
Press **Enter**.

**5.** The bot captures all current cookies from the browser, saves them to `session/cookies.json`, and prints:
```
  ✓ Session saved (47 cookies).
  You can now run the bot normally:

      ./run.sh
```
The browser closes automatically.

---

**What's inside `session/cookies.json`?**

It's a plain JSON file containing all the cookies the browser accumulated during your session. Here's a sample:

```json
[
  {
    "name": "dwsid",
    "value": "abc123xyz...",
    "domain": ".continente.pt",
    "path": "/",
    "expires": 1742000000,
    "httpOnly": true,
    "secure": true
  },
  {
    "name": "dwanonymous_abc",
    "value": "...",
    "domain": ".continente.pt"
  }
]
```

The key cookie is `dwsid` — this is the Salesforce Commerce Cloud session token that proves you're authenticated. As long as this token is valid, the bot is logged in.

---

**How the bot uses the saved session on future runs:**

Every time you run `./run.sh`, the bot starts a fresh Chromium browser in the background. Before navigating to any page, it loads all the cookies from `session/cookies.json` into the browser — exactly as if you had just logged in manually. Then it visits `continente.pt` and checks whether the account menu is visible. If it is, authentication is confirmed and the run begins. The whole check takes about 3 seconds.

```
./run.sh
  │
  ├─ Chromium starts (headless — invisible)
  ├─ Loads cookies from session/cookies.json
  ├─ Navigates to continente.pt
  ├─ Checks for account menu element
  │     ✓ Found → authenticated, start the run
  │     ✗ Not found → session expired → fall back to credentials
  │
  └─ After run: saves refreshed cookies back to session/cookies.json
```

---

**How long does the session last?**

Continente sessions typically stay valid for **2 to 4 weeks**. As long as you run the bot at least once every couple of weeks, the cookies get refreshed automatically (the bot saves updated cookies after every successful run). If you haven't used it in a while and the session has expired, you'll see:

```
  [LOGIN] ✗ Saved session has expired.
```

Just run `./run.sh --save-session` again to re-authenticate. Takes 30 seconds.

---

**Is this safe?**

- `session/cookies.json` is in `.gitignore` — it will **never** be committed to git or uploaded to GitHub, even if you push changes to the repo.
- The file lives only on your local machine, in the `session/` folder inside the project directory.
- The bot sends these cookies only to `continente.pt` — nowhere else. You can verify this by running with `--visible` and watching the browser.
- Treat this file the same way you'd treat a saved password: don't share it, don't email it, don't sync it to a public cloud folder.

> 🔁 **Session expired or bot says it can't log in?**
> ```bash
> ./run.sh --save-session
> ```
> That's all. Redo the 5 steps above. Takes 30 seconds.

---

### 🔑 Option B — `.env` credentials file

This approach stores your email and password in a file that the bot reads at startup. Use it if you prefer not to do the manual login step, or if you're setting the bot up on a machine where you can't interactively open a browser.

```bash
cp .env.example .env
./edit.sh    # or: nano .env / open .env / code .env
```

Fill in your credentials:

```env
CONTINENTE_USER=your@email.com
CONTINENTE_PASS=yourpassword
```

Save the file. On every run, the bot will:
1. Load `.env` automatically via `python-dotenv`
2. Navigate to the login page
3. Fill in your email and password
4. Submit the form
5. Wait for the redirect back to the homepage
6. Confirm authentication, then save the resulting cookies to `session/cookies.json`

So after the first successful `.env` login, the behaviour converges with Option A — the bot uses saved cookies going forward and only falls back to the password if the cookies expire.

> ⚠️ `.env` is in `.gitignore` and will never be committed to git. But it does contain your plaintext password, so don't share the file.

---

### 🔑 Option C — `config.yaml` fields

For quick local testing only. Add these two lines to `config.yaml` (outside the `products:` list):

```yaml
username: "your@email.com"
password: "yourpassword"
```

> ⚠️ `config.yaml` is gitignored, but Option A or B are cleaner. This option is mainly useful for a quick one-off test.

---

### How the bot decides which method to use

On every run, the bot checks in this exact order:

```
1. session/cookies.json exists?
      → Load cookies into browser → navigate to continente.pt → check if logged in
          ✓ Logged in  → proceed with run, refresh cookies at end
          ✗ Not logged in (expired) → fall through to step 2

2. CONTINENTE_USER env var set? (from .env or shell export)
          ✓ Found → perform automated login with credentials
          ✗ Not found → check config.yaml

3. username field in config.yaml?
          ✓ Found → perform automated login with credentials
          ✗ Not found → print setup instructions and exit
```

If you have a saved session, credentials are never touched.

---

## Step 4 — Edit your shopping list

```bash
./edit.sh
```

This opens `config.yaml` in the best editor available on your Mac. Edit your product list, save, close.

**How to find a product URL:**

1. Open [continente.pt](https://www.continente.pt) in Safari or Chrome
2. Search for the product you want
3. Click on it to open the product page
4. Copy the URL from the address bar:
   `https://www.continente.pt/produto/leite-uht-meio-gordo-mimosa-6879912.html`
5. Paste it as the `url:` field in `config.yaml`

Product URLs on Continente are stable — the same URL works for months or years unless the product is discontinued.

---

## Step 5 — Run

```bash
./run.sh
```

What happens:
1. Virtual environment is activated automatically
2. Bot checks session / logs in
3. Each product is processed in order
4. A report is printed and saved to `reports/`
5. The cart page opens — go check out

---

## CLI Reference

| Command | What it does |
|---|---|
| `./run.sh` | Normal headless run (no visible browser) |
| `./run.sh --visible` | Same run with the browser window visible |
| `./run.sh --save-session` | Opens browser for manual login, saves cookies |
| `./edit.sh` | Open `config.yaml` in your best available editor |
| `./install.sh` | First-time setup |
| `./update.sh` | Pull latest code + refresh all packages |
| `./uninstall.sh` | Remove venv, session, reports, Chromium cache |

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `config.yaml not found` | Wrong working directory | `cd continente-hero` first |
| `Virtual environment not found` | `install.sh` not run | Run `./install.sh` |
| `Session expired` or login loop | Cookies too old | Run `./run.sh --save-session` |
| Login fields not found | SSO layout changed | Open an [Issue](https://github.com/paulfxyz/continente-hero/issues) |
| Products not found | Query too specific | Use a broader `query:` or a direct `url:` |
| Out of stock shown | Product unavailable | Normal — report will note it, nothing crashes |
| Timeout errors | Slow connection or site load | Increase `slow_mo: 300` in `config.yaml` |
| TextEdit saved as `.rtf` | Rich Text mode | Format → Make Plain Text, then re-save as `.yaml` |

---

## Security notes

| File | Contains | Gitignored? |
|---|---|---|
| `session/cookies.json` | Live session tokens | ✅ Yes — never committed |
| `.env` | Email + password (if using Option B) | ✅ Yes — never committed |
| `config.yaml` | Shopping list + optional credentials | ✅ Yes — never committed |
| `reports/*.txt` | Run logs (no credentials) | ✅ Yes — never committed |

The bot communicates only with `continente.pt`. No telemetry, no third-party services, no analytics.

---

*MIT — free to use, modify, and share. Created with [Perplexity Computer](https://www.perplexity.ai/)*
