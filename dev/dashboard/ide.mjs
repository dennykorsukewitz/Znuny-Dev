/**
 * DEFAULT_IDE from configs/instance/my.env (dashboard editor button).
 */
import { execSync } from "child_process";
import fs from "fs";
import path from "path";

/** Known CLI aliases → command + UI label. */
export const REGISTRY = {
    cursor: { cmd: "cursor", label: "Cursor" },
    code: {
        cmd: "code",
        label: "VS Code",
        paths: [
            "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
        ],
        darwinAppBin: { app: "Visual Studio Code", bin: "code" },
    },
    vscode: {
        cmd: "code",
        label: "VS Code",
        paths: [
            "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
        ],
        darwinAppBin: { app: "Visual Studio Code", bin: "code" },
    },
    "code-insiders": { cmd: "code-insiders", label: "VS Code Insiders" },
    idea: { cmd: "idea", label: "IntelliJ IDEA" },
    phpstorm: { cmd: "phpstorm", label: "PhpStorm" },
    webstorm: { cmd: "webstorm", label: "WebStorm" },
    zed: { cmd: "zed", label: "Zed" },
    sublime: {
        cmd: "subl",
        label: "Sublime Text",
        paths: [
            "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl",
        ],
        darwinAppBin: { app: "Sublime Text", bin: "subl" },
    },
    subl: {
        cmd: "subl",
        label: "Sublime Text",
        paths: [
            "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl",
        ],
        darwinAppBin: { app: "Sublime Text", bin: "subl" },
    },
};

/** Registry scan order — first id wins when several aliases share one cmd. */
const REGISTRY_SCAN_ORDER = [
    "cursor",
    "code",
    "vscode",
    "code-insiders",
    "idea",
    "phpstorm",
    "webstorm",
    "zed",
    "sublime",
    "subl",
];

function isCommandAvailable(cmd) {
    if (!cmd || typeof cmd !== "string") {
        return false;
    }
    try {
        if (process.platform === "win32") {
            execSync("where " + cmd, { stdio: "ignore" });
        } else {
            execSync("command -v " + cmd, { stdio: "ignore", shell: true });
        }
        return true;
    } catch {
        return false;
    }
}

function isExecutableFile(filePath) {
    if (!filePath || typeof filePath !== "string") {
        return false;
    }
    try {
        fs.accessSync(filePath, fs.constants.X_OK);
        return true;
    } catch {
        return false;
    }
}

function findDarwinAppBin(appNameIncludes, binName) {
    if (process.platform !== "darwin" || !appNameIncludes || !binName) {
        return null;
    }
    let names;
    try {
        names = fs.readdirSync("/Applications");
    } catch {
        return null;
    }
    for (const name of names) {
        if (!name.endsWith(".app") || !name.includes(appNameIncludes)) {
            continue;
        }
        const candidate = path.join(
            "/Applications",
            name,
            "Contents/SharedSupport/bin",
            binName,
        );
        if (isExecutableFile(candidate)) {
            return candidate;
        }
    }
    return null;
}

function resolveIdeExecutable(entry) {
    if (!entry || !entry.cmd) {
        return null;
    }
    if (isCommandAvailable(entry.cmd)) {
        return entry.cmd;
    }
    for (const candidate of entry.paths || []) {
        if (isExecutableFile(candidate)) {
            return candidate;
        }
    }
    if (entry.darwinAppBin) {
        const found = findDarwinAppBin(
            entry.darwinAppBin.app,
            entry.darwinAppBin.bin,
        );
        if (found) {
            return found;
        }
    }
    return null;
}

function enrichIde(meta, registryEntry) {
    const exec = resolveIdeExecutable(registryEntry || { cmd: meta.cmd, paths: [] });
    if (!exec) {
        return null;
    }
    return {
        id: meta.id,
        cmd: meta.cmd,
        label: meta.label,
        exec,
    };
}

