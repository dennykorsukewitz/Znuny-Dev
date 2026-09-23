# Local dashboard

Optional web UI for Znuny-Dev instance overview. Same data as `zd status` / `zd status --json`.

Default URL: [http://127.0.0.1:9999/](http://127.0.0.1:9999/)

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

Folder and IDE buttons need a **host** process (`opener.mjs` on `127.0.0.1:9998`). The Docker container cannot start host processes when that listener is dead.

**Cross-platform approach:** `zd dashboard start` launches `supervisor.mjs` on the host. It:

- keeps `opener.mjs` alive (respawn on crash / exit)
- watches repo-root `.opener-wake` so a GUI restart can wake opener again while the supervisor is still running

GUI **Dashboard restart**: soft-restarts opener when reachable; if not, writes `.opener-wake`. If the supervisor itself is gone (e.g. after reboot), run `zd dashboard start` or `zd dashboard restart` once on the host.

Optional later: OS login autostart (launchd / systemd / Task Scheduler) wrapping the same `supervisor.mjs`.

---

## What you can do in the UI

- List instances (cards or table), sort and filter layout
- See Docker health (instance + database)
- Services block under the instances: database containers and Selenium (start / stop / restart, noVNC link)
- Start / stop / restart / build / remove instances
- Open Znuny agent/customer login links
- Open host workspace / IDE
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
