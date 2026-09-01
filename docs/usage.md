# `zd` command reference

All operations go through `zd` (alias set by `setup-all` / `setup-alias`). From the project root, if the alias is missing, use `./znuny-dev.sh` instead.

**Tab-completion:** `setup-alias` sources `dev/completions/zd.zsh` (zsh) or `zd.bash` (bash). After setup, reload the shell (`source ~/.zshrc`). Then `zd ran` + Tab → `random-data-insert` (unique match completes immediately). Second argument completes known frameworks / `all`.

```bash
zd help       # Full command list (always up to date)
zd examples   # Concrete examples
zd dev        # Tests, release helpers, dashboard
zd version    # Version from RELEASE
```

Replace `<framework>` with your instance name (e.g. `dev`). Many instance commands also accept `all`.

When your shell is inside a checkout under `FRAMEWORKS_DIR` (e.g. `frameworks/dev` or a subdirectory), the framework argument is optional — `zd` detects it from the current working directory. An explicit argument always wins.

---

## Setup

Step-by-step installation: [setup.md](setup.md)

| Command | Purpose |
| --- | --- |
| `zd setup-status [--verbose]` | Setup status overview |
| `zd setup-all` | Full setup (framework, tools, instance) |
| `zd setup-remove` | Remove frameworks, tools, and instances |
| `zd setup-env` | Generate global `.env` from template |
| `zd setup-alias` | Install global `zd` alias + tab-completion |
| `zd setup-tools` | Clone/setup Fred, CodePolicy, module-tools |
| `zd setup-framework [<branch> <directory>]` | Setup framework (optional branch / dir) |
| `zd setup-packages` | Setup packages |
| `zd setup-compose` | Generate Compose files for all frameworks |

```bash
zd setup-status
zd setup-status --verbose
zd setup-all
```

---

## Instances

| Command | Purpose |
| --- | --- |
| `zd status [<framework>\|all] [--verbose]` | Instance status |
| `zd status --json` | JSON status (dashboard / scripting) |
| `zd create <framework> [options]` | Create instance |
| `zd sync-indices` | Rebuild `USED_FRAMEWORK_INDICES` after manual deletes |
| `zd remove <framework\|all> [options]` | Remove instance(s) |
| `zd start <framework\|all>` | Start |
| `zd stop <framework\|all>` | Stop |
| `zd restart <framework\|all>` | Restart |
| `zd build <framework\|all> [--no-cache]` | Build Docker image |
| `zd shell <framework> [options]` | Shell in container (default: `znuny` user) |
| `zd console <framework> <cmd>` | Znuny console command |
| `zd log <framework> [log_file]` | Framework log (default: `error.log`) |
| `zd container-log [<framework>] [lines]` | Docker stdout/stderr |
| `zd random-data-insert <framework> [options]` | RandomDataInsert |

```bash
zd status
zd status dev
zd status all --verbose
zd status --json

zd create dev
zd create prod --url https://github.com/znuny/Znuny.git --branch dev --port 10000

zd start dev
zd start all
zd stop dev
zd restart dev
zd build dev
zd build dev --no-cache
zd remove dev

zd shell dev
zd console dev Maint::Cache::Delete
zd console dev Maint::Config::Rebuild
zd console dev Dev::Tools::TranslationsUpdate

zd log dev
zd log dev access.log
zd container-log dev 100
zd container-log
```

---

## Common shortcuts

| Command | Purpose |
| --- | --- |
| `zd delreb <framework>` | Cache delete + loader cleanup + config rebuild |
| `zd delrebres <framework>` | Same as `delreb`, then restart instance |
| `zd reb <framework>` | Config rebuild (`--cleanup` on Znuny 7+) |
| `zd del <framework>` | Cache delete + loader cleanup |
| `zd unit <framework>` | Unit tests (`Dev::UnitTest::Run`) |
| `zd translate <framework>` | Config sync/rebuild + TranslationsUpdate |
| `zd contributors <framework>` | ContributorsListUpdate |
| `zd sql-schema <framework>` | XML2SQL for `*schema.xml` |
| `zd sql-initial-insert <framework>` | XML2SQL for `*initial_insert.xml` |
| `zd cpanm <framework> [options] <Module::Name> ...` | Install CPAN modules in container |
| `zd codepolicy <framework> [options\|paths]` | Znuny CodePolicy (default framework: `dev`) |

```bash
zd delreb dev
zd delrebres dev
zd reb dev
zd del dev
zd unit dev
zd translate dev
zd contributors dev
zd sql-schema dev
zd sql-initial-insert dev
zd cpanm dev CGI::Struct
zd cpanm dev --notest CGI::Struct
zd codepolicy dev
zd codepolicy dev --all-files
zd codepolicy dev --file-path Kernel/System/Ticket.pm
zd codepolicy dev --directory Kernel/System
zd random-data-insert dev
```

---

## Module-Tools

Commands run inside the instance via `znuny.ModuleTools.pl`.

- `<package>` — directory under `packages/` (e.g. `FAQ`)
- `<tool>` — directory under `tools/` (e.g. `Fred`, `ZnunyCodePolicy`)
- `--only` — link/unlink only (no install side effects where applicable)

### Package linking (`/opt/packages/`)

```bash
zd link <framework> <package> [package ...] [--only]
zd unlink <framework> <package> [package ...] [--only]
zd rmlinks <framework>
```

### Tool linking (`/opt/tools/`)

```bash
zd link-tool <framework> <tool> [tool ...] [--only]
zd unlink-tool <framework> <tool> [tool ...] [--only]

# Shortcuts (often used)
zd link-fred <framework>
zd unlink-fred <framework>
zd link-codepolicy <framework>
zd unlink-codepolicy <framework>
```

### Package install / uninstall

```bash
zd install <framework> <package>        # DB + code install
zd uninstall <framework> <package>      # DB + code uninstall

zd dbinstall <framework> <package>
zd dbupgrade <framework> <package>
zd dbuninstall <framework> <package>

zd codeinstall <framework> <package>
zd codereinstall <framework> <package>
zd codeuninstall <framework> <package>
zd codeupgrade <framework> <package>
```

### Direct module-tools

```bash
zd module-tools <framework>             # List available commands
zd module-tools <framework> <command> [args...]
zd module-tools <framework> List
```

### Examples

```bash
zd link dev FAQ
zd link dev FAQ --only
zd unlink dev FAQ
zd link-tool dev Fred
zd link-tool dev ZnunyCodePolicy
zd link-fred dev
zd link-codepolicy dev
zd rmlinks dev

zd install dev FAQ
zd uninstall dev FAQ
zd dbinstall dev FAQ
zd codeinstall dev FAQ
```

---

## Development helpers

See also `zd dev`.

| Command | Purpose |
| --- | --- |
| `zd test` | Run all test suites |
| `zd test --verbose` | Verbose tests |
| `zd test --test <name>` | Specific suite |
| `zd release` | Auto-increment patch in `RELEASE` |
| `zd release <version>` | Set version (e.g. `1.0.0`) |

```bash
zd test
zd test -v -t instance
zd release 1.0.0
```

---

## Dashboard

Local web UI for instance overview. See [dashboard.md](dashboard.md).

```bash
zd dashboard start
zd dashboard restart
zd dashboard stop
zd dashboard status
```

Default URL: `http://127.0.0.1:9999/`
