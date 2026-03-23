#!/usr/bin/env python3
"""
continente.py — Automated cart builder for continente.pt
=========================================================

Logs in to continente.pt, iterates over the shopping list defined in
config.yaml, searches for each item (or navigates directly to its URL),
adds it to the cart, and prints a human-readable report.

Every per-product failure is caught and classified — the bot never crashes
on a missing or out-of-stock item. You always end up with a clean summary
of what was added and what was skipped.

Usage
-----
  # First run — save your session (opens browser window, you log in once):
  python continente.py --save-session

  # Normal run (headless, reuses saved session or .env credentials):
  python continente.py

  # Run with a visible browser window (great for debugging):
  python continente.py --visible

Architecture
------------
  config.yaml              → load_config()
  .env / env vars          → credential fallback
  session/cookies.json     → load_session() / save_session()
  ContinenteBot            → login() → run() → report()
    └─ add_product()         one call per item, never raises
         ├─ _add_from_pdp()  direct URL path
         └─ _add_from_search() search path with brand filter
"""

import asyncio
import json
import os
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Optional

import yaml
from dotenv import load_dotenv
from playwright.async_api import (
    Browser,
    BrowserContext,
    Page,
    Playwright,
    TimeoutError as PlaywrightTimeoutError,
    async_playwright,
)

# ── Load .env file if present (silently ignored if missing) ───────────────────
load_dotenv()

# ── Paths ─────────────────────────────────────────────────────────────────────
ROOT         = Path(__file__).parent
CONFIG_FILE  = ROOT / "config.yaml"
SESSION_FILE = ROOT / "session" / "cookies.json"
REPORTS_DIR  = ROOT / "reports"

# ── Continente / SFCC constants ───────────────────────────────────────────────
BASE_URL   = "https://www.continente.pt"
LOGIN_URL  = f"{BASE_URL}/login/"
SEARCH_URL = f"{BASE_URL}/pesquisa/?q="
CART_URL   = f"{BASE_URL}/checkout/carrinho/"

# ── Cart-clear retry / backoff tuning ────────────────────────────────────────
# SFCC cart XHRs can stall under server load — see _clear_loop() for full docs.
REMOVE_SELECTOR  = 'button[aria-label="Apagar produto"]'  # confirmed via DOM inspection
CLEAR_TIMEOUT    = 8_000    # ms — per-item count-drop poll timeout
CLEAR_BACKOFF    = [2, 5, 15, 30, 60]  # s — wait ladder: 2 → 5 → 15 → 30 → 60 → 60…
CLEAR_RELOAD_AT  = 3        # consecutive timeouts before reloading the page
CLEAR_GIVE_UP_AT = 5        # consecutive timeouts before skipping an item
CLEAR_MAX_SKIPS  = 5        # total skipped items before aborting the whole run

# ── Timeouts (ms) ─────────────────────────────────────────────────────────────
NAV_TIMEOUT     = 30_000   # page navigation
ELEMENT_TIMEOUT = 15_000   # waitForSelector
ACTION_PAUSE    = 1_000    # polite delay between cart actions


# ─────────────────────────────────────────────────────────────────────────────
#  Data models
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class ProductConfig:
    """One entry from the config.yaml shopping list."""
    name:     str
    query:    str            # search term (defaults to name)
    quantity: int   = 1
    url:      Optional[str] = None   # direct product page URL
    brand:    Optional[str] = None   # prefer this brand in search results


@dataclass
class ProductResult:
    """Outcome after attempting to add one product."""
    name:     str
    query:    str
    quantity: int
    # "added" | "not_found" | "out_of_stock" | "error"
    status:   str = "error"
    detail:   str = ""
    pid:      Optional[str] = None


# ─────────────────────────────────────────────────────────────────────────────
#  Config helpers
# ─────────────────────────────────────────────────────────────────────────────

def load_config() -> dict:
    """Read and minimally validate config.yaml."""
    if not CONFIG_FILE.exists():
        _die(f"config.yaml not found at {CONFIG_FILE}")
    with open(CONFIG_FILE, encoding="utf-8") as fh:
        cfg = yaml.safe_load(fh)
    if not cfg.get("products"):
        _die("config.yaml must contain a non-empty 'products' list.")
    return cfg


def parse_products(cfg: dict) -> list[ProductConfig]:
    """Convert raw YAML entries into typed ProductConfig objects."""
    products = []
    for entry in cfg["products"]:
        if not isinstance(entry, dict) or "name" not in entry:
            print(f"  [WARN] Skipping malformed product entry: {entry}")
            continue
        products.append(ProductConfig(
            name     = entry["name"],
            query    = entry.get("query", entry["name"]),
            quantity = int(entry.get("quantity", 1)),
            url      = entry.get("url"),
            brand    = entry.get("brand"),
        ))
    return products


