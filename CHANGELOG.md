## 🔖 [2.1.3] — 2026-03-23

### ⚡ Feat — Exponential backoff + page-reload escape hatch for clear cart timeouts

#### The problem

After v2.1.2 delivered a working clear-cart flow, real-world use exposed a second failure mode: **XHR stalls**. SFCC's cart endpoint occasionally hangs under load. The optimistic UI removes the item from the DOM instantly, but the server-side cart state update never completes — the count drops for a moment and then bounces back, or the page just hangs.

Naively retrying immediately made things worse. The already-overloaded endpoint received a flood of requests, causing further stalls. A single stuck item could spin for the entire run timeout without making progress.

---

#### The fix — `_clear_loop()` shared engine

Both `clear_cart()` (the headless method) and `clear_cart_interactive()` now delegate the entire removal sequence to a single **`_clear_loop(page, selector)`** helper. This eliminates duplicated logic and makes the retry behaviour consistent regardless of which code path is used.

`_clear_loop()` implements a five-layer resilience strategy:

**Layer 1 — Count-drop polling (200 ms tick, 8 000 ms ceiling)**

Rather than waiting a fixed time after each click, the bot polls the DOM every 200 ms and moves to the next item the moment the button count drops. Fast on a good connection (~100–300 ms), patient on a slow one.

```python
async def _poll_count_drop(current_count: int) -> bool:
    while elapsed < CLEAR_TIMEOUT:
        await page.wait_for_timeout(200)
        remaining = await page.query_selector_all(selector)
        if len(remaining) < current_count:
            return True
    return False
```

**Layer 2 — Exponential backoff ladder on timeout**

If the poll times out (8 s with no count drop), the bot waits before retrying. Wait time escalates with each consecutive failure:

| Attempt | Wait |
|---|---|
| 1st timeout | 2 s |
| 2nd timeout | 5 s |
| 3rd timeout | 15 s |
| 4th timeout | 30 s |
| 5th+ timeout | 60 s |

The ladder is capped at 60 s — once you're at the last rung, it stays there. `asyncio.sleep()` is used for all backoff waits (not `page.wait_for_timeout()`). The distinction matters: `page.wait_for_timeout()` schedules a Playwright-internal timer and blocks the Python event loop for the duration. `asyncio.sleep()` yields to the event loop, keeping the browser window alive and responsive during long waits (30–60 s).

**Layer 3 — Page-reload escape hatch every 3 consecutive timeouts**

A stuck XHR can leave React's cart state in a half-updated limbo. Reloading the cart page forces a fresh server-side fetch, clearing any in-flight request and re-rendering the cart from ground truth.

```python
if consecutive_fails % CLEAR_RELOAD_AT == 0:  # every 3 failures
    await page.reload(wait_until="domcontentloaded")
    await page.wait_for_timeout(2_500)  # wait for React to hydrate
```

**Layer 4 — Skip + move on after 5 consecutive failures**

If an item cannot be removed after 5 consecutive attempts, it is added to the skip queue and the bot moves on. No single item should block the entire run. The consecutive failure counter resets to zero so the next item starts fresh.

**Layer 5 — Retry pass at the end**

After the main loop, if any items were skipped, the bot does one final reload and attempts each skipped item once more. By this point, the transient server pressure that caused the original stalls has typically cleared.

---

#### Return value

`_clear_loop()` returns a `(removed: int, skipped: int)` tuple. Both call sites unpack and report this cleanly:

```
[CLEAR CART] ✅  Removed 12 item(s). ⚠ 1 item(s) timed out and were skipped.
[CLEAR CART] Refresh the cart in your browser to verify.
```

---

#### Code quality improvements in this release

- `REMOVE_SELECTOR` hoisted from two local variable definitions to a **module-level constant** alongside the other SFCC constants — single source of truth, consistent with `CLEAR_TIMEOUT`, `CLEAR_BACKOFF`, etc.
- Redundant `import asyncio` inside `_clear_loop()` body removed — `asyncio` is already imported at module level (line 36).
- All cart-clear tuning constants grouped under a dedicated block comment:
  ```python
  # ── Cart-clear retry / backoff tuning ────────────────────────────
  REMOVE_SELECTOR  = 'button[aria-label="Apagar produto"]'
  CLEAR_TIMEOUT    = 8_000
  CLEAR_BACKOFF    = [2, 5, 15, 30, 60]
  CLEAR_RELOAD_AT  = 3
  CLEAR_GIVE_UP_AT = 5
  CLEAR_MAX_SKIPS  = 5
  ```

