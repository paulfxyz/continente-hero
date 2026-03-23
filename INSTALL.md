# 📦 Installation Guide — continente-hero v2.0.2

This guide covers every installation path, explains the technical choices behind each step, and gives you the tools to debug anything that goes wrong.

---

## 🚀 The fast path (recommended)

Open **Terminal** (`⌘ Space` → type Terminal → Enter) and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/paulfxyz/continente-hero/main/setup.sh | bash
```

That one command handles everything — Python, the repo, the virtual environment, all packages, Chromium, and the `shop` alias. When it finishes, type:

```bash
source ~/.zshrc   # activate the alias in this tab
shop              # open the menu
```

> **Want to read the script before running it?** That's a healthy instinct. Any time you're asked to pipe a script from the internet into bash, reading it first is smart:
> ```bash
> curl -fsSL https://raw.githubusercontent.com/paulfxyz/continente-hero/main/setup.sh -o setup.sh
> cat setup.sh     # read it
> bash setup.sh    # run it
> ```

---

## 📋 System requirements

| Requirement | Version | Notes |
|---|---|---|
| macOS | Any modern version | Tested on Apple Silicon (M-series) and Intel |
| Python | 3.11, 3.12, or 3.13 | **3.14 is blocked** — see [why](#-why-python-314-is-blocked) |
| Homebrew | Any | Only needed if Python 3.11–3.13 is not installed |
| git | Any | Comes with Xcode Command Line Tools |
| Disk space | ~500 MB | ~170 MB Chromium + ~300 MB venv |
| Internet | Required | For install, Chromium download, and first session save |

---

## 🐍 Why Python 3.14 is blocked

This is the most common installation problem, so it deserves a full explanation.

### The dependency chain

```
continente-hero
└── playwright (Python package)
    └── greenlet (C extension — must be compiled)
        └── requires: <cstdlib> C++ standard library header
            └── NOT shipped by Apple's Clang on current macOS toolchains
```

### What happens when you try

```
src/greenlet/greenlet.cpp:9:10: fatal error: 'cstdlib' file not found
    9 | #include <cstdlib>
      |          ^~~~~~~~~