# ─────────────────────────────────────────────────────────────────────────────
#  Session helpers
# ─────────────────────────────────────────────────────────────────────────────

def load_session() -> Optional[list]:
    """Return persisted cookies if they exist, else None."""
    if SESSION_FILE.exists():
        with open(SESSION_FILE) as fh:
            return json.load(fh)
    return None


def save_session(cookies: list) -> None:
    """Persist browser cookies to disk for future runs."""
    SESSION_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(SESSION_FILE, "w") as fh:
        json.dump(cookies, fh, indent=2)
    print(f"  [SESSION] Cookies saved → {SESSION_FILE}")


# ─────────────────────────────────────────────────────────────────────────────
#  The Bot
# ─────────────────────────────────────────────────────────────────────────────

class ContinenteBot:
    """
    Async context manager that drives a Playwright Chromium session.

    Usage:
        async with ContinenteBot(cfg) as bot:
            await bot.run()
            print(bot.report())
    """

    def __init__(self, cfg: dict):
        self.cfg      = cfg
        self.headless = cfg.get("headless", True)
        self.slow_mo  = int(cfg.get("slow_mo", 150))
        self.products = parse_products(cfg)
        self.results: list[ProductResult] = []

        self._playwright: Optional[Playwright]     = None
        self._browser:    Optional[Browser]        = None
        self._context:    Optional[BrowserContext] = None
        self._page:       Optional[Page]           = None

    # ── Lifecycle ─────────────────────────────────────────────────────────────

    async def __aenter__(self):
        self._playwright = await async_playwright().start()
        self._browser = await self._playwright.chromium.launch(
            headless = self.headless,
            slow_mo  = self.slow_mo,
            args     = [
                "--no-sandbox",
                # Mask Playwright's automation fingerprint
                "--disable-blink-features=AutomationControlled",
            ],
        )
        self._context = await self._browser.new_context(
            viewport     = {"width": 1280, "height": 900},
            user_agent   = (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/123.0.0.0 Safari/537.36"
            ),
            locale       = "pt-PT",
            timezone_id  = "Europe/Lisbon",
        )

        # Restore saved session cookies if available
        saved = load_session()
        if saved:
            await self._context.add_cookies(saved)
            print("  [SESSION] Loaded saved cookies.")

        self._page = await self._context.new_page()
        return self

    async def __aexit__(self, *_):
        if self._browser:    await self._browser.close()
        if self._playwright: await self._playwright.stop()

    # ── Authentication ────────────────────────────────────────────────────────

    async def _is_logged_in(self) -> bool:
        """
        Navigate to the homepage and check for any element that only
        appears when the user is authenticated.
        """
        await self._page.goto(BASE_URL, timeout=NAV_TIMEOUT)
        await self._page.wait_for_load_state("domcontentloaded")
        try:
            await self._page.wait_for_selector(
                # Multiple known selectors for the logged-in account nav area
                "a[href*='/conta/'], .ct-header--user-logged, "
                "[data-user-logged], .ct-user-info--name",
                timeout=7_000,
            )
            return True
        except PlaywrightTimeoutError:
            return False

    async def login(self) -> bool:
        """
        Authenticate the session.

        Priority order:
          1. Saved cookies (session/cookies.json) — skip full login if valid.
          2. Environment variables / .env file    — CONTINENTE_USER / CONTINENTE_PASS.
          3. config.yaml username / password fields.

        Returns True on success, False on failure.
        """
        print("\n  [LOGIN] Checking session…")

        if await self._is_logged_in():
            print("  [LOGIN] ✓ Authenticated via saved session.")
            save_session(await self._context.cookies())
            return True

        # ── Resolve credentials ───────────────────────────────────────────────
        username = (
            os.getenv("CONTINENTE_USER")
            or self.cfg.get("username", "")
        )
        password = (
            os.getenv("CONTINENTE_PASS")
            or self.cfg.get("password", "")
        )

        if not username or not password:
            print(
                "\n  [LOGIN] ✗ No credentials found.\n"
                "\n  Options:\n"
                "    A) Run once with a visible browser to save your session:\n"
                "         python continente.py --save-session\n"
                "\n    B) Set credentials in .env:\n"
                "         CONTINENTE_USER=your@email.com\n"
                "         CONTINENTE_PASS=yourpassword\n"
                "\n    C) Set 'username' / 'password' in config.yaml\n"
            )
            return False

        print(f"  [LOGIN] Signing in as {username}…")
        await self._page.goto(LOGIN_URL, timeout=NAV_TIMEOUT)
        await self._page.wait_for_load_state("networkidle", timeout=NAV_TIMEOUT)

        # The SSO form is a React SPA injected by login.continente.pt —
        # we try multiple selector patterns to handle layout changes.
        email_field = await self._find_first([
            "input[name='loginEmail']",
            "input[name='email']",
            "input[type='email']",
            "#email", "#loginEmail",
        ], timeout=12_000)

        if not email_field:
            print("  [LOGIN] ✗ Could not locate email field (SSO layout may have changed).")
            return False

        password_field = await self._find_first([
            "input[name='loginPassword']",
            "input[name='password']",
            "input[type='password']",
            "#password", "#loginPassword",
        ], timeout=6_000)

        if not password_field:
            print("  [LOGIN] ✗ Could not locate password field.")
            return False

        await email_field.fill(username)
        await self._page.wait_for_timeout(350)
        await password_field.fill(password)
        await self._page.wait_for_timeout(350)

        # Submit the form
        submit = await self._find_first([
            "button[type='submit']",
            "button:has-text('Entrar')",
            "button:has-text('Login')",
            "input[type='submit']",
        ], timeout=4_000)

        if submit:
            await submit.click()
        else:
            await password_field.press("Enter")

        # Wait for redirect back to continente.pt
        try:
            await self._page.wait_for_url(f"{BASE_URL}/**", timeout=20_000)
        except PlaywrightTimeoutError:
            pass  # Some SSO flows keep the same URL — check auth state anyway

        if await self._is_logged_in():
            print("  [LOGIN] ✓ Login successful.")
            save_session(await self._context.cookies())
            return True

        print("  [LOGIN] ✗ Login failed — double-check your credentials.")
        return False

    # ── Product adding ────────────────────────────────────────────────────────

    async def add_product(self, product: ProductConfig) -> ProductResult:
        """
        Attempt to find and add one product to the cart.

        Strategy:
          A) If product.url is provided → go directly to the product page (PDP).
          B) Otherwise                  → search for product.query.

        Failover guarantees:
          - No search results       → status "not_found"
          - Button disabled         → status "out_of_stock"
          - Any network / timeout   → status "error"  (never raises)
          - Brand filter miss       → logs a warning, uses first result
        """
        result = ProductResult(
            name=product.name, query=product.query, quantity=product.quantity
        )

        try:
            # ── A: Direct URL ─────────────────────────────────────────────────
            if product.url:
                await self._page.goto(product.url, timeout=NAV_TIMEOUT)
                await self._page.wait_for_load_state("domcontentloaded")
                if await self._add_from_pdp(product, result):
                    return result
                # PDP add failed — fall through to search as a backup

            # ── B: Search ─────────────────────────────────────────────────────
            await self._add_from_search(product, result)

        except PlaywrightTimeoutError as exc:
            result.status = "error"
            result.detail = f"Navigation timeout: {exc}"
            print(f"    → Timeout.")

        except Exception as exc:  # noqa: BLE001 — intentional catch-all
            result.status = "error"
            result.detail = f"Unexpected error: {exc}"
            print(f"    → Error: {exc}")

        return result

    async def _add_from_pdp(
        self, product: ProductConfig, result: ProductResult
    ) -> bool:
        """
        Add from a Product Detail Page. Mutates result in place.
        Returns True on success so the caller can skip the search fallback.
        """
        try:
            atc = await self._page.wait_for_selector(
                "button.add-to-cart, button[aria-label='Adicionar ao carrinho']",
                timeout=ELEMENT_TIMEOUT,
            )
        except PlaywrightTimeoutError:
            return False  # No ATC button found → try search path

        if await atc.get_attribute("disabled") is not None:
            result.status = "out_of_stock"
            result.detail = "Add-to-cart button is disabled on product page."
            print(f"    → Out of stock.")
            return True  # Definitively out of stock — no point searching

        # Grab PID for the report
        try:
            result.pid = await self._page.eval_on_selector(
                "[data-pid]", "el => el.dataset.pid"
            )
        except Exception:  # noqa: BLE001
            pass

        await atc.scroll_into_view_if_needed()
        await self._page.wait_for_timeout(ACTION_PAUSE)
        await atc.click()

        if product.quantity > 1:
            await self._set_quantity(result.pid, product.quantity)

        await self._page.wait_for_timeout(ACTION_PAUSE)
        result.status = "added"
        result.detail = f"Added via direct URL (pid={result.pid}, qty={product.quantity})"
        print(f"    → ✅ Added (pid={result.pid})")
        return True

    async def _add_from_search(
        self, product: ProductConfig, result: ProductResult
    ) -> None:
        """
        Search for the product and add the best matching tile.
        Mutates result in place.
        """
        url = f"{SEARCH_URL}{product.query}"
        print(f"    → Searching: {url}")
        await self._page.goto(url, timeout=NAV_TIMEOUT)
        await self._page.wait_for_load_state("domcontentloaded")

        # Dismiss cookie banner on first run
        await self._dismiss_cookies()

        # Wait briefly for JS-rendered tiles
        await self._page.wait_for_timeout(1_500)

        tiles = await self._page.query_selector_all(".ct-product-tile")

        if not tiles:
            result.status = "not_found"
            result.detail = f"No search results for query: '{product.query}'"
            print(f"    → Not found.")
            return

        # Pick the best tile (brand-filtered or first)
        tile = await self._best_tile(tiles, product)
        if tile is None:
            result.status = "not_found"
            result.detail = (
                f"Brand filter '{product.brand}' matched nothing "
                f"for query '{product.query}' (and fallback was disabled)."
            )
            print(f"    → No brand match.")
            return

        result.pid = await tile.get_attribute("data-pid")

        # Locate ATC button within the tile
        atc = await tile.query_selector(
            "button.add-to-cart, "
            "button.js-add-to-cart, "
            "button[aria-label='Adicionar ao carrinho']"
        )

        if not atc:
            result.status = "not_found"
            result.detail = "No add-to-cart button found in product tile."
            print(f"    → No ATC button in tile.")
            return

        # Check disabled / out-of-stock state
        disabled = await atc.get_attribute("disabled")
        classes  = await atc.get_attribute("class") or ""
        if disabled is not None or "disabled" in classes.split():
            result.status = "out_of_stock"
            result.detail = "Add-to-cart button is disabled (likely out of stock)."
            print(f"    → Out of stock.")
            return

        # Add to cart
        await atc.scroll_into_view_if_needed()
        await self._page.wait_for_timeout(ACTION_PAUSE)
        await atc.click()
        print(f"    → ✅ Added (pid={result.pid})")

        if product.quantity > 1:
            await self._set_quantity(result.pid, product.quantity)

        await self._page.wait_for_timeout(ACTION_PAUSE)
        result.status = "added"
        result.detail = f"Added via search '{product.query}' (pid={result.pid}, qty={product.quantity})"

    async def _best_tile(self, tiles, product: ProductConfig):
        """
        Pick the most relevant product tile from search results.

        If product.brand is set, scan tile text for a match (case-insensitive).
        Falls back to the first tile with a warning — never returns None
        unless the tiles list is empty.
        """
        if not product.brand:
            return tiles[0]

        brand_lower = product.brand.lower()
        for tile in tiles:
            text = (await tile.inner_text()).lower()
            if brand_lower in text:
                return tile

        # Brand not found — fall back to first result gracefully
        print(
            f"    [WARN] Brand '{product.brand}' not found in results "
            f"for '{product.query}' — using first result."
        )
        return tiles[0]

    async def _set_quantity(self, pid: Optional[str], quantity: int) -> None:
        """
        Best-effort quantity adjustment after adding to cart.
        Never blocks the main flow — logs a warning on failure.
        """
        try:
            pid_filter = f"[data-pid='{pid}']" if pid else ""

            # Try direct number input first
            qty_input = await self._page.query_selector(
                f"input.quantity-stepper{pid_filter}, "
                f"input.quantity{pid_filter}, "
                ".quantity-form input[type='number']"
            )
            if qty_input:
                await qty_input.triple_click()
                await qty_input.type(str(quantity))
                await qty_input.press("Enter")
                return

            # Otherwise click the + button (quantity − 1) times
            plus = await self._page.query_selector(
                f"button.quantity-increase{pid_filter}, "
                f".btn-quantity-plus{pid_filter}, "
                f"{pid_filter} .icon-plus"
            )
            if plus:
                for _ in range(quantity - 1):
                    await plus.click()
                    await self._page.wait_for_timeout(300)

        except Exception:  # noqa: BLE001
            print(
                f"    [WARN] Could not set qty={quantity} for pid={pid}. "
                "Adjust manually in cart."
            )

    async def _dismiss_cookies(self) -> None:
        """
        Dismiss the GDPR / cookie consent banner if it appears.
        Silently no-ops if no banner is found.
        """
        for sel in [
            "button#onetrust-accept-btn-handler",
            "button.accept-cookies",
            "button:has-text('Aceitar todos')",
            "button:has-text('Aceitar')",
            "#CybotCookiebotDialogBodyLevelButtonLevelOptinAllowAll",
        ]:
            try:
                btn = await self._page.query_selector(sel)
                if btn:
                    await btn.click()
                    await self._page.wait_for_timeout(600)
                    print("  [COOKIES] Banner dismissed.")
                    return
            except Exception:  # noqa: BLE001
                continue

    async def _find_first(self, selectors: list[str], timeout: int = 5_000):
        """Try each selector in order and return the first element found."""
        for sel in selectors:
            try:
                el = await self._page.wait_for_selector(sel, timeout=timeout)
                if el:
                    return el
            except PlaywrightTimeoutError:
                continue
        return None

    # ── Clear cart ────────────────────────────────────────────────────────────

    async def clear_cart(self) -> int:
        """
        Navigate to the cart page and remove every item.

        SFCC cart behaviour on continente.pt
        ------------------------------------
        The cart is a React SPA. Clicking a remove button triggers an XHR
        request and then re-renders the item list in place — it does NOT
        do a full page reload. This means we must:

          1. After each removal, wait for the DOM to settle before looking
             for the next remove button (the old NodeList is stale).
          2. Query for remove buttons fresh on every iteration rather than
             collecting them all upfront.
          3. Accept that the selectors may vary between SFCC themes —
             we try four known patterns in priority order.
          4. Cap iterations at 50 to avoid an infinite loop if the DOM
             never reaches an empty state for any reason.

        Returns the number of items removed.
        """
        print("\n  [CLEAR CART] Navigating to cart…")
        await self._page.goto(CART_URL, timeout=NAV_TIMEOUT)
        await self._page.wait_for_load_state("domcontentloaded")
        await self._dismiss_cookies()

        # Give React time to render the cart items
        await self._page.wait_for_timeout(2_000)

        # Correct selector confirmed via live DOM inspection.
        # Full retry/backoff logic lives in the shared _clear_loop() helper.
        removed, skipped = await _clear_loop(self._page, REMOVE_SELECTOR)

        if removed == 0 and skipped == 0:
            print("  [CLEAR CART] Cart was already empty — nothing to remove.")
        else:
            print(f"  [CLEAR CART] ✅ Removed {removed} item(s)."
                  + (f" ⚠ {skipped} item(s) could not be removed." if skipped else ""))

        return removed

    # ── Main run ──────────────────────────────────────────────────────────────

    async def run(self) -> None:
        """Login → iterate all products → save session → open cart."""
        _banner("CONTINENTE CART BOT")

        if not await self.login():
            print("\n  [ABORT] Cannot proceed without authentication.\n")
            sys.exit(1)

        print(f"\n  Processing {len(self.products)} product(s)…\n")

        for i, product in enumerate(self.products, 1):
            label = f"[{i}/{len(self.products)}]"
            print(f"  {label} {product.name!r}  (qty: {product.quantity})")
            result = await self.add_product(product)
            self.results.append(result)
            await self._page.wait_for_timeout(600)

        # Persist fresh cookies after a successful run
        save_session(await self._context.cookies())

        # Navigate to cart for the user to review
        print(f"\n  [DONE] Opening cart → {CART_URL}")
        await self._page.goto(CART_URL, timeout=NAV_TIMEOUT)
        await self._page.wait_for_load_state("domcontentloaded")

        # Keep the window open a few seconds so the user can see it
        if not self.headless:
            await self._page.wait_for_timeout(4_000)

    # ── Report ────────────────────────────────────────────────────────────────

    def report(self) -> str:
        """
        Build a human-readable run report, print it, and save it to
        reports/report-<timestamp>.txt.
        """
        ts      = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        added   = [r for r in self.results if r.status == "added"]
        missing = [r for r in self.results if r.status == "not_found"]
        oos     = [r for r in self.results if r.status == "out_of_stock"]
        errors  = [r for r in self.results if r.status == "error"]

        W = 62   # report width

        def h(title: str) -> str:
            return f"\n  {'─' * (W - 4)}\n  {title}\n  {'─' * (W - 4)}"

        lines = [
            "",
            "  " + "═" * W,
            "  CONTINENTE CART — RUN REPORT",
            f"  {ts}",
            "  " + "═" * W,
            "",
            f"  Total products in list : {len(self.results)}",
            f"  ✅  Added to cart       : {len(added)}",
            f"  ❌  Not found           : {len(missing)}",
            f"  🚫  Out of stock        : {len(oos)}",
            f"  ⚠️   Errors              : {len(errors)}",
        ]

        if added:
            lines.append(h("✅  ADDED TO CART"))
            for r in added:
                lines.append(f"  • {r.name}")
                lines.append(f"    qty: {r.quantity}   pid: {r.pid or '—'}")

        if missing:
            lines.append(h("❌  NOT FOUND"))
            for r in missing:
                lines.append(f"  • {r.name}")
                lines.append(f"    search query : {r.query}")
                lines.append(f"    reason       : {r.detail}")

        if oos:
            lines.append(h("🚫  OUT OF STOCK"))
            for r in oos:
                lines.append(f"  • {r.name}  (pid: {r.pid or '—'})")
                lines.append(f"    {r.detail}")

        if errors:
            lines.append(h("⚠️   ERRORS"))
            for r in errors:
                lines.append(f"  • {r.name}")
                lines.append(f"    {r.detail}")

        lines += [
            "",
            f"  Cart → {CART_URL}",
            "  " + "═" * W,
            "",
        ]

        text = "\n".join(lines)

        # Save timestamped report
        REPORTS_DIR.mkdir(exist_ok=True)
        report_path = REPORTS_DIR / f"report-{datetime.now().strftime('%Y%m%d-%H%M%S')}.txt"
        report_path.write_text(text, encoding="utf-8")
        print(f"\n  [REPORT] Saved → {report_path}")

        return text


