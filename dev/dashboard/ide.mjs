/**
 * DEFAULT_IDE from configs/instance/my.env (dashboard editor button).
 */
import fs from "fs";
import path from "path";

/** Known CLI aliases → command + UI label. */
export const REGISTRY = {
    cursor: { cmd: "cursor", label: "Cursor" },
    code: { cmd: "code", label: "VS Code" },
    vscode: { cmd: "code", label: "VS Code" },
    "code-insiders": { cmd: "code-insiders", label: "VS Code Insiders" },
    idea: { cmd: "idea", label: "IntelliJ IDEA" },
    phpstorm: { cmd: "phpstorm", label: "PhpStorm" },
    webstorm: { cmd: "webstorm", label: "WebStorm" },
    zed: { cmd: "zed", label: "Zed" },
};

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