---

#### Summary of changes

- ⚡ `feat:` `continente.py` — `_clear_loop()` shared engine with full retry architecture
- ⚡ `feat:` `continente.py` — exponential backoff ladder `[2, 5, 15, 30, 60]` s
- ⚡ `feat:` `continente.py` — page-reload escape hatch every 3 consecutive timeouts
- ⚡ `feat:` `continente.py` — skip queue + retry pass for items that could not be removed
- 🧹 `refactor:` `continente.py` — `REMOVE_SELECTOR` hoisted to module-level constant
- 🧹 `refactor:` `continente.py` — redundant `import asyncio` removed from `_clear_loop()` body
- 🏷️ `bump:` version banners → v2.1.3 in all five `.sh` files + README badge
- 📖 `docs:` `README.md` — “Clear your cart” section expanded with retry behaviour table
- 📖 `docs:` `README.md` — new **Challenge #12** section: SFCC XHR timeouts, backoff design, and `asyncio.sleep` vs `wait_for_timeout` explanation

---

## 🔖 [2.1.2] — 2026-03-23

### 🐛 Fix — Clear cart only removed 1 item (wrong selectors + wrong wait strategy)

#### Root cause — the DOM inspection findings

All ten CSS selectors in the original `REMOVE_SELECTORS` list were wrong. Live DOM inspection of the actual continente.pt cart page revealed:

| What we tried | What actually exists |
|---|---|
| `button.remove-product` | ❌ no such class |
| `button[data-action='remove']` | ❌ no such attribute |
| `.cart-item__remove button` | ❌ no such class |
| `button[aria-label='Remover']` | ❌ wrong Portuguese — the tooltip says "Remover" but the `aria-label` is different |
| `button[aria-label='Remove']` | ❌ wrong language entirely |
| …all others | ❌ not present |

The actual remove button HTML:
```html
<button aria-label="Apagar produto" title="Remover produto">
  <img src="[trash-icon.svg]" />
</button>
```

**"Apagar produto"** is Portuguese for "Delete product". No class names containing "remove", "delete", "apagar", or "eliminar" are present. The correct selector is:

```python
REMOVE_SELECTOR = 'button[aria-label="Apagar produto"]'
```

This returns all 30 buttons on a full cart. Our old selectors returned 0. The first click happened to work because Playwright sometimes resolves partial matches — but it found the button by a different path and could not find it again for subsequent items.

---

#### Root cause — the wait strategy

The original code used `wait_for_element_state("detached")` to detect when SFCC had processed a removal. This was wrong for two reasons:

1. **Optimistic UI** — continente.pt removes the item from the DOM **immediately and synchronously** on click, before the XHR response returns. The element is already "detached" before we even register the wait, so Playwright either times out or races past it.

2. **"Anular" undo row** — after removal, an inline "Produto removido" + "Anular" (undo) row appears in the same slot. Clicking the next remove button too quickly can interfere with SFCC's cart state while the undo window is still active, occasionally causing the item to be re-added.

**The correct wait strategy:**

```python
# Count buttons BEFORE clicking
btns = await page.query_selector_all(REMOVE_SELECTOR)
count_before = len(btns)

await btn.click()

# Poll until the count drops — confirms optimistic update completed
for _ in range(80):          # max 8 seconds
    await page.wait_for_timeout(100)
    remaining = await page.query_selector_all(REMOVE_SELECTOR)
    if len(remaining) < count_before:
        break

# Extra 600 ms for the "Anular" undo row to settle
await page.wait_for_timeout(600)
```

Total per-item cost: ~700 ms on a fast connection, ~2 s on a slow one. For a 30-item cart this takes about 20–60 seconds — reasonable and reliable.

---

#### Summary of changes

- 🐛 `fix:` `continente.py` — `clear_cart_interactive()`: replaced 10 wrong selectors with `button[aria-label="Apagar produto"]`
- 🐛 `fix:` `continente.py` — `clear_cart()` method: same selector fix
- 🐛 `fix:` `continente.py` — wait strategy replaced: count-drop polling + 600 ms undo-row settle, replaces broken `wait_for_element_state("detached")`
- 🏷️ `bump:` version banners → v2.1.2 in all five `.sh` files + README badge