# ─────────────────────────────────────────────────────────────────────────────
#  Interactive session-save flow
# ─────────────────────────────────────────────────────────────────────────────

async def _clear_loop(page, selector: str) -> tuple[int, int]:
    """
    Shared cart-clearing engine used by both clear_cart() and
    clear_cart_interactive().

    Retry / backoff architecture
    ────────────────────────────
    SFCC's cart XHR can stall under load — the DOM count does not drop within
    the poll window even though the click was registered. Naively retrying
    immediately makes things worse (hammering a rate-limited endpoint).

    Strategy:
      1. Click the first remove button.
      2. Poll for count-drop every 200 ms for up to CLEAR_TIMEOUT ms.
      3. If count dropped → success, move to next item.
      4. If count did NOT drop (timeout) → track consecutive_timeouts:
           • Every CLEAR_RELOAD_AT consecutive timeouts: reload the cart page
             (forces a fresh server-side cart state, clears any stuck XHR).
           • Wait using the backoff ladder: [2s, 5s, 15s, 30s, 60s, 60s, …]
           • Retry the same item.
           • After CLEAR_GIVE_UP_AT consecutive timeouts on one item: skip it,
             add to the "skipped" list, reset consecutive counter, move on.
      5. After CLEAR_MAX_SKIPS total skips: abort and report.
      6. After the main loop finishes: retry any skipped items once with a
         fresh page reload and full backoff — they may have been stuck due to
         transient server pressure that has since cleared.

    Returns (removed: int, skipped: int).
    """
    removed            = 0
    skipped            = 0
    consecutive_fails  = 0   # resets on each successful removal
    backoff_idx        = 0   # index into CLEAR_BACKOFF ladder
    max_iterations     = 150  # hard cap — a cart with 100+ items is unusual

    async def _poll_count_drop(current_count: int) -> bool:
        """Poll until button count < current_count. Returns True on success."""
        deadline_ms = CLEAR_TIMEOUT
        interval_ms = 200
        elapsed     = 0
        while elapsed < deadline_ms:
            await page.wait_for_timeout(interval_ms)
            elapsed += interval_ms
            try:
                remaining = await page.query_selector_all(selector)
                if len(remaining) < current_count:
                    return True
            except Exception:  # noqa: BLE001
                pass
        return False  # timed out

    async def _reload_cart() -> None:
        """Reload the cart page and wait for React to settle."""
        print("  [CLEAR CART] ↺  Reloading cart page to recover from stall…")
        try:
            await page.reload(timeout=NAV_TIMEOUT, wait_until="domcontentloaded")
            await page.wait_for_timeout(2_500)
        except Exception:  # noqa: BLE001
            await page.wait_for_timeout(3_000)

    for iteration in range(max_iterations):
        # Fresh query every iteration — React replaces the whole list on render
        try:
            btns = await page.query_selector_all(selector)
        except Exception:  # noqa: BLE001
            btns = []

        count_before = len(btns)
        if count_before == 0:
            break  # Cart empty — done

        btn = btns[0]

        # ── Click ─────────────────────────────────────────────────────────────
        try:
            await btn.scroll_into_view_if_needed()
            await page.wait_for_timeout(300)
            await btn.click()
        except Exception as exc:  # noqa: BLE001
            print(f"  [CLEAR CART] ✗  Click failed: {exc}")
            consecutive_fails += 1
            if consecutive_fails >= CLEAR_GIVE_UP_AT:
                print(f"  [CLEAR CART] ⚠  {CLEAR_GIVE_UP_AT} consecutive failures — skipping item.")
                skipped += 1
                consecutive_fails = 0
                backoff_idx = 0
                if skipped >= CLEAR_MAX_SKIPS:
                    print(f"  [CLEAR CART] ✗  Too many skips ({CLEAR_MAX_SKIPS}) — aborting.")
                    break
            continue

        # ── Poll for count drop ────────────────────────────────────────────────
        success = await _poll_count_drop(count_before)

        if success:
            # Happy path
            await page.wait_for_timeout(600)   # let "Anular" undo row settle
            removed         += 1
            consecutive_fails = 0
            backoff_idx       = 0
            remaining_now     = count_before - 1
            print(f"  [CLEAR CART] ✓  Item {removed} removed  ({remaining_now} left)")
        else:
            # Timeout — the XHR did not complete in time
            consecutive_fails += 1
            wait_s = CLEAR_BACKOFF[min(backoff_idx, len(CLEAR_BACKOFF) - 1)]
            backoff_idx += 1

            print(
                f"  [CLEAR CART] ⏱  Count did not drop after {CLEAR_TIMEOUT//1000}s "
                f"(fail #{consecutive_fails}) — waiting {wait_s}s…"
            )
            await asyncio.sleep(wait_s)

            # Reload every CLEAR_RELOAD_AT consecutive timeouts
            if consecutive_fails % CLEAR_RELOAD_AT == 0:
                await _reload_cart()

            # Give up on this item after too many consecutive failures
            if consecutive_fails >= CLEAR_GIVE_UP_AT:
                print(
                    f"  [CLEAR CART] ⚠  Item could not be removed after "
                    f"{CLEAR_GIVE_UP_AT} attempts — skipping."
                )
                skipped          += 1
                consecutive_fails  = 0
                backoff_idx        = 0
                if skipped >= CLEAR_MAX_SKIPS:
                    print(f"  [CLEAR CART] ✗  Too many skips ({CLEAR_MAX_SKIPS}) — aborting.")
                    break

    # ── Retry pass — reload and attempt any lingering items once more ──────────
    try:
        remaining_btns = await page.query_selector_all(selector)
    except Exception:  # noqa: BLE001
        remaining_btns = []

    if remaining_btns and skipped > 0:
        print(
            f"\n  [CLEAR CART] ↺  Retry pass — {len(remaining_btns)} item(s) still present. "
            "Reloading and retrying once…"
        )
        await _reload_cart()
        await asyncio.sleep(5)

        retry_btns = await page.query_selector_all(selector)
        retry_removed = 0
        for retry_btn in retry_btns:
            try:
                count_now = len(await page.query_selector_all(selector))
                await retry_btn.scroll_into_view_if_needed()
                await page.wait_for_timeout(400)
                await retry_btn.click()
                ok = await _poll_count_drop(count_now)
                if ok:
                    await page.wait_for_timeout(800)
                    removed       += 1
                    retry_removed += 1
                    skipped        = max(0, skipped - 1)
                    print(f"  [CLEAR CART] ✓  Retry removed item  ({count_now - 1} left)")
                else:
                    await asyncio.sleep(10)
            except Exception:  # noqa: BLE001
                pass

        if retry_removed:
            print(f"  [CLEAR CART] Retry pass recovered {retry_removed} item(s).")

    return removed, skipped


