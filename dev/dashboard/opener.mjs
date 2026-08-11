/**
 * Host-side opener: FRAMEWORK_DIR in Finder / Explorer or DEFAULT_IDE.
 * 127.0.0.1 only. Started by `zd dashboard start` on the host (not in Docker).
 */
import http from "http";
import fs from "fs";
import path from "path";
import { spawn } from "child_process";
import { fileURLToPath } from "url";
import { buildDashboardIdeConfig, resolveIdeForOpen } from "./ide.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ZNUNY_DEV_DIR =
    process.env.ZNUNY_DEV_DIR || path.resolve(__dirname, "..", "..");
const PORT = Number(process.env.OPENER_PORT || 9998);
const FRAMEWORK_NAME_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/;

function readFrameworkDir(framework) {
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

function validateFrameworkDir(framework) {
    const hostPath = readFrameworkDir(framework);
    if (!hostPath) {
        return { error: "framework env not found", status: 404 };
    }
    try {
        const st = fs.statSync(hostPath);
        if (!st.isDirectory()) {
            return { error: "path is not a directory", status: 404 };
        }
    } catch {
        return { error: "path does not exist on host", status: 404 };
    }
    return { hostPath };
}

function openNative(hostPath) {
    if (process.platform === "darwin") {
        spawn("open", [hostPath], { detached: true, stdio: "ignore" }).unref();
        return;
    }
    if (process.platform === "win32") {
        spawn("explorer.exe", [hostPath], {
            detached: true,
            stdio: "ignore",
        }).unref();
        return;
    }
    spawn("xdg-open", [hostPath], { detached: true, stdio: "ignore" }).unref();
}

function openIde(hostPath, ide) {
    if (!ide || (!ide.exec && !ide.cmd)) {
        throw new Error("no default IDE configured");
    }
    spawn(ide.exec || ide.cmd, [hostPath], {
        detached: true,
        stdio: "ignore",
        shell: process.platform === "win32",
    }).unref();
}

function json(res, status, body) {
    res.writeHead(status, {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store",
    });
    res.end(JSON.stringify(body));
}

function openerPidfile() {
    return path.join(ZNUNY_DEV_DIR, ".opener.pid");
}

/** Spawn a replacement opener, update pidfile, then exit this process. */
function scheduleSelfRestart() {
    setTimeout(() => {
        const scriptPath = fileURLToPath(import.meta.url);
        const child = spawn(process.execPath, [scriptPath], {
            detached: true,
            stdio: "ignore",
            cwd: ZNUNY_DEV_DIR,
            env: {
                ...process.env,
                ZNUNY_DEV_DIR,
                OPENER_PORT: String(PORT),
            },
        });
        child.on("error", (e) => {
            console.error(
                "[opener] restart spawn failed:",
                e && e.message ? e.message : e,
            );
        });
        try {
            if (child.pid) {
                fs.writeFileSync(openerPidfile(), String(child.pid) + "\n");
            }
        } catch (e) {
            console.error(
                "[opener] pidfile update failed:",
                e && e.message ? e.message : e,
            );
        }
        child.unref();
        server.close(() => {
            process.exit(0);
        });
        setTimeout(() => {
            process.exit(0);
        }, 800);
    }, 150);
}

const server = http.createServer((req, res) => {
    let u;
    try {
        u = new URL(req.url || "/", `http://127.0.0.1:${PORT}`);
    } catch {
        json(res, 400, { error: "bad request" });
        return;
    }

    if (req.method !== "GET" && req.method !== "POST") {
        json(res, 405, { error: "method not allowed" });
        return;
    }

    if (u.pathname === "/health") {
        json(res, 200, { ok: true });
        return;
    }

    if (u.pathname === "/config") {
        json(res, 200, buildDashboardIdeConfig(ZNUNY_DEV_DIR));
        return;
    }

    if (u.pathname === "/restart") {
        if (req.method !== "POST") {
            json(res, 405, { error: "method not allowed" });
            return;
        }
        json(res, 200, { ok: true, restarting: true });
        scheduleSelfRestart();
        return;
    }

    const framework = u.searchParams.get("framework") || "";
    if (!FRAMEWORK_NAME_RE.test(framework)) {
        json(res, 400, { error: "invalid or missing framework" });
        return;
    }

    const validated = validateFrameworkDir(framework);
    if (validated.error) {
        json(res, validated.status, { error: validated.error });
        return;
    }
    const hostPath = validated.hostPath;

    if (u.pathname === "/open") {
        try {
            openNative(hostPath);
        } catch (e) {
            json(res, 500, {
                error: "open failed",
                detail: String(e && e.message ? e.message : e).slice(0, 300),
            });
            return;
        }
        json(res, 200, { ok: true, path: hostPath, framework });
        return;
    }

    if (u.pathname === "/open-ide") {
        const ideId = u.searchParams.get("ide") || "";
        const ide = resolveIdeForOpen(ideId || null, ZNUNY_DEV_DIR);
        if (!ide) {
            json(res, 503, {
                error: "no IDE available",
                detail: ideId
                    ? "Requested editor is not installed or not on PATH"
                    : "Set DEFAULT_IDE in configs/instance/my.env (e.g. cursor or code)",
            });
            return;
        }
        try {
            json(res, 200, {
                ok: true,
                path: hostPath,
                framework,
                ide: ide.id,
                label: ide.label,
            });
            setImmediate(function () {
                try {
                    openIde(hostPath, ide);
                } catch (spawnErr) {
                    console.error(
                        "[opener] IDE spawn failed:",
                        spawnErr && spawnErr.message
                            ? spawnErr.message
                            : spawnErr,
                    );
                }
            });
        } catch (e) {
            json(res, 500, {
                error: "IDE open failed",
                detail: String(e && e.message ? e.message : e).slice(0, 300),
            });
        }
        return;
    }

    json(res, 404, { error: "not found" });
});

server.listen(PORT, "127.0.0.1", () => {
    console.error(`[opener] 127.0.0.1:${PORT} znuny-dev=${ZNUNY_DEV_DIR}`);
});