---

## 🔖 [2.1.1] — 2026-03-23

### 🐛 Fix — Clear cart: session fallback + integrated login flow

#### The bug

`--clear-cart` called `bot.login()`, which:
1. Tried saved session cookies → expired or missing → fell through
2. Tried `CONTINENTE_USER` / `CONTINENTE_PASS` env vars → not set
3. Tried `username` / `password` in `config.yaml` → not set (most users don't store credentials there)
4. Printed `[ABORT] Cannot proceed without authentication` and exited

The result: clear cart was unusable unless the user had a live session **and** it happened to still be valid. No recovery path.

---

#### The fix — `clear_cart_interactive()`

Replaced the `ContinenteBot`-based flow with a new standalone `clear_cart_interactive()` function that handles the full lifecycle in a **single continuous Playwright session**:

```
Launch visible browser
  ↓
Load saved session cookies (if any)
  ↓
Check login state (7 s timeout)
  ├── Logged in → go straight to cart clear
  └── Not logged in → navigate to login page
                       prompt: "log in and press Enter"
                       wait for Enter
                       verify login
                       save fresh cookies to disk
                           ↓
                       proceed to cart clear (same browser context)
```

The browser **never closes and reopens** between login and clearing. This matters because SFCC session cookies are bound to the browser context that authenticated them. Saving to disk and loading into a new context can trigger a CSRF / session validation check and silently log the user out. Keeping one continuous context avoids this entirely.

After clearing, the browser stays open on the empty cart page so the user can visually confirm everything is gone, then presses Enter to close and return to the `shop` menu.

---

#### Why a standalone function instead of extending `ContinenteBot`

`ContinenteBot.__enter__` loads cookies and immediately calls `new_page()` — by the time `login()` runs, the context is already committed to the saved session (or lack of one). To do an interactive login fallback we would need to restructure the bot's startup sequence. Easier and cleaner to have a purpose-built function for this one flow that owns its entire browser lifecycle.

---

#### Changes in this patch

- 🐛 `fix:` `continente.py` — new `clear_cart_interactive()` function replaces the inline `--clear-cart` block; handles session expiry with interactive login fallback in the same browser context
- 🐛 `fix:` `continente.py` — `--clear-cart` path now always runs `headless=False`; browser stays open after clearing for visual confirmation; Press Enter to close
- 🏷️ `bump:` version banners → v2.1.1 in all five `.sh` files + README badge

---

## 🔖 [2.1.0] — 2026-03-23

### ✨ Feature — Option 2: Clear my cart

New menu option that empties your entire Continente cart in one step. Useful when you loaded the wrong shopping list and want a clean slate before re-running the bot.

```
📂  shop menu

  1)  🛒  Fill my cart              (run the bot)
  2)  🗑️   Clear my cart             (remove all items)   ← NEW
  3)  🔐  Save / refresh session    (log in once)
  4)  ✏️   Edit shopping list        (opens editor)
  5)  📂  Manage shopping lists    (select, browse, create)
  6)  🔄  Update continente-hero    (pull latest)
  7)  👋  Quit
```

---

#### How it works

The shell menu option calls `python continente.py --clear-cart`, which:

1. Logs in via saved session cookies
2. Navigates to `https://www.continente.pt/checkout/carrinho/`
3. Dismisses the cookie banner if present
4. Iterates: find a remove button → click it → wait for it to detach from the DOM → repeat
5. Stops when no more remove buttons are found (cart is empty)
6. Saves refreshed session cookies

Runs with a **visible browser** by default — not because headless wouldn't work, but because watching items disappear builds trust that it actually worked. There is no "cart is empty" confirmation screen in SFCC; the visual feedback is the most reliable signal.

---

#### The SFCC React re-render problem (bottleneck)

This is the most technically interesting part of this feature and the reason it lives in Python rather than bash.

Continente.pt's cart is a **React SPA**. When you click a remove button:
- SFCC fires an XHR to its API
- React receives the response and re-renders the cart item list in place
- The old DOM nodes are **replaced entirely** — they are not just hidden

This means you **cannot** collect all remove buttons upfront and iterate them:

```python
# WRONG — stale NodeList after first removal:
buttons = await page.query_selector_all("button.remove-product")
for btn in buttons:
    await btn.click()   # btn 2, 3, 4... are detached after first click
```

The correct pattern is to re-query on every iteration:

```python
# CORRECT — fresh query each time:
while True:
    btn = await page.query_selector("button.remove-product")
    if not btn:
        break
    await btn.click()
    await btn.wait_for_element_state("detached")  # wait for DOM update
```

`wait_for_element_state("detached")` is Playwright's way of knowing the XHR completed and React re-rendered. It is much more reliable than a fixed `sleep` — on fast connections the detach happens in under 200 ms; on slow connections it might take 2+ seconds. The fixed fallback (`wait_for_timeout(1500)`) only kicks in if `wait_for_element_state` itself raises (e.g. the element was already detached before we could register the wait).

A safety cap of 50 iterations prevents an infinite loop if the cart somehow keeps showing a remove button even after clicking it.

---

#### Selector resilience

SFCC's cart page uses different CSS class names across themes and releases. Ten selectors are tried in priority order:

```python
REMOVE_SELECTORS = [
    "button.remove-product",           # SFCC default theme
    "button[data-action='remove']",    # data-action variant
    ".cart-item__remove button",       # nested button
    "button.btn-remove-item",          # alternative class
    "button[aria-label='Remover']",    # aria-label (PT)
    "button[aria-label='Remove']",     # aria-label (EN)
    ".product-info__remove button",    # product-info block
    "[data-action='remove-product'] button",
    ".ct-cart-item__remove button",    # ct- prefix theme
    "button.icon-close[data-pid]",     # icon + pid attribute
]
```

If continente.pt ever changes their cart DOM, updating this list is the only thing needed.

---

#### Changes in this release

- ✨ `feat:` `continente.py` — new `clear_cart()` async method + `--clear-cart` CLI flag
- ✨ `feat:` `shop.sh` — new Option 2 `_clear_cart()` with confirmation prompt; all other options renumbered 3–7
- 🏷️ `bump:` version banners → v2.1.0 in all five `.sh` files
- 📖 `docs:` `README.md` — badge v2.1.0, menu display updated, new "Clear your cart" section
- 📖 `docs:` `CHANGELOG.md` — this entry with SFCC React re-render bottleneck deep-dive

---

# 📝 Changelog

*Made with ❤️ by Paul Fleury — [@paulfxyz](https://github.com/paulfxyz)*

All notable changes to this project are documented here.
This project follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and [Semantic Versioning](https://semver.org/).

---

## 🔖 [2.0.4] — 2026-03-23

### 🔧 Audit — stale version banners in `install.sh` and `uninstall.sh`

Full cross-file version audit revealed two files that were missed in previous bumps:

- `install.sh` banner still read `v2.0.2` — corrected to `v2.0.4`
- `uninstall.sh` banner still read `CONTINENTE CART BOT — Uninstall` (the old pre-rename branding from v1.x) — corrected to `CONTINENTE HERO — Uninstall  (v2.0.4)`

No functional changes — purely a consistency and branding audit pass.

#### Changes in this patch

- 🏷️ `fix:` `install.sh` — banner version corrected from v2.0.2 → v2.0.4
- 🏷️ `fix:` `uninstall.sh` — banner renamed from `CONTINENTE CART BOT` → `CONTINENTE HERO` + version added
- 🏷️ `bump:` version banners → v2.0.4 in `shop.sh`, `setup.sh`, `update.sh`
- 📖 `docs:` `README.md` — badge + menu display updated to v2.0.4

---

## 🔖 [2.0.3] — 2026-03-23

### ✨ Feature — Option 4 is now a full list management sub-menu

The old Option 4 ("Switch shopping list") was a single flat numbered picker. Useful, but limited: to get to a list you had to already know it existed. There was no way to inspect, add, or organise lists without dropping to the Finder or using a text editor outside the app.

v2.0.3 replaces that single screen with a three-option sub-menu:

```
📂  Manage Shopping Lists

  1)  ✅  Select active list   (choose which list the bot runs)
  2)  📂  Open lists folder    (browse, edit, add or delete lists in Finder)
  3)  ✨  Create new list      (copies current config as a starting point)

  4)  ↩  Back to main menu
```

---

#### Sub-option breakdown

**✅ Select active list** — the picker now shows a `● active` marker next to whichever list is currently selected. If only the default `config.yaml` exists, the picker tells you so and directs you to the other two options instead of presenting a useless one-item list.

**📂 Open lists folder** — runs `open "$CONFIGS_DIR"` (macOS Finder). This is the most requested UX pattern: letting people manage files with the tools they already know. Rename, duplicate, drag in a list from another machine, delete — all without learning any shell commands. If `configs/` is empty, it auto-creates `weekly.yaml` as a sample so Finder doesn't open to a blank folder.

**✨ Create new list** — prompts for a name, sanitises it (strips anything that isn’t alphanumeric, dash, or underscore), copies the current active config as the starting template, and asks whether to activate the new list immediately. This means you can go from zero to a second named list in about 10 seconds without leaving the terminal.

---

#### The symlink design (why config.yaml is always the active file)

This is worth explaining once because it shapes the entire multi-config system.

`continente.py` always reads `config.yaml`. It has no knowledge of `configs/`, list names, or any switching logic. This is intentional: keeping the Python bot simple means the shell layer can evolve independently.

When you switch lists, `shop.sh` does one of two things:
- **Activating a `configs/*.yaml`**: `ln -sf configs/weekly.yaml config.yaml` — config.yaml becomes a symlink pointing into `configs/`.
- **Reverting to the default**: if config.yaml is currently a symlink, it is removed and replaced with a real file (copied from the symlink target), so the default standalone config is restored.

This means:
1. Backups are automatic — all lists live in `configs/`, never overwritten by switching
2. `continente.py` never needs a flag like `--config=weekly.yaml`
3. Finder and any editor work correctly — they follow the symlink transparently

---

#### Bottleneck: symlink vs real-file duality

The tricky edge case was the transition between a symlink `config.yaml` and a real-file `config.yaml`. The first time you ever use multi-config, `config.yaml` is a real file (no symlink). You create `configs/weekly.yaml` as a copy of it, activate `weekly.yaml` — now `config.yaml` is a symlink. If you later revert to "default", we can’t just `rm config.yaml` (that would leave nothing). We also can’t just create a new symlink back to itself. The fix:

```bash
# Before creating the first symlink, always save the real file into configs/
if [[ ! -L "$ACTIVE_CONFIG" ]]; then
    cp "$ACTIVE_CONFIG" "$CONFIGS_DIR/_config_backup.yaml"
fi
ln -sf "$selected_path" "$ACTIVE_CONFIG"
```

And when reverting to the default:
```bash
if [[ -L "$ACTIVE_CONFIG" ]]; then
    backup_src=$(readlink "$ACTIVE_CONFIG")
    rm "$ACTIVE_CONFIG"
    cp "$backup_src" "$ACTIVE_CONFIG"   # materialise back to a real file
fi
```

This ensures config.yaml always exists as a readable file regardless of what state the multi-config system is in.

---

#### Changes in this release

- ✨ `feat:` `shop.sh` — `_switch_list()` replaced by `_manage_lists()` sub-menu with three sub-functions:
  - `_select_list()` — numbered picker with `● active` marker, graceful empty-state message
  - `_open_lists_folder()` — `open "$CONFIGS_DIR"` (Finder), auto-creates `weekly.yaml` sample if empty
  - `_create_list()` — name prompt, sanitisation, copy-from-active, optional immediate activation
- 🏷️ `fix:` main menu label updated: `Switch shopping list` → `Manage shopping lists`
- 🏷️ `bump:` version banners → v2.0.3 in `shop.sh`, `setup.sh`, `update.sh`
- 📖 `docs:` `README.md` — badge v2.0.3, menu block updated, Option 4 section rewritten with sub-menu breakdown and symlink design explanation
- 📖 `docs:` `CHANGELOG.md` — this entry

---

## 🔖 [2.0.2] — 2026-03-23

### 🐛 Critical fix — `greenlet` wheel missing on macOS 26 + Python 3.14 now supported

This patch fixes the installer crash on macOS 26 (Tahoe/Sequoia) — the `cstdlib file not found` compilation error that affected both Python 3.13 and 3.14.

---

#### Root cause

`requirements.txt` previously pinned `playwright==1.44.0`, which resolves `greenlet==3.0.3` as a dependency. `greenlet` is a C extension. When pip cannot find a pre-built wheel for the current OS/Python combination, it falls back to compiling from source.

`greenlet 3.0.3` was released before macOS 26 (Tahoe) existed. Its wheel tag is `macosx_11_0_arm64`, which pip correctly identifies as compatible with newer macOS versions — but the pip wheel resolver on macOS 26 reports the platform tag as `macosx_26_0_arm64`, and the fallback source build fails because Apple's SDK ships without the `<cstdlib>` C++ header that `greenlet` requires:

```
src/greenlet/greenlet.cpp:9:10: fatal error: 'cstdlib' file not found
```

This happened regardless of whether Python 3.13 or 3.14 was used.

#### The fix

Updated `requirements.txt` to `playwright>=1.50.0`. Playwright 1.50+ depends on `greenlet>=3.1.1`, which ships a pre-built `macosx_11_0_universal2` wheel for every Python version including 3.13 and 3.14. Universal2 wheels work on all macOS versions — no compilation, no SDK dependency.

Added `--upgrade` flag to `pip install` in both `setup.sh` and `install.sh` to ensure stale cached wheels are never reused.

#### Python 3.14 now supported

Previous versions blocked Python 3.14 explicitly. With `greenlet 3.3+` having a `cp314-cp314-macosx_11_0_universal2` wheel, Python 3.14 works correctly. The Python version check has been updated to accept 3.11–3.14.

---

#### Changes in this patch

- 🐛 `fix:` `requirements.txt` — `playwright==1.44.0` → `playwright>=1.50.0` (resolves greenlet 3.3+ with universal2 wheels)
- 🐛 `fix:` `setup.sh` — `pip install --upgrade` to bust stale cached wheels
- 🐛 `fix:` `install.sh` — same `pip install --upgrade` fix
- ✅ `feat:` `setup.sh` + `install.sh` — Python 3.14 unblocked, now accepted
- 🐛 `fix:` `setup.sh` — banner version corrected to v2.0.2 (was showing v2.0.1)
- 🐛 `fix:` `install.sh` — banner version corrected to v2.0.2 (was showing v1.2.4)
- 💬 `ux:` `setup.sh` — final output now shows a standalone bold `source ~/.zshrc` command as the required next step, with explanation of why the subshell can’t do it automatically
- 🏷️ `fix:` `shop.sh` + `update.sh` banners updated to v2.0.2
- 📖 `docs:` `README.md` — version badge 2.0.2, Python badge 3.11–3.14, greenlet fix explained, new bottleneck #10 (subshell isolation)
- 📖 `docs:` `INSTALL.md` — header updated to v2.0.2

---

#### Why `shop` wasn’t working after install (subshell isolation)

This is worth explaining because it confused nearly every user.

When the installer runs as `curl URL | bash`, bash is a **child process** of the user’s zsh session. The installer correctly writes `alias shop='...'` to `~/.zshrc`. But then it exits — and with it, its entire environment. The parent zsh never reloads `~/.zshrc` just because a child wrote to it.

This is not a bug. It is a fundamental POSIX rule: **no process can modify the environment of its parent.** macOS, Linux, every Unix system works this way. Even Homebrew can’t work around it — which is why `brew install` also tells you to run `eval "$(brew shellenv)"` after first install.

**The only solutions:**
1. Source the rc file manually: `source ~/.zshrc`
2. Open a new terminal tab (loads rc file on startup)
3. Use the alias-free fallback: `bash ~/continente-hero/shop.sh`

v2.0.2 makes option 1 unmissable — it’s now the first thing you see after a successful install, displayed as a large bold standalone command.

---

## 🔖 [2.0.1] — 2026-03-23

### 🐛 Critical fix — `curl | bash` stdin pipe contamination

This patch resolves the root cause of every installation failure reported since v1.3.0: the `curl -fsSL URL | bash` pipe was being contaminated by stdout output from subprocesses (`brew`, `git`, `pip`, `playwright`), causing bash to interpret tool output as commands.

---

#### The bug — technical explanation

When bash is invoked as `curl URL | bash`, it reads its script from **stdin** — the same file descriptor connected to curl's output. This is how the pipe works: curl writes the script, bash reads it.

The problem is that stdin remains "live" throughout the script's execution. Any child process that writes to **stdout** is writing to the same file descriptor that bash is using to read its next commands. Bash then interprets that output as shell code.

`brew install python@3.13` is a prime offender. It outputs:
- Download progress lines (harmless but noisy)
- Path configuration blocks that look like shell commands
- Lines matching the variable names used in our script (`section`, `REPO_URL`, etc.)

The result was non-deterministic: the installer appeared to succeed but skipped critical steps, or it crashed mid-run with errors like `command not found: section`, or the `shop` alias was never written because the alias-writing block had already been "consumed" from stdin.

#### The fix

Every subprocess that writes to stdout now redirects to stderr:

```bash
brew install python@3.13                     >&2
git clone "$REPO_URL" "$CONTINENTE_DIR"      >&2
git reset --hard origin/main                  >&2
pip install -r requirements.txt               >&2
"$VENV_DIR/bin/playwright" install chromium  >&2
```

Stderr (`>&2`) always flows to the terminal — users still see all output. But it does **not** enter the curl pipe. Stdin stays clean for bash to read the actual script.

---

#### Changes in this patch

- 🐛 `fix:` `brew install python@3.13 >&2` — prevents brew stdout entering curl pipe
- 🐛 `fix:` `git clone ... >&2` — same fix for clone output
- 🐛 `fix:` `git reset --hard ... >&2` — same fix for reset output
- 🐛 `fix:` `pip install ... >&2` — same fix for pip install output
- 🐛 `fix:` `playwright install chromium >&2` — same fix for Chromium download
- 🏷️ `fix:` `shop.sh` version banner updated to `v2.0.1`
- 🏷️ `fix:` `update.sh` version banner updated to `v2.0.1`
- 📖 `docs:` `INSTALL.md` — full rewrite for v2 era: curl installer walkthrough, session deep-dive, `shop` alias setup, troubleshooting table with every known error and fix
- 📖 `docs:` `README.md` — version badge updated to 2.0.1; new “Challenges, bottlenecks & how we solved them” section documenting all 9 technical problems with code examples

---

## 🔖 [2.0.0] — 2026-03-23

### 🚀 Major release — interactive menu, multi-config, shell alias

This release introduces a complete workflow overhaul. The primary way to use continente-hero is now the `shop` command — a single alias that opens an interactive menu covering every operation.

---

#### `shop.sh` — new interactive menu launcher

- 🎛️ `feat:` New `shop.sh` — interactive TUI menu with 6 options:
  - **1) Fill my cart** — runs the bot, offers visible/headless choice
  - **2) Save / refresh session** — guided browser login flow
  - **3) Edit shopping list** — opens in best available editor (VS Code → Cursor → Sublime → TextEdit → nano)
  - **4) Switch shopping list** — multi-config management (see below)
  - **5) Update continente-hero** — pulls latest code + refreshes dependencies
  - **6) Quit**