async def clear_cart_interactive(cfg: dict) -> None:
    """
    Clear every item from the Continente cart.

    Full flow (single Playwright session, always visible):
    ──────────────────────────────────────────────────────
    1. Launch a visible Chromium window.
    2. Load any saved session cookies.
    3. Check if we are already logged in.
       YES → go straight to clearing.
       NO  → navigate to the login page, prompt the user to log in manually,
             wait for Enter, save the fresh cookies, THEN clear — all in the
             same browser context without closing and reopening.

    Why one continuous session?
    ───────────────────────────
    If we saved cookies to disk and immediately reloaded them in a new
    ContinenteBot instance, there would be a race: SFCC session cookies
    are bound to the browser context that created them. Reloading them into
    a fresh context sometimes triggers a CSRF / session validation check and
    drops the user back to the login page. Keeping the same context alive
    from login through to cart clearing bypasses this entirely.
    """
    _banner("CLEAR CART")

    playwright = await async_playwright().start()
    browser    = await playwright.chromium.launch(
        headless = False,
        slow_mo  = 100,
        args     = ["--no-sandbox", "--disable-blink-features=AutomationControlled"],
    )
    context = await browser.new_context(
        viewport    = {"width": 1280, "height": 900},
        user_agent  = (
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/123.0.0.0 Safari/537.36"
        ),
        locale      = "pt-PT",
        timezone_id = "Europe/Lisbon",
    )
    page = await context.new_page()

    # ── Step 1: load saved session if available ───────────────────────────────
    saved = load_session()
    if saved:
        await context.add_cookies(saved)
        print("  [SESSION] Loaded saved cookies — checking if still valid…")
    else:
        print("  [SESSION] No saved session found.")

    # ── Step 2: check login state ─────────────────────────────────────────────
    await page.goto(BASE_URL, timeout=NAV_TIMEOUT)
    await page.wait_for_load_state("domcontentloaded")

    logged_in = False
    try:
        await page.wait_for_selector(
            "a[href*='/conta/'], .ct-header--user-logged, "
            "[data-user-logged], .ct-user-info--name",
            timeout=7_000,
        )
        logged_in = True
        print("  [LOGIN] ✓ Session valid — proceeding to clear cart.")
    except PlaywrightTimeoutError:
        logged_in = False

    # ── Step 3: if not logged in, prompt for manual login ─────────────────────
    if not logged_in:
        print()
        print("  [LOGIN] Session expired or missing.")
        print("  A browser window is open. Log in to continente.pt,")
        print("  then come back here and press Enter.")
        print()
        await page.goto(LOGIN_URL, timeout=NAV_TIMEOUT)
        input("  Press Enter once you are logged in… ")
        print()

        # Verify login succeeded
        try:
            await page.wait_for_selector(
                "a[href*='/conta/'], .ct-header--user-logged, "
                "[data-user-logged], .ct-user-info--name",
                timeout=10_000,
            )
            print("  [LOGIN] ✓ Login confirmed.")
        except PlaywrightTimeoutError:
            print("  [LOGIN] ✗ Could not confirm login. Attempting to clear anyway…")

        # Save the fresh cookies for future runs
        save_session(await context.cookies())
        print("  [SESSION] Fresh session saved for future runs.")
        print()

    # ── Step 4: clear the cart ────────────────────────────────────────────────
    print("  [CLEAR CART] Navigating to cart…")
    await page.goto(CART_URL, timeout=NAV_TIMEOUT)
    await page.wait_for_load_state("domcontentloaded")

    # Dismiss cookie/GDPR banner if it appears
    for sel in [
        "button#onetrust-accept-btn-handler",
        "button.accept-cookies",
        "button:has-text('Aceitar todos')",
        "button:has-text('Aceitar')",
    ]:
        try:
            btn = await page.query_selector(sel)
            if btn:
                await btn.click()
                await page.wait_for_timeout(600)
                break
        except Exception:  # noqa: BLE001
            continue

    # Give React time to render the cart
    await page.wait_for_timeout(2_000)

    # Correct selector confirmed via live DOM inspection.
    # Full retry/backoff logic lives in the shared _clear_loop() helper.
    removed, skipped = await _clear_loop(page, REMOVE_SELECTOR)

    if removed == 0 and skipped == 0:
        print("  [CLEAR CART] Cart was already empty — nothing to remove.")
    else:
        print(f"  [CLEAR CART] ✅ Removed {removed} item(s)."
              + (f" ⚠ {skipped} item(s) timed out and were skipped." if skipped else ""))
        if skipped:
            print("  [CLEAR CART] Refresh the cart in your browser to verify.")

    # Save refreshed cookies after clearing
    save_session(await context.cookies())

    # Stay on cart page so user can visually confirm
    print(f"  Leaving browser open on cart page — verify it is empty.")
    print(f"  Close the browser window when done.")
    print()
    input("  Press Enter to close the browser and return to the menu… ")

    await browser.close()
    await playwright.stop()
    print(f"\n  Done — {removed} item(s) removed.\n")