function parseEnvValue(raw) {
    let v = String(raw || "").trim();
    if (
        (v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("'"))
    ) {
        v = v.slice(1, -1);
    }
    return v.trim();
}

function readKeyFromEnvFile(filePath, key) {
    let raw;
    try {
        raw = fs.readFileSync(filePath, "utf8");
    } catch {
        return "";
    }
    const re = new RegExp("^" + key + "=(.+)$", "m");
    const match = raw.match(re);
    if (!match) {
        return "";
    }
    return parseEnvValue(match[1]);
}

/**
 * @returns {{ id: string, cmd: string, label: string } | null}
 */
export function readDefaultIde(znunyDevDir) {
    const root = znunyDevDir || process.cwd();
    const fromMyEnv = readKeyFromEnvFile(
        path.join(root, "configs/instance/my.env"),
        "DEFAULT_IDE",
    );
    const fromDotEnv = readKeyFromEnvFile(path.join(root, ".env"), "DEFAULT_IDE");
    const id = parseEnvValue(
        process.env.DEFAULT_IDE || fromMyEnv || fromDotEnv || "",
    );
    if (!id) {
        return null;
    }
    const key = id.toLowerCase();
    const known = REGISTRY[key];
    if (known) {
        return { id: key, cmd: known.cmd, label: known.label };
    }
    return { id, cmd: id, label: id };
}

/**
 * @returns {Array<{ id: string, cmd: string, label: string, exec: string }>}
 */
export function detectAvailableIdes() {
    const seen = new Map();
    const keys = REGISTRY_SCAN_ORDER.concat(
        Object.keys(REGISTRY).filter((id) => !REGISTRY_SCAN_ORDER.includes(id)),
    );
    for (const id of keys) {
        const entry = REGISTRY[id];
        if (!entry || seen.has(entry.cmd)) {
            continue;
        }
        const resolved = enrichIde(
            { id, cmd: entry.cmd, label: entry.label },
            entry,
        );
        if (resolved) {
            seen.set(entry.cmd, resolved);
        }
    }
    return Array.from(seen.values()).sort((a, b) =>
        a.label.localeCompare(b.label, undefined, { sensitivity: "base" }),
    );
}

/**
 * @returns {{ id: string, cmd: string, label: string, exec: string } | null}
 */
export function resolveIdeById(id) {
    if (!id || typeof id !== "string") {
        return null;
    }
    const key = id.toLowerCase().trim();
    const known = REGISTRY[key];
    if (known) {
        return enrichIde({ id: key, cmd: known.cmd, label: known.label }, known);
    }
    const raw = id.trim();
    if (!/^[A-Za-z0-9._-]+$/.test(raw)) {
        return null;
    }
    return enrichIde({ id: raw, cmd: raw, label: raw }, { cmd: raw, paths: [] });
}

/**
 * @returns {{ id: string, cmd: string, label: string, exec: string } | null}
 */
export function resolveIdeForOpen(ideId, znunyDevDir) {
    if (ideId) {
        return resolveIdeById(ideId);
    }
    const defaultIde = readDefaultIde(znunyDevDir);
    if (defaultIde) {
        const resolved = resolveIdeById(defaultIde.id);
        if (resolved) {
            return resolved;
        }
    }
    const available = detectAvailableIdes();
    return available.length ? available[0] : null;
}

/**
 * @returns {{
 *   default_ide: string | null,
 *   default_ide_cmd: string | null,
 *   default_ide_label: string | null,
 *   available_ides: Array<{ id: string, cmd: string, label: string, exec: string }>,
 * }}
 */
export function buildDashboardIdeConfig(znunyDevDir) {
    const defaultIde = readDefaultIde(znunyDevDir);
    return {
        default_ide: defaultIde ? defaultIde.id : null,
        default_ide_cmd: defaultIde ? defaultIde.cmd : null,
        default_ide_label: defaultIde ? defaultIde.label : null,
        available_ides: detectAvailableIdes(),
    };
}
