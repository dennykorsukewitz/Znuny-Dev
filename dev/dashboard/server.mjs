/**
 * Minimal static server: GET /api/status, POST /api/zd, GET|POST /api/open-workspace, static UI.
 */
import http from "http";
import fs from "fs";
import path from "path";
import { spawn } from "child_process";
import { fileURLToPath } from "url";
import { buildDashboardIdeConfig, resolveIdeForOpen } from "./ide.mjs";

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
const ZD_BODY_MAX = 16384;
/** Safe framework directory basename (matches typical frameworks/* names). */
const FRAMEWORK_NAME_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/;
const OPENER_PORT = Number(process.env.OPENER_PORT || 9998);
const OPENER_HOST = process.env.OPENER_HOST || "host.docker.internal";

/**
 * Registered dashboard commands: extend here for sync-indices, create, remove, etc.
 * Each value builds argv passed to instance.sh (no shell interpolation).
 */
const ZD_REGISTRY = {
    start: { buildArgv: (framework) => ["start", framework] },
    stop: { buildArgv: (framework) => ["stop", framework] },
    restart: { buildArgv: (framework) => ["restart", framework] },
    build: { buildArgv: (framework) => ["build", framework] },
    remove: { buildArgv: (framework) => ["remove", framework, "--force"] },
    "db-start": { buildArgv: (framework) => ["db-start", framework] },
    "db-stop": { buildArgv: (framework) => ["db-stop", framework] },
    "db-restart": { buildArgv: (framework) => ["db-restart", framework] },
};

function jsonError(res, status, error, detail) {
    const payload = { error };
    if (detail) {
        payload.detail = detail;
    }
    res.writeHead(status, {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store",
    });
    res.end(JSON.stringify(payload));
}

function runInstanceScript(argv, res) {
    const root = getZnunyDevDir();
    const scriptPath = path.join(root, "dev/scripts/instance.sh");
    const child = spawn("bash", [scriptPath, ...argv], {
        env: { ...process.env, ZNUNY_DEV_DIR: root },
        cwd: root,
        stdio: ["ignore", "pipe", "pipe"],
    });
    let out = "";
    let err = "";
    let finished = false;
    function finish(fn) {
        if (finished) {
            return;
        }
        finished = true;
        fn();
    }
    child.stdout.on("data", (c) => {
        out += c;
    });
    child.stderr.on("data", (c) => {
        err += c;
    });
    child.on("error", (e) => {
        finish(function () {
            jsonError(
                res,
                500,
                "spawn failed",
                String(e && e.message ? e.message : e).slice(0, 500),
            );
        });
    });
    child.on("close", (code) => {
        finish(function () {
            const combined = (err + "\n" + out).trim();
            const detail = combined.slice(0, 8000);
            if (code !== 0) {
                jsonError(
                    res,
                    500,
                    "instance.sh failed",
                    detail || `exit ${code}`,
                );
                return;
            }
            res.writeHead(200, {
                "Content-Type": "application/json; charset=utf-8",
                "Cache-Control": "no-store",
            });
            res.end(JSON.stringify({ ok: true }));
        });
    });
}