async def save_session_interactive(cfg: dict) -> None:
    """
    Open a visible Chromium window at the login page.
    The user logs in manually; press Enter in the terminal when done.
    Cookies are saved to session/cookies.json for all future runs.

    Usage: python continente.py --save-session
    """
    _banner("SAVE SESSION")
    print(
        "  A browser window will open at the continente.pt login page.\n"
        "  Log in with your account, then come back here and press Enter.\n"
    )
    input("  Press Enter to open the browser… ")
    print()

    playwright = await async_playwright().start()
    browser    = await playwright.chromium.launch(headless=False, slow_mo=80)
    context    = await browser.new_context(
        viewport    = {"width": 1280, "height": 900},
        locale      = "pt-PT",
        timezone_id = "Europe/Lisbon",
    )
    page = await context.new_page()
    await page.goto(LOGIN_URL)

    print("  → Browser is open. Log in to continente.pt.")
    print("  → Once you see your account / homepage, come back here.\n")
    input("  Press Enter once you are logged in… ")

    cookies = await context.cookies()
    save_session(cookies)

    print(
        f"\n  ✓ Session saved ({len(cookies)} cookies).\n"
        "  You can now run the bot normally:\n\n"
        "      python continente.py\n"
        "      — or —\n"
        "      ./run.sh\n"
    )

    await browser.close()
    await playwright.stop()


