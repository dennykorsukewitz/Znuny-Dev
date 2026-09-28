import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

// ESM import does not look at NODE_PATH. The workflow installs Playwright
// outside the repo and exposes it through NODE_PATH.
const require = createRequire(import.meta.url);
const { chromium } = require("playwright");

// Repo root. This file lives in .github/scripts/, next to the Screenshots workflow.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const outDir = path.join(root, "docs/images");
const dashboardUrl = process.env.DASHBOARD_URL || "http://127.0.0.1:9999/";

function runZd(args) {
    const command = `./znuny-dev.sh ${args.map((arg) => `'${arg.replace(/'/g, `'\\''`)}'`).join(" ")}`;
    const result = spawnSync("zsh", ["-c", command], {
        cwd: root,
        encoding: "utf8",
        env: {
            ...process.env,
            FORCE_COLOR: "1",
            CLICOLOR_FORCE: "1",
        },
    });
    if (result.error) {
        throw result.error;
    }
    return `${result.stdout || ""}${result.stderr || ""}`.trimEnd();
}

function escapeHtml(text) {
    return text
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");
}

const ANSI_FG = {
    30: "#6b6b6b",
    31: "#f14c4c",
    32: "#23d18b",
    33: "#f5c542",
    34: "#3b8eea",
    35: "#d670d6",
    36: "#29b8db",
    37: "#e5e5e5",
    90: "#8a8a8a",
    91: "#ff6b6b",
    92: "#5af78e",
    93: "#f4f99d",
    94: "#82aaff",
    95: "#ff7ab2",
    96: "#9aedfe",
    97: "#ffffff",
};

function ansiToHtml(text) {
    const pattern = /\u001b\[([0-9;]*)m/g;
    let html = "";
    let last = 0;
    let open = false;
    let color = "";
    let bold = false;

    function closeSpan() {
        if (open) {
            html += "</span>";
            open = false;
        }
    }

    function openSpan() {
        closeSpan();
        if (!color && !bold) {
            return;
        }
        const style = [];
        if (color) {
            style.push(`color:${color}`);
        }
        if (bold) {
            style.push("font-weight:700");
        }
        html += `<span style="${style.join(";")}">`;
        open = true;
    }

    let match = pattern.exec(text);
    while (match) {
        html += escapeHtml(text.slice(last, match.index));
        last = pattern.lastIndex;
        const codes = match[1] === "" ? [0] : match[1].split(";").map(Number);
        for (const code of codes) {
            if (code === 0) {
                color = "";
                bold = false;
            } else if (code === 1) {
                bold = true;
            } else if (code === 22) {
                bold = false;
            } else if (code === 39) {
                color = "";
            } else if (ANSI_FG[code]) {
                color = ANSI_FG[code];
            }
        }
        openSpan();
        match = pattern.exec(text);
    }
    html += escapeHtml(text.slice(last));
    closeSpan();
    return html;
}

function terminalHtml(title, body) {
    return `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  html, body { margin: 0; background: #1e1e1e; }
  .term {
    width: 1100px;
    padding: 18px 20px 22px;
    background: #1e1e1e;
    color: #d4d4d4;
    font: 14px/1.45 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    white-space: pre;
  }
  .title { color: #fe8a26; margin-bottom: 12px; }
</style>
</head>
<body>
  <div class="term"><div class="title">% ${escapeHtml(title)}</div>${ansiToHtml(body)}</div>
</body>
</html>`;
}

async function shootCli(page, fileName, command, args) {
    const body = runZd(args);
    await page.setContent(terminalHtml(command, body), { waitUntil: "load" });
    const term = page.locator(".term");
    await term.screenshot({ path: path.join(outDir, fileName) });
}

async function waitForDashboard(page) {
    await page.route(dashboardUrl, async (route) => {
        const response = await route.fetch();
        const body = (await response.text()).replace(
            "<!-- <script src=\"/mock-status-data.js\"></script> -->",
            "<script src=\"/mock-status-data.js\"></script>"
        );
        await route.fulfill({
            status: response.status(),
            contentType: "text/html; charset=utf-8",
            body,
        });
    });
    await page.goto(dashboardUrl, { waitUntil: "domcontentloaded" });
    await page.waitForFunction(
        () => {
            const text = document.body ? document.body.innerText : "";
            return (
                typeof getZnunyDashboardStatusMock === "function" &&
                text.includes("Znuny Development") &&
                !text.includes("Status · loading")
            );
        },
        { timeout: 30000 }
    );
}

async function setTheme(page, mode) {
    await page.evaluate((nextMode) => {
        const input = document.getElementById("theme-toggle");
        const wantDark = nextMode === "dark";
        if (input.checked !== wantDark) {
            input.checked = wantDark;
            input.dispatchEvent(new Event("change", { bubbles: true }));
        }
    }, mode);
    const className = mode === "dark" ? "theme-dark" : "theme-light";
    await page.waitForFunction(
        (expected) => document.body.classList.contains(expected),
        className
    );
}

async function setView(page, view) {
    const selector = view === "table" ? "#view-table" : "#view-cards";
    await page.click(selector);
    await page.waitForFunction((buttonSelector) => {
        const button = document.querySelector(buttonSelector);
        return button && button.getAttribute("aria-pressed") === "true";
    }, selector);
}

async function shootDashboard(page) {
    for (const mode of ["dark", "light"]) {
        await setTheme(page, mode);
        await setView(page, "cards");
        await page.screenshot({
            path: path.join(outDir, `dashboard-cards-${mode}.png`),
            fullPage: true,
        });
        await setView(page, "table");
        await page.screenshot({
            path: path.join(outDir, `dashboard-table-${mode}.png`),
            fullPage: true,
        });
    }
}

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });

await page.addInitScript(() => {
    localStorage.setItem("znuny-dashboard-theme", "dark");
});

await waitForDashboard(page);
await shootDashboard(page);

await shootCli(page, "cli-help.png", "zd help", ["help"]);
await shootCli(page, "cli-release.png", "zd release --help", ["release", "--help"]);
await shootCli(page, "cli-status.png", "zd status", ["status"]);

await browser.close();
