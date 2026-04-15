/**
 * Minimal static server: GET /api/status + static UI (znuny-dev dashboard).
 */
import http from "http";
import fs from "fs";
import path from "path";
import { spawn } from "child_process";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT || 3000);

/** Prefer Docker mount path; host may set ZNUNY_DEV_DIR to a macOS path that breaks inside the container. */
function getZnunyDevDir() {
    const mount = "/znuny-dev";
    try {
        fs.accessSync(path.join(mount, "dev/scripts/common.sh"), fs.constants.R_OK);
        return mount;
    } catch {
        return process.env.ZNUNY_DEV_DIR || path.join(__dirname, "..", "..");
    }
}

const ZNUNY_DEV_DIR = getZnunyDevDir();
/** Dashboard API: dev/scripts/instance/status-json.sh */
const DASHBOARD_STATUS_SCRIPT = path.join(
    ZNUNY_DEV_DIR,
    "dev/scripts/instance/status-json.sh",
);

/**
 * Serve UI from the repo mount when available (Compose binds ../../ → /znuny-dev),
 * so CSS/JS changes apply without `zd dashboard build`. Fallback: files baked into /app/public.
 */
function getStaticDir() {
    const fromMount = path.join(ZNUNY_DEV_DIR, "dev/dashboard/public");
    try {
        fs.accessSync(path.join(fromMount, "index.html"), fs.constants.R_OK);
        return fromMount;
    } catch {
        return path.join(__dirname, "public");
    }
}

const MIME = {
    ".html": "text/html; charset=utf-8",
    ".js": "application/javascript; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".svg": "image/svg+xml",
    ".ico": "image/x-icon",
};

function sendFile(res, filePath, contentType) {
    fs.readFile(filePath, (err, data) => {
        if (err) {
            const code = err.code === "ENOENT" ? 404 : 500;
            res.writeHead(code, { "Content-Type": "text/plain; charset=utf-8" });
            res.end(code === 404 ? "Not found" : "Server error");
            return;
        }
        const headers = { "Content-Type": contentType };
        if (
            contentType.includes("text/html") ||
            contentType.includes("text/css") ||
            contentType.includes("javascript")
        ) {
            headers["Cache-Control"] = "no-store";
        }
        res.writeHead(200, headers);
        res.end(data);
    });
}

function normalizePathname(p) {
    if (!p || p === "/") {
        return "/";
    }
    return p.replace(/\/+$/, "") || "/";
}

const server = http.createServer((req, res) => {
    const host = req.headers.host || "localhost";
    let u;
    try {
        u = new URL(req.url || "/", `http://${host}`);
    } catch {
        res.writeHead(400, { "Content-Type": "text/plain; charset=utf-8" });
        res.end("Bad request");
        return;
    }

    const pathname = normalizePathname(u.pathname);

    if (pathname === "/api/status") {
        const verbose =
            u.searchParams.get("verbose") === "1" ||
            u.searchParams.get("verbose") === "true";
        const args = verbose
            ? [DASHBOARD_STATUS_SCRIPT, "--verbose"]
            : [DASHBOARD_STATUS_SCRIPT];
        const child = spawn("bash", args, {
            env: { ...process.env, ZNUNY_DEV_DIR: getZnunyDevDir() },
            stdio: ["ignore", "pipe", "pipe"],
        });
        let out = "";
        let err = "";
        child.stdout.on("data", (c) => {
            out += c;
        });
        child.stderr.on("data", (c) => {
            err += c;
        });
        child.on("close", (code) => {
            if (code !== 0) {
                res.writeHead(500, {
                    "Content-Type": "application/json; charset=utf-8",
                });
                res.end(
                    JSON.stringify({
                        error: "status script failed",
                        detail: err.slice(0, 2000),
                    }),
                );
                return;
            }
            res.writeHead(200, {
                "Content-Type": "application/json; charset=utf-8",
                "Cache-Control": "no-store",
            });
            res.end(out.trim());
        });
        return;
    }

    // Browsers request /favicon.ico by default; serve SVG via redirect if no .ico on disk.
    if (pathname === "/favicon.ico") {
        const staticDir = getStaticDir();
        const icoPath = path.join(staticDir, "favicon.ico");
        if (!fs.existsSync(icoPath)) {
            const svgPath = path.join(staticDir, "favicon.svg");
            if (fs.existsSync(svgPath)) {
                res.writeHead(302, { Location: "/favicon.svg" });
                res.end();
                return;
            }
        }
    }

    const rel = pathname === "/" ? "index.html" : pathname.slice(1);
    if (rel.includes("..") || path.isAbsolute(rel)) {
        res.writeHead(403);
        res.end("Forbidden");
        return;
    }
    const staticDir = getStaticDir();
    let staticRoot;
    try {
        staticRoot = fs.realpathSync(staticDir);
    } catch {
        staticRoot = path.resolve(staticDir);
    }
    const filePath = path.resolve(staticRoot, rel);
    if (
        filePath !== staticRoot &&
        !filePath.startsWith(staticRoot + path.sep)
    ) {
        res.writeHead(403);
        res.end("Forbidden");
        return;
    }
    const ext = path.extname(filePath);
    const ct = MIME[ext] || "application/octet-stream";
    sendFile(res, filePath, ct);
});

const _staticDir = getStaticDir();
console.error(
    "[dashboard] http://0.0.0.0:" + PORT,
    "ui=" + _staticDir,
    fs.existsSync(path.join(_staticDir, "index.html")) ? "ok" : "MISSING index.html",
);

server.listen(PORT, "0.0.0.0");
