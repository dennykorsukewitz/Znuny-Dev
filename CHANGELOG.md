# Changelog

All notable changes to the Znuny Development Environment will be documented in this file.

## [UNRELEASED] - YYYY-MM-DD

### Added

- Dashboard lists linked packages per instance (count and names from framework symlinks) and can link or unlink one or more packages (`zd link` / `zd unlink --only`). Fred and ZnunyCodePolicy are in the same list and use `zd link-tool` / `zd unlink-tool --only`.
- Dashboard package dialog: Unlink all when the instance already has linked packages or tools. DBInstall, CodeInstall, Rebuild Config, and Delete Cache checkboxes (on by default) run after the file change. A failed step shows the command output in the dialog.
- Dashboard dialogs have a close icon in the top-right corner.
- Document host Node.js as optional for the dashboard opener (Folder / IDE). The dashboard UI, status, and instance actions work without it; the HTTP server uses Node.js 22 inside its Docker image.
- Shared Selenium Chrome (`zd selenium start`) on `znuny-network` (hostname `selenium`, port 4444). Opt-in `ENABLE_SELENIUM=y` makes instance startup write `SeleniumTestsConfig` and `TestHTTPHostname` so browser unit tests can run.
- Selenium Docker health check: `znuny-selenium` is healthy when `http://localhost:4444/status` reports `ready`.
- Dashboard services block, visually separate from instances, lists database containers and Selenium with start / stop / restart.
- Document WSL bind-mount ownership: `zd start` maps container `www-data` to `HOST_UID`/`HOST_GID` so host `git pull` works without a manual `chown`.

### Changed

- Dashboard Folder and IDE buttons are gray and struck through when the host opener is down. Hover shows `Run zd dashboard restart`.
- Dashboard Restart button runs `zd dashboard restart` on the host via `host-restart-agent.mjs`, so the Folder opener comes back with the container.
- Dashboard package dialog drops Cancel. Apply stays gray until a link or unlink is pending, then runs for new links and for unlinks. Afterwards shows DBInstall and CodeInstall (on) for new packages, DBUninstall and CodeUninstall (off) for unlinked packages, and Rebuild Config plus Delete Cache (on) for either change. Above Apply, LINK and UNLINK list the names. A checked new package shows a green + at the right of its row; an unchecked linked package shows a red -. LINK uses that green, UNLINK that red. Apply progress uses the bottom-right message stack; the dialog has no separate status line.
- Dashboard dialogs fit the viewport. Status legend, about, packages, and confirm scroll inside the panel on short or narrow screens, and the close icon stays in the corner.
- Dashboard dev tools that can be linked come from `DEV_TOOL_IDS` in `.env` (default `Fred,ZnunyCodePolicy`). `load_environment` appends that default when the key is missing.
- Selenium noVNC no longer asks for the image default password `secret` (`SE_VNC_NO_PASSWORD=1`). Recreate the container with `zd selenium start` so a running `znuny-selenium` picks it up.
- Leave the clone target before `rm -rf` / `git clone` so a fresh checkout does not fail with `Unable to read current working directory` when the previous framework directory was the shell cwd.

### Fixed

- Create the container user `znuny` with `useradd --non-unique` so it really shares UID/GID with `www-data`. Previously `useradd` aborted with `UID 33 is not unique` and the `adduser --system` fallback assigned UID 100, which chowned the bind-mounted framework to an unrelated host account (e.g. `syslog` on WSL) until `SetPermissions.pl` switched it to `www-data`. Existing containers are realigned on start.
- Map instance `www-data` to the host developer UID (`HOST_UID`/`HOST_GID` from `zd start`) so Linux/WSL bind mounts stay writable for Git. Existing compose files pick this up via the instance env file; new templates pass the variables explicitly.

## [1.0.0] - 2026-08-14

### Added

- Multi-instance Docker environment: run several Znuny frameworks in parallel via `znuny-dev.sh` / `zd`
- Multi-database support per instance: MariaDB, MySQL, or PostgreSQL
- Instance modes: shared DB (default) or dedicated DB + network per instance
- Automatic HTTP port assignment (`BASE_PORT`, default 10000+) and per-instance Compose generation
- Setup flow: `setup-all`, `setup-status`, `setup-env`, `setup-alias`, framework / tools / packages / Compose
- Instance lifecycle: create, remove, start, stop, restart, build, status (`--json`), logs, shell, console
- Global `zd` alias with shell tab-completion (bash/zsh)
- Host overrides via `configs/` (`instance/my.env`, `framework/Config.pm` injected on container start)
- Module-Tools integration: link/unlink packages and tools, dbinstall/codeinstall, install/uninstall
- Developer tools: Fred, ZnunyCodePolicy (link helpers included)
- `zd random-data-insert` for seed data on new instances
- Local web dashboard (`zd dashboard`, default `http://127.0.0.1:9999/`) with host opener for folder/IDE actions
- Docs: `docs/usage.md`, `docs/dashboard.md`; `zd help` / `zd examples` / `zd version`
- Built-in test suite entry (`zd test`) and GitHub Actions lint/unittest workflows