- 🗂️ `feat:` **Multi-config support** — maintain multiple `.yaml` shopping lists in a `configs/` folder, switch between them from the menu. Active list is always `config.yaml`
- 🏷️ `feat:` Active list name shown at the top of every menu screen
- 🏗️ `feat:` Create new lists from within the menu — copies current config as a starting point
- 🛡️ `feat:` venv guard at startup — prints the curl install command if the venv doesn't exist yet
- 🔄 `feat:` Update option uses `git reset --hard origin/main` — never fails due to local modifications

---

#### `setup.sh` — curl installer now fully automatic

- 🤖 `feat:` Python 3.13 is now **installed automatically via Homebrew** when missing — no prompt, no manual step, works when piped through `curl | bash`
- 🏷️ `feat:` Shell alias `shop` registered in `~/.zshrc` (or `~/.bashrc`) automatically during install
- 🔄 `feat:` Alias update logic — if `shop` alias already exists, it is updated in-place (handles re-installs to a different path)
- 📌 `feat:` Version bumped to v2.0 in the banner

---

#### `update.sh` — rewritten

- 🔄 `fix:` Replaced `git pull` with `git fetch + git reset --hard origin/main` — `git pull` aborts when local files have been modified (e.g. by `chmod +x`); `reset --hard` always succeeds
- 📦 `fix:` Playwright updated using `$VENV_DIR/bin/playwright` full path — the bare `playwright` command is unreliable in zsh after venv activation
- 🏷️ `fix:` Banner updated from "CONTINENTE CART BOT" to "CONTINENTE HERO"