# ─────────────────────────────────────────────────────────────────────────────
#  Utilities
# ─────────────────────────────────────────────────────────────────────────────

def _banner(title: str) -> None:
    print("\n" + "═" * 64)
    print(f"  {title}")
    print("═" * 64)


def _die(msg: str) -> None:
    print(f"\n  [ERROR] {msg}\n")
    sys.exit(1)


# ─────────────────────────────────────────────────────────────────────────────
#  Entry point
# ─────────────────────────────────────────────────────────────────────────────

async def main() -> None:
    cfg = load_config()

    # CLI flags
    if "--save-session" in sys.argv:
        await save_session_interactive(cfg)
        return

    if "--clear-cart" in sys.argv:
        # Clear-cart always uses a visible browser so the user can:
        #   a) Log in manually if the saved session is missing or expired
        #   b) Watch every item disappear and confirm the cart is empty
        #
        # The flow is a single continuous Playwright session — we never
        # open and close the browser between "log in" and "clear". This
        # avoids the cookie timing issue that would occur if we saved
        # cookies to disk and immediately reloaded them in a new context.
        cfg["headless"] = False  # always visible for clear-cart
        await clear_cart_interactive(cfg)
        return

    if "--visible" in sys.argv:
        cfg["headless"] = False

    async with ContinenteBot(cfg) as bot:
        await bot.run()
        print(bot.report())


if __name__ == "__main__":
    asyncio.run(main())
