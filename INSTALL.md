# continente-cart — Installation Guide

A macOS-native, dependency-light bot. No Docker, no build steps. Just Python, a virtual environment, and a Chromium browser.

---

## Requirements

| Requirement | Minimum | Notes |
|---|---|---|
| **macOS** | 12 Monterey | Also works on Linux with minor adjustments |
| **Python** | 3.11 | 3.12 or 3.13 work fine too |
| **Disk space** | ~300 MB | ~170 MB for Playwright Chromium + Python venv |
| **Network** | Any | The bot runs locally; continente.pt is accessed over the web |

---

## Step 1 — Clone the repo

```bash
git clone https://github.com/paulfxyz/continente-cart.git
cd continente-cart
```

---

## Step 2 — Install

Run the one-shot installer:

```bash
chmod +x install.sh && ./install.sh
```

This script:
1. Checks for Python 3.11+ (tells you how to install it if missing)
2. Creates a `.venv` Python virtual environment inside the project folder
3. Installs `playwright`, `pyyaml`, and `python-dotenv`
4. Downloads the Playwright Chromium browser (~170 MB)
5. Creates `session/` and `reports/` directories
6. Copies `.env.example` → `.env` if no `.env` exists yet

> ⚠️ **Python not found?** Install it with Homebrew:
> ```bash
> brew install python@3.12
> ```
> Or download from [python.org](https://www.python.org/downloads/).

---

## Step 3 — Authenticate

Choose the method that suits you best.

---

### Option A — Save session (recommended)

This is the cleanest approach. You log in once through a real browser window, your session cookies are saved, and the bot reuses them silently on every future run. No password ever stored in a file.

```bash
./run.sh --save-session
```

What happens:
1. A Chromium window opens at `continente.pt/login/`
2. You log in with your account (manually — the bot does nothing here)
3. Press **Enter** in the terminal once you see your account homepage
4. Cookies are saved to `session/cookies.json`

On all future runs the bot checks this file first. If the session is still valid, it skips the login entirely.

> 🔁 **Session expired?** Just run `./run.sh --save-session` again.

---

### Option B — Environment variables / `.env` file

```bash
cp .env.example .env
nano .env
```

```env
CONTINENTE_USER=your@email.com
CONTINENTE_PASS=yourpassword
```

The bot reads these automatically. The `.env` file is gitignored and stays on your machine only.

---

### Option C — `config.yaml` fields

```yaml
username: "your@email.com"
password: "yourpassword"
```

> ⚠️ `config.yaml` is listed in `.gitignore` and will never be committed. Still, Option A or B are preferable.

---

### Credential priority

```
session/cookies.json   →   CONTINENTE_USER env var   →   config.yaml username
```

---

## Step 4 — Edit your shopping list

```bash
nano config.yaml
```

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

**Tip:** Navigate to any product on continente.pt, copy the URL, paste it as the `url:` field. Most reliable method.

---

## Step 5 — Run

```bash
./run.sh
```

---

## CLI Reference

| Command | What it does |
|---|---|
| `./run.sh` | Normal headless run |
| `./run.sh --visible` | Same run but with the browser window visible |
| `./run.sh --save-session` | Opens browser for manual login, saves cookies |
| `./install.sh` | First-time setup |
| `./update.sh` | Pull latest code + refresh all packages |
| `./uninstall.sh` | Remove venv, session, reports, Chromium cache |

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `config.yaml not found` | Wrong working directory | `cd` into the project folder first |
| `Virtual environment not found` | `install.sh` not run | Run `./install.sh` |
| Bot logs in but gets kicked out | Session expired | Run `./run.sh --save-session` |
| Login fields not found | SSO layout changed | Open an Issue |
| Products not found | Query too specific | Try a broader `query:` or add a direct `url:` |
| Out of stock shown | Product unavailable | Normal — the report will note it |
| Timeout errors | Slow connection | Increase `slow_mo: 300` in `config.yaml` |

---

## Security notes

- `session/cookies.json` contains live auth tokens. It is gitignored and should never be shared.
- `.env` with your password is also gitignored.
- `config.yaml` is gitignored.
- The bot never sends your credentials anywhere other than continente.pt.

---

*MIT — free to use, modify, and share. Created with [Perplexity Computer](https://www.perplexity.ai/)*