function readFrameworkDirFromEnv(framework) {
    const envFile = path.join(
        ZNUNY_DEV_DIR,
        "instances",
        framework,
        `${framework}.env`,
    );
    let raw;
    try {
        raw = fs.readFileSync(envFile, "utf8");
    } catch {
        return null;
    }
    const match = raw.match(/^FRAMEWORK_DIR=(.+)$/m);
    if (!match) {
        return null;
    }
    let dir = match[1].trim().replace(/^["']|["']$/g, "");
    if (!dir || dir.includes("..")) {
        return null;
    }
    return path.resolve(dir);
}

function openPathNative(hostPath) {
    if (process.platform === "darwin") {
        spawn("open", [hostPath], { detached: true, stdio: "ignore" }).unref();
        return true;
    }
    if (process.platform === "win32") {
        spawn("explorer.exe", [hostPath], {
            detached: true,
            stdio: "ignore",
        }).unref();
        return true;
    }
    if (process.platform === "linux") {
        spawn("xdg-open", [hostPath], {
            detached: true,
            stdio: "ignore",
        }).unref();
        return true;
    }
    return false;
}

async function proxyOpener(pathSuffix, res, fallbackBody) {
    const url =
        "http://" +
        OPENER_HOST +
        ":" +
        OPENER_PORT +
        pathSuffix;
    try {
        const upstream = await fetch(url, {
            method: "GET",
            signal: AbortSignal.timeout(30000),
        });
        const text = await upstream.text();
        let data = null;
        if (text) {
            try {
                data = JSON.parse(text);
            } catch {
                jsonError(
                    res,
                    502,
                    "opener invalid response",
                    text.slice(0, 300),
                );
                return;
            }
        }
        if (!upstream.ok) {
            jsonError(
                res,
                upstream.status >= 400 ? upstream.status : 502,
                (data && data.error) || "opener failed",
                data && data.detail,
            );
            return;
        }
        res.writeHead(200, {
            "Content-Type": "application/json; charset=utf-8",
            "Cache-Control": "no-store",
        });
        res.end(JSON.stringify(data || fallbackBody || { ok: true }));
    } catch (e) {
        jsonError(
            res,
            503,
            "opener unavailable",
            "Start the dashboard with zd dashboard start (opener on 127.0.0.1:" +
                OPENER_PORT +
                "). " +
                String(e && e.message ? e.message : e).slice(0, 200),
        );
    }
}

function openIdeNative(hostPath, ide) {
    spawn(ide.exec || ide.cmd, [hostPath], {
        detached: true,
        stdio: "ignore",
        shell: process.platform === "win32",
    }).unref();
}

async function handleDashboardConfig(res) {
    if (fs.existsSync("/.dockerenv")) {
        await proxyOpener("/config", res);
        return;
    }
    res.writeHead(200, {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store",
    });
    res.end(JSON.stringify(buildDashboardIdeConfig(getZnunyDevDir())));
}

async function handleOpenWorkspace(req, res, framework) {
    const hostPath = readFrameworkDirFromEnv(framework);
    if (!hostPath) {
        jsonError(res, 404, "framework not found");
        return;
    }

    const inDocker = fs.existsSync("/.dockerenv");

    if (!inDocker) {
        try {
            fs.accessSync(hostPath, fs.constants.R_OK);
        } catch {
            jsonError(res, 404, "host workspace path not found");
            return;
        }
        if (!openPathNative(hostPath)) {
            jsonError(res, 500, "unsupported platform for open");
            return;
        }
        res.writeHead(200, {
            "Content-Type": "application/json; charset=utf-8",
            "Cache-Control": "no-store",
        });
        res.end(JSON.stringify({ ok: true, path: hostPath }));
        return;
    }

    await proxyOpener(
        "/open?framework=" + encodeURIComponent(framework),
        res,
        { ok: true, path: hostPath },
    );
}

async function handleOpenIde(req, res, framework, ideId) {
    const hostPath = readFrameworkDirFromEnv(framework);
    if (!hostPath) {
        jsonError(res, 404, "framework not found");
        return;
    }

    const inDocker = fs.existsSync("/.dockerenv");

    if (inDocker) {
        await proxyOpener(
            "/open-ide?framework=" +
                encodeURIComponent(framework) +
                (ideId ? "&ide=" + encodeURIComponent(ideId) : ""),
            res,
        );
        return;
    }

    const ide = resolveIdeForOpen(ideId || null, getZnunyDevDir());
    if (!ide) {
        jsonError(
            res,
            503,
            ideId ? "IDE not available" : "no IDE available",
            ideId
                ? "Requested editor is not installed or not on PATH"
                : "Set DEFAULT_IDE in configs/instance/my.env (e.g. cursor or code)",
        );
        return;
    }

    try {
        fs.accessSync(hostPath, fs.constants.R_OK);
    } catch {
        jsonError(res, 404, "host workspace path not found");
        return;
    }

    res.writeHead(200, {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store",
    });
    res.end(
        JSON.stringify({
            ok: true,
            path: hostPath,
            framework,
            ide: ide.id,
            label: ide.label,
        }),
    );
    setImmediate(() => {
        try {
            openIdeNative(hostPath, ide);
        } catch (spawnErr) {
            console.error(
                "[dashboard] IDE spawn failed:",
                spawnErr && spawnErr.message ? spawnErr.message : spawnErr,
            );
        }
    });
}

function handlePostZd(req, res) {
    let raw = "";
    let tooBig = false;
    req.on("error", () => {
        if (!res.headersSent) {
            res.destroy();
        }
    });
    req.on("data", (chunk) => {
        raw += chunk;
        if (raw.length > ZD_BODY_MAX) {
            tooBig = true;
        }
    });
    req.on("end", () => {
        if (tooBig) {
            jsonError(res, 413, "request body too large");
            return;
        }
        let body;
        try {
            body = raw ? JSON.parse(raw) : {};
        } catch {
            jsonError(res, 400, "invalid JSON");
            return;
        }
        const command = body.command;
        if (typeof command !== "string" || !ZD_REGISTRY[command]) {
            jsonError(res, 400, "unknown or missing command");
            return;
        }
        const framework = body.framework;
        if (typeof framework !== "string" || !FRAMEWORK_NAME_RE.test(framework)) {
            jsonError(res, 400, "invalid or missing framework");
            return;
        }
        const entry = ZD_REGISTRY[command];
        let argv;
        try {
            argv = entry.buildArgv(framework);
        } catch (e) {
            jsonError(
                res,
                500,
                "command build failed",
                String(e && e.message ? e.message : e).slice(0, 500),
            );
            return;
        }
        runInstanceScript(argv, res);
    });
}

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

    if (pathname === "/api/zd") {
        if (req.method === "POST") {
            handlePostZd(req, res);
            return;
        }
        res.writeHead(405, {
            "Content-Type": "application/json; charset=utf-8",
            Allow: "POST",
            "Cache-Control": "no-store",
        });
        res.end(JSON.stringify({ error: "method not allowed" }));
        return;
    }

    if (pathname === "/api/config") {
        if (req.method !== "GET") {
            res.writeHead(405, {
                "Content-Type": "application/json; charset=utf-8",
                Allow: "GET",
                "Cache-Control": "no-store",
            });
            res.end(JSON.stringify({ error: "method not allowed" }));
            return;
        }
        handleDashboardConfig(res).catch((e) => {
            if (!res.headersSent) {
                jsonError(
                    res,
                    500,
                    "config failed",
                    String(e && e.message ? e.message : e).slice(0, 300),
                );
            }
        });
        return;
    }

    if (pathname === "/api/open-workspace") {
        if (req.method !== "GET" && req.method !== "POST") {
            res.writeHead(405, {
                "Content-Type": "application/json; charset=utf-8",
                Allow: "GET, POST",
                "Cache-Control": "no-store",
            });
            res.end(JSON.stringify({ error: "method not allowed" }));
            return;
        }
        const framework = u.searchParams.get("framework") || "";
        if (!FRAMEWORK_NAME_RE.test(framework)) {
            jsonError(res, 400, "invalid or missing framework");
            return;
        }
        handleOpenWorkspace(req, res, framework);
        return;
    }

    if (pathname === "/api/open-ide") {
        if (req.method !== "GET" && req.method !== "POST") {
            res.writeHead(405, {
                "Content-Type": "application/json; charset=utf-8",
                Allow: "GET, POST",
                "Cache-Control": "no-store",
            });
            res.end(JSON.stringify({ error: "method not allowed" }));
            return;
        }
        const framework = u.searchParams.get("framework") || "";
        if (!FRAMEWORK_NAME_RE.test(framework)) {
            jsonError(res, 400, "invalid or missing framework");
            return;
        }
        const ideId = u.searchParams.get("ide") || "";
        handleOpenIde(req, res, framework, ideId);
        return;
    }

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
