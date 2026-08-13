/**
 * Cross-platform host supervisor for opener.mjs.
 * - Respawns opener on crash / exit
 * - Watches .opener-wake (GUI / container can write this when opener is down)
 * Started by `zd dashboard start` on the host (not in Docker).
 */
import { spawn } from "child_process";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ZNUNY_DEV_DIR =
    process.env.ZNUNY_DEV_DIR || path.resolve(__dirname, "..", "..");
const OPENER_PORT = String(process.env.OPENER_PORT || 9998);
const OPENER_SCRIPT = path.join(__dirname, "opener.mjs");
const WAKE_FILE = path.join(ZNUNY_DEV_DIR, ".opener-wake");
const SUPERVISOR_PIDFILE = path.join(ZNUNY_DEV_DIR, ".supervisor.pid");
const RESPAWN_MS = 400;
const WAKE_POLL_MS = 1000;

let child = null;
let shuttingDown = false;
let respawnTimer = null;
let lastWakeMtimeMs = 0;

function log(msg) {
    console.error("[supervisor] " + msg);
}

function writePidfile() {
    try {
        fs.writeFileSync(SUPERVISOR_PIDFILE, String(process.pid) + "\n");
    } catch (e) {
        log(
            "pidfile write failed: " +
                (e && e.message ? e.message : String(e)),
        );
    }
}

function clearPidfile() {
    try {
        fs.unlinkSync(SUPERVISOR_PIDFILE);
    } catch {
        /* ignore */
    }
}

function clearRespawnTimer() {
    if (respawnTimer) {
        clearTimeout(respawnTimer);
        respawnTimer = null;
    }
}

function scheduleRespawn() {
    if (shuttingDown) {
        return;
    }
    clearRespawnTimer();
    respawnTimer = setTimeout(function () {
        respawnTimer = null;
        spawnOpener();
    }, RESPAWN_MS);
}

function spawnOpener() {
    if (shuttingDown || child) {
        return;
    }
    child = spawn(process.execPath, [OPENER_SCRIPT], {
        cwd: ZNUNY_DEV_DIR,
        env: {
            ...process.env,
            ZNUNY_DEV_DIR,
            OPENER_PORT,
            SUPERVISED: "1",
        },
        stdio: "ignore",
        detached: false,
    });
    child.on("exit", function (code, signal) {
        child = null;
        if (shuttingDown) {
            return;
        }
        log(
            "opener exited code=" +
                code +
                " signal=" +
                signal +
                "; respawn in " +
                RESPAWN_MS +
                "ms",
        );
        scheduleRespawn();
    });
    child.on("error", function (e) {
        log("opener spawn failed: " + (e && e.message ? e.message : e));
        child = null;
        if (!shuttingDown) {
            scheduleRespawn();
        }
    });
    log("opener started pid=" + (child.pid || "?"));
}

function killOpener() {
    if (!child || !child.pid) {
        return;
    }
    try {
        child.kill("SIGTERM");
    } catch {
        /* ignore */
    }
}

function readWakeMtime() {
    try {
        return fs.statSync(WAKE_FILE).mtimeMs;
    } catch {
        return 0;
    }
}

function handleWake() {
    if (shuttingDown) {
        return;
    }
    const mtime = readWakeMtime();
    if (!mtime || mtime <= lastWakeMtimeMs) {
        return;
    }
    lastWakeMtimeMs = mtime;
    log("wake file — restarting opener");
    if (child && child.pid) {
        killOpener();
        return;
    }
    spawnOpener();
}

function shutdown() {
    if (shuttingDown) {
        return;
    }
    shuttingDown = true;
    clearRespawnTimer();
    killOpener();
    clearPidfile();
    process.exit(0);
}

process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);

lastWakeMtimeMs = readWakeMtime();
writePidfile();
spawnOpener();
setInterval(handleWake, WAKE_POLL_MS);
log(
    "127.0.0.1 opener via supervisor; wake=" +
        WAKE_FILE +
        " znuny-dev=" +
        ZNUNY_DEV_DIR,
);
