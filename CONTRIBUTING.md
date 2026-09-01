# Contributing to Znuny-Dev

Thanks for helping improve the Znuny Multi-Instance Development Environment.

This guide covers how to report issues, propose changes, and open pull requests.

## Code of conduct

Be respectful and constructive. Focus on the technical problem and a clear fix.

## Ways to contribute

- Bug reports and reproductions
- Feature ideas and enhancements
- Documentation improvements
- Fixes and features for `znuny-dev.sh`, `dev/scripts/`, Docker setup, tests, or the local dashboard (`dev/dashboard/`)

## Before you start

1. Search [existing issues](https://github.com/dennykorsukewitz/Znuny-Dev/issues) and pull requests to avoid duplicates.
2. For larger changes, open an issue first so scope can be discussed.
3. Use the templates:
   - [Bug report](https://github.com/dennykorsukewitz/Znuny-Dev/issues/new?template=bug.md)
   - [Enhancement](https://github.com/dennykorsukewitz/Znuny-Dev/issues/new?template=enhancement.md)

## Development setup

Prerequisites and full walkthrough: [docs/setup.md](docs/setup.md)

Quick start:

```bash
git clone https://github.com/dennykorsukewitz/Znuny-Dev.git znuny-dev
cd znuny-dev
chmod -R +x dev/scripts
chmod +x znuny-dev.sh
./znuny-dev.sh setup-all
```

After setup, prefer the `zd` alias (or `./znuny-dev.sh` if the alias is not configured yet).

Useful commands:

```bash
zd status
zd help
./dev/test/run.sh
```

Optional local dashboard (UI from repo mount; restart after CSS/JS changes):

```bash
zd dashboard start
# http://127.0.0.1:9999/
```

Do not commit local-only files such as `.env`, instance data under `instances/`, or cloned trees under `frameworks/`, `packages/`, and `tools/` unless the change is intentionally part of the project templates.

## Branching

- Default branch: `dev`
- Branch naming is optional but recommended (best practice):
  - Pattern: `<topic>/<INITIALS>[/<issueID>]/<short-description>`
  - `<topic>`: `fix`, `feature`, `docs`, …
  - `<INITIALS>`: your initials (e.g. `DK`)
  - `/<issueID>`: optional GitHub issue number when one exists
- Examples:
  - `feature/DK/dashboard-restart`
  - `fix/DK/42/port-allocation`
  - `docs/DK/17/contributing-guide`

```bash
git checkout dev
git pull origin dev
git checkout -b feature/DK/42/my-change
```

## Coding guidelines

- Keep changes focused; avoid unrelated refactors.
- Match existing style in nearby files (Bash, Markdown, YAML, Dockerfile, dashboard JS/CSS).
- Prefer clear names and small functions over clever one-liners.
- Comments in English; explain *why* when the intent is not obvious.
- For Bash scripts under `dev/scripts/`, reuse helpers from `common.sh` when possible.
- Dashboard UI (`dev/dashboard/public`): edit on the host, then `zd dashboard restart`. Rebuild only when the Dockerfile changes (`zd dashboard build`).

## Tests and CI

Run the test suite locally before opening a PR:

```bash
./dev/test/run.sh
# or a single suite:
./dev/test/run.sh --test common
./dev/test/run.sh --verbose
```

Details: [dev/test/README.md](dev/test/README.md).

CI on GitHub:

- **Lint** — runs on push and pull requests
- **UnitTest** — runs the script test suite

PRs should keep Lint and UnitTest green.

## Commit messages

Use short, imperative English subjects (Conventional Commits style is welcome):

```text
feat: add dashboard restart action
fix: correct port allocation when BASE_PORT is set
docs: clarify ModuleTools link examples
test: cover compose path helpers

# With issue ID (prefer when a GitHub issue exists):
feat: add dashboard restart action (#42)
fix: correct port allocation when BASE_PORT is set (#17)

# Or reference in the body / footer:
fix: correct port allocation when BASE_PORT is set

Fixes #17
```

- Subject ideally ≤ 72 characters
- Body optional; use it for non-obvious *why*
- One logical change per commit when practical

## Changelog

User-facing or notable changes belong in [CHANGELOG.md](CHANGELOG.md) under `## [Unreleased]`, in the matching section (`Added`, `Changed`, `Fixed`, …).

Skip trivial typo-only or internal-only noise unless maintainers ask for an entry.

## Pull requests

1. Fork the repository (or use a branch with write access).
2. Push your topic branch.
3. Open a PR against `dev`.
4. Fill in the pull request template:
   - Expected behavior
   - Actual behavior
   - What you changed
5. Link related issues (`Fixes #123` / `Refs #123`).
6. Keep the PR focused; split large work into smaller PRs when possible.
7. Update docs (`README.md`, `docs/usage.md`, `docs/dashboard.md`, this file, or `dev/test/README.md`) when behavior or usage changes.

Maintainers may request changes. Please respond to review comments or mark discussion resolved when addressed.

## Reporting bugs

Include:

- Expected vs actual behavior
- Exact steps to reproduce (`zd …` commands help)
- OS, Docker version, Znuny-Dev version / commit
- Relevant logs (`zd log`, `zd container-log`, dashboard output)
- Screenshots if UI-related

## Suggesting enhancements

Describe:

- The problem or workflow gap
- Proposed behavior
- Why existing commands or config are not enough

## Security

Do not file public issues for sensitive security problems if disclosure could harm users. Contact the maintainer privately via GitHub ([@dennykorsukewitz](https://github.com/dennykorsukewitz)).

## License

By contributing, you agree that your contributions are licensed under the same terms as this project: **[GNU General Public License v3 (GPL-3.0)](LICENSE)**.

## Questions

- Open a GitHub issue for project discussion
- See [README.md](README.md) for setup
- See [docs/usage.md](docs/usage.md) for the full `zd` reference
- See [docs/dashboard.md](docs/dashboard.md) for the local dashboard
