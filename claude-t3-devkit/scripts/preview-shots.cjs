/**
 * Screenshot harness template for the design review lenses (design-reviewer +
 * design-foundations-reviewer). Copy into the target repo as
 * scripts/preview-shots.cjs and edit ROUTES/PRINT_ROUTES to match its pages.
 *
 * Usage:  <dev server running>
 *         node scripts/preview-shots.cjs
 *
 * Requires playwright in the repo (devDependency). Output lands in
 * preview-shots/ — gitignore it; the shots are review evidence, not source.
 */
const { chromium } = require("playwright");

const BASE = process.env.PREVIEW_BASE_URL ?? "http://localhost:3000";
const OUT = `${__dirname}/../preview-shots`;

// EDIT ME: the screens the design lenses should judge.
const ROUTES = [
  { path: "/", name: "landing" },
  // { path: "/dashboard", name: "dashboard" },
];

// EDIT ME: screens that get printed (receipts, QR codes, tickets) — captured
// with print-media emulation so the print-fidelity check has real evidence.
const PRINT_ROUTES = [
  // { path: "/receipt/example", name: "receipt" },
];

const VIEWPORTS = {
  mobile: { width: 430, height: 920 },
  desktop: { width: 1280, height: 900 },
};

/**
 * @param {import("playwright").Page} page
 * @param {string} route
 * @param {string} name
 * @param {number} [settle]
 */
async function shoot(page, route, name, settle = 1000) {
  await page.goto(`${BASE}${route}`, { waitUntil: "load" });
  await page.waitForTimeout(settle);
  await page.screenshot({ path: `${OUT}/${name}.png`, fullPage: true });
  console.log(`${name} ok`);
}

(async () => {
  const browser = await chromium.launch({ args: ["--no-sandbox"] });

  for (const [device, viewport] of Object.entries(VIEWPORTS)) {
    const page = await browser.newPage({ viewport });
    for (const { path, name } of ROUTES) {
      await shoot(page, path, `${name}-${device}`);
    }
    await page.close();
  }

  if (PRINT_ROUTES.length) {
    const page = await browser.newPage({ viewport: VIEWPORTS.mobile });
    await page.emulateMedia({ media: "print" });
    for (const { path, name } of PRINT_ROUTES) {
      await shoot(page, path, `${name}-print`);
    }
    await page.close();
  }

  await browser.close();
})().catch((e) => {
  console.error("ERR", e.message);
  process.exit(1);
});