---

#### `README.md` — complete v2 rewrite

- 🚀 `feat:` `shop` alias documented as the primary entry point
- 🗂️ `feat:` Multi-config usage guide — `configs/` folder, switching, creating new lists
- 🔐 `feat:` Session connection deep-dive — cookie anatomy table, full flow diagram, security notes
- ⚠️ `feat:` Python 3.14 incompatibility explained with the exact compiler error
- 🛠️ `feat:` Full "how it works" section — browser engine, product resolution strategy, failover guarantee, run report format
- 🏷️ `feat:` Version badge updated to 2.0.0, links to GitHub Releases

---

## 🔖 [1.4.0] — 2026-03-23

### ✨ setup.sh — curl installer improvements

- 🤖 `feat:` Python 3.13 installation is now attempted automatically (not just when stdin is a terminal)
- 🏷️ `feat:` Shell alias `shop` registered during install
- 📌 `feat:` Version bumped to v1.4.0

---

## 🔖 [1.3.0] — 2026-03-23

### ✨ New — curl one-liner installer

**`setup.sh` — new curl-based installer (zero prior clone required)**
- 🚀 `feat:` Added `setup.sh` — full installation from one curl command
- 📁 `feat:` Auto-clones the repo to `~/continente-hero` on first run
- 🔄 `feat:` Uses `git fetch + git reset --hard origin/main` to bypass local-change conflicts
- 🛡️ `feat:` Explicit guards on `git clone`, `pip install`, and `playwright install chromium`
- 🪤 `feat:` `trap EXIT` handler — prints exit code and debug instructions on failure
- 📂 `feat:` `CONTINENTE_DIR` env var override for custom install path

