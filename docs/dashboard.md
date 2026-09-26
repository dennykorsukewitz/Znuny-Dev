# Local dashboard

Optional web UI for Znuny-Dev instance overview. Same data as `zd status` / `zd status --json`.

Default URL: [http://127.0.0.1:9999/](http://127.0.0.1:9999/)

---

## Requirements

- **Docker** and Docker Compose. The dashboard HTTP server runs in a container (`dev/dashboard/Dockerfile`, image `node:22-alpine`). Host Node.js is not required for the UI, status, or instance actions.

### Optional: host opener

**Node.js on the host** is optional. It is only used for Folder and IDE buttons. `zd dashboard start` launches `supervisor.mjs` with the host `node` binary (`opener.mjs` on `127.0.0.1:9998`) when `node` is installed. Without it, the container still starts and prints `node not found — workspace links need opener (install Node.js)`. Cards, table, Docker health, instance actions, service actions, and login links keep working.

```bash
node --version
```

Current Node.js LTS is enough. The opener scripts are plain ESM (`.mjs`).

---

## Commands

```bash
zd dashboard start              # Start stack (opens browser)
zd dashboard restart            # Restart container — pick up UI / server changes
zd dashboard stop               # Stop container
zd dashboard remove             # Stop and remove stack
zd dashboard build [--no-cache] # Rebuild image (only when Dockerfile changes)
zd dashboard status             # Show container state
```

---

## How the UI is served

- UI files live in the repo under `dev/dashboard/public` (HTML, CSS, JS, images).
- The dashboard container mounts the repo, so edits on the host are available after **`zd dashboard restart`**.
- No image rebuild for CSS/JS/HTML changes.
- Use **`zd dashboard build`** only when `dev/dashboard/Dockerfile` (base image / packages) changes.

```text
dev/dashboard/
├── public/          # Static UI (mounted from host)
│   ├── index.html
│   ├── app.css
│   ├── app.js
│   └── img/
├── server.mjs       # HTTP API + static server
├── supervisor.mjs   # Host supervisor (respawns opener; watches .opener-wake)
├── opener.mjs       # Host opener (workspace / IDE)
├── ide.mjs          # IDE detection for open-workspace
└── Dockerfile
```

Compose stack: `dev/docker/compose-dashboard.yml`.

---

## Host opener / supervisor

Folder and IDE buttons use an optional host process (`opener.mjs` on `127.0.0.1:9998`) and **Node.js on the host**. The Docker container cannot start host processes when that listener is dead. The rest of the dashboard works without it. See [Optional: host opener](#optional-host-opener).

When the opener is down, Folder and IDE buttons are gray and struck through. Hover shows `Run zd dashboard restart`. `/api/config` reports `opener_available`.

**Cross-platform approach:** `zd dashboard start` launches `supervisor.mjs` on the host. It:

- keeps `opener.mjs` alive (respawn on crash / exit)
- watches repo-root `.opener-wake` so a GUI restart can wake opener again while the supervisor is still running

GUI **Dashboard restart**: soft-restarts opener when reachable; if not, writes `.opener-wake`. If the supervisor itself is gone (e.g. after reboot), run `zd dashboard start` or `zd dashboard restart` once on the host.

Optional later: OS login autostart (launchd / systemd / Task Scheduler) wrapping the same `supervisor.mjs`.

---

## What you can do in the UI

- List instances (cards or table), sort and filter layout
- See Docker health (instance + database)
- Services block under the instances: database containers and Selenium (start / stop / restart, noVNC login)
- Start / stop / restart / build / remove instances
- Open Znuny agent/customer login links
- Open host workspace / IDE
- See linked packages per instance (count and names) and link or unlink them (`zd link` / `zd unlink --only`). Fred and ZnunyCodePolicy are in the same list (`zd link-tool` / `zd unlink-tool --only`). Unlink all unchecks every linked item that still exists on disk. Apply stays gray until a package or tool is newly checked or a linked one is unchecked. Above Apply, LINK lists newly checked names and UNLINK lists unchecked linked names. Afterwards shows DBInstall and CodeInstall (on) for new packages, DBUninstall and CodeUninstall (off) for unlinked packages, and Rebuild Config plus Delete Cache (on) for either change. A failed step keeps the dialog open and shows the command output.
- About dialog (version, docs links, support)

---

## Tips

| Goal | Command |
| --- | --- |
| First start | `zd dashboard start` |
| After editing `app.css` / `app.js` / `index.html` | `zd dashboard restart` |
| After changing `server.mjs` | `zd dashboard restart` |
| After changing `Dockerfile` | `zd dashboard build` then `zd dashboard start` |
| Tear down | `zd dashboard remove` |

Opener (open Finder / IDE from the UI) listens on `127.0.0.1:9998`, supervised by `supervisor.mjs`, started with the dashboard.

---

## Related

- Full `zd` reference: [usage.md](usage.md)
- Project overview: [README.md](../README.md)
