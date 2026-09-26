/**
 * Host helper for the dashboard Restart button.
 * The UI runs in Docker and cannot spawn macOS/Windows processes.
 * This agent stays on the host and runs `zd dashboard restart` when the
 * container writes `.dashboard-host-restart`.
 * Started by launchd (macOS), systemd --user (Linux), or nohup from
 * `zd dashboard start` / `zd dashboard restart`.
 */
import { spawn } from "child_process";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ZNUNY_DEV_DIR =
    process.env.ZNUNY_DEV_DIR || path.resolve(__dirname, "..", "..");
const TRIGGER = path.join(ZNUNY_DEV_DIR, ".dashboard-host-restart");
const ACK = path.join(ZNUNY_DEV_DIR, ".dashboard-host-restart.ack");
const POLL_MS = 250;

let lastMtimeMs = 0;
let running = false;

function log(msg) {
    console.error("[host-restart] " + msg);
}

function readMtime() {
    try {
        return fs.statSync(TRIGGER).mtimeMs;
    } catch {
        return 0;
    }
}

function runRestart(token) {
    running = true;
    try {
        fs.writeFileSync(ACK, token + "\n");
    } catch (e) {
        log("ack write failed: " + (e && e.message ? e.message : e));
        running = false;
        return;
    }
    log("zd dashboard restart");
    const child = spawn(
        "bash",
        [path.join(ZNUNY_DEV_DIR, "znuny-dev.sh"), "dashboard", "restart"],
        {
            cwd: ZNUNY_DEV_DIR,
            env: {
                ...process.env,
                ZNUNY_DEV_DIR: ZNUNY_DEV_DIR,
                ZNUNY_HOST_RESTART_AGENT: "1",
            },
            stdio: "ignore",
        },
    );
    child.on("error", (e) => {
        log("spawn failed: " + (e && e.message ? e.message : e));
        running = false;
    });
    child.on("exit", (code) => {
        running = false;
        if (code) {
            log("zd dashboard restart exit " + code);
        }
    });
}

function tick() {
    if (running) {
        return;
    }
    const mtime = readMtime();
    if (!mtime || mtime <= lastMtimeMs) {
        return;
    }
    lastMtimeMs = mtime;
    let token = "";
    try {
        token = fs.readFileSync(TRIGGER, "utf8").trim();
    } catch {
        return;
    }
    if (!token) {
        return;
    }
    runRestart(token);
}

lastMtimeMs = readMtime();
setInterval(tick, POLL_MS);
log("watching " + TRIGGER);