---

## 🔖 [1.2.4] — 2026-03-23

### 🐛 Hotfix — shell compatibility bugs

- 🐛 `fix:` `${answer,,}` bash-only lowercase expansion replaced with explicit comparison
- 📂 `fix:` `SCRIPT_DIR` double-nesting bug — `${BASH_SOURCE[0]:-$0}` fallback added
- 📌 `fix:` Version bumped to v1.2.4

---

## 🔖 [1.2.3] — 2026-03-23

### 🐛 Hotfix

- 🛡️ `fix:` All `.sh` scripts `chmod +x`'d at install start — fresh git clone strips execute bits
- 📦 `fix:` Playwright installed using `$VENV_DIR/bin/playwright` full path

---

## 🔖 [1.2.2] — 2026-03-23

### 🐛 `install.sh` — full rewrite

- 🗑️ `fix:` `.venv` always wiped and rebuilt clean on every run
- 🍺 `fix:` Auto-brew python@3.13 offered interactively if no compatible Python found
- 🛇 `fix:` Python version parsing rewritten to use `print(v.major, v.minor)` (space-separated integers)
- 🏷️ `fix:` Banner corrected from "CONTINENTE CART BOT" to "CONTINENTE HERO"

---

## 🔖 [1.2.1] — 2026-03-22

