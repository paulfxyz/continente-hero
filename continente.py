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

    if "--visible" in sys.argv:
        cfg["headless"] = False

    async with ContinenteBot(cfg) as bot:
        await bot.run()
        print(bot.report())


if __name__ == "__main__":
    asyncio.run(main())