1 error generated.
error: command '/usr/bin/clang++' failed with exit code 1
```

`greenlet` is a C extension. pip installs C extensions from pre-built binary wheels when available — no compilation needed. But `greenlet` does not publish a wheel for Python 3.14 yet. When no wheel exists, pip falls back to compiling from source, which fails because Apple's Clang (the compiler that comes with macOS) is missing `<cstdlib>` — a C++ standard library header that `greenlet`'s source code needs.

### Why not just fix the compiler?

You could install Apple's full Xcode or the LLVM libc++ headers, but that's a complex and fragile path. The clean solution is simply to use Python 3.13, where a pre-built wheel for `greenlet` exists and installs instantly.

### What setup.sh does about it

`setup.sh` detects Python 3.14 during the Python scan and immediately installs Python 3.13 via Homebrew — automatically, without any prompts:

```bash
brew install python@3.13 >&2
```

Note the `>&2`: brew's output is redirected to stderr. This is important when running via `curl | bash` — see [the pipe bug](#-the-curl--bash-stdin-pipe-bug) below.

---

## 🔧 What `setup.sh` does, step by step

### Step 1 — macOS check
Warns if not macOS. Continues anyway — the script may work on Linux but is untested.

### Step 2 — Python detection
Tries these in order, stops at the first compatible version:
```
python3.13  →  python3.12  →  python3.11  →  python3
/opt/homebrew/bin/python3.13  →  ...3.12  →  ...3.11   (Apple Silicon Homebrew)
/usr/local/bin/python3.13     →  ...3.12  →  ...3.11   (Intel Mac Homebrew)
```
`python3` (bare, no version suffix) is tried last intentionally — on many Homebrew setups it points to the most recently installed Python, which may be 3.14.

If no compatible Python is found and Homebrew is available: runs `brew install python@3.13 >&2` automatically and re-scans.

### Step 3 — Clone or update repo
- **First run:** `git clone` into `~/continente-hero`
- **Re-run:** `git fetch` then `git reset --hard origin/main`

`git reset --hard` instead of `git pull` is a deliberate choice. `git pull` aborts if any local file differs from the remote — this happens every time `chmod +x install.sh` modifies the file's metadata. `reset --hard` discards all local modifications and brings the tree to exactly what's on GitHub. For an install/repair script, this is always the right behaviour.

### Step 4 — Permissions
```bash
chmod +x ~/continente-hero/*.sh
```
`git clone` does not preserve execute bits. Without this step, every `.sh` file would produce `permission denied` when you try to run it.

### Step 5 — Virtual environment
Always **wipes and rebuilds** the `.venv` from scratch. This is intentional. A venv built with Python 3.14 will silently produce a broken environment — all the packages appear to install but `playwright` won't work. Starting clean every time takes 10 extra seconds and eliminates an entire class of subtle bugs.

### Step 6 — Playwright Chromium
```bash
~/continente-hero/.venv/bin/playwright install chromium >&2
```
The full venv path is used instead of the bare `playwright` command. On zsh (the default shell on modern macOS), the shell's command hash table doesn't always update after venv activation in a non-interactive script context. The bare `playwright` command can silently resolve to nothing, meaning Chromium never gets downloaded and the bot fails at runtime with a cryptic browser-not-found error.

### Step 7 — Register `shop` alias
Appends to `~/.zshrc` (or `~/.bashrc`):
```bash
alias shop='bash ~/continente-hero/shop.sh'
```
The alias update logic removes any previous `shop=` line before writing the new one, so re-running `setup.sh` (e.g. after moving the install directory) always produces exactly one correct alias entry.

---

## 🐛 The `curl | bash` stdin pipe bug

> This was the hardest bug in this project to track down. It's documented here because it's a fundamental `curl | bash` gotcha that affects any installer written this way.

### How `curl | bash` works

```
curl fetches setup.sh content
        ↓
        pipe (stdin)
        ↓
bash reads commands from stdin
        ↓
bash executes them one by one
```

### The bug

Any command running inside that bash session that writes to **stdout** puts those bytes directly into the same pipe that bash is reading its instructions from. Bash then tries to execute them as shell commands.

`brew install python@3.13` outputs several hundred lines:
- Download progress bars
- `==> Pouring python@3.13...`
- `==> Caveats`
- `Python is installed as /opt/homebrew/bin/python3.13`
- Code-looking text: `brew install python3`, `idle3.13 requires tkinter`

When those lines fed into bash's stdin, bash attempted to execute them. The result was the bizarre output Paul saw in his terminal: actual source code from `setup.sh` printed as if it were running, mixed with `command not found` errors for brew's caveats text.

### The fix

Redirect all external command stdout to stderr:
```bash
brew install python@3.13 >&2
git clone ... >&2
git reset --hard origin/main >&2
pip install ... >&2
playwright install chromium >&2
```

`>&2` sends stdout to stderr. Stderr goes directly to the terminal (the user still sees all output) but does **not** feed into the stdin pipe that bash is reading. The pipe stays clean.

This is why security-conscious developers always recommend `curl ... -o script.sh && bash script.sh` over `curl ... | bash` — the pipe mode has this inherent stdin contamination risk.

---

## 🛠️ Manual installation (if curl | bash doesn't work)

```bash
# 1. Install Python 3.13 if needed
brew install python@3.13

# 2. Clone the repo
git clone https://github.com/paulfxyz/continente-hero.git ~/continente-hero
cd ~/continente-hero

# 3. Make scripts executable
chmod +x *.sh

# 4. Run the local installer
./install.sh

# 5. Add the shop alias
echo "" >> ~/.zshrc
echo "# continente-hero" >> ~/.zshrc
echo "alias shop='bash ~/continente-hero/shop.sh'" >> ~/.zshrc
source ~/.zshrc
```

---

## 🔐 How the session connection works

This is the recommended authentication method — and understanding it will help you trust it.

### The concept: cookies, not passwords

When you log in to any website, the server creates a **session** and gives your browser a cookie — a short random token (like `abc123xyz`) that acts as a temporary ID card. Every subsequent request your browser makes sends that cookie, and the server says "ah yes, I know you — you're logged in."

continente-hero saves this cookie to `session/cookies.json` and reuses it. Your password never touches the bot.

### The full flow

```
You run:  shop  →  Option 2 (Save session)
                         ↓
         Playwright opens a real Chromium browser
         on the continente.pt login page
                         ↓
         You type your email + password yourself
         (the bot is idle — it just holds the window open)
                         ↓
         Continente's server creates a session
         and sends cookies to the browser
                         ↓
         You press Enter in the Terminal
                         ↓
         Playwright reads the browser's cookie jar
         and saves it to:  session/cookies.json
                         ↓
         Every future run:  bot loads cookies → already logged in
         No password. No typing. Instant.
```

### What's actually saved

`session/cookies.json` contains only HTTP session tokens:

```json
[
  {
    "name": "dwsid",
    "value": "abcXYZ123...",
    "domain": ".continente.pt",
    "httpOnly": true,
    "secure": true
  }
]
```

| Cookie | What it does |
|---|---|
| `dwsid` | Salesforce Commerce Cloud session ID — the main auth token |
| `dwanonymous` | Guest/anonymous tracking token (present even when logged in) |
| `dw_*` | Demandware preference and cart state cookies |

### Security notes

- `session/cookies.json` is in `.gitignore` — **never committed to GitHub**
- `config.yaml` is also in `.gitignore`
- Sessions typically last weeks to months
- These cookies are equivalent to "staying logged in" in your browser — if someone gets this file, they can act as you on continente.pt until the session expires
- Store the `session/` directory only on your own machine

### Credential priority (for the technical reader)

The bot checks these in order, using the first that works:

```
1. session/cookies.json          ← best: no password stored anywhere
2. CONTINENTE_USER + CONTINENTE_PASS env vars  ← via .env file or shell
3. username + password in config.yaml          ← least recommended
```

### When to re-save your session

- The bot says you're not logged in / redirects to login page
- Reports show unexpected "not found" for products you know exist (cart may have been rejected)
- After ~1–3 months (session expiry is server-side, varies)

Just run **Option 2** from the `shop` menu — takes 30 seconds.

---

## 🗂️ Multiple shopping lists

Keep different lists for different occasions. All extra lists live in `configs/`:

```
~/continente-hero/
├── config.yaml          ← active list (always what the bot reads)
└── configs/
    ├── weekly.yaml
    ├── party.yaml
    └── pantry.yaml
```

Switch between them via **Option 4** in the `shop` menu. You can also create new ones from the menu — it copies your current config as a starting point.

---

## 🔄 Updating

Use **Option 5** in the `shop` menu, or:

```bash
cd ~/continente-hero && ./update.sh
```

This runs `git reset --hard origin/main` (same logic as `setup.sh` — bypasses local-change conflicts), upgrades all Python packages, and updates Chromium.

---

## 🧹 Uninstalling

```bash
cd ~/continente-hero && ./uninstall.sh
```

This removes: `.venv`, `session/`, `reports/`, Playwright Chromium cache. Your `config.yaml` and `configs/` are preserved.

To remove everything:
```bash
rm -rf ~/continente-hero
```

Remove the alias from `~/.zshrc`:
```bash
# Delete this line:
# alias shop='bash ~/continente-hero/shop.sh'
```

---

## 🔍 Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `zsh: command not found: shop` | Alias not active in current tab | `source ~/.zshrc` or open a new Terminal tab |
| `zsh: permission denied: ./run.sh` | Execute bit missing | Run `setup.sh` again — it runs `chmod +x` on all scripts |
| `'cstdlib' file not found` | Python 3.14 + no greenlet wheel | `setup.sh` handles this automatically — run the curl command |
| `error: Your local changes would be overwritten` | `git pull` blocked by local chmod changes | Use `setup.sh` — it uses `git reset --hard` instead |
| `playwright: command not found` | zsh didn't rehash after venv activation | `setup.sh` uses the full venv path — run it to reinstall |
| Bot runs but cart is empty | Session expired or not saved | Run **Option 2** in `shop` menu |
| `git clone: destination already exists` | Repo folder already there | Use `setup.sh` — it handles existing repos cleanly |
| Chromium download hangs | Slow internet or proxy | Let it run — it's ~170 MB. Use `bash -x setup.sh` to see live progress |

---

*Designed and built in collaboration with [Perplexity Computer](https://www.perplexity.ai/)*