### 🐛 Hotfix

- 🚫 `fix:` Hard-blocked Python 3.14+ with a clear error message
- 🔍 `fix:` Versioned binaries tried before bare `python3`

---

## 🔖 [1.2.0] — 2026-03-22

### ✨ Session tutorial

- 📖 `feat:` Full "how the session connection works" section in README and INSTALL.md
- 🍪 `feat:` Cookie anatomy table — `dwsid`, `dwanonymous`, `dw_*`
- 🔄 `feat:` Three-tier credential priority diagram
- 🔒 `feat:` Security notes — what is and isn't stored

---

## 🔖 [1.1.0] — 2026-03-22

### ✨ Improvements

- 🛠️ `feat:` Added `edit.sh` — opens config in best available editor
- 📖 `feat:` README full beginner-friendly rewrite
- 🏷️ `feat:` Renamed repo from `continente-cart` to `continente-hero`

---

## 🔖 [1.0.0] — 2026-03-22

### 🎉 Initial release

- 🛒 `feat:` Full Playwright (Chromium) automation for continente.pt cart building
- 🔐 `feat:` Three-tier authentication: saved cookies → env vars → config.yaml
- 🔍 `feat:` Dual product resolution — direct URL + search with brand filter
- 🛡️ `feat:` Per-product try/except — no single failure aborts the full run
- 📄 `feat:` Timestamped run reports saved to `reports/`
- 💾 `feat:` Session persistence via `session/cookies.json`
- 🖥️ `feat:` `--visible` and `--save-session` CLI flags
- 🤖 `feat:` Anti-detection: real Chrome UA, `--disable-blink-features=AutomationControlled`

---

*Designed and built in collaboration with [Perplexity Computer](https://www.perplexity.ai/)*
